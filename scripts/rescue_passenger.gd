extends Node2D

const PICKUP_DISTANCE := 20.0
const MOVE_SPEED := 76.0

var passenger_id := ""
var _sync_timer := 0.0
var _target_position := Vector2.ZERO
var _has_authoritative_state := false

func configure(identifier: String, spawn_position: Vector2) -> void:
	passenger_id = identifier
	global_position = spawn_position

func _ready() -> void:
	add_to_group("rescue_passengers")
	_target_position = global_position
	queue_redraw()

func _physics_process(delta: float) -> void:
	if NetworkSession.is_networked and not multiplayer.is_server():
		if _has_authoritative_state:
			global_position = global_position.lerp(_target_position, minf(1.0, delta * 12.0))
		return

	var target := _nearest_player_with_space()
	if target != null:
		var offset: Vector2 = target.global_position - global_position
		if offset.length() <= PICKUP_DISTANCE:
			if bool(target.call("try_add_passenger")):
				if NetworkSession.is_networked:
					for peer_id in NetworkSession.connected_peer_ids():
						rpc_id(peer_id, "rpc_passenger_boarded")
				queue_free()
				return
		else:
			global_position = global_position.move_toward(
				target.global_position,
				MOVE_SPEED * delta
			)

	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 0.05
		if NetworkSession.is_networked and NetworkSession.is_host:
			for peer_id in NetworkSession.connected_peer_ids():
				rpc_id(peer_id, "rpc_receive_position", global_position)

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_receive_position(world_position: Vector2) -> void:
	if not NetworkSession.is_networked or multiplayer.is_server():
		return
	_target_position = world_position
	_has_authoritative_state = true

@rpc("authority", "call_remote", "reliable")
func rpc_passenger_boarded() -> void:
	if not multiplayer.is_server():
		queue_free()

func _nearest_player_with_space() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("players"):
		if not candidate is Node2D or not candidate.visible:
			continue
		if not candidate.has_method("has_passenger_space"):
			continue
		if not bool(candidate.call("has_passenger_space")):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

func _draw() -> void:
	draw_circle(Vector2(0.0, 7.0), 5.0, Color(0.18, 0.17, 0.14))
	draw_rect(Rect2(-4.0, -4.0, 8.0, 11.0), Color(0.79, 0.73, 0.53))
	draw_circle(Vector2(0.0, -7.0), 4.0, Color(0.72, 0.54, 0.38))
	draw_line(Vector2(-4.0, 0.0), Vector2(-8.0, 6.0), Color(0.73, 0.67, 0.48), 2.0)
	draw_line(Vector2(4.0, 0.0), Vector2(8.0, 6.0), Color(0.73, 0.67, 0.48), 2.0)

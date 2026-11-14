extends Node2D

const PICKUP_DISTANCE := 20.0
const MOVE_SPEED := 76.0
const PATH_REFRESH_INTERVAL := 0.35
const WAYPOINT_DISTANCE := 7.0
const PASSENGER_TEXTURE := preload("res://assets/art/rescue_prisoner_v2.png")

var passenger_id := ""
var _sync_timer := 0.0
var _target_position := Vector2.ZERO
var _has_authoritative_state := false
var _ground_path := PackedVector2Array()
var _path_index := 0
var _path_refresh_timer := 0.0
var _last_target_position := Vector2(INF, INF)
var _walk_phase := 0.0
var _walk_strength := 0.0
var _visual_moving := false
var _passenger_region := Rect2()

func configure(identifier: String, spawn_position: Vector2) -> void:
	passenger_id = identifier
	global_position = spawn_position

func _ready() -> void:
	add_to_group("rescue_passengers")
	_target_position = global_position
	_passenger_region = Rect2(PASSENGER_TEXTURE.get_image().get_used_rect())
	queue_redraw()

func _physics_process(delta: float) -> void:
	if NetworkSession.is_networked and not multiplayer.is_server():
		if _has_authoritative_state:
			var previous_position := global_position
			global_position = global_position.lerp(_target_position, minf(1.0, delta * 12.0))
			_update_walk_animation(global_position.distance_squared_to(previous_position) > 0.0025, delta)
		return

	_visual_moving = false
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
			_follow_ground_path(target, delta)
	_update_walk_animation(_visual_moving, delta)

	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 0.05
		if NetworkSession.is_networked and NetworkSession.is_host:
			for peer_id in NetworkSession.connected_peer_ids():
				rpc_id(peer_id, "rpc_receive_position", global_position, rotation)

func _follow_ground_path(target: Node2D, delta: float) -> void:
	_path_refresh_timer -= delta
	if (
		_path_refresh_timer <= 0.0
		or _ground_path.is_empty()
		or _last_target_position.distance_to(target.global_position) > 48.0
	):
		_path_refresh_timer = PATH_REFRESH_INTERVAL
		_last_target_position = target.global_position
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("passenger_ground_path"):
			_ground_path = scene.call("passenger_ground_path", global_position, target.global_position)
		else:
			_ground_path = PackedVector2Array([target.global_position])
		_path_index = 0
	if _ground_path.is_empty():
		return
	while _path_index < _ground_path.size() - 1 and global_position.distance_to(_ground_path[_path_index]) <= WAYPOINT_DISTANCE:
		_path_index += 1
	var destination := _ground_path[mini(_path_index, _ground_path.size() - 1)]
	var movement := destination - global_position
	if movement.length_squared() <= 0.01:
		return
	var direction := movement.normalized()
	rotation = lerp_angle(rotation, direction.angle() + PI * 0.5, minf(1.0, delta * 10.0))
	global_position = global_position.move_toward(destination, MOVE_SPEED * delta)
	_visual_moving = true

func _update_walk_animation(moving: bool, delta: float) -> void:
	_visual_moving = moving
	_walk_strength = move_toward(_walk_strength, 1.0 if moving else 0.0, delta * 8.0)
	if moving:
		_walk_phase = fposmod(_walk_phase + delta * 12.0, TAU)
	queue_redraw()

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_receive_position(world_position: Vector2, facing_rotation: float) -> void:
	if not NetworkSession.is_networked or multiplayer.is_server():
		return
	_target_position = world_position
	rotation = facing_rotation
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
	var stride := sin(_walk_phase) * _walk_strength
	var bob := absf(sin(_walk_phase * 2.0)) * -1.25 * _walk_strength
	var sway := stride * 0.85
	var squash := 1.0 - absf(stride) * 0.03
	draw_set_transform(Vector2(1.0, 6.0), 0.0, Vector2(10.0 + absf(stride), 6.5))
	draw_circle(Vector2.ZERO, 1.0, Color(0.0, 0.0, 0.0, 0.25))
	draw_set_transform(Vector2(sway, bob), stride * 0.03, Vector2(1.0 / squash, squash))
	draw_texture_rect_region(PASSENGER_TEXTURE, Rect2(-14.0, -18.0, 28.0, 36.0), _passenger_region)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func passenger_visual_signature() -> Dictionary:
	return {
		"camera": "orthographic_top_down",
		"walk_animation": true,
		"walk_phase": _walk_phase,
		"texture_width": PASSENGER_TEXTURE.get_width(),
		"texture_height": PASSENGER_TEXTURE.get_height(),
		"has_alpha": PASSENGER_TEXTURE.get_image().detect_alpha() != Image.ALPHA_NONE,
		"armed": false,
		"uses_ground_path": true,
	}

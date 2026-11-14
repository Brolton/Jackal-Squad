extends StaticBody2D

const BASE_HEALTH := 30

var maximum_health := BASE_HEALTH
var health := BASE_HEALTH
var _destroyed := false

func configure_coop_scaling(player_count: int) -> void:
	maximum_health = BASE_HEALTH + maxi(0, player_count - 1) * 8
	health = maximum_health

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	add_to_group("final_base")
	queue_redraw()

func take_damage(amount: int, attacker_peer_id: int = 0) -> void:
	if amount <= 0 or _destroyed:
		return
	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	health = maxi(health - amount, 0)
	queue_redraw()
	if NetworkSession.is_networked and NetworkSession.is_host:
		for peer_id in NetworkSession.connected_peer_ids():
			rpc_id(peer_id, "rpc_receive_health", health)
	if health == 0:
		_destroy(attacker_peer_id)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_health(current_health: int) -> void:
	if NetworkSession.is_host or _destroyed:
		return
	health = clampi(current_health, 0, maximum_health)
	queue_redraw()

@rpc("authority", "call_remote", "reliable")
func rpc_destroy_base() -> void:
	if NetworkSession.is_host or _destroyed:
		return
	_destroyed = true
	queue_free()

func _destroy(attacker_peer_id: int) -> void:
	_destroyed = true
	NetworkSession.record_final_base_destroyed(attacker_peer_id)
	if NetworkSession.is_networked and NetworkSession.is_host:
		rpc("rpc_destroy_base")
	queue_free()

func _draw() -> void:
	draw_rect(Rect2(-86.0, -32.0, 172.0, 82.0), Color(0.0, 0.0, 0.0, 0.30))
	draw_rect(Rect2(-78.0, -38.0, 156.0, 76.0), Color(0.13, 0.17, 0.15))
	draw_rect(Rect2(-68.0, -31.0, 136.0, 62.0), Color(0.36, 0.40, 0.30))
	draw_rect(Rect2(-40.0, -18.0, 80.0, 45.0), Color(0.25, 0.29, 0.23))
	draw_rect(Rect2(-17.0, -7.0, 34.0, 34.0), Color(0.15, 0.19, 0.18))
	draw_rect(Rect2(-4.0, -27.0, 8.0, 28.0), Color(0.17, 0.20, 0.16))
	for window_x in [-54.0, -34.0, 34.0, 54.0]:
		draw_rect(Rect2(window_x - 5.0, -18.0, 10.0, 8.0), Color(0.92, 0.63, 0.24, 0.88))
	draw_circle(Vector2(0, -32), 10.0, Color(0.19, 0.25, 0.22))
	draw_line(Vector2(-13, -32), Vector2(13, -32), Color(0.72, 0.75, 0.57), 2.0)
	draw_line(Vector2(-84.0, -40.0), Vector2(84.0, -40.0), Color(0.71, 0.63, 0.38), 3.0)
	draw_rect(Rect2(-70.0, -54.0, 140.0, 7.0), Color(0.10, 0.11, 0.10))
	draw_rect(
		Rect2(-68.0, -52.0, 136.0 * float(health) / float(maximum_health), 3.0),
		Color(0.82, 0.30, 0.20)
	)

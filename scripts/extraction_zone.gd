extends Area2D

@export var helicopter_interval := 18.0
@export var helicopter_speed := 400.0

enum HelicopterState { IDLE, APPROACHING, LANDED, DEPARTING }

const PASSENGER_TEXTURE := preload("res://assets/art/rescue_prisoner_v2.png")

var _helicopter_timer := 0.0
var _helicopter_x := -700.0
var _helicopter_active := false
var _helicopter_state := HelicopterState.IDLE
var _rotor_phase := 0.0
var _landed_clear_time := 0.0
var _waiting_players: Array[Node2D] = []
var _boarding_visuals: Array[Dictionary] = []
var _last_evacuated_count := 0
var _passenger_region := Rect2()

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = not NetworkSession.is_networked or multiplayer.is_server()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_helicopter_timer = helicopter_interval
	_last_evacuated_count = NetworkSession.evacuated_passengers
	_passenger_region = Rect2(PASSENGER_TEXTURE.get_image().get_used_rect())
	add_to_group("extraction_zones")
	queue_redraw()

func _physics_process(delta: float) -> void:
	_rotor_phase = fposmod(_rotor_phase + delta * (20.0 if _helicopter_active else 3.0), TAU)
	_update_boarding_visuals(delta)
	match _helicopter_state:
		HelicopterState.APPROACHING:
			_helicopter_x = move_toward(_helicopter_x, 0.0, helicopter_speed * delta)
			if is_zero_approx(_helicopter_x):
				_helicopter_state = HelicopterState.LANDED
				_landed_clear_time = 0.0
				if not NetworkSession.is_networked or multiplayer.is_server():
					_set_waiting_players_extraction(true)
		HelicopterState.LANDED:
			if not NetworkSession.is_networked or multiplayer.is_server():
				_update_landed_departure(delta)
		HelicopterState.DEPARTING:
			_helicopter_x += helicopter_speed * delta
			if _helicopter_x >= 700.0:
				_helicopter_state = HelicopterState.IDLE
				_helicopter_active = false
				_helicopter_timer = helicopter_interval
				if not NetworkSession.is_networked or multiplayer.is_server():
					NetworkSession.collect_evacuated_passengers()
	queue_redraw()

func _update_landed_departure(delta: float) -> void:
	_cleanup_waiting_players()
	_set_waiting_players_extraction(true)
	var has_cargo := false
	for player in _waiting_players:
		if int(player.get("passenger_count")) > 0:
			has_cargo = true
			break
	if has_cargo or not _boarding_visuals.is_empty():
		_landed_clear_time = 0.0
		return
	_landed_clear_time += delta
	if _landed_clear_time >= 0.75:
		_begin_departure()

func _update_boarding_visuals(delta: float) -> void:
	var evacuated_now := NetworkSession.evacuated_passengers
	if _helicopter_state == HelicopterState.LANDED and evacuated_now > _last_evacuated_count:
		for _index in range(evacuated_now - _last_evacuated_count):
			_boarding_visuals.append({"progress": 0.0, "from": _boarding_start_position()})
	_last_evacuated_count = evacuated_now
	for index in range(_boarding_visuals.size() - 1, -1, -1):
		var visual: Dictionary = _boarding_visuals[index]
		visual["progress"] = float(visual["progress"]) + delta / 0.72
		if float(visual["progress"]) >= 1.0:
			_boarding_visuals.remove_at(index)
		else:
			_boarding_visuals[index] = visual

func _boarding_start_position() -> Vector2:
	for player in _waiting_players:
		if is_instance_valid(player):
			return to_local(player.global_position) + Vector2(0.0, -18.0)
	return Vector2(0.0, 64.0)

func _start_helicopter() -> void:
	if _helicopter_state != HelicopterState.IDLE or _another_pad_has_helicopter():
		return
	_helicopter_x = -700.0
	_helicopter_state = HelicopterState.APPROACHING
	_helicopter_active = true
	_landed_clear_time = 0.0
	queue_redraw()
	if NetworkSession.is_networked:
		for peer_id in NetworkSession.connected_peer_ids():
			rpc_id(peer_id, "rpc_start_helicopter")

func _begin_departure() -> void:
	if _helicopter_state != HelicopterState.LANDED:
		return
	_set_waiting_players_extraction(false)
	_helicopter_state = HelicopterState.DEPARTING
	if NetworkSession.is_networked:
		for peer_id in NetworkSession.connected_peer_ids():
			rpc_id(peer_id, "rpc_depart_helicopter")

func _another_pad_has_helicopter() -> bool:
	for zone in get_tree().get_nodes_in_group("extraction_zones"):
		if zone != self and bool(zone.get("_helicopter_active")):
			return true
	return false

@rpc("authority", "call_remote", "reliable")
func rpc_start_helicopter() -> void:
	if NetworkSession.is_host:
		return
	_helicopter_x = -700.0
	_helicopter_state = HelicopterState.APPROACHING
	_helicopter_active = true
	_landed_clear_time = 0.0
	queue_redraw()

@rpc("authority", "call_remote", "reliable")
func rpc_depart_helicopter() -> void:
	if NetworkSession.is_host:
		return
	_helicopter_state = HelicopterState.DEPARTING
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players") or not body.has_method("set_extraction_active"):
		return
	if not _waiting_players.has(body):
		_waiting_players.append(body)
	if _helicopter_state == HelicopterState.LANDED:
		body.call("set_extraction_active", true)
	elif int(body.get("passenger_count")) > 0:
		_start_helicopter()

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("players") or not body.has_method("set_extraction_active"):
		return
	body.call("set_extraction_active", false)
	_waiting_players.erase(body)

func _cleanup_waiting_players() -> void:
	for index in range(_waiting_players.size() - 1, -1, -1):
		if not is_instance_valid(_waiting_players[index]) or not _waiting_players[index].visible:
			_waiting_players.remove_at(index)

func _set_waiting_players_extraction(active: bool) -> void:
	_cleanup_waiting_players()
	for player in _waiting_players:
		player.call("set_extraction_active", active)

func _draw() -> void:
	_draw_helipad()
	if _helicopter_active:
		_draw_helicopter(Vector2(_helicopter_x, -8.0))
	for visual in _boarding_visuals:
		var progress := clampf(float(visual["progress"]), 0.0, 1.0)
		var start: Vector2 = visual["from"]
		var finish := Vector2(_helicopter_x - 4.0, 10.0)
		var passenger_position := start.lerp(finish, progress)
		var bob := -absf(sin(progress * PI * 8.0)) * 2.0
		draw_texture_rect_region(
			PASSENGER_TEXTURE,
			Rect2(passenger_position + Vector2(-9.0, -12.0 + bob), Vector2(18.0, 24.0)),
			_passenger_region
		)

func _draw_helipad() -> void:
	draw_circle(Vector2(5.0, 8.0), 94.0, Color(0.0, 0.0, 0.0, 0.28))
	draw_circle(Vector2.ZERO, 92.0, Color(0.20, 0.25, 0.22, 0.94))
	draw_circle(Vector2.ZERO, 82.0, Color(0.43, 0.47, 0.39, 0.92))
	draw_arc(Vector2.ZERO, 83.0, 0.0, TAU, 64, Color(0.92, 0.84, 0.48, 0.95), 5.0)
	for angle_index in range(8):
		var angle := TAU * float(angle_index) / 8.0
		var direction := Vector2.from_angle(angle)
		draw_line(direction * 68.0, direction * 80.0, Color(0.94, 0.88, 0.56), 4.0)
	draw_string(ThemeDB.fallback_font, Vector2(-31.0, 27.0), "H", HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Color(0.94, 0.92, 0.72, 0.96))
	var status := "BOARDING" if _helicopter_state == HelicopterState.LANDED else "WAIT FOR HELICOPTER"
	draw_string(ThemeDB.fallback_font, Vector2(-72.0, 116.0), status, HORIZONTAL_ALIGNMENT_CENTER, 144.0, 11, Color(0.84, 0.94, 0.76, 0.94))

func _draw_helicopter(center: Vector2) -> void:
	var body_color := Color(0.43, 0.48, 0.29)
	var highlight := Color(0.68, 0.70, 0.42)
	draw_ellipse_shadow(center + Vector2(5, 18), Vector2(34, 9), Color(0.0, 0.0, 0.0, 0.30))
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-27, -10), center + Vector2(20, -12),
		center + Vector2(33, 0), center + Vector2(18, 13),
		center + Vector2(-27, 11), center + Vector2(-37, 0),
	]), body_color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(23, -9), center + Vector2(5, -11),
		center + Vector2(9, 2), center + Vector2(30, 3),
	]), Color(0.20, 0.37, 0.40))
	draw_line(center + Vector2(-26, 0), center + Vector2(-65, 3), body_color, 7.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-57, 2), center + Vector2(-72, -14), center + Vector2(-69, 5),
	]), highlight)
	draw_circle(center, 7.0, Color(0.18, 0.21, 0.16))
	var rotor_direction := Vector2(cos(_rotor_phase), sin(_rotor_phase) * 0.22)
	draw_line(center - rotor_direction * 49.0, center + rotor_direction * 49.0, Color(0.12, 0.15, 0.13), 3.0)
	draw_circle(center + Vector2(-68, 3), 9.0, Color(0.10, 0.13, 0.12), false, 2.0)
	draw_line(center + Vector2(-68, -6), center + Vector2(-68, 12), Color(0.15, 0.18, 0.15), 2.0)
	draw_line(center + Vector2(-77, 3), center + Vector2(-59, 3), Color(0.15, 0.18, 0.15), 2.0)
	draw_line(center + Vector2(-20, 14), center + Vector2(-13, 20), Color(0.13, 0.16, 0.13), 3.0)
	draw_line(center + Vector2(17, 14), center + Vector2(24, 20), Color(0.13, 0.16, 0.13), 3.0)

func draw_ellipse_shadow(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y))
	draw_colored_polygon(points, color)

func helicopter_visual_signature() -> Dictionary:
	return {
		"travel_direction_x": signf(helicopter_speed),
		"cockpit_offset_x": 18.0,
		"tail_offset_x": -68.0,
		"landing_pad": true,
		"pad_label": "H",
		"staged_boarding": true,
		"helicopter_state": _helicopter_state,
		"boarding_visuals": _boarding_visuals.size(),
	}

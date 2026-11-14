extends Area2D

@export var helicopter_interval := 18.0
@export var helicopter_speed := 400.0

var _helicopter_timer := 0.0
var _helicopter_x := 0.0
var _helicopter_active := false
var _rotor_phase := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = not NetworkSession.is_networked or multiplayer.is_server()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_helicopter_timer = helicopter_interval
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _helicopter_active:
		_helicopter_x += helicopter_speed * delta
		_rotor_phase = fposmod(_rotor_phase + delta * 18.0, TAU)
		queue_redraw()
		if _helicopter_x >= 700.0:
			_helicopter_active = false
			queue_redraw()
			if not NetworkSession.is_networked or multiplayer.is_server():
				NetworkSession.collect_evacuated_passengers()
				_helicopter_timer = helicopter_interval

	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	_helicopter_timer -= delta
	if _helicopter_timer <= 0.0 and not _helicopter_active:
		if NetworkSession.evacuated_passengers > 0:
			_start_helicopter()
		else:
			_helicopter_timer = helicopter_interval

func _start_helicopter() -> void:
	_helicopter_x = -700.0
	_helicopter_active = true
	queue_redraw()
	if NetworkSession.is_networked:
		for peer_id in NetworkSession.connected_peer_ids():
			rpc_id(peer_id, "rpc_start_helicopter")

@rpc("authority", "call_remote", "reliable")
func rpc_start_helicopter() -> void:
	if NetworkSession.is_host:
		return
	_helicopter_x = -700.0
	_helicopter_active = true
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players") or not body.has_method("set_extraction_active"):
		return
	body.call("set_extraction_active", true)

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("players") or not body.has_method("set_extraction_active"):
		return
	body.call("set_extraction_active", false)

func _draw() -> void:
	draw_circle(Vector2.ZERO, 88.0, Color(0.12, 0.45, 0.49, 0.20))
	draw_rect(Rect2(-220.0, -90.0, 440.0, 180.0), Color(0.54, 0.77, 0.69, 0.8), false, 3.0)
	for x in range(-200, 201, 40):
		draw_line(Vector2(x, -82.0), Vector2(x, 82.0), Color(0.59, 0.76, 0.65, 0.30), 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-92, 6), "OPTIONAL RESCUE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.70, 0.95, 0.82, 0.90))
	draw_string(ThemeDB.fallback_font, Vector2(-61, 25), "+ REPAIR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.94, 0.78, 0.36, 0.90))
	if _helicopter_active:
		_draw_helicopter(Vector2(_helicopter_x, -122.0))

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
		center + Vector2(-23, -9), center + Vector2(-5, -11),
		center + Vector2(-9, 2), center + Vector2(-30, 3),
	]), Color(0.20, 0.37, 0.40))
	draw_line(center + Vector2(26, 0), center + Vector2(65, 3), body_color, 7.0)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(57, 2), center + Vector2(72, -14), center + Vector2(69, 5),
	]), highlight)
	draw_circle(center, 7.0, Color(0.18, 0.21, 0.16))
	var rotor_direction := Vector2(cos(_rotor_phase), sin(_rotor_phase) * 0.22)
	draw_line(center - rotor_direction * 49.0, center + rotor_direction * 49.0, Color(0.12, 0.15, 0.13), 3.0)
	draw_circle(center + Vector2(68, 3), 9.0, Color(0.10, 0.13, 0.12), false, 2.0)
	draw_line(center + Vector2(68, -6), center + Vector2(68, 12), Color(0.15, 0.18, 0.15), 2.0)
	draw_line(center + Vector2(59, 3), center + Vector2(77, 3), Color(0.15, 0.18, 0.15), 2.0)
	draw_line(center + Vector2(-20, 14), center + Vector2(-13, 20), Color(0.13, 0.16, 0.13), 3.0)
	draw_line(center + Vector2(17, 14), center + Vector2(24, 20), Color(0.13, 0.16, 0.13), 3.0)

func draw_ellipse_shadow(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y))
	draw_colored_polygon(points, color)

extends Area2D

var upgrade_type: StringName = &"primary"
var _pulse := 0.0

func configure(kind: StringName) -> void:
	upgrade_type = kind

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = not NetworkSession.is_networked or multiplayer.is_server()
	body_entered.connect(_on_body_entered)
	add_to_group("weapon_upgrades")
	queue_redraw()

func _process(delta: float) -> void:
	_pulse = fposmod(_pulse + delta * 3.2, TAU)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	if not body.is_in_group("players") or not body.has_method("apply_weapon_upgrade"):
		return
	if not bool(body.call("apply_weapon_upgrade", upgrade_type)):
		return
	AudioDirector.play_sfx(&"upgrade_gun" if upgrade_type == &"primary" else &"upgrade_blast")
	if NetworkSession.is_networked:
		NetworkSession.replicate_upgrade_pickup_collected(name)
	queue_free()

func _draw() -> void:
	var primary := upgrade_type == &"primary"
	var color := Color(1.0, 0.70, 0.18) if primary else Color(0.25, 0.82, 1.0)
	var pulse_radius := 25.0 + sin(_pulse) * 3.0
	draw_circle(Vector2(2, 5), 24.0, Color(0.0, 0.0, 0.0, 0.34))
	draw_circle(Vector2.ZERO, pulse_radius, Color(color.r, color.g, color.b, 0.12), false, 3.0)
	draw_circle(Vector2.ZERO, 21.0, Color(0.04, 0.08, 0.08, 0.94))
	draw_circle(Vector2.ZERO, 17.0, color.darkened(0.16))
	draw_arc(Vector2.ZERO, 21.0, 0.0, TAU, 32, color.lightened(0.35), 3.0)
	if primary:
		for x in [-8.0, 8.0]:
			draw_line(Vector2(x, 7), Vector2(x, -11), Color(0.09, 0.12, 0.11), 4.0)
			draw_circle(Vector2(x, -11), 2.0, Color(1.0, 0.92, 0.52))
		draw_string(ThemeDB.fallback_font, Vector2(-10, 5), "MG", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.10, 0.10, 0.08))
		draw_string(ThemeDB.fallback_font, Vector2(-27, 39), "DUAL MG", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color.lightened(0.25))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-5, 6), Vector2(0, -13), Vector2(5, 6)]), Color(0.88, 0.91, 0.82))
		draw_colored_polygon(PackedVector2Array([Vector2(-5, 4), Vector2(-10, 10), Vector2(-4, 9), Vector2(4, 9), Vector2(10, 10), Vector2(5, 4)]), Color(0.24, 0.31, 0.31))
		draw_colored_polygon(PackedVector2Array([Vector2(-4, 9), Vector2(0, 17), Vector2(4, 9)]), Color(1.0, 0.42, 0.10))
		draw_string(ThemeDB.fallback_font, Vector2(-24, 39), "ROCKETS", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color.lightened(0.25))

func upgrade_visual_signature() -> Dictionary:
	return {
		"type": upgrade_type,
		"label": "DUAL MG" if upgrade_type == &"primary" else "ROCKETS",
		"icon": "multi_barrel" if upgrade_type == &"primary" else "rocket",
	}

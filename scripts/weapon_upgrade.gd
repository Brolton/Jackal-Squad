extends Area2D

var upgrade_type: StringName = &"primary"

func configure(kind: StringName) -> void:
	upgrade_type = kind

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = not NetworkSession.is_networked or multiplayer.is_server()
	body_entered.connect(_on_body_entered)
	add_to_group("weapon_upgrades")
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	if not body.is_in_group("players") or not body.has_method("apply_weapon_upgrade"):
		return
	if not bool(body.call("apply_weapon_upgrade", upgrade_type)):
		return
	AudioDirector.play_sfx(&"pickup")
	if NetworkSession.is_networked:
		NetworkSession.replicate_upgrade_pickup_collected(name)
	queue_free()

func _draw() -> void:
	var color := Color(0.94, 0.68, 0.22) if upgrade_type == &"primary" else Color(0.35, 0.72, 0.82)
	draw_circle(Vector2.ZERO, 18.0, Color(0.07, 0.09, 0.07, 0.86))
	draw_circle(Vector2.ZERO, 14.0, color)
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color(0.92, 0.88, 0.65), 2.0)
	if upgrade_type == &"primary":
		draw_rect(Rect2(-3.0, -10.0, 6.0, 16.0), Color(0.12, 0.16, 0.13))
		draw_rect(Rect2(-7.0, 1.0, 14.0, 5.0), Color(0.12, 0.16, 0.13))
	else:
		draw_circle(Vector2.ZERO, 6.0, Color(0.12, 0.16, 0.13))
		draw_circle(Vector2.ZERO, 2.5, color.lightened(0.3))

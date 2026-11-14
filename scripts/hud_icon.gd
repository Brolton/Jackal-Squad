extends Control

@export var icon_kind: StringName = &"machine_gun"
@export var tint := Color.WHITE

func _draw() -> void:
	match icon_kind:
		&"heart":
			_draw_heart()
		&"passengers":
			_draw_passengers()
		&"machine_gun":
			_draw_machine_gun()
		&"grenade":
			_draw_grenade()
		&"rocket":
			_draw_rocket()
		&"clock":
			_draw_clock()

func _draw_heart() -> void:
	var points := PackedVector2Array([
		Vector2(11, 20), Vector2(2, 11), Vector2(0.5, 8), Vector2(1, 5),
		Vector2(3, 2.5), Vector2(6, 2), Vector2(8.5, 3.5), Vector2(11, 6),
		Vector2(13.5, 3.5), Vector2(16, 2), Vector2(19, 2.5), Vector2(21, 5),
		Vector2(21.5, 8), Vector2(20, 11),
	])
	draw_colored_polygon(points, tint)

func _draw_passengers() -> void:
	draw_circle(Vector2(7, 6), 3.2, tint)
	draw_circle(Vector2(16, 7), 2.8, tint)
	draw_rect(Rect2(3, 10, 8, 9), tint, true)
	draw_rect(Rect2(13, 11, 7, 8), tint, true)

func _draw_machine_gun() -> void:
	draw_rect(Rect2(6, 8, 11, 6), tint, true)
	draw_rect(Rect2(16, 9, 6, 3), tint, true)
	draw_rect(Rect2(3, 9, 4, 4), tint, true)
	draw_line(Vector2(10, 14), Vector2(9, 19), tint, 2.5)
	draw_line(Vector2(14, 14), Vector2(16, 18), tint, 2.5)
	draw_line(Vector2(8, 7), Vector2(15, 7), tint, 2.0)

func _draw_grenade() -> void:
	draw_circle(Vector2(11, 13), 7, tint)
	draw_rect(Rect2(9, 3, 5, 3), tint, true)
	draw_line(Vector2(13, 3), Vector2(17, 1), tint, 1.8)
	draw_line(Vector2(7, 8), Vector2(15, 16), tint.darkened(0.3), 1.2)

func _draw_rocket() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(4, 18), Vector2(7, 9), Vector2(15, 2), Vector2(19, 1),
		Vector2(18, 6), Vector2(11, 14),
	]), tint)
	draw_colored_polygon(PackedVector2Array([
		Vector2(7, 13), Vector2(3, 13), Vector2(2, 19), Vector2(9, 16),
	]), tint.darkened(0.25))
	draw_circle(Vector2(15, 6), 1.5, tint.darkened(0.4))

func _draw_clock() -> void:
	draw_arc(Vector2(11, 11), 9, 0.0, TAU, 32, tint, 2.0, true)
	draw_line(Vector2(11, 11), Vector2(11, 5), tint, 2.0)
	draw_line(Vector2(11, 11), Vector2(16, 13), tint, 2.0)

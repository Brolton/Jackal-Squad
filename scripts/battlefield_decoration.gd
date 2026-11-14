extends Node2D

var kind: StringName = &"tent"
var decoration_scale := 1.0
var _pulse := 0.0

func configure(decoration_kind: StringName, visual_scale: float = 1.0) -> void:
	kind = decoration_kind
	decoration_scale = visual_scale
	scale = Vector2.ONE * decoration_scale

func _ready() -> void:
	z_index = -1
	add_to_group("battlefield_decorations")
	if kind == &"fire":
		set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if kind != &"fire":
		set_process(false)
		return
	_pulse += delta
	queue_redraw()

func _draw() -> void:
	match kind:
		&"tent":
			_draw_tent()
		&"watchtower":
			_draw_watchtower()
		&"bunker":
			_draw_bunker()
		&"fire":
			_draw_fire()
		&"antenna":
			_draw_antenna()
		&"ruins":
			_draw_ruins()
		&"barricade":
			_draw_barricade()

func _draw_tent() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-32, -19), Vector2(32, -19), Vector2(38, 22), Vector2(-38, 22)]), Color(0, 0, 0, 0.28))
	draw_colored_polygon(PackedVector2Array([Vector2(-30, -22), Vector2(30, -22), Vector2(36, 18), Vector2(-36, 18)]), Color(0.38, 0.42, 0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(-30, -22), Vector2.ZERO, Vector2(-36, 18)]), Color(0.27, 0.31, 0.19))
	draw_line(Vector2(0, -22), Vector2(0, 18), Color(0.67, 0.61, 0.37), 3.0)
	draw_line(Vector2(-28, 14), Vector2(28, 14), Color(0.18, 0.21, 0.14), 3.0)

func _draw_watchtower() -> void:
	draw_circle(Vector2(5, 7), 30, Color(0, 0, 0, 0.24))
	for corner in [Vector2(-22, -22), Vector2(22, -22), Vector2(-22, 22), Vector2(22, 22)]:
		draw_line(corner, corner * 0.55, Color(0.23, 0.18, 0.12), 5.0)
	draw_rect(Rect2(-22, -22, 44, 44), Color(0.34, 0.26, 0.16))
	draw_rect(Rect2(-17, -17, 34, 34), Color(0.57, 0.46, 0.28), false, 4.0)
	draw_circle(Vector2.ZERO, 7, Color(0.12, 0.16, 0.14))

func _draw_bunker() -> void:
	draw_circle(Vector2(4, 6), 34, Color(0, 0, 0, 0.30))
	draw_circle(Vector2.ZERO, 32, Color(0.28, 0.30, 0.25))
	draw_circle(Vector2.ZERO, 24, Color(0.45, 0.45, 0.35))
	draw_rect(Rect2(-13, -30, 26, 32), Color(0.12, 0.15, 0.14))
	for angle in range(0, 360, 45):
		var direction := Vector2.from_angle(deg_to_rad(angle))
		draw_circle(direction * 27, 5, Color(0.61, 0.52, 0.31))

func _draw_fire() -> void:
	var glow := 22.0 + sin(_pulse * 7.0) * 3.0
	draw_circle(Vector2.ZERO, glow, Color(1.0, 0.38, 0.08, 0.12))
	draw_line(Vector2(-12, -7), Vector2(12, 7), Color(0.22, 0.14, 0.08), 5.0)
	draw_line(Vector2(12, -7), Vector2(-12, 7), Color(0.22, 0.14, 0.08), 5.0)
	draw_circle(Vector2.ZERO, 8, Color(0.95, 0.26, 0.05))
	draw_circle(Vector2(0, -3), 5, Color(1.0, 0.78, 0.20))

func _draw_antenna() -> void:
	draw_circle(Vector2(4, 7), 25, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, 19, Color(0.26, 0.30, 0.27))
	draw_arc(Vector2(-2, -2), 16, -1.2, 1.2, 18, Color(0.65, 0.70, 0.61), 4.0)
	draw_line(Vector2(-2, -2), Vector2(12, -18), Color(0.18, 0.21, 0.20), 4.0)
	draw_circle(Vector2(12, -18), 3, Color(0.93, 0.34, 0.16))

func _draw_ruins() -> void:
	draw_rect(Rect2(-37, -27, 78, 58), Color(0, 0, 0, 0.24))
	draw_colored_polygon(PackedVector2Array([Vector2(-38, -28), Vector2(8, -28), Vector2(8, -17), Vector2(-24, -17), Vector2(-24, 24), Vector2(-38, 24)]), Color(0.36, 0.36, 0.31))
	draw_colored_polygon(PackedVector2Array([Vector2(16, -6), Vector2(38, -6), Vector2(38, 27), Vector2(-2, 27), Vector2(-2, 16), Vector2(16, 16)]), Color(0.43, 0.41, 0.34))
	draw_line(Vector2(-31, -21), Vector2(-6, -21), Color(0.62, 0.57, 0.43), 3.0)

func _draw_barricade() -> void:
	draw_rect(Rect2(-38, -9, 80, 22), Color(0, 0, 0, 0.25))
	for offset in [-30.0, -10.0, 10.0, 30.0]:
		draw_line(Vector2(offset - 8, -10), Vector2(offset + 8, 10), Color(0.49, 0.31, 0.16), 5.0)
		draw_line(Vector2(offset + 8, -10), Vector2(offset - 8, 10), Color(0.62, 0.42, 0.22), 4.0)

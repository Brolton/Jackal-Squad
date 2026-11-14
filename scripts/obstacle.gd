extends StaticBody2D

var kind: StringName = &"tree"
var radius := 24.0

func configure(obstacle_kind: StringName, obstacle_radius: float) -> void:
	kind = obstacle_kind
	radius = obstacle_radius

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var collision := CollisionShape2D.new()
	if kind == &"crate":
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(radius * 1.8, radius * 1.8)
		collision.shape = rectangle
	else:
		var circle := CircleShape2D.new()
		circle.radius = radius * (0.48 if kind == &"cactus" else 0.72)
		collision.shape = circle
	add_child(collision)
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2(5.0, 9.0), radius * 0.86, Color(0.0, 0.0, 0.0, 0.24))
	match kind:
		&"tree":
			draw_circle(Vector2(0.0, 7.0), radius * 0.7, Color(0.14, 0.22, 0.14))
			draw_circle(Vector2.ZERO, radius, Color(0.20, 0.37, 0.20))
			draw_circle(Vector2(-radius * 0.22, -radius * 0.2), radius * 0.49, Color(0.29, 0.46, 0.24))
			draw_circle(Vector2(radius * 0.24, radius * 0.13), radius * 0.38, Color(0.17, 0.31, 0.18))
			draw_circle(Vector2(-radius * 0.28, -radius * 0.30), radius * 0.18, Color(0.46, 0.63, 0.30, 0.85))
		&"cactus":
			draw_line(Vector2(0, radius * 0.62), Vector2(0, -radius * 0.72), Color(0.18, 0.24, 0.17), radius * 0.42)
			draw_line(Vector2(-radius * 0.52, radius * 0.12), Vector2(-radius * 0.52, -radius * 0.28), Color(0.24, 0.38, 0.24), radius * 0.3)
			draw_line(Vector2(-radius * 0.52, radius * 0.12), Vector2(-radius * 0.08, radius * 0.12), Color(0.24, 0.38, 0.24), radius * 0.3)
			draw_line(Vector2(radius * 0.42, radius * 0.32), Vector2(radius * 0.42, -radius * 0.14), Color(0.31, 0.45, 0.27), radius * 0.28)
			draw_line(Vector2(radius * 0.42, radius * 0.32), Vector2(radius * 0.08, radius * 0.32), Color(0.31, 0.45, 0.27), radius * 0.28)
			for spike_index in range(4):
				var y := -radius * 0.55 + float(spike_index) * radius * 0.3
				draw_line(Vector2(-radius * 0.09, y), Vector2(-radius * 0.22, y - radius * 0.08), Color(0.81, 0.78, 0.61), 1.5)
				draw_line(Vector2(radius * 0.09, y + radius * 0.08), Vector2(radius * 0.22, y), Color(0.81, 0.78, 0.61), 1.5)
		&"snow_tree":
			draw_circle(Vector2(5.0, 9.0), radius * 0.9, Color(0.28, 0.40, 0.46, 0.28))
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -radius),
				Vector2(-radius * 0.78, radius * 0.56),
				Vector2(-radius * 0.34, radius * 0.43),
				Vector2(-radius * 0.55, radius * 0.92),
				Vector2(radius * 0.55, radius * 0.92),
				Vector2(radius * 0.34, radius * 0.43),
				Vector2(radius * 0.78, radius * 0.56),
			]), Color(0.23, 0.39, 0.46))
			draw_colored_polygon(PackedVector2Array([
				Vector2(0, -radius),
				Vector2(-radius * 0.78, radius * 0.56),
				Vector2(0, radius * 0.27),
				Vector2(radius * 0.34, radius * 0.43),
			]), Color(0.89, 0.96, 0.98))
			draw_line(Vector2(0, -radius * 0.45), Vector2(0, radius * 0.78), Color(0.97, 0.99, 1.0, 0.85), 2.0)
		&"snow_rock":
			draw_colored_polygon(PackedVector2Array([
				Vector2(-radius, radius * 0.3),
				Vector2(-radius * 0.56, -radius * 0.62),
				Vector2(radius * 0.28, -radius),
				Vector2(radius, -radius * 0.12),
				Vector2(radius * 0.62, radius * 0.78),
			]), Color(0.46, 0.58, 0.64))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-radius * 0.56, -radius * 0.62),
				Vector2(radius * 0.28, -radius),
				Vector2(radius, -radius * 0.12),
				Vector2(radius * 0.15, -radius * 0.25),
			]), Color(0.92, 0.97, 0.99))
		&"rock":
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(-radius, radius * 0.3),
					Vector2(-radius * 0.56, -radius * 0.62),
					Vector2(radius * 0.28, -radius),
					Vector2(radius, -radius * 0.12),
					Vector2(radius * 0.62, radius * 0.78),
				]),
				Color(0.39, 0.41, 0.34)
			)
			draw_line(Vector2(-radius * 0.42, -radius * 0.3), Vector2(radius * 0.25, -radius * 0.62), Color(0.58, 0.59, 0.49), 3.0)
			draw_line(Vector2(-radius * 0.15, radius * 0.22), Vector2(radius * 0.56, radius * 0.10), Color(0.25, 0.27, 0.23), 2.0)
		&"crate":
			draw_rect(Rect2(-radius * 0.8, -radius * 0.8, radius * 1.6, radius * 1.6), Color(0.42, 0.29, 0.17))
			draw_rect(Rect2(-radius * 0.58, -radius * 0.58, radius * 1.16, radius * 1.16), Color(0.56, 0.39, 0.22), false, 3.0)
			draw_line(Vector2(-radius * 0.55, -radius * 0.55), Vector2(radius * 0.55, radius * 0.55), Color(0.36, 0.24, 0.14), 3.0)
			draw_line(Vector2(radius * 0.55, -radius * 0.55), Vector2(-radius * 0.55, radius * 0.55), Color(0.65, 0.46, 0.25), 2.0)

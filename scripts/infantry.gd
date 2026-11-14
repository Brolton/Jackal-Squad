extends CharacterBody2D

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

@export var move_speed := 48.0
@export var attack_range := 430.0
@export var maximum_health := 2
@export var fire_interval := 1.55

var health := 2
var _fire_cooldown := 0.45

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 3
	health = maximum_health
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	var target := _nearest_player()
	if target == null:
		velocity = Vector2.ZERO
		return

	var offset: Vector2 = target.global_position - global_position
	var distance := offset.length()
	if distance > 92.0:
		velocity = offset.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if distance > 0.0:
		rotation = offset.angle() + PI * 0.5
	if distance <= attack_range and _fire_cooldown == 0.0:
		_fire_at(offset.normalized())

func take_damage(amount: int) -> void:
	if amount <= 0 or not is_inside_tree():
		return
	health = maxi(health - amount, 0)
	queue_redraw()
	if health == 0:
		queue_free()

func _nearest_player() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("players"):
		if not candidate is Node2D:
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

func _fire_at(direction: Vector2) -> void:
	_fire_cooldown = fire_interval
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.configure(global_position + direction * 18.0, direction, self, true, 1, 300.0)
	get_tree().current_scene.add_child(projectile)

func _draw() -> void:
	draw_circle(Vector2(0.0, 2.0), 11.0, Color(0.50, 0.39, 0.20))
	draw_circle(Vector2.ZERO, 7.0, Color(0.66, 0.69, 0.45))
	draw_rect(Rect2(-5.0, -9.0, 10.0, 4.0), Color(0.25, 0.32, 0.21))
	draw_line(Vector2(0.0, 1.0), Vector2(0.0, -13.0), Color(0.20, 0.22, 0.18), 2.0)
	draw_circle(Vector2(0.0, -3.0), 2.0, Color(0.88, 0.79, 0.58))

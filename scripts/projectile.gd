extends Area2D

var direction := Vector2.UP
var shooter: Node2D
var damage := 1
var speed := 600.0
var hostile := false
var visual_only := false
var _remaining_lifetime := 2.4
var _projectile_color := Color(1.0, 0.83, 0.40)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("enemy_projectiles" if hostile else "player_projectiles")
	queue_redraw()

func configure(
	spawn_position: Vector2,
	travel_direction: Vector2,
	source: Node2D,
	is_hostile: bool,
	attack_damage: int,
	travel_speed: float,
	authoritative: bool = true
) -> void:
	position = spawn_position
	direction = travel_direction.normalized()
	shooter = source
	hostile = is_hostile
	visual_only = not authoritative
	damage = attack_damage
	speed = travel_speed
	collision_layer = (16 if hostile else 8) if authoritative else 0
	collision_mask = (3 if hostile else 5) if authoritative else 0
	_projectile_color = Color(1.0, 0.34, 0.22) if hostile else Color(1.0, 0.83, 0.40)
	rotation = direction.angle() + PI * 0.5

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_remaining_lifetime -= delta
	if _remaining_lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if visual_only or body == shooter:
		return
	if body.has_method("take_damage"):
		body.call("take_damage", damage)
	queue_free()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 4.0, _projectile_color)
	draw_line(Vector2(0.0, 3.0), Vector2(0.0, 9.0), _projectile_color.lightened(0.18), 2.0)

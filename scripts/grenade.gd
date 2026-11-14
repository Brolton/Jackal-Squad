extends Area2D

@export var blast_radius := 92.0

var direction := Vector2.UP
var shooter: Node2D
var visual_only := false
var _age := 0.0
var _exploded := false
var _animation_left := 0.22

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("grenades")
	queue_redraw()

func configure(
	spawn_position: Vector2,
	travel_direction: Vector2,
	source: Node2D,
	cosmetic_only: bool = false
) -> void:
	position = spawn_position
	direction = travel_direction.normalized()
	shooter = source
	visual_only = cosmetic_only
	collision_layer = 0
	collision_mask = 0 if visual_only else 5

func _physics_process(delta: float) -> void:
	if _exploded:
		_animation_left -= delta
		if _animation_left <= 0.0:
			queue_free()
		return

	_age += delta
	if _age < 0.36:
		position += direction * 250.0 * delta
	elif _age >= 0.72:
		_explode()

func _on_body_entered(body: Node2D) -> void:
	if not _exploded and body != shooter:
		_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_collision_shape.set_deferred("disabled", true)
	monitoring = false

	if visual_only:
		queue_redraw()
		return

	var blast_shape := CircleShape2D.new()
	blast_shape.radius = blast_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = blast_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 5
	query.collide_with_bodies = true
	for result in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var body: Object = result["collider"]
		if body == shooter or not body is Node2D or not body.has_method("take_damage"):
			continue
		var distance := global_position.distance_to((body as Node2D).global_position)
		body.call("take_damage", 2 if distance <= blast_radius * 0.5 else 1)
	queue_redraw()

func _draw() -> void:
	if _exploded:
		draw_circle(Vector2.ZERO, blast_radius, Color(1.0, 0.58, 0.17, 0.42))
		draw_arc(Vector2.ZERO, blast_radius, 0.0, TAU, 48, Color(1.0, 0.79, 0.36, 0.9), 4.0)
	else:
		draw_circle(Vector2.ZERO, 7.0, Color(0.48, 0.54, 0.25))
		draw_circle(Vector2(-2.0, -2.0), 2.0, Color(0.86, 0.84, 0.57))

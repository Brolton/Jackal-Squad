extends Area2D

@export var blast_radius := 112.0

var direction := Vector2.UP
var shooter: Node2D
var visual_only := false
var upgrade_level := 1
var damage := 3
var speed := 590.0
var max_travel_distance := 900.0
var travelled_distance := 0.0
var _exploded := false
var _animation_left := 0.24
var _flame_phase := 0.0

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	add_to_group("rockets")
	queue_redraw()

func configure(
	spawn_position: Vector2,
	travel_direction: Vector2,
	source: Node2D,
	cosmetic_only: bool = false,
	blast_range: float = 112.0,
	visual_upgrade_level: int = 1,
	travel_limit: float = 900.0,
	attack_damage: int = 3
) -> void:
	position = spawn_position
	direction = travel_direction.normalized()
	shooter = source
	visual_only = cosmetic_only
	blast_radius = blast_range
	upgrade_level = clampi(visual_upgrade_level, 1, 3)
	max_travel_distance = maxf(200.0, travel_limit)
	damage = maxi(1, attack_damage)
	collision_layer = 0
	# Cosmetic rockets still collide with the replicated battlefield so clients
	# see the impact at the same obstacle instead of a rocket passing through it.
	collision_mask = 69
	rotation = direction.angle() + PI * 0.5

func _physics_process(delta: float) -> void:
	if _exploded:
		_animation_left -= delta
		if _animation_left <= 0.0:
			queue_free()
		return
	var step := speed * delta
	position += direction * step
	travelled_distance += step
	_flame_phase = fposmod(_flame_phase + delta * 28.0, TAU)
	queue_redraw()
	if travelled_distance >= max_travel_distance:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not _exploded and body != shooter:
		_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	AudioDirector.play_sfx(&"rocket_blast")
	_collision_shape.set_deferred("disabled", true)
	monitoring = false
	if not visual_only:
		_apply_blast_damage()
	queue_redraw()

func _apply_blast_damage() -> void:
	var blast_shape := CircleShape2D.new()
	blast_shape.radius = blast_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = blast_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 69
	query.collide_with_bodies = true
	var attacker_peer_id := -1
	if shooter != null and shooter.is_in_group("players"):
		attacker_peer_id = int(shooter.get("player_peer_id"))
	for result in get_world_2d().direct_space_state.intersect_shape(query, 64):
		var body: Object = result["collider"]
		if body == shooter or not body is Node2D or not body.has_method("take_damage"):
			continue
		var distance := global_position.distance_to((body as Node2D).global_position)
		var applied_damage := damage if distance <= blast_radius * 0.55 else maxi(1, damage - 1)
		if attacker_peer_id >= 0 and (body.is_in_group("enemies") or body.is_in_group("final_base")):
			body.call("take_damage", applied_damage, attacker_peer_id)
		else:
			body.call("take_damage", applied_damage)

func _draw() -> void:
	if _exploded:
		draw_circle(Vector2.ZERO, blast_radius, Color(1.0, 0.24, 0.05, 0.18))
		draw_circle(Vector2.ZERO, blast_radius * 0.62, Color(1.0, 0.62, 0.08, 0.45))
		draw_circle(Vector2.ZERO, blast_radius * 0.25, Color(1.0, 0.96, 0.66, 0.90))
		for ray_index in range(10 + upgrade_level * 2):
			var ray_direction := Vector2.from_angle(TAU * float(ray_index) / float(10 + upgrade_level * 2))
			draw_line(ray_direction * 18.0, ray_direction * blast_radius * 0.82, Color(1.0, 0.74, 0.22, 0.72), 3.0)
		return
	var flame_length := 12.0 + sin(_flame_phase) * 3.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.0, 11.0), Vector2(0.0, 11.0 + flame_length), Vector2(4.0, 11.0)
	]), Color(1.0, 0.42, 0.06, 0.90))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5.5, 8.0), Vector2(-9.0, 13.0), Vector2(-4.0, 12.0),
		Vector2(4.0, 12.0), Vector2(9.0, 13.0), Vector2(5.5, 8.0),
	]), Color(0.37, 0.42, 0.41))
	draw_rect(Rect2(-5.0, -8.0, 10.0, 20.0), Color(0.70, 0.74, 0.66), true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5.0, -8.0), Vector2(0.0, -16.0), Vector2(5.0, -8.0)
	]), Color(0.94, 0.36, 0.16))
	draw_line(Vector2(-2.0, -5.0), Vector2(-2.0, 8.0), Color(0.92, 0.96, 0.84, 0.75), 1.5)

func rocket_signature() -> Dictionary:
	return {
		"straight_flight": true,
		"max_travel_distance": max_travel_distance,
		"blast_radius": blast_radius,
		"upgrade_level": upgrade_level,
	}

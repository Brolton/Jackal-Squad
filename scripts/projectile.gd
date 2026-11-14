extends Area2D

var direction := Vector2.UP
var shooter: Node2D
var damage := 1
var speed := 600.0
var hostile := false
var visual_only := false
var visual_level := 0
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
	authoritative: bool = true,
	upgrade_level: int = 0
) -> void:
	position = spawn_position
	direction = travel_direction.normalized()
	shooter = source
	hostile = is_hostile
	visual_only = not authoritative
	visual_level = clampi(upgrade_level, 0, 3)
	damage = attack_damage
	speed = travel_speed
	collision_layer = (16 if hostile else 8) if authoritative else 0
	collision_mask = (3 if hostile else 69) if authoritative else 0
	if hostile:
		_projectile_color = Color(1.0, 0.34, 0.22)
	else:
		_projectile_color = [Color(1.0, 0.83, 0.40), Color(0.40, 0.94, 1.0), Color(0.62, 0.80, 1.0), Color(0.94, 0.96, 1.0)][visual_level]
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
		var attacker_peer_id := -1
		if (
			(body.is_in_group("enemies") or body.is_in_group("final_base"))
			and shooter != null
			and shooter.is_in_group("players")
		):
			attacker_peer_id = int(shooter.get("player_peer_id"))
		if attacker_peer_id >= 0:
			body.call("take_damage", damage, attacker_peer_id)
		else:
			body.call("take_damage", damage)
	queue_free()

func _draw() -> void:
	var core_radius := 4.0 + float(visual_level) * 0.8
	draw_circle(Vector2.ZERO, 7.0 + float(visual_level) * 2.0, Color(_projectile_color.r, _projectile_color.g, _projectile_color.b, 0.18 + visual_level * 0.04))
	draw_circle(Vector2.ZERO, core_radius, _projectile_color)
	draw_circle(Vector2(-1.0, -1.0), 1.5, Color.WHITE)
	draw_line(Vector2(0.0, 3.0), Vector2(0.0, 13.0 + visual_level * 5.0), Color(_projectile_color.r, _projectile_color.g, _projectile_color.b, 0.45 + visual_level * 0.10), 3.0 + visual_level)
	if visual_level >= 2:
		draw_line(Vector2(-3.0, 5.0), Vector2(-3.0, 13.0 + visual_level * 3.0), Color(_projectile_color.r, _projectile_color.g, _projectile_color.b, 0.32), 1.5)

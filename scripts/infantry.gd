extends CharacterBody2D

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

enum EnemyType { INFANTRY, TURRET, TANK, BOAT }

@export var move_speed := 48.0
@export var attack_range := 430.0
@export var maximum_health := 2
@export var fire_interval := 1.55

var enemy_type: EnemyType = EnemyType.INFANTRY
var health := 2
var preferred_range := 92.0
var projectile_damage := 1
var projectile_speed := 300.0
var _fire_cooldown := 0.45
var _network_sync_timer := 0.0
var _target_position := Vector2.ZERO
var _target_rotation := 0.0
var _has_authoritative_state := false

func configure_enemy(kind: int) -> void:
	enemy_type = clampi(kind, EnemyType.INFANTRY, EnemyType.BOAT)
	match enemy_type:
		EnemyType.TURRET:
			move_speed = 0.0
			attack_range = 620.0
			maximum_health = 4
			fire_interval = 1.2
			preferred_range = 0.0
			projectile_damage = 1
			projectile_speed = 350.0
		EnemyType.TANK:
			move_speed = 24.0
			attack_range = 560.0
			maximum_health = 6
			fire_interval = 1.8
			preferred_range = 175.0
			projectile_damage = 2
			projectile_speed = 280.0
		EnemyType.BOAT:
			move_speed = 0.0
			attack_range = 700.0
			maximum_health = 4
			fire_interval = 1.6
			preferred_range = 0.0
			projectile_damage = 2
			projectile_speed = 330.0
		_:
			move_speed = 48.0
			attack_range = 430.0
			maximum_health = 2
			fire_interval = 1.55
			preferred_range = 92.0
			projectile_damage = 1
			projectile_speed = 300.0

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 4
	collision_mask = 3
	health = maximum_health
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if NetworkSession.is_networked and not multiplayer.is_server():
		if _has_authoritative_state:
			var weight := minf(1.0, delta * 12.0)
			global_position = global_position.lerp(_target_position, weight)
			rotation = lerp_angle(rotation, _target_rotation, weight)
		return

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	var target := _nearest_player()
	if target == null:
		velocity = Vector2.ZERO
		_broadcast_state(delta)
		return

	var offset: Vector2 = target.global_position - global_position
	var distance := offset.length()
	if move_speed > 0.0 and distance > preferred_range:
		velocity = offset.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

	if distance > 0.0:
		rotation = offset.angle() + PI * 0.5
	if distance <= attack_range and _fire_cooldown == 0.0:
		_fire_at(offset.normalized())
	_broadcast_state(delta)

func take_damage(amount: int) -> void:
	if amount <= 0 or not is_inside_tree():
		return
	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	health = maxi(health - amount, 0)
	queue_redraw()
	if health == 0:
		if NetworkSession.is_networked and multiplayer.is_server():
			for peer_id in NetworkSession.connected_peer_ids():
				rpc_id(peer_id, "rpc_enemy_destroyed")
		queue_free()

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_receive_state(world_position: Vector2, world_rotation: float, current_health: int) -> void:
	if not NetworkSession.is_networked or multiplayer.is_server():
		return
	_target_position = world_position
	_target_rotation = world_rotation
	_has_authoritative_state = true
	health = current_health
	if health <= 0:
		queue_free()

@rpc("authority", "call_remote", "reliable")
func rpc_enemy_destroyed() -> void:
	if not multiplayer.is_server():
		queue_free()

func _broadcast_state(delta: float) -> void:
	if not NetworkSession.is_host:
		return
	_network_sync_timer -= delta
	if _network_sync_timer > 0.0:
		return
	_network_sync_timer = 0.05
	for peer_id in NetworkSession.connected_peer_ids():
		rpc_id(peer_id, "rpc_receive_state", global_position, rotation, health)

func _nearest_player() -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group("players"):
		if not candidate is Node2D or not candidate.visible:
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < nearest_distance:
			nearest = candidate
			nearest_distance = distance
	return nearest

func _fire_at(direction: Vector2) -> void:
	_fire_cooldown = fire_interval
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.configure(
		global_position + direction * 18.0,
		direction,
		self,
		true,
		projectile_damage,
		projectile_speed
	)
	get_tree().current_scene.add_child(projectile)
	NetworkSession.spawn_projectile_visual(
		global_position + direction * 18.0,
		direction,
		true,
		projectile_damage,
		projectile_speed
	)

func _draw() -> void:
	match enemy_type:
		EnemyType.TURRET:
			draw_circle(Vector2(0.0, 2.0), 17.0, Color(0.20, 0.24, 0.20))
			draw_circle(Vector2.ZERO, 12.0, Color(0.43, 0.49, 0.35))
			draw_rect(Rect2(-4.0, -19.0, 8.0, 19.0), Color(0.22, 0.27, 0.21))
		EnemyType.TANK:
			draw_rect(Rect2(-18.0, -15.0, 36.0, 30.0), Color(0.18, 0.22, 0.18))
			draw_rect(Rect2(-14.0, -12.0, 28.0, 24.0), Color(0.45, 0.43, 0.29))
			draw_circle(Vector2.ZERO, 8.0, Color(0.33, 0.36, 0.27))
			draw_rect(Rect2(-3.0, -25.0, 6.0, 25.0), Color(0.19, 0.22, 0.18))
		EnemyType.BOAT:
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(-21.0, -10.0),
					Vector2(21.0, -10.0),
					Vector2(15.0, 13.0),
					Vector2(-15.0, 13.0),
				]),
				Color(0.37, 0.34, 0.26)
			)
			draw_rect(Rect2(-8.0, -7.0, 16.0, 12.0), Color(0.52, 0.49, 0.36))
			draw_rect(Rect2(-2.0, -20.0, 4.0, 18.0), Color(0.19, 0.23, 0.18))
		_:
			draw_circle(Vector2(0.0, 2.0), 11.0, Color(0.50, 0.39, 0.20))
			draw_circle(Vector2.ZERO, 7.0, Color(0.66, 0.69, 0.45))
			draw_rect(Rect2(-5.0, -9.0, 10.0, 4.0), Color(0.25, 0.32, 0.21))
			draw_line(Vector2(0.0, 1.0), Vector2(0.0, -13.0), Color(0.20, 0.22, 0.18), 2.0)
			draw_circle(Vector2(0.0, -3.0), 2.0, Color(0.88, 0.79, 0.58))

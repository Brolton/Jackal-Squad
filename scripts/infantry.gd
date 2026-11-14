extends CharacterBody2D

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const INFANTRY_TEXTURE := preload("res://assets/art/enemy_infantry_v2.png")
const TURRET_TEXTURE := preload("res://assets/art/enemy_turret.png")
const TANK_TEXTURE := preload("res://assets/art/enemy_tank.png")
const BOAT_TEXTURE := preload("res://assets/art/enemy_boat.png")

enum EnemyType { INFANTRY, TURRET, TANK, BOAT }

@export var move_speed := 48.0
@export var attack_range := 430.0
@export var maximum_health := 1
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
var coop_player_count := 1
var _hit_flash := 0.0
var _walk_phase := 0.0
var _walk_strength := 0.0
var _visual_moving := false
var _infantry_region := Rect2()

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D

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
			maximum_health = 1
			fire_interval = 1.55
			preferred_range = 92.0
			projectile_damage = 1
			projectile_speed = 300.0

func apply_coop_scaling(player_count: int) -> void:
	coop_player_count = clampi(player_count, 1, 4)
	if coop_player_count <= 1:
		return
	if enemy_type != EnemyType.INFANTRY:
		maximum_health += ceili(float(maximum_health) * 0.22 * float(coop_player_count - 1))
	fire_interval = maxf(0.65, fire_interval * (1.0 - 0.06 * float(coop_player_count - 1)))

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_collision_shape.shape = _collision_shape.shape.duplicate()
	if enemy_type == EnemyType.INFANTRY:
		collision_layer = 64
		collision_mask = 33
		(_collision_shape.shape as CircleShape2D).radius = 9.0
		_infantry_region = Rect2(INFANTRY_TEXTURE.get_image().get_used_rect())
	else:
		collision_layer = 4
		collision_mask = 35
		(_collision_shape.shape as CircleShape2D).radius = 24.0 if enemy_type != EnemyType.TURRET else 21.0
	health = maximum_health
	add_to_group("enemies")

func can_be_trampled() -> bool:
	return enemy_type == EnemyType.INFANTRY

func _physics_process(delta: float) -> void:
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		queue_redraw()
	if NetworkSession.is_networked and not multiplayer.is_server():
		if _has_authoritative_state:
			var previous_position := global_position
			var weight := minf(1.0, delta * 12.0)
			global_position = global_position.lerp(_target_position, weight)
			rotation = lerp_angle(rotation, _target_rotation, weight)
			_update_walk_animation(global_position.distance_squared_to(previous_position) > 0.0025, delta)
		return
	if NetworkSession.mission_completed:
		velocity = Vector2.ZERO
		_update_walk_animation(false, delta)
		return

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	var target := _nearest_player()
	if target == null:
		velocity = Vector2.ZERO
		_update_walk_animation(false, delta)
		_broadcast_state(delta)
		return

	var offset: Vector2 = target.global_position - global_position
	var distance := offset.length()
	if move_speed > 0.0 and distance > preferred_range:
		velocity = offset.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	_update_walk_animation(velocity.length_squared() > 1.0, delta)

	if distance > 0.0:
		rotation = offset.angle() + PI * 0.5
	if distance <= attack_range and _fire_cooldown == 0.0:
		_fire_at(offset.normalized())
	_broadcast_state(delta)

func take_damage(amount: int, attacker_peer_id: int = 0) -> void:
	if amount <= 0 or not is_inside_tree():
		return
	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	health = maxi(health - amount, 0)
	_hit_flash = 0.10
	queue_redraw()
	if health == 0:
		if enemy_type == EnemyType.INFANTRY:
			AudioDirector.play_sfx(&"soldier_death")
		NetworkSession.record_enemy_destroyed(attacker_peer_id)
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
		if enemy_type == EnemyType.INFANTRY:
			AudioDirector.play_sfx(&"soldier_death")
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
	AudioDirector.play_sfx(&"enemy_shot")
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

func _update_walk_animation(moving: bool, delta: float) -> void:
	_visual_moving = moving and enemy_type == EnemyType.INFANTRY
	_walk_strength = move_toward(_walk_strength, 1.0 if _visual_moving else 0.0, delta * 8.0)
	if _visual_moving:
		_walk_phase = fposmod(_walk_phase + delta * 11.0, TAU)
	queue_redraw()

func _draw() -> void:
	if _hit_flash > 0.0:
		draw_circle(Vector2.ZERO, 25.0, Color(1.0, 0.84, 0.45, 0.38))
	var texture_tint := Color(1.0, 0.82, 0.62) if _hit_flash > 0.0 else Color.WHITE
	match enemy_type:
		EnemyType.TURRET:
			draw_texture_rect(TURRET_TEXTURE, Rect2(-32, -35, 64, 66), false, texture_tint)
		EnemyType.TANK:
			draw_texture_rect(TANK_TEXTURE, Rect2(-31, -45, 62, 88), false, texture_tint)
		EnemyType.BOAT:
			draw_texture_rect(BOAT_TEXTURE, Rect2(-28, -45, 56, 90), false, texture_tint)
		_:
			var stride := sin(_walk_phase) * _walk_strength
			var bob := absf(sin(_walk_phase * 2.0)) * -1.2 * _walk_strength
			var sway := stride * 0.9
			var squash := 1.0 - absf(stride) * 0.025
			draw_ellipse_shadow(Vector2(1.0, 6.5), Vector2(10.5 + absf(stride), 7.0), Color(0.0, 0.0, 0.0, 0.28))
			draw_set_transform(Vector2(sway, bob), stride * 0.025, Vector2(1.0 / squash, squash))
			draw_texture_rect_region(INFANTRY_TEXTURE, Rect2(-15.0, -21.0, 30.0, 42.0), _infantry_region, texture_tint)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func draw_ellipse_shadow(center: Vector2, radii: Vector2, color: Color) -> void:
	draw_set_transform(center, 0.0, radii)
	draw_circle(Vector2.ZERO, 1.0, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func infantry_visual_signature() -> Dictionary:
	return {
		"camera": "orthographic_top_down",
		"walk_animation": true,
		"walk_phase": _walk_phase,
		"texture_width": INFANTRY_TEXTURE.get_width(),
		"has_alpha": INFANTRY_TEXTURE.get_image().detect_alpha() != Image.ALPHA_NONE,
	}

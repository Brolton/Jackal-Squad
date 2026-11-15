extends StaticBody2D

signal destroyed(turret_index: int, attacker_peer_id: int)

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")

var turret_index := 0
var boss_level := 0
var maximum_health := 5
var health := 5
var fire_interval := 1.15
var projectile_damage := 1
var projectile_speed := 360.0
var attack_range := 820.0
var _fire_cooldown := 0.35
var _destroyed := false
var _aim_direction := Vector2.DOWN
var _hit_flash := 0.0

func configure(index: int, mission_level: int) -> void:
	turret_index = index
	boss_level = clampi(mission_level, 0, 2)
	maximum_health = 5 + boss_level * 2
	health = maximum_health
	fire_interval = 1.20 - float(boss_level) * 0.12 + float(index % 2) * 0.10
	projectile_damage = 2 if boss_level >= 2 else 1
	projectile_speed = 370.0 + float(boss_level) * 35.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	add_to_group("boss_turrets")
	add_to_group("enemies")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _destroyed or NetworkSession.mission_completed or NetworkSession.game_over:
		return
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		queue_redraw()
	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	var target := _assigned_target()
	if target == null:
		return
	var offset: Vector2 = target.global_position - global_position
	if offset.length_squared() > 0.0:
		_aim_direction = offset.normalized()
		queue_redraw()
	if offset.length() <= attack_range and _fire_cooldown <= 0.0:
		_fire_at(_aim_direction)

func take_damage(amount: int, attacker_peer_id: int = 0) -> void:
	if amount <= 0 or _destroyed:
		return
	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	health = maxi(0, health - amount)
	_hit_flash = 0.12
	queue_redraw()
	if NetworkSession.is_networked and NetworkSession.is_host:
		rpc("rpc_receive_health", health)
	if health == 0:
		_destroy(attacker_peer_id)

func _destroy(attacker_peer_id: int) -> void:
	if _destroyed:
		return
	_destroyed = true
	NetworkSession.record_enemy_destroyed(attacker_peer_id)
	AudioDirector.play_sfx(&"explosion", -1.0)
	if NetworkSession.is_networked and NetworkSession.is_host:
		rpc("rpc_destroy_turret")
	destroyed.emit(turret_index, attacker_peer_id)
	queue_free()

@rpc("authority", "call_remote", "reliable")
func rpc_receive_health(current_health: int) -> void:
	if NetworkSession.is_host or _destroyed:
		return
	health = clampi(current_health, 0, maximum_health)
	_hit_flash = 0.12
	queue_redraw()

@rpc("authority", "call_remote", "reliable")
func rpc_destroy_turret() -> void:
	if NetworkSession.is_host or _destroyed:
		return
	_destroyed = true
	AudioDirector.play_sfx(&"explosion", -1.0)
	destroyed.emit(turret_index, 0)
	queue_free()

func _assigned_target() -> Node2D:
	var candidates: Array[Node2D] = []
	for candidate in get_tree().get_nodes_in_group("players"):
		if candidate is Node2D and candidate.visible:
			candidates.append(candidate)
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return int(a.get("player_peer_id")) < int(b.get("player_peer_id"))
	)
	if candidates.is_empty():
		return null
	var available_targets: Array[Node2D] = []
	for candidate in candidates:
		if global_position.distance_to(candidate.global_position) <= attack_range:
			available_targets.append(candidate)
	if not available_targets.is_empty():
		return available_targets[turret_index % available_targets.size()]
	return candidates[turret_index % candidates.size()]

func _fire_at(direction: Vector2) -> void:
	_fire_cooldown = fire_interval
	var spawn_position := global_position + direction * 27.0
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.configure(spawn_position, direction, self, true, projectile_damage, projectile_speed)
	get_tree().current_scene.add_child(projectile)
	NetworkSession.spawn_projectile_visual(spawn_position, direction, true, projectile_damage, projectile_speed)
	AudioDirector.play_sfx(&"enemy_shot", -2.0)

func _draw() -> void:
	var armor := Color(0.52, 0.24, 0.15) if boss_level == 0 else Color(0.42, 0.34, 0.18) if boss_level == 1 else Color(0.30, 0.34, 0.32)
	if _hit_flash > 0.0:
		armor = Color(1.0, 0.72, 0.34)
	draw_circle(Vector2(3, 5), 23.0, Color(0.0, 0.0, 0.0, 0.38))
	draw_circle(Vector2.ZERO, 21.0, Color(0.10, 0.12, 0.11))
	draw_circle(Vector2.ZERO, 17.0, armor)
	draw_arc(Vector2.ZERO, 18.0, 0.0, TAU, 32, Color(0.76, 0.64, 0.36), 2.0)
	draw_line(_aim_direction * 5.0, _aim_direction * 34.0, Color(0.12, 0.14, 0.13), 7.0)
	draw_line(_aim_direction * 7.0, _aim_direction * 34.0, Color(0.48, 0.52, 0.43), 3.0)
	draw_circle(Vector2.ZERO, 7.0, Color(0.15, 0.17, 0.16))
	draw_arc(Vector2.ZERO, 24.0, -PI, 0.0, 20, Color(0.08, 0.09, 0.08), 4.0)
	draw_arc(Vector2.ZERO, 24.0, -PI, -PI + PI * float(health) / float(maximum_health), 20, Color(0.94, 0.35, 0.18), 4.0)

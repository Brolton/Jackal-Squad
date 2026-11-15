extends StaticBody2D

const BOSS_TURRET_SCENE := preload("res://scenes/boss_turret.tscn")
const BASE_HEALTH := 18

var maximum_health := BASE_HEALTH
var health := BASE_HEALTH
var _destroyed := false
var mission_level := 0
var coop_player_count := 1
var turret_count := 1
var turrets_remaining := 1
var shielded := true
var _shield_flash := 0.0

func configure_coop_scaling(player_count: int) -> void:
	configure_boss(0, player_count)

func configure_boss(level_index: int, player_count: int) -> void:
	mission_level = clampi(level_index, 0, 2)
	coop_player_count = clampi(player_count, 1, 4)
	turret_count = LevelLayouts.boss_turret_count_for(mission_level, coop_player_count)
	turrets_remaining = turret_count
	shielded = turret_count > 0
	maximum_health = BASE_HEALTH + mission_level * 6
	health = maximum_health

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	add_to_group("final_base")
	_spawn_turrets()
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _shield_flash > 0.0:
		_shield_flash = maxf(0.0, _shield_flash - delta)
		queue_redraw()

func take_damage(amount: int, attacker_peer_id: int = 0) -> void:
	if amount <= 0 or _destroyed:
		return
	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	if shielded:
		_shield_flash = 0.16
		AudioDirector.play_sfx(&"hit", -7.0)
		queue_redraw()
		return
	health = maxi(health - amount, 0)
	queue_redraw()
	if NetworkSession.is_networked and NetworkSession.is_host:
		for peer_id in NetworkSession.connected_peer_ids():
			rpc_id(peer_id, "rpc_receive_health", health)
	if health == 0:
		_destroy(attacker_peer_id)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_health(current_health: int) -> void:
	if NetworkSession.is_host or _destroyed:
		return
	health = clampi(current_health, 0, maximum_health)
	queue_redraw()

@rpc("authority", "call_remote", "reliable")
func rpc_destroy_base() -> void:
	if NetworkSession.is_host or _destroyed:
		return
	_destroyed = true
	queue_free()

func _destroy(attacker_peer_id: int) -> void:
	_destroyed = true
	NetworkSession.record_final_base_destroyed(attacker_peer_id)
	if NetworkSession.is_networked and NetworkSession.is_host:
		rpc("rpc_destroy_base")
	queue_free()

func _spawn_turrets() -> void:
	var placements := _turret_placements(turret_count)
	for index in range(turret_count):
		var turret := BOSS_TURRET_SCENE.instantiate()
		turret.name = "BossTurret%02d" % (index + 1)
		turret.configure(index, mission_level)
		turret.position = placements[index]
		turret.destroyed.connect(_on_turret_destroyed)
		add_child(turret)

func _on_turret_destroyed(_turret_index: int, _attacker_peer_id: int) -> void:
	turrets_remaining = maxi(0, turrets_remaining - 1)
	shielded = turrets_remaining > 0
	queue_redraw()

func _turret_placements(count: int) -> Array[Vector2]:
	match count:
		1:
			return [Vector2(0, 45)]
		2:
			return [Vector2(-62, 35), Vector2(62, 35)]
		3:
			return [Vector2(-72, 32), Vector2(0, 49), Vector2(72, 32)]
		_:
			return [Vector2(-72, 35), Vector2(72, 35), Vector2(-38, -31), Vector2(38, -31)]

func boss_state_signature() -> Dictionary:
	return {
		"level": mission_level,
		"players": coop_player_count,
		"turrets": turret_count,
		"remaining": turrets_remaining,
		"shielded": shielded,
	}

func _draw() -> void:
	draw_rect(Rect2(-98.0, -38.0, 196.0, 96.0), Color(0.0, 0.0, 0.0, 0.34))
	draw_rect(Rect2(-88.0, -48.0, 176.0, 88.0), Color(0.10, 0.13, 0.12))
	draw_rect(Rect2(-78.0, -39.0, 156.0, 70.0), Color(0.36, 0.40, 0.30))
	draw_rect(Rect2(-40.0, -18.0, 80.0, 45.0), Color(0.25, 0.29, 0.23))
	draw_rect(Rect2(-17.0, -7.0, 34.0, 34.0), Color(0.15, 0.19, 0.18))
	draw_rect(Rect2(-4.0, -27.0, 8.0, 28.0), Color(0.17, 0.20, 0.16))
	for window_x in [-54.0, -34.0, 34.0, 54.0]:
		draw_rect(Rect2(window_x - 5.0, -18.0, 10.0, 8.0), Color(0.92, 0.63, 0.24, 0.88))
	draw_circle(Vector2(0, -32), 10.0, Color(0.19, 0.25, 0.22))
	draw_line(Vector2(-13, -32), Vector2(13, -32), Color(0.72, 0.75, 0.57), 2.0)
	draw_line(Vector2(-84.0, -40.0), Vector2(84.0, -40.0), Color(0.71, 0.63, 0.38), 3.0)
	if shielded:
		var shield_color := Color(0.32, 0.88, 1.0, 0.58 if _shield_flash > 0.0 else 0.30)
		draw_arc(Vector2.ZERO, 103.0, PI * 0.10, PI * 0.90, 36, shield_color, 5.0)
		draw_string(ThemeDB.fallback_font, Vector2(-52, 74), "DESTROY TURRETS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.94, 1.0))
	else:
		draw_string(ThemeDB.fallback_font, Vector2(-42, 74), "CORE EXPOSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.68, 0.28))
	draw_rect(Rect2(-70.0, -54.0, 140.0, 7.0), Color(0.10, 0.11, 0.10))
	draw_rect(
		Rect2(-68.0, -52.0, 136.0 * float(health) / float(maximum_health), 3.0),
		Color(0.82, 0.30, 0.20)
	)

extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var game: Node = load("res://scenes/level_01.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame

	var player: CharacterBody2D = game.get_node("Player_1")
	var camera: Camera2D = player.get_node("Camera2D")
	_check(camera.enabled, "Player camera is enabled")
	_check(camera.limit_right == int(game.get("map_size").x) and camera.limit_bottom == int(game.get("map_size").y), "Camera limits match the finite map")
	_check(get_nodes_in_group("enemies").size() >= 4, "The battlefield contains infantry enemies")

	var first_enemy: CharacterBody2D = get_nodes_in_group("enemies")[0]
	var distance_before := player.global_position.distance_to(first_enemy.global_position)
	for _frame in range(18):
		await physics_frame
	var distance_after := player.global_position.distance_to(first_enemy.global_position)
	_check(distance_after < distance_before, "Infantry advances toward the player")
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)

	var initial_position := player.global_position
	Input.action_press("move_up")
	for _frame in range(30):
		await physics_frame
	Input.action_release("move_up")
	_check(player.global_position.y < initial_position.y, "WASD movement accelerates the jeep north")

	player.global_position = Vector2(120.0, 3150.0)
	player.velocity = Vector2.ZERO
	Input.action_press("move_up")
	for _frame in range(90):
		await physics_frame
	Input.action_release("move_up")
	_check(player.global_position.y > 3040.0, "The lower river blocks jeeps away from its two bridges")

	var river_shot: Area2D = load("res://scenes/projectile.tscn").instantiate()
	# Use an open bank segment so the check measures the river layer, not a boat hit.
	river_shot.configure(Vector2(850.0, 3070.0), Vector2.UP, player, false, 1, 700.0)
	game.add_child(river_shot)
	for _frame in range(25):
		await physics_frame
	_check(
		is_instance_valid(river_shot) and river_shot.global_position.y < 2840.0,
		"Projectiles fly across river barriers while jeeps remain bridge-bound"
	)

	player.global_position = Vector2(60.0, 1050.0)
	player.velocity = Vector2.ZERO
	Input.action_press("move_left")
	for _frame in range(70):
		await physics_frame
	Input.action_release("move_left")
	_check(player.global_position.x > 0.0 and player.global_position.x < 60.0, "The west map boundary blocks jeep movement")

	player.global_position = player.get("spawn_position")
	player.velocity = Vector2.ZERO
	var player_shots_before := get_nodes_in_group("player_projectiles").size()
	var firing_position := player.global_position
	Input.action_press("fire_primary")
	Input.action_press("move_right")
	for _frame in range(4):
		await physics_frame
	Input.action_release("fire_primary")
	Input.action_release("move_right")
	_check(
		get_nodes_in_group("player_projectiles").size() > player_shots_before
		and player.global_position.x > firing_position.x,
		"The jeep can move and fire at the same time"
	)
	var latest_shot: Node2D = get_nodes_in_group("player_projectiles")[-1]
	_check(latest_shot.get("direction").x > 0.9, "Primary fire follows the jeep's facing direction")

	Input.action_press("fire_secondary")
	await physics_frame
	Input.action_release("fire_secondary")
	_check(get_nodes_in_group("grenades").size() > 0, "Secondary fire spawns a grenade")
	var base_grenade: Node = get_nodes_in_group("grenades")[-1]
	var grenade_signature: Dictionary = base_grenade.call("grenade_signature")
	_check(float(grenade_signature["throw_distance"]) >= 400.0, "The starting grenade reaches well beyond the jeep")

	var damage_target: CharacterBody2D = game.get_node("Tank01")
	var health_before: int = damage_target.get("health")
	damage_target.call("take_damage", 1)
	_check(int(damage_target.get("health")) == health_before - 1, "Enemy damage reduces heavy-unit health")

	var projectile_target: CharacterBody2D = game.get_node("Turret01")
	var projectile_health_before: int = projectile_target.get("health")
	var projectile: Area2D = load("res://scenes/projectile.tscn").instantiate()
	projectile.configure(projectile_target.global_position, Vector2.UP, player, false, 1, 1.0)
	game.add_child(projectile)
	await physics_frame
	_check(int(projectile_target.get("health")) == projectile_health_before - 1, "A machine-gun projectile damages an enemy on collision")

	var grenade: Area2D = load("res://scenes/grenade.tscn").instantiate()
	grenade.configure(damage_target.global_position, Vector2.UP, player)
	game.add_child(grenade)
	while int(damage_target.get("health")) > 2:
		damage_target.call("take_damage", 1)
	grenade.call("_explode")
	_check(damage_target.is_queued_for_deletion(), "Grenade area damage destroys a weakened nearby enemy")

	for enemy_projectile in get_nodes_in_group("enemy_projectiles"):
		enemy_projectile.queue_free()
	player.global_position = Vector2(80.0, 3100.0)
	player.velocity = Vector2.ZERO
	player.call("apply_weapon_upgrade", &"primary")
	player.call("apply_weapon_upgrade", &"secondary")
	player.call("take_damage", int(player.get("maximum_health")))
	_check(not player.visible, "A destroyed jeep is hidden during respawn")
	_check(
		int(player.get("primary_upgrade_level")) == 0
		and int(player.get("secondary_upgrade_level")) == 0,
		"Death immediately removes all collected weapon upgrades"
	)
	await create_timer(1.5).timeout
	_check(
		int(player.get("health")) == int(player.get("maximum_health")) and player.visible,
		"The jeep respawns with full health"
	)

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("Milestone 1 checks passed.")
		quit()
	else:
		push_error("%d Milestone 1 check(s) failed." % _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

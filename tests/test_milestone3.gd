extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var game: Node = load("res://scenes/level_01.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame

	var type_counts := {0: 0, 1: 0, 2: 0, 3: 0}
	for enemy in get_nodes_in_group("enemies"):
		var kind := int(enemy.get("enemy_type"))
		type_counts[kind] += 1
	_check(type_counts[0] >= 8, "Infantry remains present in the mission")
	_check(type_counts[1] >= 1, "The battlefield contains defensive turrets")
	_check(type_counts[2] >= 1, "The battlefield contains tanks")
	_check(type_counts[3] >= 1, "The river has armed boats")
	var turret: Node = game.get_node("Turret01")
	var tank: Node = game.get_node("Tank01")
	_check(
		float(turret.get("move_speed")) == 0.0
		and int(turret.get("maximum_health")) < int(tank.get("maximum_health")),
		"Turrets are stationary and tanks are tougher"
	)
	tank.call("_fire_at", Vector2.DOWN)
	var enemy_shots := get_nodes_in_group("enemy_projectiles")
	_check(int(enemy_shots[-1].get("damage")) == 2, "Heavy enemies fire stronger projectiles")

	var player: Node = game.get_node("Player_1")
	player.call("_fire_primary")
	var primary_shots := get_nodes_in_group("player_projectiles")
	var base_shot_speed := float(primary_shots[-1].get("speed"))
	var primary_pickup: Node2D = game.get_node("PrimaryUpgrade01")
	primary_pickup.global_position = player.global_position
	await physics_frame
	await physics_frame
	await process_frame
	_check(int(player.get("primary_upgrade_level")) == 1, "Collecting a machine-gun pickup upgrades the jeep")
	_check(game.get_node_or_null("PrimaryUpgrade01") == null, "Collected pickups are removed")
	player.set("_primary_cooldown", 0.0)
	player.call("_fire_primary")
	primary_shots = get_nodes_in_group("player_projectiles")
	_check(
		float(primary_shots[-1].get("speed")) > base_shot_speed,
		"Machine-gun upgrades improve primary fire"
	)

	var secondary_pickup: Node2D = game.get_node("SecondaryUpgrade01")
	secondary_pickup.global_position = player.global_position
	await physics_frame
	await physics_frame
	await process_frame
	_check(int(player.get("secondary_upgrade_level")) == 1, "Grenade upgrades belong to the collecting player")
	player.call("_fire_secondary")
	var grenades := get_nodes_in_group("grenades")
	_check(float(grenades[-1].get("blast_radius")) > 92.0, "Grenade upgrades increase blast radius")

	_check(bool(player.call("apply_weapon_upgrade", &"primary")), "Weapon upgrades can stack")
	_check(bool(player.call("apply_weapon_upgrade", &"primary")), "Weapon upgrades reach the maximum level")
	_check(not bool(player.call("apply_weapon_upgrade", &"primary")), "Weapon upgrades stop at their maximum")
	_check(int(player.get("primary_upgrade_level")) == 3, "The weapon level remains capped")

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("Milestone 3 checks passed.")
		quit()
	else:
		push_error("%d Milestone 3 check(s) failed." % _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

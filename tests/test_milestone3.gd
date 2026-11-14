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
		if enemy.is_in_group("boss_turrets"):
			continue
		var kind := int(enemy.get("enemy_type"))
		type_counts[kind] += 1
	_check(type_counts[0] >= 8, "Infantry remains present in the mission")
	var infantry_sample: Node = game.get_node("Infantry01")
	_check(int(infantry_sample.get("maximum_health")) == 1, "Infantry always dies from one standard bullet")
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
	var infantry: Node2D = game.get_node("Infantry01")
	var infantry_signature: Dictionary = infantry.call("infantry_visual_signature")
	var idle_walk_phase := float(infantry_signature["walk_phase"])
	infantry.call("_update_walk_animation", true, 0.2)
	infantry_signature = infantry.call("infantry_visual_signature")
	_check(
		str(infantry_signature["camera"]) == "orthographic_top_down"
		and bool(infantry_signature["walk_animation"])
		and bool(infantry_signature["has_alpha"])
		and float(infantry_signature["walk_phase"]) != idle_walk_phase,
		"Infantry uses a transparent true-overhead sprite with an active walking gait"
	)
	_check(int(infantry.collision_layer) == 64, "Infantry uses a non-blocking trample layer")
	infantry.set("move_speed", 0.0)
	infantry.global_position = (player as Node2D).global_position
	await physics_frame
	await physics_frame
	await process_frame
	_check(not is_instance_valid(infantry), "Driving over infantry defeats it instead of stopping the jeep")
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
	_check(int(primary_shots[-1].get("visual_level")) == 1, "Machine-gun upgrades visibly change bullets and trails")
	_check(root.get_node("AudioDirector").get_node_or_null("SFX_upgrade_gun") != null, "Machine-gun pickup uses a dedicated sound")

	var secondary_pickup: Node2D = game.get_node("SecondaryUpgrade01")
	secondary_pickup.global_position = player.global_position
	await physics_frame
	await physics_frame
	await process_frame
	_check(int(player.get("secondary_upgrade_level")) == 1, "Grenade upgrades belong to the collecting player")
	_check(root.get_node("AudioDirector").get_node_or_null("SFX_upgrade_blast") != null, "Grenade pickup uses a different dedicated sound")
	player.call("_fire_secondary")
	var grenades := get_nodes_in_group("grenades")
	_check(float(grenades[-1].get("blast_radius")) > 92.0, "Grenade upgrades increase blast radius")
	_check(int(grenades[-1].get("upgrade_level")) == 1, "Grenade upgrades select a distinct explosion style")
	grenades[-1].call("_explode")
	_check(root.get_node("AudioDirector").get_node_or_null("SFX_grenade_blast_1") != null, "Upgraded grenades use a level-specific explosion sound")

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

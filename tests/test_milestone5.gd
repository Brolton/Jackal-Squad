extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var session: Node = root.get_node("NetworkSession")
	session.call("start_solo", "SoloTester")
	var game: Node = load("res://scenes/level_01.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame

	var player: Node = game.get_node("Player_1")
	var enemies := get_nodes_in_group("enemies")
	var expected_enemy_total := enemies.size()
	for enemy in enemies:
		enemy.call("take_damage", int(enemy.get("health")), 1)
	for projectile in get_nodes_in_group("enemy_projectiles"):
		projectile.queue_free()
	_check(
		int(session.get("enemies_destroyed")) == expected_enemy_total,
		"Enemy defeats update the mission total"
	)

	var base: Node = game.get_node("FinalBase")
	base.call("take_damage", int(base.get("health")), 1)
	await process_frame
	_check(bool(session.get("final_base_destroyed")), "The final base can be destroyed")
	_check(not bool(session.get("mission_completed")), "Destroying the base alone does not win")

	var expected_passengers := 0
	for building_name in ["RescueBuilding01", "RescueBuilding02"]:
		var building: Node2D = game.get_node(building_name)
		var building_position := building.global_position
		building.call("take_damage", 4)
		expected_passengers += 3
		player.velocity = Vector2.ZERO
		player.global_position = building_position
		var boarding_deadline := Time.get_ticks_msec() + 3000
		while (
			(
				int(player.get("passenger_count")) < expected_passengers
				or not get_nodes_in_group("rescue_passengers").is_empty()
			)
			and Time.get_ticks_msec() < boarding_deadline
		):
			await physics_frame
	_check(
		int(player.get("passenger_count")) == 6,
		"One player can rescue and carry all six mission passengers"
	)

	var extraction_zone: Node2D = game.get_node("ExtractionZone")
	extraction_zone.set("helicopter_interval", 0.15)
	extraction_zone.set("_helicopter_timer", 0.1)
	extraction_zone.set("helicopter_speed", 5000.0)
	player.velocity = Vector2.ZERO
	player.global_position = extraction_zone.global_position
	var extraction_deadline := Time.get_ticks_msec() + 1000
	while not bool(player.get("_extraction_active")) and Time.get_ticks_msec() < extraction_deadline:
		await physics_frame
	_check(bool(player.get("_extraction_active")), "The solo jeep enters the extraction zone")

	extraction_deadline = Time.get_ticks_msec() + 10000
	while (
		int(session.get("rescued_passengers")) < 6
		and Time.get_ticks_msec() < extraction_deadline
	):
		await physics_frame
	await process_frame
	_check(
		int(session.get("rescued_passengers")) == 6
		and int(session.get("evacuated_passengers")) == 0,
		"Helicopters deliver all six passengers"
	)
	_check(bool(session.get("mission_completed")), "All objectives complete the mission")
	_check(float(session.get("mission_elapsed")) > 0.0, "The mission timer advances")

	var contributions: Dictionary = session.get("player_contributions")
	var solo_contribution: Dictionary = contributions.get(1, {})
	_check(
		int(solo_contribution.get("enemies_destroyed", 0)) == expected_enemy_total,
		"Solo enemy defeats are credited to the player"
	)
	_check(
		int(solo_contribution.get("passengers_rescued", 0)) == 6,
		"Solo rescues are credited after helicopter collection"
	)
	_check(
		int(solo_contribution.get("final_bases_destroyed", 0)) == 1,
		"Final base destruction is credited to the player"
	)
	var hud: Node = game.get_node("HUD")
	_check(bool(hud.get_node("VictoryPanel").visible), "Victory summary appears in the HUD")

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("Milestone 5 checks passed.")
		quit()
	else:
		push_error("%d Milestone 5 check(s) failed." % _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

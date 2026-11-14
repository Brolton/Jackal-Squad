extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var session: Node = root.get_node("NetworkSession")
	var game: Node = load("res://scenes/level_01.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.queue_free()
	for projectile in get_nodes_in_group("enemy_projectiles"):
		projectile.queue_free()
	await process_frame

	session.set("evacuated_passengers", 0)
	session.set("rescued_passengers", 0)
	var player: Node = game.get_node("Player_1")
	var building: Node2D = game.get_node("RescueBuilding01")
	var building_position := building.global_position
	building.call("take_damage", 4)
	_check(
		get_nodes_in_group("rescue_passengers").size() == 3,
		"Destroying a rescue building releases three passengers"
	)
	player.global_position = building_position
	for _frame in range(10):
		await physics_frame
	_check(int(player.get("passenger_count")) == 3, "Nearby passengers board the jeep automatically")
	_check(get_nodes_in_group("rescue_passengers").is_empty(), "Boarded passengers leave the battlefield")

	player.set("passenger_count", 5)
	_check(bool(player.call("try_add_passenger")), "A jeep can board passengers up to capacity")
	_check(not bool(player.call("try_add_passenger")), "A full jeep rejects additional passengers")
	_check(int(player.get("passenger_count")) == 6, "Passenger capacity is capped at six")

	player.set("passenger_count", 2)
	var extraction_zone: Node2D = game.get_node("ExtractionZone")
	extraction_zone.set("helicopter_interval", 60.0)
	extraction_zone.set("_helicopter_timer", 60.0)
	extraction_zone.set("helicopter_speed", 5000.0)
	player.velocity = Vector2.ZERO
	player.global_position = extraction_zone.global_position
	var deadline := Time.get_ticks_msec() + 1000
	while not bool(player.get("_extraction_active")) and Time.get_ticks_msec() < deadline:
		await physics_frame
	_check(bool(player.get("_extraction_active")), "Entering extraction starts automatic unloading")

	deadline = Time.get_ticks_msec() + 1800
	while int(session.get("evacuated_passengers")) < 1 and Time.get_ticks_msec() < deadline:
		await physics_frame
	_check(
		int(session.get("evacuated_passengers")) == 1 and int(player.get("passenger_count")) == 1,
		"Extraction unloads passengers one at a time"
	)

	player.velocity = Vector2.ZERO
	player.global_position = extraction_zone.global_position + Vector2(400.0, 0.0)
	deadline = Time.get_ticks_msec() + 1000
	while bool(player.get("_extraction_active")) and Time.get_ticks_msec() < deadline:
		await physics_frame
	_check(not bool(player.get("_extraction_active")), "Leaving extraction pauses unloading")
	var passengers_at_exit := int(player.get("passenger_count"))
	for _frame in range(45):
		await physics_frame
	_check(
		int(player.get("passenger_count")) == passengers_at_exit
		and int(session.get("evacuated_passengers")) == 1,
		"Unloading remains paused outside the extraction zone"
	)

	player.velocity = Vector2.ZERO
	player.global_position = extraction_zone.global_position
	deadline = Time.get_ticks_msec() + 1000
	while not bool(player.get("_extraction_active")) and Time.get_ticks_msec() < deadline:
		await physics_frame
	_check(bool(player.get("_extraction_active")), "Returning to extraction resumes unloading")
	deadline = Time.get_ticks_msec() + 1800
	while int(session.get("evacuated_passengers")) < 2 and Time.get_ticks_msec() < deadline:
		await physics_frame
	_check(
		int(player.get("passenger_count")) == 0
		and int(session.get("evacuated_passengers")) == 2,
		"Returning jeep unloads its remaining passengers"
	)

	extraction_zone.call("_start_helicopter")
	deadline = Time.get_ticks_msec() + 1800
	while int(session.get("rescued_passengers")) < 2 and Time.get_ticks_msec() < deadline:
		await physics_frame
	_check(
		int(session.get("rescued_passengers")) == 2
		and int(session.get("evacuated_passengers")) == 0,
		"The helicopter transfers evacuated passengers into the rescue total"
	)

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("Milestone 4 checks passed.")
		quit()
	else:
		push_error("%d Milestone 4 check(s) failed." % _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

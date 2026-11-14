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
	var extraction_zone: Node2D = game.get_node("ExtractionZone")
	var helicopter_signature: Dictionary = extraction_zone.call("helicopter_visual_signature")
	_check(
		float(helicopter_signature["travel_direction_x"]) > 0.0
		and float(helicopter_signature["cockpit_offset_x"]) > 0.0
		and float(helicopter_signature["tail_offset_x"]) < 0.0
		and bool(helicopter_signature["landing_pad"])
		and str(helicopter_signature["pad_label"]) == "H"
		and bool(helicopter_signature["staged_boarding"]),
		"The rescue helicopter flies nose-first to a marked H pad with staged boarding"
	)
	extraction_zone.set("_helicopter_timer", 0.0)
	extraction_zone.call("_physics_process", 0.1)
	_check(not bool(extraction_zone.get("_helicopter_active")), "The rescue helicopter does not fly when nobody is waiting")
	var player: Node = game.get_node("Player_1")
	var building: Node2D = game.get_node("RescueBuilding01")
	var building_position := building.global_position
	var route: PackedVector2Array = game.call("passenger_ground_path", building_position, player.global_position)
	var route_uses_bridge := false
	for point in route:
		for bridge_variant in LevelLayouts.get_layout(0)["bridges"]:
			var bridge: Rect2 = bridge_variant
			if bridge.has_point(point):
				route_uses_bridge = true
	_check(route.size() >= 3 and route_uses_bridge, "Rescued prisoners route across rivers by bridge")
	building.call("take_damage", 4)
	_check(
		get_nodes_in_group("rescue_passengers").size() == 3,
		"Destroying a rescue building releases three passengers"
	)
	var passenger: Node = get_nodes_in_group("rescue_passengers")[0]
	var passenger_signature: Dictionary = passenger.call("passenger_visual_signature")
	var idle_walk_phase := float(passenger_signature["walk_phase"])
	passenger.call("_update_walk_animation", true, 0.2)
	passenger_signature = passenger.call("passenger_visual_signature")
	_check(
		int(passenger_signature["texture_width"]) >= 1000
		and bool(passenger_signature["has_alpha"])
		and not bool(passenger_signature["armed"])
		and bool(passenger_signature["uses_ground_path"])
		and str(passenger_signature["camera"]) == "orthographic_top_down"
		and bool(passenger_signature["walk_animation"])
		and float(passenger_signature["walk_phase"]) != idle_walk_phase,
		"Rescued prisoners use a true-overhead unarmed sprite, walking gait, and ground navigation"
	)
	var lower_river: Rect2 = LevelLayouts.get_layout(0)["water"][0]
	var crossed_lower_river := false
	var entered_water_away_from_bridge := false
	for _step in range(260):
		if passenger.is_queued_for_deletion():
			break
		passenger.call("_physics_process", 0.1)
		var passenger_position: Vector2 = passenger.global_position
		if passenger_position.y > lower_river.end.y:
			crossed_lower_river = true
		if lower_river.has_point(passenger_position):
			var on_bridge := false
			for bridge_variant in LevelLayouts.get_layout(0)["bridges"]:
				var bridge: Rect2 = bridge_variant
				if bridge.has_point(passenger_position):
					on_bridge = true
			if not on_bridge:
				entered_water_away_from_bridge = true
	_check(crossed_lower_river and not entered_water_away_from_bridge, "A rescued prisoner physically crosses the river only on a bridge")
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
	extraction_zone.set("helicopter_interval", 60.0)
	extraction_zone.set("_helicopter_timer", 60.0)
	extraction_zone.set("helicopter_speed", 5000.0)
	player.velocity = Vector2.ZERO
	player.global_position = extraction_zone.global_position
	var deadline := Time.get_ticks_msec() + 1000
	while not bool(player.get("_extraction_active")) and Time.get_ticks_msec() < deadline:
		await physics_frame
	_check(
		bool(player.get("_extraction_active"))
		and bool(extraction_zone.get("_helicopter_active"))
		and int(extraction_zone.get("_helicopter_state")) == 2,
		"Standing on the pad calls the helicopter and unloading waits for its landing"
	)

	deadline = Time.get_ticks_msec() + 1800
	while int(session.get("evacuated_passengers")) < 1 and Time.get_ticks_msec() < deadline:
		await physics_frame
	_check(
		int(session.get("evacuated_passengers")) == 1 and int(player.get("passenger_count")) == 1,
		"Extraction unloads passengers one at a time"
	)
	helicopter_signature = extraction_zone.call("helicopter_visual_signature")
	_check(int(helicopter_signature["boarding_visuals"]) > 0, "An unloaded passenger visibly walks from the jeep to the helicopter")

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

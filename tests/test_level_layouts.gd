extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var expected_sizes := [Vector2(1500, 4200), Vector2(1400, 3600), Vector2(1600, 4000)]
	var minimum_enemy_counts := [30, 20, 23]
	for level_index in range(3):
		var session: Node = root.get_node("NetworkSession")
		session.call("start_solo", "LayoutTester", level_index)
		var scene_path := CampaignCatalog.scene_path(level_index)
		var game: Node = load(scene_path).instantiate()
		root.add_child(game)
		current_scene = game
		await process_frame

		_check(game.get("map_size") == expected_sizes[level_index], "Mission %d uses its large world size" % (level_index + 1))
		_check(get_nodes_in_group("enemies").size() >= minimum_enemy_counts[level_index], "Mission %d has its full encounter roster" % (level_index + 1))
		_check(game.get_tree().get_nodes_in_group("rescue_buildings").size() == 2 or game.get_node_or_null("RescueBuilding02") != null, "Mission %d has two rescue sites" % (level_index + 1))
		_check(game.get_node_or_null("ExtractionZone") != null and game.get_node_or_null("FinalBase") != null, "Mission %d has extraction and a command base" % (level_index + 1))
		_check(get_nodes_in_group("extraction_zones").size() >= 3, "Mission %d provides helipads along the route" % (level_index + 1))
		var reinforcement_signature: Dictionary = game.call("reinforcement_signature")
		var expected_infantry_limits := [1, 2, 2]
		var expected_tank_limits := [1, 1, 2]
		var expected_respawn_intervals := [12.0, 9.0, 6.0]
		_check(
			int(reinforcement_signature["infantry_limit"]) == expected_infantry_limits[level_index]
			and int(reinforcement_signature["tank_limit"]) == expected_tank_limits[level_index]
			and is_equal_approx(float(reinforcement_signature["respawn_seconds"]), expected_respawn_intervals[level_index]),
			"Mission %d reinforcement numbers and return time scale with difficulty" % (level_index + 1)
		)
		var player: Node2D = game.get_node("Player_1")
		var final_base: Node2D = game.get_node("FinalBase")
		player.global_position = final_base.global_position + Vector2(0.0, 700.0)
		var reinforcement_slots: Dictionary = game.get("_reinforcement_slots")
		for enemy_type in [0, 2]:
			var slot: Dictionary = reinforcement_slots[enemy_type]
			slot["timer"] = 0.0
			reinforcement_slots[enemy_type] = slot
		game.set("_reinforcement_slots", reinforcement_slots)
		for _spawn_attempt in range(2):
			game.call("_update_reinforcements", 0.0)
			for enemy_type in [0, 2]:
				var slot: Dictionary = reinforcement_slots[enemy_type]
				slot["timer"] = 0.0
				reinforcement_slots[enemy_type] = slot
			game.set("_reinforcement_slots", reinforcement_slots)
		var reinforcement_counts := {0: 0, 2: 0}
		for enemy in get_nodes_in_group("reinforcement_enemies"):
			reinforcement_counts[int(enemy.get("enemy_type"))] += 1
		_check(
			int(reinforcement_counts[0]) == expected_infantry_limits[level_index]
			and int(reinforcement_counts[2]) == expected_tank_limits[level_index],
			"Mission %d deploys no more than its reinforcement limits" % (level_index + 1)
		)
		var camera: Camera2D = game.get_node("Player_1/Camera2D")
		_check(camera.limit_right == int(expected_sizes[level_index].x) and camera.limit_bottom == int(expected_sizes[level_index].y), "Mission %d camera follows its world bounds" % (level_index + 1))
		if level_index == 0:
			_check(get_nodes_in_group("battlefield_decorations").size() >= 20, "Emerald Approach has dense landmark dressing")
			var layout := LevelLayouts.get_layout(0)
			_check(layout["roads"].size() >= 4 and layout["bridges"].size() == 4, "Emerald Approach has branching routes and four bridge choices")
		elif level_index == 2:
			var terrain_signature: Dictionary = game.call("terrain_render_signature")
			_check(int(terrain_signature["visible_collision_barriers"]) == 3, "Iron Highlands renders every blocking cliff pass")

		game.queue_free()
		await process_frame

	if _failures == 0:
		print("Large level layout checks passed.")
		quit()
	else:
		push_error("%d large level layout check(s) failed." % _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

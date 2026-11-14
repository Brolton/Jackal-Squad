extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var expected_sizes := [Vector2(1200, 3200), Vector2(1400, 3600), Vector2(1600, 4000)]
	var minimum_enemy_counts := [14, 20, 23]
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
		var camera: Camera2D = game.get_node("Player_1/Camera2D")
		_check(camera.limit_right == int(expected_sizes[level_index].x) and camera.limit_bottom == int(expected_sizes[level_index].y), "Mission %d camera follows its world bounds" % (level_index + 1))

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

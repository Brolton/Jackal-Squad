extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	_check(CampaignCatalog.count() == 3, "The campaign contains three missions")
	var scene_paths: Array[String] = []
	var unique_scene_paths: Dictionary = {}
	for index in range(CampaignCatalog.count()):
		var scene_path := CampaignCatalog.scene_path(index)
		scene_paths.append(scene_path)
		unique_scene_paths[scene_path] = true
		_check(ResourceLoader.exists(scene_path), "Mission %d has a loadable scene" % (index + 1))
	_check(unique_scene_paths.size() == 3, "Every mission has a distinct scene entry point")

	var session: Node = root.get_node("NetworkSession")
	session.call("start_solo", "CampaignTester", 1)
	_check(int(session.get("campaign_level_index")) == 1, "Solo play can start from a selected mission")
	_check(
		session.call("current_level_scene") == "res://scenes/level_02.tscn",
		"The selected mission resolves to its own scene"
	)
	var state: Dictionary = session.call("mission_state_snapshot")
	_check(str(state.get("level_name", "")) == "DESERT BASIN", "Mission state includes the selected desert mission name")
	_check(int(state.get("campaign_level_count", 0)) == 3, "Mission state includes campaign progress")

	session.set("mission_completed", true)
	_check(bool(session.call("advance_campaign")), "A completed mission advances the campaign")
	_check(int(session.get("campaign_level_index")) == 2, "Campaign advancement selects the next mission")
	_check(not bool(session.call("has_next_campaign_level")), "The third mission is the campaign finale")

	if _failures == 0:
		print("Campaign foundation checks passed.")
		quit()
	else:
		push_error("%d campaign foundation check(s) failed." % _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

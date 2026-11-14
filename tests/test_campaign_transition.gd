extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var session: Node = root.get_node("NetworkSession")
	session.call("start_solo", "TransitionTester", 0)
	var first_scene_path := str(session.call("current_level_scene"))
	_check(change_scene_to_file(first_scene_path) == OK, "The first mission scene starts")
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.scene_file_path == first_scene_path, "Mission one is the active scene")

	session.set("mission_completed", true)
	_check(bool(session.call("advance_campaign")), "A boss victory requests campaign advancement")
	await process_frame
	await process_frame
	var second_scene_path := str(session.call("current_level_scene"))
	_check(
		current_scene != null and current_scene.scene_file_path == second_scene_path,
		"Campaign advancement loads mission two instead of leaving mission one on screen"
	)
	_check(int(session.get("loaded_level_index")) == 1, "Mission two finishes loading its own layout")

	if _failures == 0:
		print("Campaign scene transition checks passed.")
		quit()
	else:
		push_error("%d campaign transition check(s) failed." % _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

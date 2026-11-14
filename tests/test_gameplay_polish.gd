extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var session: Node = root.get_node("NetworkSession")
	session.call("start_solo", "PolishTester", 0)
	var game: Node = load("res://scenes/level_01.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame

	_check(get_nodes_in_group("hazards").size() == 10, "Emerald Approach contains a designed multi-zone minefield")
	var mine: Area2D = get_nodes_in_group("hazards")[0]
	var player: CharacterBody2D = game.get_node("Player_1")
	var health_before := int(player.get("health"))
	mine.call("_trigger", player)
	_check(int(player.get("health")) == health_before - 2, "A mine damages an authoritative player")
	_check(bool(mine.get("_exploded")), "Triggered mines play their destruction state")
	_check(float(player.get("_hit_flash")) > 0.0 and float(player.get("_camera_trauma")) > 0.0, "Player damage activates hit flash and camera feedback")

	var enemy: CharacterBody2D = load("res://scenes/infantry.tscn").instantiate()
	enemy.call("configure_enemy", 2)
	var solo_health := int(enemy.get("maximum_health"))
	enemy.call("apply_coop_scaling", 4)
	_check(int(enemy.get("maximum_health")) > solo_health, "Enemy durability scales for a four-player squad")
	_check(float(enemy.get("fire_interval")) < 1.8, "Co-op scaling also increases enemy pressure")
	enemy.free()

	var pause_menu: CanvasLayer = game.get_node("PauseMenu")
	_check(pause_menu.find_child("ResumeButton", true, false) != null, "Pause menu offers resume")
	_check(pause_menu.find_child("RestartButton", true, false) != null, "Pause menu offers mission restart")
	_check(pause_menu.find_child("CommandButton", true, false) != null, "Pause menu offers return to command")
	pause_menu.call("_toggle_pause")
	_check(paused and pause_menu.visible, "Solo pause freezes the battlefield")
	pause_menu.call("_toggle_pause")
	_check(not paused and not pause_menu.visible, "Resume restores the battlefield")

	session.set("mission_elapsed", 45.0)
	_check(bool(session.call("restart_current_mission")), "Solo play can restart the current mission")
	_check(int(session.get("campaign_level_index")) == 0 and float(session.get("mission_elapsed")) == 0.0, "Restart preserves mission selection and resets progress")

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("Gameplay polish checks passed.")
		quit()
	else:
		push_error("%d gameplay polish check(s) failed." % _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

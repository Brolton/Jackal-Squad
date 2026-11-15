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
	var expected_enemy_health := [1, 4, 6, 4]
	var expected_fire_intervals := [1.55, 1.2, 1.8, 1.6]
	for enemy_type in range(4):
		enemy.call("configure_enemy", enemy_type)
		_check(
			int(enemy.get("maximum_health")) == expected_enemy_health[enemy_type]
			and is_equal_approx(float(enemy.get("fire_interval")), expected_fire_intervals[enemy_type]),
			"Enemy type %d retains its standard health and fire rate" % enemy_type
		)
	var player_camera: Camera2D = player.get_node("Camera2D")
	var half_view := root.get_visible_rect().size * 0.5 / player_camera.zoom
	var visible_distance := Vector2(half_view.x, half_view.y + absf(player_camera.position.y)).length()
	for enemy_type in range(4):
		_check(
			float(enemy.get("detection_range")) >= visible_distance
			and float(enemy.get("attack_range")) >= visible_distance,
			"Enemy type %d can detect and attack players anywhere on screen" % enemy_type
		)
	enemy.free()

	for existing_enemy in get_nodes_in_group("enemies"):
		existing_enemy.set_physics_process(false)
	var sentry: CharacterBody2D = load("res://scenes/infantry.tscn").instantiate()
	sentry.position = Vector2(220.0, 220.0)
	game.add_child(sentry)
	player.global_position = Vector2(1200.0, 3200.0)
	var sentry_start := sentry.global_position
	sentry.call("_physics_process", 0.5)
	_check(sentry.global_position == sentry_start, "Enemies remain at their posts while every player is outside detection range")
	player.global_position = sentry_start + Vector2(0.0, 180.0)
	sentry.call("_physics_process", 0.5)
	_check(sentry.global_position.distance_to(sentry_start) > 1.0, "Enemies engage after a player enters their detection radius")
	sentry.queue_free()

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

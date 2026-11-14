extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	_check(ProjectSettings.get_setting("display/window/stretch/mode") == "canvas_items", "Window resizing preserves a fixed game viewport")
	_check(ProjectSettings.get_setting("display/window/stretch/aspect") == "keep", "Non-16:9 windows use letterboxing instead of revealing more world")

	var session: Node = root.get_node("NetworkSession")
	session.call("start_solo", "ControlTester", 0)
	var game: Node = load("res://scenes/level_01.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var player: CharacterBody2D = game.get_node("Player_1")
	var camera: Camera2D = player.get_node("Camera2D")
	_check(camera.zoom == Vector2(1.3, 1.3), "Gameplay camera is intentionally closer to the action")
	_check(_has_physical_key("fire_primary", KEY_J), "J is bound to machine-gun fire")
	_check(_has_physical_key("fire_secondary", KEY_K), "K is bound to grenade fire")
	_check(_has_mouse_button("fire_primary", MOUSE_BUTTON_LEFT), "Left mouse remains a primary-fire alternative")
	_check(_has_mouse_button("fire_secondary", MOUSE_BUTTON_RIGHT), "Right mouse remains a grenade alternative")
	_check(not _has_physical_key("fire_primary", KEY_SPACE), "Space is no longer required for firing")
	_check(not _has_physical_key("fire_secondary", KEY_CTRL), "Ctrl is no longer required for grenades")

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("Controls and camera checks passed.")
		quit()
	else:
		push_error("%d controls/camera check(s) failed." % _failures)
		quit(1)

func _has_physical_key(action: StringName, key_code: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == key_code:
			return true
	return false

func _has_mouse_button(action: StringName, button: MouseButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventMouseButton and event.button_index == button:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

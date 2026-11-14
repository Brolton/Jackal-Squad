extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var key_art: Texture2D = load("res://assets/art/campaign_key_art.png")
	var ground_art: Texture2D = load("res://assets/art/jungle_ground.png")
	_check(key_art != null and key_art.get_width() >= 1200 and key_art.get_width() > key_art.get_height(), "Campaign key art is a high-resolution landscape texture")
	_check(ground_art != null and ground_art.get_width() >= 1000 and ground_art.get_height() >= 1000, "Battlefield ground art is a high-resolution tile texture")

	var menu: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var background := menu.find_child("CampaignKeyArt", true, false) as TextureRect
	var panel := menu.find_child("MenuPanel", true, false) as PanelContainer
	_check(background != null and background.texture == key_art, "Main menu displays the generated campaign artwork")
	_check(panel != null and panel.get_theme_stylebox("panel") is StyleBoxFlat, "Main menu uses the production panel theme")
	var mission_options := menu.find_children("*", "OptionButton", true, false)
	_check(mission_options.size() == 1 and (mission_options[0] as OptionButton).item_count == 3, "Styled menu exposes all three mission briefings")
	menu.queue_free()
	await process_frame

	var hud: CanvasLayer = load("res://scenes/hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	_check(hud.get_node_or_null("TopBackdrop") != null, "HUD has a readable tactical backdrop")
	var continue_button := hud.get_node("VictoryPanel/VBoxContainer/ContinueButton") as Button
	_check(continue_button != null and continue_button.get_theme_stylebox("normal") is StyleBoxFlat, "Mission result panel has a styled campaign action")
	hud.queue_free()
	await process_frame

	if _failures == 0:
		print("Visual presentation checks passed.")
		quit()
	else:
		push_error("%d visual presentation check(s) failed." % _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

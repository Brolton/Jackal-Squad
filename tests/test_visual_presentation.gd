extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var key_art: Texture2D = load("res://assets/art/campaign_key_art.png")
	var ground_art: Texture2D = load("res://assets/art/jungle_ground.png")
	var river_art: Texture2D = load("res://assets/art/river_water_v2.png")
	_check(key_art != null and key_art.get_width() >= 1200 and key_art.get_width() > key_art.get_height(), "Campaign key art is a high-resolution landscape texture")
	_check(ground_art != null and ground_art.get_width() >= 1000 and ground_art.get_height() >= 1000, "Battlefield ground art is a high-resolution tile texture")
	_check(river_art != null and river_art.get_width() >= 1000 and river_art.get_height() >= 1000, "River uses a high-resolution painted water texture")
	for sprite_path in [
		"res://assets/art/player_jeep_v2.png",
		"res://assets/art/enemy_infantry_v2.png",
		"res://assets/art/enemy_turret.png",
		"res://assets/art/enemy_tank.png",
		"res://assets/art/enemy_boat.png",
		"res://assets/art/rescue_prisoner_v2.png",
	]:
		var sprite_texture: Texture2D = load(sprite_path)
		_check(
			sprite_texture != null
			and sprite_texture.get_width() >= 1000
			and sprite_texture.get_image().detect_alpha() != Image.ALPHA_NONE,
			"%s is a high-resolution transparent gameplay sprite" % sprite_path.get_file()
		)

	var menu: Control = load("res://scenes/main.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	var background := menu.find_child("CampaignKeyArt", true, false) as TextureRect
	var panel := menu.find_child("MenuPanel", true, false) as PanelContainer
	_check(background != null and background.texture == key_art, "Main menu displays the generated campaign artwork")
	_check(panel != null and panel.get_theme_stylebox("panel") is StyleBoxFlat, "Main menu uses the production panel theme")
	_check(panel != null and panel.size.y <= 504.0, "Main menu fits completely inside the 960x540 base viewport")
	var mission_options := menu.find_children("MissionSelector", "OptionButton", true, false)
	_check(mission_options.size() == 1 and (mission_options[0] as OptionButton).item_count == 3, "Styled menu exposes all three mission briefings")
	var lan_picker := menu.find_child("LanServerPicker", true, false) as OptionButton
	_check(lan_picker != null, "Main menu exposes automatic LAN game discovery")
	menu.queue_free()
	await process_frame

	var hud: CanvasLayer = load("res://scenes/hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	_check(hud.get_node_or_null("TopBackdrop") != null, "HUD has a readable tactical backdrop")
	var backdrop := hud.get_node("TopBackdrop") as ColorRect
	_check(backdrop.size.y <= 64.0, "Tactical HUD stays compact and does not obscure the battlefield")
	_check(hud.get_node_or_null("ControlsHint") != null, "Control help uses a separate temporary hint")
	var continue_button := hud.get_node("VictoryPanel/VBoxContainer/ContinueButton") as Button
	_check(continue_button != null and continue_button.get_theme_stylebox("normal") is StyleBoxFlat, "Mission result panel has a styled campaign action")
	hud.queue_free()
	await process_frame

	var session: Node = root.get_node("NetworkSession")
	session.call("start_solo", "VisualTester", 0)
	var game: Node = load("res://scenes/level_01.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var player: Node = game.get_node("Player_1")
	var terrain_signature: Dictionary = game.call("terrain_render_signature")
	_check(int(terrain_signature["road_layers"]) >= 5, "Roads use layered shoulders, surface, and wheel tracks")
	_check(bool(terrain_signature["textured_water"]), "Rivers use painted water instead of a flat blue rectangle")
	_check(int(terrain_signature["bank_layers"]) >= 3 and bool(terrain_signature["bridge_planks"]), "Rivers have irregular banks and detailed bridge decks")
	var base_signature: Dictionary = player.call("weapon_visual_signature")
	_check(not bool(base_signature["team_stripes"]), "Player color is shown by the name label without painted bars on the jeep")
	player.call("apply_weapon_upgrade", &"primary")
	player.call("apply_weapon_upgrade", &"secondary")
	var upgraded_signature: Dictionary = player.call("weapon_visual_signature")
	_check(int(upgraded_signature["barrels"]) > int(base_signature["barrels"]), "Primary upgrades add visible gun barrels")
	_check(int(upgraded_signature["rocket_pods"]) > int(base_signature["rocket_pods"]), "Secondary upgrades add visible rocket pods")
	_check(int(upgraded_signature["projectile_style"]) > int(base_signature["projectile_style"]), "Primary upgrades switch projectile presentation")
	_check(int(upgraded_signature["blast_style"]) > int(base_signature["blast_style"]), "Secondary upgrades switch explosion presentation")
	var pickup_scene: PackedScene = load("res://scenes/weapon_upgrade.tscn")
	var gun_pickup: Node = pickup_scene.instantiate()
	gun_pickup.call("configure", &"primary")
	root.add_child(gun_pickup)
	var blast_pickup: Node = pickup_scene.instantiate()
	blast_pickup.call("configure", &"secondary")
	root.add_child(blast_pickup)
	var gun_signature: Dictionary = gun_pickup.call("upgrade_visual_signature")
	var blast_signature: Dictionary = blast_pickup.call("upgrade_visual_signature")
	_check(str(gun_signature["label"]) == "RAPID FIRE" and str(gun_signature["icon"]) == "multi_barrel", "Machine-gun pickup clearly names and depicts its effect")
	_check(str(blast_signature["label"]) == "ROCKETS" and str(blast_signature["icon"]) == "rocket", "Secondary pickup clearly shows that grenades become rockets")
	gun_pickup.queue_free()
	blast_pickup.queue_free()
	_check(player.get_node_or_null("TrampleArea") != null, "Jeep has a dedicated infantry trample sensor")
	game.queue_free()
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

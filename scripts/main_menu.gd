extends Control

const PLAYER_COLOR_NAMES := ["Red", "Blue", "Yellow", "Purple"]
const KEY_ART := preload("res://assets/art/campaign_key_art.png")

var _nickname_input: LineEdit
var _address_input: LineEdit
var _lan_server_picker: OptionButton
var _main_view: VBoxContainer
var _lobby_view: VBoxContainer
var _players_label: Label
var _waiting_label: Label
var _start_button: Button
var _status_label: Label
var _mission_selector: OptionButton
var _briefing_label: Label
var _lan_servers: Array = []

func _ready() -> void:
	AudioDirector.stop_music()
	_build_ui()
	NetworkSession.lobby_changed.connect(_on_lobby_changed)
	NetworkSession.status_changed.connect(_on_status_changed)
	NetworkSession.game_start_requested.connect(_on_game_start_requested)
	LanDiscovery.servers_changed.connect(_on_lan_servers_changed)
	_status_label.text = NetworkSession.status_message
	_start_lan_search()

func _build_ui() -> void:
	var background := TextureRect.new()
	background.name = "CampaignKeyArt"
	background.texture = KEY_ART
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var shade := ColorRect.new()
	shade.name = "MenuShade"
	shade.color = Color(0.01, 0.045, 0.05, 0.32)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 28)
	outer_margin.add_theme_constant_override("margin_top", 18)
	outer_margin.add_theme_constant_override("margin_right", 28)
	outer_margin.add_theme_constant_override("margin_bottom", 18)
	add_child(outer_margin)

	var row := HBoxContainer.new()
	outer_margin.add_child(row)

	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.custom_minimum_size = Vector2(430.0, 0.0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", VisualTheme.panel_style(0.93, 16))
	row.add_child(panel)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 2)
	margin.add_theme_constant_override("margin_bottom", 0)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	margin.add_child(content)

	var title := Label.new()
	title.text = "JACKAL SQUAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", VisualTheme.GOLD)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	content.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "COOPERATIVE STRIKE CAMPAIGN"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.78, 0.67))
	content.add_child(subtitle)

	_nickname_input = LineEdit.new()
	_nickname_input.placeholder_text = "Nickname"
	_nickname_input.text = "Player"
	content.add_child(_nickname_input)

	var mission_label := Label.new()
	mission_label.text = "STARTING MISSION  •  CAMPAIGN ADVANCES AFTER VICTORY"
	mission_label.add_theme_font_size_override("font_size", 10)
	mission_label.add_theme_color_override("font_color", VisualTheme.GOLD)
	content.add_child(mission_label)

	_mission_selector = OptionButton.new()
	_mission_selector.name = "MissionSelector"
	for index in range(CampaignCatalog.count()):
		_mission_selector.add_item(
			"Mission %d: %s" % [index + 1, CampaignCatalog.display_name(index)],
			index
		)
	_mission_selector.item_selected.connect(_on_mission_selected)
	content.add_child(_mission_selector)

	_briefing_label = Label.new()
	_briefing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_label.custom_minimum_size = Vector2(0, 42)
	_briefing_label.add_theme_font_size_override("font_size", 12)
	_briefing_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.73))
	content.add_child(_briefing_label)
	_on_mission_selected(0)

	var settings_row := HBoxContainer.new()
	settings_row.add_theme_constant_override("separation", 6)
	var settings_label := Label.new()
	settings_label.text = "SETTINGS"
	settings_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_label.add_theme_font_size_override("font_size", 10)
	settings_label.add_theme_color_override("font_color", VisualTheme.GOLD)
	settings_row.add_child(settings_label)
	var music_toggle := CheckButton.new()
	music_toggle.name = "MusicToggle"
	music_toggle.text = "Music"
	music_toggle.button_pressed = AudioDirector.is_music_enabled()
	music_toggle.toggled.connect(AudioDirector.set_music_enabled)
	settings_row.add_child(music_toggle)
	content.add_child(settings_row)

	_main_view = VBoxContainer.new()
	_main_view.add_theme_constant_override("separation", 5)
	content.add_child(_main_view)

	var solo_button := _make_button("Start Solo Campaign")
	solo_button.pressed.connect(_on_solo_pressed)
	_main_view.add_child(solo_button)

	var host_button := _make_button("Host Game")
	host_button.pressed.connect(_on_host_pressed)
	_main_view.add_child(host_button)

	var lan_row := HBoxContainer.new()
	lan_row.add_theme_constant_override("separation", 6)
	_lan_server_picker = OptionButton.new()
	_lan_server_picker.name = "LanServerPicker"
	_lan_server_picker.add_item("SEARCHING FOR LAN GAMES...")
	_lan_server_picker.disabled = true
	_lan_server_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lan_server_picker.item_selected.connect(_on_lan_server_selected)
	lan_row.add_child(_lan_server_picker)
	var refresh_button := _make_button("Refresh")
	refresh_button.custom_minimum_size.x = 92.0
	refresh_button.pressed.connect(_start_lan_search)
	lan_row.add_child(refresh_button)
	_main_view.add_child(lan_row)

	_address_input = LineEdit.new()
	_address_input.text = ""
	_address_input.placeholder_text = "Manual host IP (optional)"
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 6)
	_address_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(_address_input)
	var join_button := _make_button("Join Game")
	join_button.pressed.connect(_on_join_pressed)
	join_button.custom_minimum_size.x = 122.0
	join_row.add_child(join_button)
	_main_view.add_child(join_row)

	var quit_button := _make_button("Quit")
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	_main_view.add_child(quit_button)

	_lobby_view = VBoxContainer.new()
	_lobby_view.add_theme_constant_override("separation", 10)
	_lobby_view.visible = false
	content.add_child(_lobby_view)

	var lobby_title := Label.new()
	lobby_title.text = "HOST LOBBY"
	lobby_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_title.add_theme_font_size_override("font_size", 22)
	_lobby_view.add_child(lobby_title)

	_players_label = Label.new()
	_players_label.custom_minimum_size = Vector2(0.0, 120.0)
	_lobby_view.add_child(_players_label)

	_waiting_label = Label.new()
	_waiting_label.text = "Waiting for the host to start..."
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lobby_view.add_child(_waiting_label)

	_start_button = _make_button("Start Game")
	_start_button.pressed.connect(_on_start_pressed)
	_lobby_view.add_child(_start_button)

	var back_button := _make_button("Back")
	back_button.pressed.connect(_on_back_pressed)
	_lobby_view.add_child(back_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(0.0, 26.0)
	_status_label.add_theme_font_size_override("font_size", 10)
	_status_label.add_theme_color_override("font_color", Color(0.76, 0.82, 0.75))
	content.add_child(_status_label)

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 34.0)
	VisualTheme.decorate_button(button, text in ["Start Solo Campaign", "Start Game"])
	return button

func _on_mission_selected(index: int) -> void:
	var level := CampaignCatalog.get_level(index)
	_briefing_label.text = str(level["briefing"])

func _on_solo_pressed() -> void:
	NetworkSession.start_solo(_nickname_input.text, _mission_selector.get_selected_id())

func _on_host_pressed() -> void:
	NetworkSession.select_campaign_level(_mission_selector.get_selected_id())
	if NetworkSession.host_game(_nickname_input.text):
		_show_lobby()
		_refresh_lobby()

func _on_join_pressed() -> void:
	if _address_input.text.strip_edges().is_empty() and not _lan_servers.is_empty():
		_on_lan_server_selected(_lan_server_picker.selected)
	if NetworkSession.join_game(_address_input.text, _nickname_input.text):
		_show_lobby()
		_refresh_lobby()

func _on_start_pressed() -> void:
	if not NetworkSession.start_multiplayer_game():
		_status_label.text = "Only the host can start the match."

func _on_back_pressed() -> void:
	NetworkSession.leave_lobby()
	_main_view.visible = true
	_lobby_view.visible = false
	_nickname_input.editable = true
	_start_lan_search()

func _on_lobby_changed(_players: Dictionary) -> void:
	if NetworkSession.is_networked:
		_show_lobby()
		_refresh_lobby()

func _on_status_changed(message: String) -> void:
	_status_label.text = message
	if message.begins_with("Host unreachable"):
		_main_view.visible = true
		_lobby_view.visible = false
		_nickname_input.editable = true
		_start_lan_search()

func _start_lan_search() -> void:
	_lan_servers.clear()
	if _lan_server_picker != null:
		_lan_server_picker.clear()
		_lan_server_picker.add_item("SEARCHING FOR LAN GAMES...")
		_lan_server_picker.disabled = true
	if not LanDiscovery.start_browser():
		_status_label.text = "LAN search could not start. Enter the host's LAN IPv4 address manually."

func _on_lan_servers_changed(servers: Array) -> void:
	_lan_servers = servers.duplicate(true)
	_lan_server_picker.clear()
	if _lan_servers.is_empty():
		_lan_server_picker.add_item("NO LAN GAMES YET — SEARCHING...")
		_lan_server_picker.disabled = true
		return
	_lan_server_picker.disabled = false
	for server_variant in _lan_servers:
		var server: Dictionary = server_variant
		_lan_server_picker.add_item(
			"%s  •  %d/%d  •  %s"
			% [server["nickname"], server["players"], server["capacity"], server["address"]]
		)
	if _address_input.text.strip_edges().is_empty():
		_on_lan_server_selected(0)
	_status_label.text = "LAN game found. Select it and press Join Game."

func _on_lan_server_selected(index: int) -> void:
	if index < 0 or index >= _lan_servers.size():
		return
	_address_input.text = str((_lan_servers[index] as Dictionary).get("address", ""))

func _on_game_start_requested() -> void:
	get_tree().change_scene_to_file(NetworkSession.current_level_scene())

func _show_lobby() -> void:
	_main_view.visible = false
	_lobby_view.visible = true
	_nickname_input.editable = false
	_start_button.visible = NetworkSession.is_host
	_waiting_label.visible = not NetworkSession.is_host
	if NetworkSession.is_host:
		var addresses := LanDiscovery.local_ipv4_addresses()
		_waiting_label.visible = true
		_waiting_label.text = (
			"LAN ADDRESS: %s:%d\nIf no game appears, allow JackalSquad.exe in Windows Firewall."
			% [", ".join(addresses), NetworkSession.PORT]
		)
	else:
		_waiting_label.text = "Connected — waiting for the host to start."

func _refresh_lobby() -> void:
	var peer_ids: Array = NetworkSession.players.keys()
	peer_ids.sort()
	var lines: Array[String] = ["Players: %d / %d" % [peer_ids.size(), NetworkSession.MAX_PLAYERS]]
	for peer_id in peer_ids:
		var profile: Dictionary = NetworkSession.players[peer_id]
		var slot := int(profile["slot"])
		var host_marker := " (Host)" if int(peer_id) == 1 else ""
		lines.append("%s — %s%s" % [profile["nickname"], PLAYER_COLOR_NAMES[slot], host_marker])
	_players_label.text = "\n".join(lines)
	_start_button.disabled = not NetworkSession.is_host or peer_ids.is_empty()

extends Control

const PLAYER_COLOR_NAMES := ["Red", "Blue", "Yellow", "Purple"]

var _nickname_input: LineEdit
var _address_input: LineEdit
var _main_view: VBoxContainer
var _lobby_view: VBoxContainer
var _players_label: Label
var _waiting_label: Label
var _start_button: Button
var _status_label: Label
var _mission_selector: OptionButton

func _ready() -> void:
	_build_ui()
	NetworkSession.lobby_changed.connect(_on_lobby_changed)
	NetworkSession.status_changed.connect(_on_status_changed)
	NetworkSession.game_start_requested.connect(_on_game_start_requested)
	_status_label.text = NetworkSession.status_message

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.055, 0.075, 0.067)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560.0, 560.0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)

	var title := Label.new()
	title.text = "JACKAL SQUAD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.85, 0.78, 0.48))
	content.add_child(title)

	_nickname_input = LineEdit.new()
	_nickname_input.placeholder_text = "Nickname"
	_nickname_input.text = "Player"
	content.add_child(_nickname_input)

	_mission_selector = OptionButton.new()
	for index in range(CampaignCatalog.count()):
		_mission_selector.add_item(
			"Mission %d: %s" % [index + 1, CampaignCatalog.display_name(index)],
			index
		)
	content.add_child(_mission_selector)

	_main_view = VBoxContainer.new()
	_main_view.add_theme_constant_override("separation", 10)
	content.add_child(_main_view)

	var solo_button := _make_button("Play Solo")
	solo_button.pressed.connect(_on_solo_pressed)
	_main_view.add_child(solo_button)

	var host_button := _make_button("Host Game")
	host_button.pressed.connect(_on_host_pressed)
	_main_view.add_child(host_button)

	_address_input = LineEdit.new()
	_address_input.text = "127.0.0.1"
	_address_input.placeholder_text = "Host IP address"
	_main_view.add_child(_address_input)

	var join_button := _make_button("Join Game")
	join_button.pressed.connect(_on_join_pressed)
	_main_view.add_child(join_button)

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
	_status_label.custom_minimum_size = Vector2(0.0, 42.0)
	_status_label.add_theme_color_override("font_color", Color(0.76, 0.82, 0.75))
	content.add_child(_status_label)

func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 42.0)
	return button

func _on_solo_pressed() -> void:
	NetworkSession.start_solo(_nickname_input.text, _mission_selector.get_selected_id())

func _on_host_pressed() -> void:
	NetworkSession.select_campaign_level(_mission_selector.get_selected_id())
	if NetworkSession.host_game(_nickname_input.text):
		_show_lobby()
		_refresh_lobby()

func _on_join_pressed() -> void:
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

func _on_lobby_changed(_players: Dictionary) -> void:
	if NetworkSession.is_networked:
		_show_lobby()
		_refresh_lobby()

func _on_status_changed(message: String) -> void:
	_status_label.text = message

func _on_game_start_requested() -> void:
	get_tree().change_scene_to_file(NetworkSession.current_level_scene())

func _show_lobby() -> void:
	_main_view.visible = false
	_lobby_view.visible = true
	_nickname_input.editable = false
	_start_button.visible = NetworkSession.is_host
	_waiting_label.visible = not NetworkSession.is_host

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

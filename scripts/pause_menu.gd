extends CanvasLayer

var _panel: PanelContainer
var _status: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.04, 0.05, 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "PausePanel"
	_panel.custom_minimum_size = Vector2(390, 390)
	_panel.add_theme_stylebox_override("panel", VisualTheme.panel_style(0.98, 16))
	center.add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	_panel.add_child(column)
	var title := Label.new()
	title.text = "OPERATION PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", VisualTheme.GOLD)
	column.add_child(title)
	_status = Label.new()
	_status.text = "The battlefield is held." if not NetworkSession.is_networked else "Online simulation continues while this menu is open."
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var resume := _make_button("Resume", "ResumeButton")
	resume.pressed.connect(_toggle_pause)
	column.add_child(resume)
	var restart := _make_button("Restart Mission", "RestartButton")
	restart.disabled = NetworkSession.is_networked and not NetworkSession.is_host
	restart.pressed.connect(_restart_mission)
	column.add_child(restart)
	var command := _make_button("Return to Command", "CommandButton")
	command.pressed.connect(_return_to_command)
	column.add_child(command)

func _make_button(label: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = Vector2(0, 48)
	VisualTheme.decorate_button(button, label == "Resume")
	return button

func _toggle_pause() -> void:
	visible = not visible
	if not NetworkSession.is_networked:
		get_tree().paused = visible

func _restart_mission() -> void:
	if NetworkSession.restart_current_mission():
		get_tree().paused = false

func _return_to_command() -> void:
	get_tree().paused = false
	NetworkSession.leave_lobby()
	get_tree().change_scene_to_file(NetworkSession.MAIN_SCENE)

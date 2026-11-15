extends CanvasLayer

@onready var _top_backdrop: PanelContainer = $TopBackdrop
@onready var _health_display: HBoxContainer = $TopBackdrop/Row/HealthDisplay
@onready var _health_count: Label = $TopBackdrop/Row/HealthDisplay/HealthCount
@onready var _lives_count: Label = $TopBackdrop/Row/HealthDisplay/LivesCount
@onready var _passenger_display: HBoxContainer = $TopBackdrop/Row/PassengerDisplay
@onready var _passenger_count_label: Label = $TopBackdrop/Row/PassengerDisplay/PassengerCount
@onready var _primary_weapon: Control = $TopBackdrop/Row/PrimaryWeapon
@onready var _secondary_weapon: Control = $TopBackdrop/Row/SecondaryWeapon
@onready var _mission_time: Label = $TopBackdrop/Row/ClockDisplay/MissionTime
@onready var _controls_hint: Label = $ControlsHint
@onready var _victory_panel: Control = $VictoryPanel
@onready var _victory_title: Label = $VictoryPanel/VBoxContainer/Title
@onready var _victory_details: Label = $VictoryPanel/VBoxContainer/Details
@onready var _continue_button: Button = $VictoryPanel/VBoxContainer/ContinueButton
@onready var _spectator_message: Label = $SpectatorMessage

var _current_health := 0
var _maximum_health := 0
var _primary_upgrade_level := 0
var _secondary_upgrade_level := 0
var _rescued_passengers := 0
var _mission_elapsed := 0.0
var _enemies_destroyed := 0
var _mission_completed := false
var _game_over := false
var _player_contributions: Dictionary = {}
var _player_lives: Dictionary = {}
var _spectating := false
var _spectator_target_name := ""
var _campaign_level_index := 0
var _controls_hint_time := 7.0
var _auto_advance_started := false

func _ready() -> void:
	var hud_style := VisualTheme.panel_style(0.55, 12)
	hud_style.content_margin_left = 10.0
	hud_style.content_margin_right = 10.0
	hud_style.content_margin_top = 5.0
	hud_style.content_margin_bottom = 5.0
	_top_backdrop.add_theme_stylebox_override("panel", hud_style)
	_victory_panel.add_theme_stylebox_override("panel", VisualTheme.panel_style(0.97, 14))
	VisualTheme.decorate_button(_continue_button, true)
	_continue_button.pressed.connect(_on_continue_pressed)
	_refresh_health()
	_refresh_weapons()

func _process(delta: float) -> void:
	if _controls_hint_time > 0.0:
		_controls_hint_time = maxf(0.0, _controls_hint_time - delta)
		if _controls_hint_time <= 0.0:
			_controls_hint.hide()
	_mission_elapsed = NetworkSession.mission_elapsed
	var formatted_time := _format_time(_mission_elapsed)
	if _mission_time.text != formatted_time:
		_mission_time.text = formatted_time

func update_health(current: int, maximum: int) -> void:
	_current_health = current
	_maximum_health = maximum
	_refresh_health()

func update_lives(current: int, _maximum: int) -> void:
	_lives_count.text = "x%d" % current
	_lives_count.tooltip_text = "Lives remaining: %d" % current

func update_spectator_state(spectating: bool, target_name: String) -> void:
	_spectating = spectating
	_spectator_target_name = target_name
	_refresh_spectator_message()

func update_weapon_upgrades(primary_level: int, secondary_level: int) -> void:
	_primary_upgrade_level = primary_level
	_secondary_upgrade_level = secondary_level
	_refresh_weapons()

func update_passengers(current: int, _maximum: int) -> void:
	_passenger_display.visible = current > 0
	_passenger_count_label.text = "x%d" % current

func update_rescue_score(_evacuated: int, rescued: int) -> void:
	_rescued_passengers = rescued

func update_mission_state(state: Dictionary) -> void:
	_mission_elapsed = float(state.get("mission_elapsed", 0.0))
	_enemies_destroyed = int(state.get("enemies_destroyed", 0))
	_mission_completed = bool(state.get("mission_completed", false))
	_game_over = bool(state.get("game_over", false))
	_rescued_passengers = int(state.get("rescued_passengers", 0))
	_player_contributions = state.get("player_contributions", {}).duplicate(true)
	_player_lives = state.get("player_lives", {}).duplicate(true)
	_campaign_level_index = int(state.get("campaign_level_index", 0))
	_refresh_victory_panel()
	_refresh_spectator_message()

func _refresh_health() -> void:
	_health_count.text = "%d/%d" % [_current_health, _maximum_health]
	_health_display.tooltip_text = "Health: %d of %d" % [_current_health, _maximum_health]

func _refresh_weapons() -> void:
	_primary_weapon.tooltip_text = "Machine gun - Lv.%d" % (_primary_upgrade_level + 1)
	if _secondary_upgrade_level == 0:
		_secondary_weapon.set("icon_kind", &"grenade")
		_secondary_weapon.tooltip_text = "Grenade"
	else:
		_secondary_weapon.set("icon_kind", &"rocket")
		_secondary_weapon.tooltip_text = "Rocket - Lv.%d" % _secondary_upgrade_level
	_secondary_weapon.queue_redraw()

func _refresh_victory_panel() -> void:
	_victory_panel.visible = _mission_completed or _game_over
	if not _mission_completed:
		if not _game_over:
			return
	_spectator_message.hide()
	if NetworkSession.auto_advance_enabled and not _auto_advance_started and (not NetworkSession.is_networked or NetworkSession.is_host):
		if _mission_completed:
			_auto_advance_started = true
			_auto_continue_after_delay.call_deferred()
	_victory_title.text = "GAME OVER - SQUAD ELIMINATED" if _game_over else (
		"CAMPAIGN COMPLETE" if CampaignCatalog.is_last(_campaign_level_index) else "MISSION COMPLETE"
	)
	var summary: Array[String] = [
		"Time: %s" % _format_time(_mission_elapsed),
		"Enemies destroyed: %d" % _enemies_destroyed,
		"Passengers rescued: %d" % _rescued_passengers,
		"Player contributions:",
	]
	var peer_ids: Array = _player_contributions.keys()
	peer_ids.sort()
	for peer_id in peer_ids:
		var contribution: Dictionary = _player_contributions[peer_id]
		summary.append(
			"%s - %d enemies, %d passengers, %d base"
			% [
				str(contribution.get("nickname", "Player")),
				int(contribution.get("enemies_destroyed", 0)),
				int(contribution.get("passengers_rescued", 0)),
				int(contribution.get("final_bases_destroyed", 0)),
			]
		)
		if _game_over:
			summary[-1] += ", %d deaths" % int(contribution.get("deaths", 0))
		summary[-1] += ", %d lives" % int(_player_lives.get(peer_id, 0))
	_victory_details.text = "\n".join(summary)
	var is_finale := CampaignCatalog.is_last(_campaign_level_index)
	_continue_button.text = (
		"RESTART CAMPAIGN"
		if _game_over
		else ("RETURN TO COMMAND" if is_finale else "NEXT MISSION")
	)
	_continue_button.disabled = NetworkSession.is_networked and not NetworkSession.is_host
	if _continue_button.disabled:
		_continue_button.text = "WAITING FOR HOST"

func _refresh_spectator_message() -> void:
	_spectator_message.visible = _spectating and not _game_over and not _mission_completed
	if _spectator_message.visible:
		_spectator_message.text = "ELIMINATED - WAITING FOR THE NEXT MISSION\nSPECTATING %s" % _spectator_target_name.to_upper()

func _on_continue_pressed() -> void:
	if _game_over:
		NetworkSession.restart_campaign()
	elif CampaignCatalog.is_last(_campaign_level_index):
		NetworkSession.leave_lobby()
		get_tree().change_scene_to_file(NetworkSession.MAIN_SCENE)
	else:
		NetworkSession.advance_campaign()

func _auto_continue_after_delay() -> void:
	await get_tree().create_timer(4.0).timeout
	if is_inside_tree() and _mission_completed and _victory_panel.visible:
		_on_continue_pressed()

func _format_time(seconds: float) -> String:
	var total_seconds := maxi(0, int(seconds))
	return "%02d:%02d" % [int(total_seconds / 60), total_seconds % 60]

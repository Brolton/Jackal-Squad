extends CanvasLayer

@onready var _status: Label = $Status
@onready var _victory_panel: Control = $VictoryPanel
@onready var _victory_title: Label = $VictoryPanel/VBoxContainer/Title
@onready var _victory_details: Label = $VictoryPanel/VBoxContainer/Details

var _current_health := 0
var _maximum_health := 0
var _primary_upgrade_level := 0
var _secondary_upgrade_level := 0
var _passenger_count := 0
var _evacuated_passengers := 0
var _rescued_passengers := 0
var _rescue_objective_total := 6
var _mission_elapsed := 0.0
var _enemies_destroyed := 0
var _final_base_destroyed := false
var _mission_completed := false
var _player_contributions: Dictionary = {}

func update_health(current: int, maximum: int) -> void:
	_current_health = current
	_maximum_health = maximum
	_refresh()

func update_weapon_upgrades(primary_level: int, secondary_level: int) -> void:
	_primary_upgrade_level = primary_level
	_secondary_upgrade_level = secondary_level
	_refresh()

func update_passengers(current: int, _maximum: int) -> void:
	_passenger_count = current
	_refresh()

func update_rescue_score(evacuated: int, rescued: int) -> void:
	_evacuated_passengers = evacuated
	_rescued_passengers = rescued
	_refresh()

func update_mission_state(state: Dictionary) -> void:
	_mission_elapsed = float(state.get("mission_elapsed", 0.0))
	_enemies_destroyed = int(state.get("enemies_destroyed", 0))
	_rescue_objective_total = int(state.get("rescue_objective_total", 6))
	_final_base_destroyed = bool(state.get("final_base_destroyed", false))
	_mission_completed = bool(state.get("mission_completed", false))
	_evacuated_passengers = int(state.get("evacuated_passengers", 0))
	_rescued_passengers = int(state.get("rescued_passengers", 0))
	_player_contributions = state.get("player_contributions", {}).duplicate(true)
	_refresh()
	_refresh_victory_panel()

func _refresh() -> void:
	_status.text = (
		"JACKAL SQUAD  |  HEALTH: %d / %d  |  PASSENGERS: %d / 6\n"
		+ "MACHINE GUN: Lv. %d  |  GRENADE: Lv. %d\nEVACUATED: %d  |  RESCUED: %d\n"
		+ "OBJECTIVE: RESCUE %d / %d  |  FINAL BASE: %s\nTIME: %s  |  ENEMIES: %d\n"
		+ "WASD / ARROWS: DRIVE     SPACE / LMB: FIRE     CTRL / RMB: GRENADE"
	) % [
		_current_health,
		_maximum_health,
		_passenger_count,
		_primary_upgrade_level + 1,
		_secondary_upgrade_level + 1,
		_evacuated_passengers,
		_rescued_passengers,
		_rescued_passengers,
		_rescue_objective_total,
		"DESTROYED" if _final_base_destroyed else "ACTIVE",
		_format_time(_mission_elapsed),
		_enemies_destroyed,
	]

func _refresh_victory_panel() -> void:
	_victory_panel.visible = _mission_completed
	if not _mission_completed:
		return
	_victory_title.text = "MISSION COMPLETE"
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
	_victory_details.text = "\n".join(summary)

func _format_time(seconds: float) -> String:
	var total_seconds := maxi(0, int(seconds))
	return "%02d:%02d" % [int(total_seconds / 60), total_seconds % 60]

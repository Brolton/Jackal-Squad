extends CanvasLayer

@onready var _status: Label = $Status

var _current_health := 0
var _maximum_health := 0
var _primary_upgrade_level := 0
var _secondary_upgrade_level := 0

func update_health(current: int, maximum: int) -> void:
	_current_health = current
	_maximum_health = maximum
	_refresh()

func update_weapon_upgrades(primary_level: int, secondary_level: int) -> void:
	_primary_upgrade_level = primary_level
	_secondary_upgrade_level = secondary_level
	_refresh()

func _refresh() -> void:
	_status.text = (
		"JACKAL SQUAD  |  HEALTH: %d / %d\nMACHINE GUN: Lv. %d  |  GRENADE: Lv. %d\n"
		+ "WASD / ARROWS: DRIVE     SPACE / LMB: FIRE     CTRL / RMB: GRENADE"
	) % [
		_current_health,
		_maximum_health,
		_primary_upgrade_level + 1,
		_secondary_upgrade_level + 1,
	]

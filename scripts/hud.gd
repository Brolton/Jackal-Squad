extends CanvasLayer

@onready var _status: Label = $Status

func update_health(current: int, maximum: int) -> void:
	_status.text = "JACKAL SQUAD  |  HEALTH: %d / %d\nMACHINE GUN: Lv. 1  |  GRENADE: Lv. 1\nWASD / ARROWS: DRIVE     SPACE / LMB: FIRE     CTRL / RMB: GRENADE" % [current, maximum]

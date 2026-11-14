class_name CampaignCatalog
extends RefCounted

const LEVELS: Array[Dictionary] = [
	{
		"id": &"emerald_approach",
		"name": "EMERALD APPROACH",
		"briefing": "Break through the jungle corridor, rescue the captured scouts, and silence the frontier command post.",
		"scene": "res://scenes/level_01.tscn",
		"rescue_total": 6,
	},
	{
		"id": &"desert_basin",
		"name": "DESERT BASIN",
		"briefing": "Cross the sun-scorched basin, fight through the cactus fields, and evacuate the stranded field team.",
		"scene": "res://scenes/level_02.tscn",
		"rescue_total": 6,
	},
	{
		"id": &"snowbound_highlands",
		"name": "SNOWBOUND HIGHLANDS",
		"briefing": "Cross the frozen highlands, break through the snowbound defenses, and destroy the enemy headquarters.",
		"scene": "res://scenes/level_03.tscn",
		"rescue_total": 6,
	},
]

static func count() -> int:
	return LEVELS.size()

static func get_level(index: int) -> Dictionary:
	return LEVELS[clampi(index, 0, LEVELS.size() - 1)]

static func scene_path(index: int) -> String:
	return str(get_level(index)["scene"])

static func display_name(index: int) -> String:
	return str(get_level(index)["name"])

static func rescue_total(index: int) -> int:
	return int(get_level(index)["rescue_total"])

static func is_last(index: int) -> bool:
	return index >= LEVELS.size() - 1

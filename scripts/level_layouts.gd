class_name LevelLayouts
extends RefCounted

static func get_layout(index: int) -> Dictionary:
	match clampi(index, 0, 2):
		1:
			return _flooded_delta()
		2:
			return _iron_highlands()
		_:
			return _emerald_approach()

static func _emerald_approach() -> Dictionary:
	return {
		"map_size": Vector2(1200.0, 3200.0),
		"seed": 24681357,
		"palette": [Color(0.20, 0.31, 0.20), Color(0.28, 0.39, 0.24), Color(0.13, 0.24, 0.16)],
		"road": [Vector2(600, 3200), Vector2(560, 2780), Vector2(650, 2320), Vector2(520, 1950), Vector2(600, 1620), Vector2(600, 1380), Vector2(690, 1040), Vector2(570, 700), Vector2(630, 350), Vector2(600, 0)],
		"road_width": 250.0,
		"water": [Rect2(0, 1420, 1200, 200)],
		"bridges": [Rect2(510, 1380, 180, 280)],
		"barriers": [
			{"name": "WestRiverbank", "center": Vector2(255, 1520), "size": Vector2(510, 200)},
			{"name": "EastRiverbank", "center": Vector2(945, 1520), "size": Vector2(510, 200)},
		],
		"spawns": [Vector2(600, 2860), Vector2(640, 2860), Vector2(600, 2910), Vector2(640, 2910)],
		"infantry": [Vector2(600, 2500), Vector2(420, 2180), Vector2(800, 1850), Vector2(580, 1640), Vector2(670, 1270), Vector2(390, 930), Vector2(830, 560), Vector2(550, 300)],
		"heavy_enemies": [
			{"name": "Turret01", "type": 1, "position": Vector2(330, 2050)}, {"name": "Tank01", "type": 2, "position": Vector2(760, 1740)},
			{"name": "Boat01", "type": 3, "position": Vector2(430, 1510)}, {"name": "Boat02", "type": 3, "position": Vector2(770, 1510)},
			{"name": "Tank02", "type": 2, "position": Vector2(850, 600)}, {"name": "Turret02", "type": 1, "position": Vector2(340, 350)},
		],
		"obstacles": _obstacles_level_one(),
		"rescues": [Vector2(470, 2330), Vector2(760, 1150)],
		"extraction": Vector2(600, 220), "base": Vector2(600, 82),
		"upgrades": [{"type": &"primary", "position": Vector2(500, 2700)}, {"type": &"secondary", "position": Vector2(700, 2700)}],
	}

static func _flooded_delta() -> Dictionary:
	return {
		"map_size": Vector2(1400.0, 3600.0),
		"seed": 739144,
		"palette": [Color(0.17, 0.29, 0.23), Color(0.25, 0.40, 0.29), Color(0.10, 0.23, 0.20)],
		"road": [Vector2(700, 3600), Vector2(760, 3260), Vector2(540, 2920), Vector2(830, 2550), Vector2(700, 2200), Vector2(470, 1860), Vector2(780, 1510), Vector2(920, 1180), Vector2(610, 820), Vector2(700, 0)],
		"road_width": 220.0,
		"water": [Rect2(0, 2480, 1400, 230), Rect2(0, 1320, 1400, 260)],
		"bridges": [Rect2(690, 2440, 180, 310), Rect2(395, 1280, 190, 340), Rect2(890, 1280, 190, 340)],
		"barriers": [
			{"name": "LowerWestBank", "center": Vector2(345, 2595), "size": Vector2(690, 230)}, {"name": "LowerEastBank", "center": Vector2(1135, 2595), "size": Vector2(530, 230)},
			{"name": "UpperWestBank", "center": Vector2(195, 1450), "size": Vector2(390, 260)}, {"name": "UpperMidBank", "center": Vector2(738, 1450), "size": Vector2(305, 260)}, {"name": "UpperEastBank", "center": Vector2(1240, 1450), "size": Vector2(320, 260)},
		],
		"spawns": [Vector2(680, 3400), Vector2(730, 3400), Vector2(680, 3450), Vector2(730, 3450)],
		"infantry": [Vector2(710, 3160), Vector2(430, 3000), Vector2(980, 2840), Vector2(720, 2300), Vector2(370, 2100), Vector2(1020, 1930), Vector2(520, 1690), Vector2(910, 1660), Vector2(350, 1120), Vector2(1080, 1040), Vector2(620, 720), Vector2(790, 430)],
		"heavy_enemies": [
			{"name": "DeltaTurret01", "type": 1, "position": Vector2(430, 2870)}, {"name": "DeltaTank01", "type": 2, "position": Vector2(970, 2200)},
			{"name": "DeltaBoat01", "type": 3, "position": Vector2(300, 2580)}, {"name": "DeltaBoat02", "type": 3, "position": Vector2(1120, 2580)},
			{"name": "DeltaBoat03", "type": 3, "position": Vector2(720, 1450)}, {"name": "DeltaTank02", "type": 2, "position": Vector2(460, 900)},
			{"name": "DeltaTurret02", "type": 1, "position": Vector2(980, 760)}, {"name": "DeltaTurret03", "type": 1, "position": Vector2(480, 340)},
		],
		"obstacles": _scatter_obstacles(1400, 3600, 739144, 28, &"tree"),
		"rescues": [Vector2(1080, 3020), Vector2(310, 1780)],
		"extraction": Vector2(700, 250), "base": Vector2(700, 92),
		"upgrades": [{"type": &"primary", "position": Vector2(420, 3260)}, {"type": &"secondary", "position": Vector2(1020, 2260)}, {"type": &"primary", "position": Vector2(650, 980)}],
	}

static func _iron_highlands() -> Dictionary:
	return {
		"map_size": Vector2(1600.0, 4000.0),
		"seed": 991827,
		"palette": [Color(0.27, 0.28, 0.22), Color(0.39, 0.39, 0.29), Color(0.18, 0.20, 0.17)],
		"road": [Vector2(800, 4000), Vector2(1030, 3650), Vector2(520, 3290), Vector2(1080, 2870), Vector2(510, 2460), Vector2(1050, 2050), Vector2(560, 1640), Vector2(1040, 1210), Vector2(610, 760), Vector2(800, 0)],
		"road_width": 240.0,
		"water": [Rect2(0, 3050, 1600, 150)],
		"bridges": [Rect2(420, 3010, 220, 230)],
		"barriers": [
			{"name": "RavineWest", "center": Vector2(210, 3125), "size": Vector2(420, 150)}, {"name": "RavineEast", "center": Vector2(1120, 3125), "size": Vector2(960, 150)},
			{"name": "CliffPass01", "center": Vector2(270, 2700), "size": Vector2(420, 90)}, {"name": "CliffPass02", "center": Vector2(1310, 2300), "size": Vector2(430, 90)},
			{"name": "CliffPass03", "center": Vector2(280, 1450), "size": Vector2(430, 90)},
		],
		"spawns": [Vector2(780, 3800), Vector2(830, 3800), Vector2(780, 3850), Vector2(830, 3850)],
		"infantry": [Vector2(900, 3540), Vector2(570, 3360), Vector2(1100, 3140), Vector2(520, 2800), Vector2(1120, 2600), Vector2(710, 2350), Vector2(1050, 2100), Vector2(500, 1850), Vector2(940, 1600), Vector2(620, 1300), Vector2(1080, 980), Vector2(520, 700), Vector2(940, 480), Vector2(770, 280)],
		"heavy_enemies": [
			{"name": "HighlandTank01", "type": 2, "position": Vector2(1080, 3400)}, {"name": "HighlandTurret01", "type": 1, "position": Vector2(410, 3180)},
			{"name": "HighlandTank02", "type": 2, "position": Vector2(470, 2500)}, {"name": "HighlandTurret02", "type": 1, "position": Vector2(1160, 2240)},
			{"name": "HighlandTank03", "type": 2, "position": Vector2(700, 1760)}, {"name": "HighlandTurret03", "type": 1, "position": Vector2(1040, 1320)},
			{"name": "HighlandTank04", "type": 2, "position": Vector2(560, 820)}, {"name": "HighlandTurret04", "type": 1, "position": Vector2(1050, 520)},
			{"name": "HighlandTurret05", "type": 1, "position": Vector2(550, 310)},
		],
		"obstacles": _scatter_obstacles(1600, 4000, 991827, 34, &"rock"),
		"rescues": [Vector2(1240, 2920), Vector2(350, 1180)],
		"extraction": Vector2(800, 260), "base": Vector2(800, 96),
		"upgrades": [{"type": &"secondary", "position": Vector2(1180, 3650)}, {"type": &"primary", "position": Vector2(390, 2200)}, {"type": &"secondary", "position": Vector2(1180, 1500)}, {"type": &"primary", "position": Vector2(700, 620)}],
	}

static func _obstacles_level_one() -> Array[Dictionary]:
	return [
		{"position": Vector2(260, 2600), "kind": &"tree", "radius": 27.0}, {"position": Vector2(900, 2700), "kind": &"tree", "radius": 30.0},
		{"position": Vector2(350, 2360), "kind": &"rock", "radius": 20.0}, {"position": Vector2(820, 2200), "kind": &"tree", "radius": 26.0},
		{"position": Vector2(250, 1990), "kind": &"tree", "radius": 32.0}, {"position": Vector2(930, 1900), "kind": &"rock", "radius": 24.0},
		{"position": Vector2(300, 1740), "kind": &"crate", "radius": 24.0}, {"position": Vector2(890, 1690), "kind": &"tree", "radius": 30.0},
		{"position": Vector2(250, 1260), "kind": &"tree", "radius": 29.0}, {"position": Vector2(930, 1120), "kind": &"rock", "radius": 23.0},
		{"position": Vector2(330, 870), "kind": &"crate", "radius": 26.0}, {"position": Vector2(870, 760), "kind": &"tree", "radius": 32.0},
		{"position": Vector2(270, 510), "kind": &"rock", "radius": 24.0}, {"position": Vector2(950, 390), "kind": &"tree", "radius": 29.0}, {"position": Vector2(340, 180), "kind": &"tree", "radius": 28.0},
	]

static func _scatter_obstacles(width: int, height: int, seed_value: int, count_value: int, dominant: StringName) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(count_value):
		var kind := dominant
		if index % 5 == 0:
			kind = &"crate"
		elif index % 3 == 0:
			kind = &"rock" if dominant == &"tree" else &"tree"
		result.append({
			"position": Vector2(rng.randf_range(110.0, width - 110.0), rng.randf_range(300.0, height - 180.0)),
			"kind": kind,
			"radius": rng.randf_range(21.0, 34.0),
		})
	return result

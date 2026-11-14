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
		"map_size": Vector2(1500.0, 4200.0),
		"seed": 24681357,
		"palette": [Color(0.13, 0.27, 0.18), Color(0.25, 0.43, 0.24), Color(0.07, 0.19, 0.14)],
		"road": [Vector2(750, 4200), Vector2(750, 3600), Vector2(360, 2960), Vector2(520, 2480), Vector2(720, 1780), Vector2(700, 1500), Vector2(660, 1120), Vector2(760, 620), Vector2(750, 0)],
		"roads": [
			[Vector2(750, 4200), Vector2(750, 3600), Vector2(650, 3300), Vector2(360, 3040), Vector2(360, 2790), Vector2(520, 2480), Vector2(720, 1780), Vector2(700, 1500), Vector2(660, 1120), Vector2(760, 620), Vector2(750, 0)],
			[Vector2(830, 3500), Vector2(1080, 3040), Vector2(1080, 2790), Vector2(960, 2440), Vector2(720, 2050)],
			[Vector2(520, 2480), Vector2(300, 2280), Vector2(280, 2050), Vector2(470, 1870), Vector2(720, 1780)],
			[Vector2(720, 1780), Vector2(1180, 1630), Vector2(1180, 1390), Vector2(1210, 1080), Vector2(930, 820), Vector2(760, 620)],
		],
		"road_width": 170.0,
		"water": [Rect2(0, 2820, 1500, 220), Rect2(0, 1420, 1500, 240)],
		"bridges": [Rect2(280, 2780, 180, 300), Rect2(1000, 2780, 180, 300), Rect2(620, 1380, 180, 320), Rect2(1120, 1380, 180, 320)],
		"barriers": [
			{"name": "LowerWestBank", "center": Vector2(140, 2930), "size": Vector2(280, 220)},
			{"name": "LowerCenterBank", "center": Vector2(730, 2930), "size": Vector2(540, 220)},
			{"name": "LowerEastBank", "center": Vector2(1340, 2930), "size": Vector2(320, 220)},
			{"name": "UpperWestBank", "center": Vector2(310, 1540), "size": Vector2(620, 240)},
			{"name": "UpperCenterBank", "center": Vector2(960, 1540), "size": Vector2(320, 240)},
			{"name": "UpperEastBank", "center": Vector2(1400, 1540), "size": Vector2(200, 240)},
		],
		"spawns": [Vector2(720, 4000), Vector2(780, 4000), Vector2(720, 4060), Vector2(780, 4060)],
		"infantry": [Vector2(650, 3700), Vector2(850, 3560), Vector2(470, 3380), Vector2(1030, 3300), Vector2(330, 3150), Vector2(1080, 3140), Vector2(540, 2680), Vector2(980, 2520), Vector2(290, 2260), Vector2(480, 2110), Vector2(820, 1950), Vector2(1170, 1810), Vector2(690, 1320), Vector2(1180, 1160), Vector2(520, 960), Vector2(920, 780), Vector2(650, 480), Vector2(820, 310)],
		"heavy_enemies": [
			{"name": "Turret01", "type": 1, "position": Vector2(520, 3450)}, {"name": "Tank01", "type": 2, "position": Vector2(980, 3220)},
			{"name": "Boat01", "type": 3, "position": Vector2(710, 2930)}, {"name": "Boat02", "type": 3, "position": Vector2(1360, 2930)},
			{"name": "Turret02", "type": 1, "position": Vector2(230, 2450)}, {"name": "Tank02", "type": 2, "position": Vector2(900, 2200)},
			{"name": "Turret03", "type": 1, "position": Vector2(1210, 1880)}, {"name": "Boat03", "type": 3, "position": Vector2(420, 1540)},
			{"name": "Boat04", "type": 3, "position": Vector2(950, 1540)}, {"name": "Tank03", "type": 2, "position": Vector2(1190, 1030)},
			{"name": "Turret04", "type": 1, "position": Vector2(510, 720)}, {"name": "Tank04", "type": 2, "position": Vector2(810, 390)},
		],
		"obstacles": _emerald_obstacles(),
		"rescues": [Vector2(300, 2180), Vector2(1210, 1080)],
		"extraction": Vector2(750, 245),
		"extractions": [Vector2(750, 245), Vector2(720, 2050), Vector2(940, 3470)],
		"base": Vector2(750, 92),
		"upgrades": [{"type": &"primary", "position": Vector2(550, 3650)}, {"type": &"secondary", "position": Vector2(1080, 2670)}, {"type": &"primary", "position": Vector2(420, 1850)}, {"type": &"secondary", "position": Vector2(930, 820)}],
		"hazards": [Vector2(620, 3490), Vector2(880, 3410), Vector2(430, 3170), Vector2(1060, 3150), Vector2(570, 2630), Vector2(820, 2350), Vector2(410, 1940), Vector2(1040, 1770), Vector2(570, 1210), Vector2(890, 690)],
		"decorations": [
			{"kind": &"barricade", "position": Vector2(610, 3470), "rotation": 0.2}, {"kind": &"watchtower", "position": Vector2(1040, 3360)},
			{"kind": &"tent", "position": Vector2(230, 2220), "rotation": -0.15}, {"kind": &"tent", "position": Vector2(365, 2130), "rotation": 0.12},
			{"kind": &"fire", "position": Vector2(300, 2070)}, {"kind": &"antenna", "position": Vector2(190, 2110)}, {"kind": &"barricade", "position": Vector2(470, 2300), "rotation": 0.7},
			{"kind": &"ruins", "position": Vector2(1030, 2460), "rotation": -0.3}, {"kind": &"bunker", "position": Vector2(770, 1880)},
			{"kind": &"watchtower", "position": Vector2(1090, 1780)}, {"kind": &"barricade", "position": Vector2(890, 1740), "rotation": -0.4},
			{"kind": &"tent", "position": Vector2(1160, 1140), "rotation": 0.2}, {"kind": &"tent", "position": Vector2(1290, 1040), "rotation": -0.2},
			{"kind": &"fire", "position": Vector2(1220, 970)}, {"kind": &"antenna", "position": Vector2(1330, 1160)}, {"kind": &"barricade", "position": Vector2(1050, 1210), "rotation": 0.45},
			{"kind": &"bunker", "position": Vector2(540, 760)}, {"kind": &"watchtower", "position": Vector2(1020, 650)},
			{"kind": &"barricade", "position": Vector2(650, 520), "rotation": 0.1}, {"kind": &"barricade", "position": Vector2(860, 520), "rotation": -0.1},
			{"kind": &"antenna", "position": Vector2(910, 240)}, {"kind": &"bunker", "position": Vector2(590, 300)},
		],
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
		"extraction": Vector2(700, 250),
		"extractions": [Vector2(700, 250), Vector2(690, 2160), Vector2(1030, 3180)],
		"base": Vector2(700, 92),
		"upgrades": [{"type": &"primary", "position": Vector2(420, 3260)}, {"type": &"secondary", "position": Vector2(1020, 2260)}, {"type": &"primary", "position": Vector2(650, 980)}],
		"hazards": [Vector2(610, 3140), Vector2(890, 2820), Vector2(620, 2290), Vector2(940, 1880), Vector2(530, 1040), Vector2(840, 650)],
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
		"extraction": Vector2(800, 260),
		"extractions": [Vector2(800, 260), Vector2(1030, 2020), Vector2(980, 3560)],
		"base": Vector2(800, 96),
		"upgrades": [{"type": &"secondary", "position": Vector2(1180, 3650)}, {"type": &"primary", "position": Vector2(390, 2200)}, {"type": &"secondary", "position": Vector2(1180, 1500)}, {"type": &"primary", "position": Vector2(700, 620)}],
		"hazards": [Vector2(930, 3540), Vector2(650, 3270), Vector2(980, 2810), Vector2(610, 2430), Vector2(950, 2010), Vector2(650, 1580), Vector2(940, 1080), Vector2(680, 620)],
	}

static func _emerald_obstacles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 24681357
	for index in range(54):
		var outer_side := index % 2 == 0
		var x := rng.randf_range(70.0, 330.0) if outer_side else rng.randf_range(1170.0, 1430.0)
		var kind: StringName = &"tree"
		if index % 11 == 0:
			kind = &"crate"
		elif index % 7 == 0:
			kind = &"rock"
		result.append({"position": Vector2(x, rng.randf_range(260.0, 4050.0)), "kind": kind, "radius": rng.randf_range(23.0, 38.0)})
	for placement in [
		{"position": Vector2(480, 3740), "kind": &"tree", "radius": 34.0}, {"position": Vector2(1040, 3700), "kind": &"tree", "radius": 32.0},
		{"position": Vector2(520, 3300), "kind": &"rock", "radius": 25.0}, {"position": Vector2(940, 3300), "kind": &"crate", "radius": 23.0},
		{"position": Vector2(500, 2550), "kind": &"tree", "radius": 35.0}, {"position": Vector2(1020, 2380), "kind": &"rock", "radius": 27.0},
		{"position": Vector2(530, 1810), "kind": &"tree", "radius": 34.0}, {"position": Vector2(980, 1260), "kind": &"tree", "radius": 36.0},
		{"position": Vector2(440, 900), "kind": &"rock", "radius": 26.0}, {"position": Vector2(1080, 560), "kind": &"tree", "radius": 35.0},
	]:
		result.append(placement)
	return result

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

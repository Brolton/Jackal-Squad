class_name LevelLayouts
extends RefCounted

const MAP_SCALE := Vector2(1.75, 7.0)

static func get_layout(index: int) -> Dictionary:
	var layout: Dictionary
	match clampi(index, 0, 2):
		1:
			layout = _desert_basin()
		2:
			layout = _snowbound_highlands()
		_:
			layout = _emerald_approach()
	layout = _scale_layout(layout)
	_add_long_route_encounters(layout)
	_add_flank_guards(layout)
	_add_long_route_obstacles(layout)
	return layout

static func _scale_rect(rect: Rect2) -> Rect2:
	var scaled_size := rect.size * Vector2(MAP_SCALE.x, 1.0)
	return Rect2(rect.get_center() * MAP_SCALE - scaled_size * 0.5, scaled_size)

static func _scale_layout(layout: Dictionary) -> Dictionary:
	var scaled := {}
	for key in layout:
		var value: Variant = layout[key]
		if value is Vector2:
			scaled[key] = value * MAP_SCALE
		elif value is Rect2:
			scaled[key] = _scale_rect(value)
		elif value is Array:
			scaled[key] = _scale_array(value)
		elif value is Dictionary:
			scaled[key] = _scale_dictionary(value)
		elif key == "road_width":
			scaled[key] = float(value) * MAP_SCALE.x
		else:
			scaled[key] = value
	return scaled

static func _scale_array(values: Array) -> Array:
	var scaled: Array = []
	for value in values:
		if value is Vector2:
			scaled.append(value * MAP_SCALE)
		elif value is Rect2:
			scaled.append(_scale_rect(value))
		elif value is Array:
			scaled.append(_scale_array(value))
		elif value is Dictionary:
			scaled.append(_scale_dictionary(value))
		else:
			scaled.append(value)
	return scaled

static func _scale_dictionary(values: Dictionary) -> Dictionary:
	var scaled := {}
	for key in values:
		var value: Variant = values[key]
		if value is Vector2:
			var scale := Vector2(MAP_SCALE.x, 1.0) if key == "size" else MAP_SCALE
			scaled[key] = value * scale
		elif value is Rect2:
			scaled[key] = _scale_rect(value)
		elif value is Array:
			scaled[key] = _scale_array(value)
		elif value is Dictionary:
			scaled[key] = _scale_dictionary(value)
		else:
			scaled[key] = value
	return scaled

static func _add_long_route_encounters(layout: Dictionary) -> void:
	var road: Array = layout["road"]
	var width := float(layout["road_width"])
	var infantry: Array = layout["infantry"]
	var heavy_enemies: Array = layout["heavy_enemies"]
	var heavy_types := [1, 2, 1, 2]
	var heavy_index := 0
	for segment_index in range(1, road.size()):
		var start: Vector2 = road[segment_index - 1]
		var finish: Vector2 = road[segment_index]
		var direction := (finish - start).normalized()
		var side := Vector2(-direction.y, direction.x)
		for encounter_index in range(3):
			var progress := float(encounter_index + 1) / 4.0
			var offset := width * (0.7 if encounter_index % 2 == 0 else -0.7)
			infantry.append(start.lerp(finish, progress) + side * offset)
		if segment_index % 2 == 0:
			var position := start.lerp(finish, 0.58) - side * width * 0.9
			heavy_enemies.append({
				"name": "RouteGuard%02d" % (heavy_index + 1),
				"type": heavy_types[heavy_index % heavy_types.size()],
				"position": position,
			})
			heavy_index += 1
	layout["infantry"] = infantry
	layout["heavy_enemies"] = heavy_enemies

static func _add_flank_guards(layout: Dictionary) -> void:
	var map_size: Vector2 = layout["map_size"]
	var infantry: Array = layout["infantry"]
	var water_rects: Array = layout["water"]
	var guard_rows := maxi(2, int(ceil(map_size.y / 1100.0)))
	for row in range(1, guard_rows):
		var y := map_size.y * float(row) / float(guard_rows)
		for x in [56.0, map_size.x - 56.0]:
			var position := Vector2(x, y)
			for water: Rect2 in water_rects:
				if water.has_point(position):
					var north_bank := water.position.y - 145.0
					var south_bank := water.end.y + 145.0
					position.y = north_bank if absf(position.y - north_bank) < absf(position.y - south_bank) else south_bank
			infantry.append(position)
	layout["infantry"] = infantry

static func _add_long_route_obstacles(layout: Dictionary) -> void:
	var map_size: Vector2 = layout["map_size"]
	var terrain: StringName = layout["terrain_theme"]
	var obstacle_kind: StringName = &"tree"
	if terrain == &"desert":
		obstacle_kind = &"cactus"
	elif terrain == &"snow":
		obstacle_kind = &"snow_tree"
	var placements: Array = layout["obstacles"]
	placements.append_array(
		_scatter_obstacles(
			int(map_size.x),
			int(map_size.y),
			int(layout["seed"]) + 41827,
			360,
			obstacle_kind
		)
	)
	layout["obstacles"] = placements

static func _emerald_approach() -> Dictionary:
	return {
		"map_size": Vector2(1500.0, 4200.0),
		"terrain_theme": &"jungle",
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

static func _desert_basin() -> Dictionary:
	return {
		"map_size": Vector2(1400.0, 3600.0),
		"terrain_theme": &"desert",
		"seed": 739144,
		"palette": [Color(0.38, 0.32, 0.24), Color(0.55, 0.45, 0.32), Color(0.25, 0.27, 0.26)],
		"road": [Vector2(700, 3600), Vector2(760, 3260), Vector2(540, 2920), Vector2(830, 2550), Vector2(700, 2200), Vector2(470, 1860), Vector2(780, 1510), Vector2(920, 1180), Vector2(610, 820), Vector2(700, 0)],
		"road_width": 220.0,
		"water": [],
		"bridges": [],
		"barriers": [
			{"name": "CliffPass01", "center": Vector2(220, 2800), "size": Vector2(420, 90)},
			{"name": "CliffPass02", "center": Vector2(1180, 2050), "size": Vector2(400, 90)},
			{"name": "CliffPass03", "center": Vector2(250, 1120), "size": Vector2(460, 90)},
		],
		"spawns": [Vector2(680, 3400), Vector2(730, 3400), Vector2(680, 3450), Vector2(730, 3450)],
		"infantry": [Vector2(710, 3160), Vector2(430, 3000), Vector2(980, 2840), Vector2(720, 2300), Vector2(370, 2100), Vector2(1020, 1930), Vector2(520, 1690), Vector2(910, 1660), Vector2(350, 1120), Vector2(1080, 1040), Vector2(620, 720), Vector2(790, 430)],
		"heavy_enemies": [
			{"name": "DesertTurret01", "type": 1, "position": Vector2(430, 2870)}, {"name": "DesertTank01", "type": 2, "position": Vector2(970, 2200)},
			{"name": "DesertTank02", "type": 2, "position": Vector2(300, 2580)}, {"name": "DesertTurret02", "type": 1, "position": Vector2(1120, 2580)},
			{"name": "DesertTank03", "type": 2, "position": Vector2(720, 1450)}, {"name": "DesertTank04", "type": 2, "position": Vector2(460, 900)},
			{"name": "DesertTurret03", "type": 1, "position": Vector2(980, 760)}, {"name": "DesertTurret04", "type": 1, "position": Vector2(480, 340)},
		],
		"obstacles": _scatter_obstacles(1400, 3600, 739144, 120, &"cactus"),
		"rescues": [Vector2(1080, 3020), Vector2(310, 1780)],
		"extraction": Vector2(700, 250),
		"extractions": [Vector2(700, 250), Vector2(690, 2160), Vector2(1030, 3180)],
		"base": Vector2(700, 92),
		"upgrades": [{"type": &"primary", "position": Vector2(420, 3260)}, {"type": &"secondary", "position": Vector2(1020, 2260)}, {"type": &"primary", "position": Vector2(650, 980)}],
		"hazards": [Vector2(610, 3140), Vector2(890, 2820), Vector2(620, 2290), Vector2(940, 1880), Vector2(530, 1040), Vector2(840, 650)],
	}

static func _snowbound_highlands() -> Dictionary:
	return {
		"map_size": Vector2(1600.0, 4000.0),
		"terrain_theme": &"snow",
		"seed": 991827,
		"palette": [Color(0.82, 0.87, 0.89), Color(0.94, 0.97, 0.98), Color(0.63, 0.73, 0.77)],
		"road": [Vector2(800, 4000), Vector2(1030, 3650), Vector2(520, 3290), Vector2(1080, 2870), Vector2(510, 2460), Vector2(1050, 2050), Vector2(560, 1640), Vector2(1040, 1210), Vector2(610, 760), Vector2(800, 0)],
		"road_width": 240.0,
		"water": [],
		"bridges": [],
		"barriers": [
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
		"obstacles": _scatter_obstacles(1600, 4000, 991827, 120, &"snow_tree"),
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
	var secondary: StringName = &"rock"
	if dominant == &"snow_tree":
		secondary = &"snow_rock"
	for index in range(count_value):
		var kind := dominant
		if index % 5 == 0:
			kind = &"crate"
		elif index % 3 == 0:
			kind = secondary
		result.append({
			"position": Vector2(rng.randf_range(110.0, width - 110.0), rng.randf_range(300.0, height - 180.0)),
			"kind": kind,
			"radius": rng.randf_range(21.0, 34.0),
		})
	return result

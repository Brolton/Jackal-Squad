extends Node2D

@export_range(0, 2) var level_index := 0

const PLAYER_SCENE := preload("res://scenes/player_jeep.tscn")
const INFANTRY_SCENE := preload("res://scenes/infantry.tscn")
const OBSTACLE_SCENE := preload("res://scenes/obstacle.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")
const WEAPON_UPGRADE_SCENE := preload("res://scenes/weapon_upgrade.tscn")
const RESCUE_BUILDING_SCENE := preload("res://scenes/rescue_building.tscn")
const EXTRACTION_ZONE_SCENE := preload("res://scenes/extraction_zone.tscn")
const FINAL_BASE_SCENE := preload("res://scenes/final_base.tscn")
const GROUND_TEXTURE := preload("res://assets/art/jungle_ground.png")
const RIVER_TEXTURE := preload("res://assets/art/river_water_v2.png")
const MINE_HAZARD_SCENE := preload("res://scenes/mine_hazard.tscn")
const PAUSE_MENU_SCENE := preload("res://scenes/pause_menu.tscn")
const DECORATION_SCENE := preload("res://scenes/battlefield_decoration.tscn")

var map_size := Vector2(1200.0, 3200.0)
var _layout: Dictionary = {}
var _reinforcement_slots: Dictionary = {}
var _reinforcement_serials: Dictionary = {}
var _reinforcements_enabled := false

func _ready() -> void:
	_layout = LevelLayouts.get_layout(level_index)
	map_size = _layout["map_size"]
	AudioDirector.start_music(level_index)
	NetworkSession.set_loaded_level(level_index)
	queue_redraw()
	_create_map_collisions()
	_create_obstacles()
	_create_decorations()
	_create_hazards()
	_create_players_and_enemies()
	_create_rescue_objects()
	_create_final_base()
	_configure_reinforcements()
	add_child(PAUSE_MENU_SCENE.instantiate())
	NetworkSession.player_left.connect(_on_player_left)
	NetworkSession.game_start_requested.connect(_on_game_start_requested)

func _physics_process(delta: float) -> void:
	_update_reinforcements(delta)

func _exit_tree() -> void:
	AudioDirector.stop_mission_audio()

func _configure_reinforcements() -> void:
	var configurations := [
		{"infantry": 1, "tanks": 1, "respawn": 12.0},
		{"infantry": 2, "tanks": 1, "respawn": 9.0},
		{"infantry": 2, "tanks": 2, "respawn": 6.0},
	]
	var configuration: Dictionary = configurations[clampi(level_index, 0, 2)]
	for enemy_type in [0, 2]:
		var limit := int(configuration["infantry"] if enemy_type == 0 else configuration["tanks"])
		_reinforcement_slots[enemy_type] = {
			"limit": limit,
			"interval": float(configuration["respawn"]),
			"timer": 3.0 if enemy_type == 0 else 5.0,
		}
		_reinforcement_serials[enemy_type] = 0

func _update_reinforcements(delta: float) -> void:
	if (
		NetworkSession.mission_completed
		or NetworkSession.game_over
		or (NetworkSession.is_networked and not NetworkSession.is_host)
	):
		return
	var boss := get_node_or_null("FinalBase") as Node2D
	if boss == null:
		return
	var nearest_player := _nearest_player_to_boss(boss.global_position)
	if nearest_player == null or nearest_player.global_position.distance_to(boss.global_position) > 1350.0:
		return
	_reinforcements_enabled = true
	for enemy_type in [0, 2]:
		var slot: Dictionary = _reinforcement_slots[enemy_type]
		if _active_reinforcement_count(enemy_type) >= int(slot["limit"]):
			slot["timer"] = float(slot["interval"])
			_reinforcement_slots[enemy_type] = slot
			continue
		slot["timer"] = float(slot["timer"]) - delta
		if float(slot["timer"]) <= 0.0:
			_spawn_reinforcement(enemy_type, nearest_player)
			slot["timer"] = float(slot["interval"])
		_reinforcement_slots[enemy_type] = slot

func _nearest_player_to_boss(boss_position: Vector2) -> Node2D:
	var nearest: Node2D
	var nearest_distance := INF
	for player in get_tree().get_nodes_in_group("players"):
		if not player is Node2D or not player.visible:
			continue
		var distance := boss_position.distance_squared_to(player.global_position)
		if distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	return nearest

func _active_reinforcement_count(enemy_type: int) -> int:
	var count := 0
	for enemy in get_tree().get_nodes_in_group("reinforcement_enemies"):
		if (
			is_instance_valid(enemy)
			and not enemy.is_queued_for_deletion()
			and int(enemy.get("enemy_type")) == enemy_type
		):
			count += 1
	return count

func _spawn_reinforcement(enemy_type: int, nearby_player: Node2D) -> void:
	var serial := int(_reinforcement_serials[enemy_type]) + 1
	_reinforcement_serials[enemy_type] = serial
	var kind_name := "Infantry" if enemy_type == 0 else "Tank"
	var enemy_name := "Reinforcement%s_%03d" % [kind_name, serial]
	var camera := nearby_player.get_node_or_null("Camera2D") as Camera2D
	var screen_top := nearby_player.global_position.y - 210.0
	if camera != null:
		var half_height := get_viewport_rect().size.y * 0.5 / maxf(camera.zoom.y, 0.01)
		screen_top = camera.global_position.y - half_height + 24.0
	var type_offset := -55.0 if enemy_type == 0 else 55.0
	var reinforcement_x := clampf(
		nearby_player.global_position.x + float((serial % 3) - 1) * 90.0 + type_offset,
		40.0,
		map_size.x - 40.0
	)
	var spawn_position := Vector2(
		reinforcement_x,
		clampf(screen_top, 24.0, map_size.y - 24.0)
	)
	_create_reinforcement_enemy(enemy_type, enemy_name, spawn_position)
	if NetworkSession.is_networked and NetworkSession.is_host:
		rpc("rpc_spawn_reinforcement", enemy_type, enemy_name, spawn_position)

func _create_reinforcement_enemy(enemy_type: int, enemy_name: String, spawn_position: Vector2) -> void:
	var enemy := INFANTRY_SCENE.instantiate()
	enemy.name = enemy_name
	enemy.configure_enemy(enemy_type)
	enemy.apply_coop_scaling(maxi(1, NetworkSession.players.size()))
	enemy.position = spawn_position
	enemy.add_to_group("reinforcement_enemies")
	add_child(enemy)

@rpc("authority", "call_remote", "reliable")
func rpc_spawn_reinforcement(enemy_type: int, enemy_name: String, spawn_position: Vector2) -> void:
	if NetworkSession.is_host:
		return
	_create_reinforcement_enemy(enemy_type, enemy_name, spawn_position)

func reinforcement_signature() -> Dictionary:
	var infantry_slot: Dictionary = _reinforcement_slots.get(0, {})
	var tank_slot: Dictionary = _reinforcement_slots.get(2, {})
	return {
		"infantry_limit": int(infantry_slot.get("limit", 0)),
		"tank_limit": int(tank_slot.get("limit", 0)),
		"respawn_seconds": float(infantry_slot.get("interval", 0.0)),
		"enabled_near_boss": _reinforcements_enabled,
	}

func _on_game_start_requested() -> void:
	get_tree().change_scene_to_file(NetworkSession.current_level_scene())

func _draw() -> void:
	var palette: Array = _layout["palette"]
	var terrain: StringName = _layout["terrain_theme"]
	draw_rect(Rect2(Vector2.ZERO, map_size), palette[0])
	for band in range(5):
		var band_height := map_size.y / 5.0
		var band_color: Color = palette[0].lightened(0.025) if band % 2 == 0 else palette[0].darkened(0.025)
		draw_rect(Rect2(0.0, band * band_height, map_size.x, band_height), band_color)
	if terrain == &"jungle":
		draw_texture_rect(GROUND_TEXTURE, Rect2(Vector2.ZERO, map_size), true, Color(0.70, 0.76, 0.64, 0.40))
	else:
		_draw_terrain_accents(terrain)

	var road_width := float(_layout["road_width"])
	var road_paths: Array = _layout.get("roads", [_layout["road"]])
	for road_points: Array in road_paths:
		_draw_road(PackedVector2Array(road_points), road_width, terrain)
	for water_rect: Rect2 in _layout["water"]:
		_draw_river(water_rect)
	for bridge_rect: Rect2 in _layout["bridges"]:
		_draw_bridge(bridge_rect)
	for barrier: Dictionary in _layout["barriers"]:
		if str(barrier["name"]).begins_with("CliffPass"):
			_draw_cliff_barrier(barrier["center"], barrier["size"], terrain)

func _draw_terrain_accents(terrain: StringName) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_layout["seed"]) + 983
	var accent_count := int(map_size.y / 115.0)
	for _index in range(accent_count):
		var position := Vector2(rng.randf_range(0.0, map_size.x), rng.randf_range(0.0, map_size.y))
		if terrain == &"desert":
			var radius := rng.randf_range(8.0, 28.0)
			draw_circle(position, radius, Color(0.78, 0.64, 0.44, 0.16))
			draw_circle(position + Vector2(radius * 0.45, -radius * 0.25), radius * 0.35, Color(0.88, 0.75, 0.56, 0.22))
		else:
			var radius := rng.randf_range(18.0, 64.0)
			draw_circle(position, radius, Color(0.94, 0.98, 1.0, 0.48))
			draw_arc(position, radius * 0.72, 0.2, 2.8, 12, Color(0.55, 0.72, 0.82, 0.22), 2.0)

func _draw_road(points: PackedVector2Array, width: float, terrain: StringName) -> void:
	if points.size() < 2:
		return
	var shoulder := Color(0.08, 0.10, 0.07, 0.48)
	var edge := Color(0.31, 0.27, 0.18)
	var surface := Color(0.42, 0.34, 0.23)
	var track := Color(0.21, 0.18, 0.14, 0.42)
	if terrain == &"desert":
		shoulder = Color(0.19, 0.18, 0.16, 0.52)
		edge = Color(0.48, 0.40, 0.31)
		surface = Color(0.34, 0.31, 0.27)
		track = Color(0.18, 0.17, 0.15, 0.45)
	elif terrain == &"snow":
		shoulder = Color(0.35, 0.48, 0.55, 0.50)
		edge = Color(0.54, 0.65, 0.70)
		surface = Color(0.39, 0.48, 0.52)
		track = Color(0.23, 0.31, 0.35, 0.48)
	draw_polyline(points, shoulder, width + 34.0, true)
	draw_polyline(points, edge, width + 22.0, true)
	draw_polyline(points, edge.lightened(0.12), width + 10.0, true)
	draw_polyline(points, surface, width, true)
	for offset in [-width * 0.24, width * 0.24]:
		var wheel_track := _offset_path(points, offset)
		draw_polyline(wheel_track, track, 5.0, true)
		draw_polyline(wheel_track, edge.lightened(0.2), 1.5, true)
	for index in range(1, points.size()):
		var start := points[index - 1]
		var finish := points[index]
		var segment := finish - start
		var steps := maxi(1, int(segment.length() / 72.0))
		for step in range(steps):
			var ratio := (float(step) + 0.5) / float(steps)
			var center := start.lerp(finish, ratio)
			var tangent := segment.normalized()
			var normal := Vector2(-tangent.y, tangent.x)
			var side := -1.0 if (index + step) % 2 == 0 else 1.0
			draw_circle(center + normal * width * 0.36 * side, 3.0, Color(0.23, 0.19, 0.13, 0.42))

func _offset_path(points: PackedVector2Array, distance: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in range(points.size()):
		var tangent: Vector2
		if index == 0:
			tangent = points[1] - points[0]
		elif index == points.size() - 1:
			tangent = points[index] - points[index - 1]
		else:
			tangent = points[index + 1] - points[index - 1]
		var normal := Vector2(-tangent.y, tangent.x).normalized()
		result.append(points[index] + normal * distance)
	return result

func _draw_river(water_rect: Rect2) -> void:
	draw_rect(water_rect.grow(18.0), Color(0.09, 0.12, 0.08, 0.82))
	draw_rect(water_rect.grow(10.0), Color(0.35, 0.29, 0.18))
	draw_texture_rect(RIVER_TEXTURE, water_rect, true, Color(0.66, 0.82, 0.78, 0.92))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_layout["seed"]) + int(water_rect.position.y)
	for edge_y in [water_rect.position.y, water_rect.end.y]:
		var bank := PackedVector2Array()
		var foam := PackedVector2Array()
		var direction := 1.0 if edge_y == water_rect.position.y else -1.0
		for x in range(int(water_rect.position.x), int(water_rect.end.x) + 1, 36):
			var wobble := rng.randf_range(-4.0, 4.0)
			bank.append(Vector2(x, edge_y + wobble))
			foam.append(Vector2(x, edge_y + direction * (7.0 + wobble * 0.35)))
		draw_polyline(bank, Color(0.55, 0.43, 0.25), 10.0, true)
		draw_polyline(bank, Color(0.15, 0.24, 0.13), 4.0, true)
		draw_polyline(foam, Color(0.60, 0.88, 0.84, 0.58), 2.0, true)
	for x in range(int(water_rect.position.x + 40.0), int(water_rect.end.x), 120):
		var y := water_rect.position.y + water_rect.size.y * (0.28 if x % 240 == 0 else 0.68)
		draw_arc(Vector2(x, y), 16.0, 0.15, 2.65, 12, Color(0.72, 0.94, 0.88, 0.42), 1.5)

func _draw_bridge(bridge_rect: Rect2) -> void:
	draw_rect(Rect2(bridge_rect.position + Vector2(5, 7), bridge_rect.size), Color(0.03, 0.04, 0.03, 0.52))
	draw_rect(bridge_rect, Color(0.24, 0.17, 0.11))
	var deck := bridge_rect.grow(-10.0)
	draw_rect(deck, Color(0.54, 0.39, 0.22))
	draw_line(Vector2(deck.position.x + 5, deck.position.y), Vector2(deck.position.x + 5, deck.end.y), Color(0.18, 0.12, 0.08), 5.0)
	draw_line(Vector2(deck.end.x - 5, deck.position.y), Vector2(deck.end.x - 5, deck.end.y), Color(0.18, 0.12, 0.08), 5.0)
	for y in range(int(deck.position.y + 12.0), int(deck.end.y), 18):
		draw_line(Vector2(deck.position.x + 8, y), Vector2(deck.end.x - 8, y), Color(0.28, 0.20, 0.13, 0.85), 2.0)
		draw_line(Vector2(deck.position.x + 10, y + 2), Vector2(deck.end.x - 10, y + 2), Color(0.69, 0.51, 0.28, 0.38), 1.0)

func _draw_cliff_barrier(center: Vector2, dimensions: Vector2, terrain: StringName) -> void:
	var barrier_rect := Rect2(center - dimensions * 0.5, dimensions)
	var rock_color := Color(0.43, 0.43, 0.34)
	var highlight_color := Color(0.66, 0.63, 0.48)
	if terrain == &"desert":
		rock_color = Color(0.52, 0.42, 0.30)
		highlight_color = Color(0.72, 0.58, 0.39)
	elif terrain == &"snow":
		rock_color = Color(0.56, 0.68, 0.73)
		highlight_color = Color(0.91, 0.97, 0.99)
	draw_rect(barrier_rect.grow(8.0), Color(0.08, 0.09, 0.07, 0.48))
	draw_rect(barrier_rect, rock_color.darkened(0.25))
	draw_line(barrier_rect.position, Vector2(barrier_rect.end.x, barrier_rect.position.y), highlight_color, 5.0)
	draw_line(Vector2(barrier_rect.position.x, barrier_rect.end.y), barrier_rect.end, rock_color.darkened(0.35), 6.0)
	var rock_count := maxi(3, int(dimensions.x / 38.0))
	for index in range(rock_count):
		var ratio := (float(index) + 0.5) / float(rock_count)
		var x := lerpf(barrier_rect.position.x, barrier_rect.end.x, ratio)
		var y := center.y + sin(float(index) * 2.31) * dimensions.y * 0.18
		var radius := 13.0 + float(index % 3) * 3.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - radius, y + radius * 0.45),
			Vector2(x - radius * 0.58, y - radius * 0.72),
			Vector2(x + radius * 0.18, y - radius),
			Vector2(x + radius, y - radius * 0.12),
			Vector2(x + radius * 0.64, y + radius * 0.72),
		]), rock_color)
		draw_line(Vector2(x - radius * 0.42, y - radius * 0.34), Vector2(x + radius * 0.25, y - radius * 0.60), highlight_color, 2.0)

func terrain_render_signature() -> Dictionary:
	var visible_barriers := 0
	for barrier: Dictionary in _layout.get("barriers", []):
		if str(barrier["name"]).begins_with("CliffPass"):
			visible_barriers += 1
	return {
		"terrain_theme": _layout.get("terrain_theme", &"jungle"),
		"road_layers": 6,
		"textured_water": RIVER_TEXTURE != null and not _layout.get("water", []).is_empty(),
		"bank_layers": 3 if not _layout.get("water", []).is_empty() else 0,
		"bridge_planks": not _layout.get("bridges", []).is_empty(),
		"visible_collision_barriers": visible_barriers,
	}

func passenger_ground_path(from_position: Vector2, target_position: Vector2) -> PackedVector2Array:
	var path := PackedVector2Array()
	var water_rects: Array = _layout.get("water", []).duplicate()
	var travelling_down := target_position.y > from_position.y
	water_rects.sort_custom(func(left: Rect2, right: Rect2) -> bool:
		return left.position.y < right.position.y if travelling_down else left.position.y > right.position.y
	)
	var current_position := from_position
	for water_variant in water_rects:
		var water: Rect2 = water_variant
		var current_side := _water_side(current_position, water)
		var target_side := _water_side(target_position, water)
		if current_side == 0 or current_side == target_side:
			continue
		var bridge := _best_bridge_for_crossing(water, current_position, target_position)
		if bridge.size == Vector2.ZERO:
			continue
		var crossing_x := bridge.get_center().x
		var near_y := water.position.y - 14.0 if current_side < 0 else water.end.y + 14.0
		var far_y := water.end.y + 14.0 if current_side < 0 else water.position.y - 14.0
		path.append(Vector2(crossing_x, near_y))
		if target_side == 0 and bridge.has_point(target_position):
			path.append(target_position)
			current_position = target_position
			break
		path.append(Vector2(crossing_x, far_y))
		current_position = Vector2(crossing_x, far_y)
	if path.is_empty() or path[-1].distance_to(target_position) > 1.0:
		path.append(target_position)
	return path

func _water_side(point: Vector2, water: Rect2) -> int:
	if point.y < water.position.y:
		return -1
	if point.y > water.end.y:
		return 1
	return 0

func _best_bridge_for_crossing(water: Rect2, from_position: Vector2, target_position: Vector2) -> Rect2:
	var best_bridge := Rect2()
	var best_score := INF
	for bridge_variant in _layout.get("bridges", []):
		var bridge: Rect2 = bridge_variant
		if bridge.end.y < water.position.y or bridge.position.y > water.end.y:
			continue
		if bridge.has_point(target_position):
			return bridge
		var center := bridge.get_center()
		var score := from_position.distance_to(center) + center.distance_to(target_position)
		if score < best_score:
			best_score = score
			best_bridge = bridge
	return best_bridge

func _create_map_collisions() -> void:
	_add_wall("WestBoundary", Vector2(-16.0, map_size.y * 0.5), Vector2(32.0, map_size.y + 64.0))
	_add_wall("EastBoundary", Vector2(map_size.x + 16.0, map_size.y * 0.5), Vector2(32.0, map_size.y + 64.0))
	_add_wall("NorthBoundary", Vector2(map_size.x * 0.5, -16.0), Vector2(map_size.x, 32.0))
	_add_wall("SouthBoundary", Vector2(map_size.x * 0.5, map_size.y + 16.0), Vector2(map_size.x, 32.0))
	for barrier: Dictionary in _layout["barriers"]:
		_add_wall(barrier["name"], barrier["center"], barrier["size"], 32)

func _add_wall(wall_name: String, center: Vector2, dimensions: Vector2, physics_layer: int = 1) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.collision_layer = physics_layer
	wall.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = dimensions
	collision.shape = shape
	wall.add_child(collision)
	wall.position = center
	add_child(wall)

func _create_obstacles() -> void:
	for placement: Dictionary in _layout["obstacles"]:
		var obstacle := OBSTACLE_SCENE.instantiate()
		obstacle.configure(placement["kind"], placement["radius"])
		obstacle.position = placement["position"]
		add_child(obstacle)

func _create_hazards() -> void:
	for index in range(_layout["hazards"].size()):
		var mine := MINE_HAZARD_SCENE.instantiate()
		mine.name = "Mine%02d" % (index + 1)
		mine.position = _layout["hazards"][index]
		add_child(mine)

func _create_decorations() -> void:
	for index in range(_layout.get("decorations", []).size()):
		var placement: Dictionary = _layout["decorations"][index]
		var decoration := DECORATION_SCENE.instantiate()
		decoration.name = "Decoration%02d_%s" % [index + 1, str(placement["kind"])]
		decoration.configure(placement["kind"], float(placement.get("scale", 1.0)))
		decoration.position = placement["position"]
		decoration.rotation = float(placement.get("rotation", 0.0))
		add_child(decoration)

func _create_players_and_enemies() -> void:
	var profiles := NetworkSession.players.duplicate(true)
	if profiles.is_empty():
		profiles[1] = {"nickname": NetworkSession.local_nickname, "slot": 0}
	var peer_ids: Array = profiles.keys()
	peer_ids.sort()
	var local_player: Node
	var player_count := profiles.size()
	for peer_id in peer_ids:
		var profile: Dictionary = profiles[peer_id]
		var slot := int(profile["slot"])
		var player := PLAYER_SCENE.instantiate()
		player.name = "Player_%d" % int(peer_id)
		player.configure(int(peer_id), str(profile["nickname"]), slot)
		player.configure_world_bounds(map_size)
		player.configure_lives(NetworkSession.ensure_player_lives(int(peer_id)))
		player.position = _layout["spawns"][slot]
		add_child(player)
		if not NetworkSession.is_networked or int(peer_id) == multiplayer.get_unique_id():
			local_player = player

	var infantry_positions: Array = _layout["infantry"]
	for index in range(infantry_positions.size()):
		var enemy := INFANTRY_SCENE.instantiate()
		enemy.name = "Infantry%02d" % (index + 1)
		enemy.apply_coop_scaling(player_count)
		enemy.position = infantry_positions[index]
		add_child(enemy)
	for placement: Dictionary in _layout["heavy_enemies"]:
		var enemy := INFANTRY_SCENE.instantiate()
		enemy.name = placement["name"]
		var enemy_type := int(placement["type"])
		enemy.configure_enemy(enemy_type)
		enemy.apply_coop_scaling(player_count)
		enemy.position = placement["position"]
		if enemy_type == 3:
			enemy.configure_boat_patrol(_boat_patrol_bounds(placement["position"]))
		add_child(enemy)

	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	if local_player != null:
		local_player.connect(&"health_changed", Callable(hud, "update_health"))
		local_player.connect(&"lives_changed", Callable(hud, "update_lives"))
		local_player.connect(&"spectator_changed", Callable(hud, "update_spectator_state"))
		local_player.connect(&"weapon_upgrades_changed", Callable(hud, "update_weapon_upgrades"))
		local_player.connect(&"passenger_count_changed", Callable(hud, "update_passengers"))
		hud.call("update_health", local_player.get("health"), local_player.get("maximum_health"))
		hud.call("update_lives", local_player.get("lives"), NetworkSession.STARTING_PLAYER_LIVES)
		hud.call(
			"update_weapon_upgrades",
			local_player.get("primary_upgrade_level"),
			local_player.get("secondary_upgrade_level")
		)
		hud.call(
			"update_passengers",
			local_player.get("passenger_count"),
			local_player.get("passenger_capacity")
		)
	NetworkSession.rescue_score_changed.connect(Callable(hud, "update_rescue_score"))
	hud.call("update_rescue_score", NetworkSession.evacuated_passengers, NetworkSession.rescued_passengers)
	NetworkSession.mission_state_changed.connect(Callable(hud, "update_mission_state"))
	hud.call("update_mission_state", NetworkSession.mission_state_snapshot())
	_create_weapon_upgrades()

func _boat_patrol_bounds(boat_position: Vector2) -> Rect2:
	for water: Rect2 in _layout.get("water", []):
		if not water.has_point(boat_position):
			continue
		var x_segments: Array[Vector2] = []
		var segment_start := water.position.x + 28.0
		var segment_end := water.end.x - 28.0
		for bridge: Rect2 in _layout.get("bridges", []):
			if bridge.end.y < water.position.y or bridge.position.y > water.end.y:
				continue
			var bridge_start := maxf(water.position.x + 28.0, bridge.position.x - 28.0)
			var bridge_end := minf(water.end.x - 28.0, bridge.end.x + 28.0)
			if bridge_start > segment_start:
				x_segments.append(Vector2(segment_start, bridge_start))
			segment_start = maxf(segment_start, bridge_end)
		if segment_end > segment_start:
			x_segments.append(Vector2(segment_start, segment_end))
		if x_segments.is_empty():
			push_error("No navigable river section is available for boat at %s." % boat_position)
			return Rect2()

		var selected_segment := x_segments[0]
		var best_distance := INF
		for segment in x_segments:
			if boat_position.x >= segment.x and boat_position.x <= segment.y:
				selected_segment = segment
				best_distance = 0.0
				break
			var distance := absf(boat_position.x - (segment.x + segment.y) * 0.5)
			if distance < best_distance:
				selected_segment = segment
				best_distance = distance
		return Rect2(
			Vector2(selected_segment.x, water.position.y + 28.0),
			Vector2(selected_segment.y - selected_segment.x, water.size.y - 56.0)
		)
	push_error("No river contains boat at %s." % boat_position)
	return Rect2()

func _create_rescue_objects() -> void:
	var rescue_positions: Array = _layout["rescues"]
	for index in range(rescue_positions.size()):
		var building := RESCUE_BUILDING_SCENE.instantiate()
		building.name = "RescueBuilding%02d" % (index + 1)
		building.position = rescue_positions[index]
		add_child(building)
	var extraction_positions: Array = _layout.get("extractions", [_layout["extraction"]])
	for index in range(extraction_positions.size()):
		var extraction_zone := EXTRACTION_ZONE_SCENE.instantiate()
		extraction_zone.name = "ExtractionZone" if index == 0 else "ExtractionZone%02d" % (index + 1)
		extraction_zone.position = extraction_positions[index]
		add_child(extraction_zone)

func _create_final_base() -> void:
	var final_base := FINAL_BASE_SCENE.instantiate()
	final_base.name = "FinalBase"
	final_base.configure_boss(level_index, maxi(1, NetworkSession.players.size()))
	final_base.position = _layout["base"]
	add_child(final_base)

func _create_weapon_upgrades() -> void:
	var type_counts := {&"primary": 0, &"secondary": 0}
	for placement: Dictionary in _layout["upgrades"]:
		var pickup := WEAPON_UPGRADE_SCENE.instantiate()
		var upgrade_type: StringName = placement["type"]
		type_counts[upgrade_type] = int(type_counts[upgrade_type]) + 1
		pickup.name = "%sUpgrade%02d" % ["Primary" if upgrade_type == &"primary" else "Secondary", type_counts[upgrade_type]]
		pickup.configure(placement["type"])
		pickup.position = placement["position"]
		add_child(pickup)

func _on_player_left(peer_id: int) -> void:
	var player := get_node_or_null("Player_%d" % peer_id)
	if player != null:
		player.queue_free()

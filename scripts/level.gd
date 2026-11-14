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
	add_child(PAUSE_MENU_SCENE.instantiate())
	NetworkSession.player_left.connect(_on_player_left)

func _exit_tree() -> void:
	AudioDirector.stop_mission_audio()

func _draw() -> void:
	var palette: Array = _layout["palette"]
	draw_rect(Rect2(Vector2.ZERO, map_size), palette[0])
	for band in range(5):
		var band_height := map_size.y / 5.0
		var band_color: Color = palette[0].lightened(0.025) if band % 2 == 0 else palette[0].darkened(0.025)
		draw_rect(Rect2(0.0, band * band_height, map_size.x, band_height), band_color)
	draw_texture_rect(GROUND_TEXTURE, Rect2(Vector2.ZERO, map_size), true, Color(0.70, 0.76, 0.64, 0.40))

	var road_width := float(_layout["road_width"])
	var road_paths: Array = _layout.get("roads", [_layout["road"]])
	for road_points: Array in road_paths:
		_draw_road(PackedVector2Array(road_points), road_width)
	for water_rect: Rect2 in _layout["water"]:
		_draw_river(water_rect)
	for bridge_rect: Rect2 in _layout["bridges"]:
		_draw_bridge(bridge_rect)

func _draw_road(points: PackedVector2Array, width: float) -> void:
	if points.size() < 2:
		return
	draw_polyline(points, Color(0.08, 0.10, 0.07, 0.48), width + 34.0, true)
	draw_polyline(points, Color(0.31, 0.27, 0.18), width + 22.0, true)
	draw_polyline(points, Color(0.48, 0.39, 0.25), width + 10.0, true)
	draw_polyline(points, Color(0.42, 0.34, 0.23), width, true)
	for offset in [-width * 0.24, width * 0.24]:
		var track := _offset_path(points, offset)
		draw_polyline(track, Color(0.21, 0.18, 0.14, 0.42), 5.0, true)
		draw_polyline(track, Color(0.64, 0.53, 0.34, 0.18), 1.5, true)
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

func terrain_render_signature() -> Dictionary:
	return {
		"road_layers": 6,
		"textured_water": RIVER_TEXTURE != null,
		"bank_layers": 3,
		"bridge_planks": true,
	}

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
		enemy.configure_enemy(int(placement["type"]))
		enemy.apply_coop_scaling(player_count)
		enemy.position = placement["position"]
		add_child(enemy)

	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	if local_player != null:
		local_player.connect(&"health_changed", Callable(hud, "update_health"))
		local_player.connect(&"weapon_upgrades_changed", Callable(hud, "update_weapon_upgrades"))
		local_player.connect(&"passenger_count_changed", Callable(hud, "update_passengers"))
		hud.call("update_health", local_player.get("health"), local_player.get("maximum_health"))
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

func _create_rescue_objects() -> void:
	var rescue_positions: Array = _layout["rescues"]
	for index in range(rescue_positions.size()):
		var building := RESCUE_BUILDING_SCENE.instantiate()
		building.name = "RescueBuilding%02d" % (index + 1)
		building.position = rescue_positions[index]
		add_child(building)
	var extraction_zone := EXTRACTION_ZONE_SCENE.instantiate()
	extraction_zone.position = _layout["extraction"]
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

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

var map_size := Vector2(1200.0, 3200.0)
var _layout: Dictionary = {}

func _ready() -> void:
	_layout = LevelLayouts.get_layout(level_index)
	map_size = _layout["map_size"]
	NetworkSession.set_loaded_level(level_index)
	queue_redraw()
	_create_map_collisions()
	_create_obstacles()
	_create_players_and_enemies()
	_create_rescue_objects()
	_create_final_base()
	NetworkSession.player_left.connect(_on_player_left)

func _draw() -> void:
	var palette: Array = _layout["palette"]
	draw_rect(Rect2(Vector2.ZERO, map_size), palette[0])
	for band in range(5):
		var band_height := map_size.y / 5.0
		var band_color: Color = palette[0].lightened(0.025) if band % 2 == 0 else palette[0].darkened(0.025)
		draw_rect(Rect2(0.0, band * band_height, map_size.x, band_height), band_color)
	draw_texture_rect(GROUND_TEXTURE, Rect2(Vector2.ZERO, map_size), true, Color(0.72, 0.78, 0.66, 0.23))

	var rng := RandomNumberGenerator.new()
	rng.seed = int(_layout["seed"])
	for index in range(int(map_size.y / 12.0)):
		var patch := Vector2(
			rng.randf_range(24.0, map_size.x - 24.0),
			rng.randf_range(24.0, map_size.y - 24.0)
		)
		var tint: Color = palette[1] if index % 2 == 0 else palette[2]
		tint.a = 0.40
		draw_circle(patch, rng.randf_range(5.0, 15.0), tint)

	var road := PackedVector2Array(_layout["road"])
	var road_width := float(_layout["road_width"])
	draw_polyline(road, Color(0.32, 0.28, 0.22), road_width, true)
	draw_polyline(road, Color(0.49, 0.41, 0.29), road_width - 34.0, true)
	for water_rect: Rect2 in _layout["water"]:
		draw_rect(water_rect, Color(0.08, 0.27, 0.36))
		for ripple_x in range(int(water_rect.position.x + 24.0), int(water_rect.end.x), 96):
			draw_line(Vector2(ripple_x, water_rect.position.y + 42.0), Vector2(ripple_x + 38.0, water_rect.position.y + 42.0), Color(0.30, 0.58, 0.64, 0.62), 2.0)
	for bridge_rect: Rect2 in _layout["bridges"]:
		draw_rect(bridge_rect, Color(0.39, 0.30, 0.21))
		draw_rect(bridge_rect.grow(-12.0), Color(0.61, 0.49, 0.32))

func _create_map_collisions() -> void:
	_add_wall("WestBoundary", Vector2(-16.0, map_size.y * 0.5), Vector2(32.0, map_size.y + 64.0))
	_add_wall("EastBoundary", Vector2(map_size.x + 16.0, map_size.y * 0.5), Vector2(32.0, map_size.y + 64.0))
	_add_wall("NorthBoundary", Vector2(map_size.x * 0.5, -16.0), Vector2(map_size.x, 32.0))
	_add_wall("SouthBoundary", Vector2(map_size.x * 0.5, map_size.y + 16.0), Vector2(map_size.x, 32.0))
	for barrier: Dictionary in _layout["barriers"]:
		_add_wall(barrier["name"], barrier["center"], barrier["size"])

func _add_wall(wall_name: String, center: Vector2, dimensions: Vector2) -> void:
	var wall := StaticBody2D.new()
	wall.name = wall_name
	wall.collision_layer = 1
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

func _create_players_and_enemies() -> void:
	var profiles := NetworkSession.players.duplicate(true)
	if profiles.is_empty():
		profiles[1] = {"nickname": NetworkSession.local_nickname, "slot": 0}
	var peer_ids: Array = profiles.keys()
	peer_ids.sort()
	var local_player: Node
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
		enemy.position = infantry_positions[index]
		add_child(enemy)
	for placement: Dictionary in _layout["heavy_enemies"]:
		var enemy := INFANTRY_SCENE.instantiate()
		enemy.name = placement["name"]
		enemy.configure_enemy(int(placement["type"]))
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

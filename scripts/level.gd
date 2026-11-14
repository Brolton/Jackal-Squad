extends Node2D

const MAP_SIZE := Vector2(1200.0, 3200.0)
const PLAYER_SCENE := preload("res://scenes/player_jeep.tscn")
const INFANTRY_SCENE := preload("res://scenes/infantry.tscn")
const OBSTACLE_SCENE := preload("res://scenes/obstacle.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")

const INFANTRY_POSITIONS := [
	Vector2(600.0, 2500.0),
	Vector2(420.0, 2180.0),
	Vector2(800.0, 1850.0),
	Vector2(580.0, 1640.0),
	Vector2(670.0, 1270.0),
	Vector2(390.0, 930.0),
	Vector2(830.0, 560.0),
	Vector2(550.0, 300.0),
]
const PLAYER_SPAWN_POSITIONS := [
	Vector2(600.0, 2860.0),
	Vector2(640.0, 2860.0),
	Vector2(600.0, 2910.0),
	Vector2(640.0, 2910.0),
]

func _ready() -> void:
	queue_redraw()
	_create_map_collisions()
	_create_obstacles()
	_create_players_and_enemies()
	NetworkSession.player_left.connect(_on_player_left)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.20, 0.31, 0.20))
	draw_rect(Rect2(0.0, 0.0, MAP_SIZE.x, 700.0), Color(0.22, 0.33, 0.21))
	draw_rect(Rect2(0.0, 700.0, MAP_SIZE.x, 800.0), Color(0.19, 0.29, 0.19))
	draw_rect(Rect2(0.0, 1620.0, MAP_SIZE.x, 780.0), Color(0.20, 0.30, 0.19))
	draw_rect(Rect2(0.0, 2400.0, MAP_SIZE.x, 800.0), Color(0.22, 0.32, 0.20))

	var rng := RandomNumberGenerator.new()
	rng.seed = 24681357
	for index in range(240):
		var patch := Vector2(
			rng.randf_range(24.0, MAP_SIZE.x - 24.0),
			rng.randf_range(24.0, MAP_SIZE.y - 24.0)
		)
		var tint := Color(0.28, 0.39, 0.24, 0.42) if index % 2 == 0 else Color(0.13, 0.24, 0.16, 0.36)
		draw_circle(patch, rng.randf_range(5.0, 15.0), tint)

	var road := PackedVector2Array([
		Vector2(600.0, 3200.0),
		Vector2(560.0, 2780.0),
		Vector2(650.0, 2320.0),
		Vector2(520.0, 1950.0),
		Vector2(600.0, 1620.0),
		Vector2(600.0, 1380.0),
		Vector2(690.0, 1040.0),
		Vector2(570.0, 700.0),
		Vector2(630.0, 350.0),
		Vector2(600.0, 0.0),
	])
	draw_polyline(road, Color(0.43, 0.36, 0.25), 250.0, true)
	draw_polyline(road, Color(0.48, 0.40, 0.28), 212.0, true)

	draw_rect(Rect2(0.0, 1420.0, MAP_SIZE.x, 200.0), Color(0.12, 0.30, 0.37))
	for ripple_x in range(24, int(MAP_SIZE.x), 96):
		draw_line(
			Vector2(ripple_x, 1460.0 + float(ripple_x % 5) * 13.0),
			Vector2(ripple_x + 38.0, 1460.0 + float(ripple_x % 5) * 13.0),
			Color(0.30, 0.53, 0.55, 0.62),
			2.0
		)
	draw_rect(Rect2(510.0, 1380.0, 180.0, 280.0), Color(0.49, 0.39, 0.27))
	draw_rect(Rect2(522.0, 1390.0, 156.0, 260.0), Color(0.59, 0.48, 0.33))

func _create_map_collisions() -> void:
	_add_wall("WestBoundary", Vector2(-16.0, MAP_SIZE.y * 0.5), Vector2(32.0, MAP_SIZE.y + 64.0))
	_add_wall("EastBoundary", Vector2(MAP_SIZE.x + 16.0, MAP_SIZE.y * 0.5), Vector2(32.0, MAP_SIZE.y + 64.0))
	_add_wall("NorthBoundary", Vector2(MAP_SIZE.x * 0.5, -16.0), Vector2(MAP_SIZE.x, 32.0))
	_add_wall("SouthBoundary", Vector2(MAP_SIZE.x * 0.5, MAP_SIZE.y + 16.0), Vector2(MAP_SIZE.x, 32.0))
	_add_wall("WestRiverbank", Vector2(255.0, 1520.0), Vector2(510.0, 200.0))
	_add_wall("EastRiverbank", Vector2(945.0, 1520.0), Vector2(510.0, 200.0))

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
	var placements := [
		{"position": Vector2(260.0, 2600.0), "kind": &"tree", "radius": 27.0},
		{"position": Vector2(900.0, 2700.0), "kind": &"tree", "radius": 30.0},
		{"position": Vector2(350.0, 2360.0), "kind": &"rock", "radius": 20.0},
		{"position": Vector2(820.0, 2200.0), "kind": &"tree", "radius": 26.0},
		{"position": Vector2(250.0, 1990.0), "kind": &"tree", "radius": 32.0},
		{"position": Vector2(930.0, 1900.0), "kind": &"rock", "radius": 24.0},
		{"position": Vector2(300.0, 1740.0), "kind": &"crate", "radius": 24.0},
		{"position": Vector2(890.0, 1690.0), "kind": &"tree", "radius": 30.0},
		{"position": Vector2(250.0, 1260.0), "kind": &"tree", "radius": 29.0},
		{"position": Vector2(930.0, 1120.0), "kind": &"rock", "radius": 23.0},
		{"position": Vector2(330.0, 870.0), "kind": &"crate", "radius": 26.0},
		{"position": Vector2(870.0, 760.0), "kind": &"tree", "radius": 32.0},
		{"position": Vector2(270.0, 510.0), "kind": &"rock", "radius": 24.0},
		{"position": Vector2(950.0, 390.0), "kind": &"tree", "radius": 29.0},
		{"position": Vector2(340.0, 180.0), "kind": &"tree", "radius": 28.0},
	]
	for placement in placements:
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
		player.position = PLAYER_SPAWN_POSITIONS[slot]
		add_child(player)
		if not NetworkSession.is_networked or int(peer_id) == multiplayer.get_unique_id():
			local_player = player

	for index in range(INFANTRY_POSITIONS.size()):
		var enemy := INFANTRY_SCENE.instantiate()
		enemy.name = "Infantry%02d" % (index + 1)
		enemy.position = INFANTRY_POSITIONS[index]
		add_child(enemy)

	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	if local_player != null:
		local_player.connect(&"health_changed", Callable(hud, "update_health"))
		hud.call("update_health", local_player.get("health"), local_player.get("maximum_health"))

func _on_player_left(peer_id: int) -> void:
	var player := get_node_or_null("Player_%d" % peer_id)
	if player != null:
		player.queue_free()

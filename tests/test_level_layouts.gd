extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var expected_sizes := [Vector2(2625, 29400), Vector2(2450, 25200), Vector2(2800, 28000)]
	var expected_themes: Array[StringName] = [&"jungle", &"desert", &"snow"]
	var minimum_enemy_counts := [30, 20, 23]
	for level_index in range(3):
		var layout := LevelLayouts.get_layout(level_index)
		var session: Node = root.get_node("NetworkSession")
		session.call("start_solo", "LayoutTester", level_index)
		var scene_path := CampaignCatalog.scene_path(level_index)
		var game: Node = load(scene_path).instantiate()
		root.add_child(game)
		current_scene = game
		await process_frame

		_check(game.get("map_size") == expected_sizes[level_index], "Mission %d is wider and seven times longer" % (level_index + 1))
		_check(layout["terrain_theme"] == expected_themes[level_index], "Mission %d has its own terrain style" % (level_index + 1))
		var base_boss_turret_count := LevelLayouts.boss_turret_count_for(level_index, 1)
		var base_enemy_count: int = layout["infantry"].size() + layout["heavy_enemies"].size() + base_boss_turret_count
		var playable_rect := Rect2(Vector2.ZERO, layout["map_size"])
		for player_count in range(1, 5):
			var player_boss_turret_count := LevelLayouts.boss_turret_count_for(level_index, player_count)
			var scaled_infantry := LevelLayouts.scaled_infantry_positions(
				layout,
				player_count,
				base_boss_turret_count,
				player_boss_turret_count
			)
			var expected_enemy_count := roundi(
				float(base_enemy_count) * (1.0 + 0.35 * float(player_count - 1))
			)
			_check(
				scaled_infantry.size() + layout["heavy_enemies"].size() + player_boss_turret_count == expected_enemy_count,
				"Mission %d scales the enemy roster to %d%% for %d player(s)" % [
					level_index + 1,
					roundi((1.0 + 0.35 * float(player_count - 1)) * 100.0),
					player_count,
				]
			)
			var additions_are_inside_playable_map := true
			for index in range(layout["infantry"].size(), scaled_infantry.size()):
				var position: Vector2 = scaled_infantry[index]
				if not playable_rect.has_point(position) or position.y <= float(layout["base"].y):
					additions_are_inside_playable_map = false
					break
			_check(additions_are_inside_playable_map, "Mission %d extra enemies stay in front of the final base" % (level_index + 1))
		_check(
			_max_flank_gap(layout, true) <= 1400.0 and _max_flank_gap(layout, false) <= 1400.0,
			"Mission %d has continuous enemy coverage along both map edges" % (level_index + 1)
		)
		var ground_color: Color = layout["palette"][0]
		var color_matches_theme := false
		match level_index:
			0:
				color_matches_theme = ground_color.g > ground_color.r
			1:
				color_matches_theme = ground_color.r > ground_color.g and ground_color.g > ground_color.b
			_:
				color_matches_theme = ground_color.r > 0.8 and ground_color.g > 0.8 and ground_color.b > 0.8
		_check(color_matches_theme, "Mission %d ground palette matches its terrain" % (level_index + 1))
		_check(layout["infantry"].size() >= 35, "Mission %d has additional encounters along its extended route" % (level_index + 1))
		if level_index == 1:
			_check(
				_obstacle_count(layout, &"cactus") > 100 and layout["water"].is_empty(),
				"Desert Basin has cactus fields and no flooded terrain"
			)
		elif level_index == 2:
			_check(
				_obstacle_count(layout, &"snow_tree") > 100
				and _obstacle_count(layout, &"snow_rock") > 0
				and layout["water"].is_empty(),
				"Snowbound Highlands has snow-covered forests and rocky snow"
			)
		var actual_enemy_count := get_nodes_in_group("enemies").size()
		_check(
			actual_enemy_count == base_enemy_count,
			"Mission %d spawns its original one-player roster (%d/%d)" % [
				level_index + 1,
				actual_enemy_count,
				base_enemy_count,
			]
		)
		_check(get_nodes_in_group("enemies").size() >= minimum_enemy_counts[level_index], "Mission %d meets the minimum encounter count" % (level_index + 1))
		_check(game.get_tree().get_nodes_in_group("rescue_buildings").size() == 2 or game.get_node_or_null("RescueBuilding02") != null, "Mission %d has two rescue sites" % (level_index + 1))
		_check(game.get_node_or_null("ExtractionZone") != null and game.get_node_or_null("FinalBase") != null, "Mission %d has extraction and a command base" % (level_index + 1))
		_check(get_nodes_in_group("extraction_zones").size() >= 3, "Mission %d provides helipads along the route" % (level_index + 1))
		var reinforcement_signature: Dictionary = game.call("reinforcement_signature")
		var expected_infantry_limits := [1, 2, 2]
		var expected_tank_limits := [1, 1, 2]
		var expected_respawn_intervals := [12.0, 9.0, 6.0]
		_check(
			int(reinforcement_signature["infantry_limit"]) == expected_infantry_limits[level_index]
			and int(reinforcement_signature["tank_limit"]) == expected_tank_limits[level_index]
			and is_equal_approx(float(reinforcement_signature["respawn_seconds"]), expected_respawn_intervals[level_index]),
			"Mission %d reinforcement numbers and return time scale with difficulty" % (level_index + 1)
		)
		var player: Node2D = game.get_node("Player_1")
		var final_base: Node2D = game.get_node("FinalBase")
		var north_boundary: StaticBody2D = game.get_node("NorthBoundary")
		var north_boundary_shape := north_boundary.get_child(0).shape as RectangleShape2D
		_check(
			is_equal_approx(
				north_boundary.position.y + north_boundary_shape.size.y * 0.5,
				final_base.position.y - 40.0
			),
			"Mission %d north collision wall meets the rear wall of the final base" % (level_index + 1)
		)
		player.global_position = final_base.global_position + Vector2(0.0, 700.0)
		var reinforcement_slots: Dictionary = game.get("_reinforcement_slots")
		for enemy_type in [0, 2]:
			var slot: Dictionary = reinforcement_slots[enemy_type]
			slot["timer"] = 0.0
			reinforcement_slots[enemy_type] = slot
		game.set("_reinforcement_slots", reinforcement_slots)
		for _spawn_attempt in range(2):
			game.call("_update_reinforcements", 0.0)
			for enemy_type in [0, 2]:
				var slot: Dictionary = reinforcement_slots[enemy_type]
				slot["timer"] = 0.0
				reinforcement_slots[enemy_type] = slot
			game.set("_reinforcement_slots", reinforcement_slots)
		var reinforcement_counts := {0: 0, 2: 0}
		for enemy in get_nodes_in_group("reinforcement_enemies"):
			reinforcement_counts[int(enemy.get("enemy_type"))] += 1
		_check(
			int(reinforcement_counts[0]) == expected_infantry_limits[level_index]
			and int(reinforcement_counts[2]) == expected_tank_limits[level_index],
			"Mission %d deploys no more than its reinforcement limits" % (level_index + 1)
		)
		var camera: Camera2D = game.get_node("Player_1/Camera2D")
		_check(camera.limit_right == int(expected_sizes[level_index].x) and camera.limit_bottom == int(expected_sizes[level_index].y), "Mission %d camera follows its world bounds" % (level_index + 1))
		if level_index == 0:
			_check(get_nodes_in_group("battlefield_decorations").size() >= 20, "Emerald Approach has dense landmark dressing")
			_check(layout["roads"].size() >= 4 and layout["bridges"].size() == 4, "Emerald Approach has branching routes and four bridge choices")
			for bridge: Rect2 in layout["bridges"]:
				var crosses_river := false
				for water: Rect2 in layout["water"]:
					if bridge.position.y <= water.get_center().y and bridge.end.y >= water.get_center().y:
						crosses_river = true
				_check(crosses_river, "Every bridge is aligned with the river")
				var closest_road_distance := INF
				for road_path: Array in layout["roads"]:
					for segment_index in range(1, road_path.size()):
						closest_road_distance = minf(
							closest_road_distance,
							_point_to_segment_distance(
								bridge.get_center(),
								road_path[segment_index - 1],
								road_path[segment_index]
							)
						)
				_check(closest_road_distance <= 1.0, "Every bridge lines up with a road crossing")
			var boat_count := 0
			var patrol_boat: Node2D
			for enemy in get_nodes_in_group("enemies"):
				if enemy.get("enemy_type") != 3:
					continue
				boat_count += 1
				if patrol_boat == null:
					patrol_boat = enemy
				var patrol_bounds: Rect2 = enemy.get("_boat_patrol_bounds")
				var collision_mask: int = enemy.get("collision_mask")
				_check(patrol_bounds.has_point(enemy.global_position), "River boats spawn inside their patrol area")
				_check((collision_mask & 32) == 0, "River boats can move past riverbank barriers")
				for bridge: Rect2 in layout["bridges"]:
					_check(not patrol_bounds.intersects(bridge), "River boat patrols stay clear of bridges")
			_check(boat_count == 4, "All river boats receive navigable patrol areas")
			if patrol_boat != null:
				var patrol_start := patrol_boat.global_position
				for _frame in range(30):
					await physics_frame
				var boat_bounds: Rect2 = patrol_boat.get("_boat_patrol_bounds")
				_check(
					patrol_boat.global_position.distance_to(patrol_start) > 1.0
					and boat_bounds.has_point(patrol_boat.global_position),
					"River boats patrol continuously without entering bridges or banks"
				)
		elif level_index == 2:
			var terrain_signature: Dictionary = game.call("terrain_render_signature")
			_check(
				int(terrain_signature["visible_collision_barriers"]) == 3
				and terrain_signature["terrain_theme"] == &"snow",
				"Snowbound Highlands renders icy terrain and every blocking pass"
			)

		game.queue_free()
		await process_frame
		if level_index == 0:
			for player_count in range(2, 5):
				session.call("start_solo", "CoopLayoutTester", 0)
				var profiles: Dictionary = {}
				for peer_id in range(1, player_count + 1):
					profiles[peer_id] = {
						"nickname": "Player%d" % peer_id,
						"slot": peer_id - 1,
					}
				session.set("players", profiles)
				var coop_game: Node = load(scene_path).instantiate()
				root.add_child(coop_game)
				current_scene = coop_game
				await process_frame
				var expected_coop_enemy_count := roundi(
					float(base_enemy_count) * (1.0 + 0.35 * float(player_count - 1))
				)
				var coop_enemies := get_nodes_in_group("enemies")
				_check(
					coop_enemies.size() == expected_coop_enemy_count,
					"Mission 1 actually spawns %d%% enemies for %d players (%d/%d)" % [
						roundi((1.0 + 0.35 * float(player_count - 1)) * 100.0),
						player_count,
						coop_enemies.size(),
						expected_coop_enemy_count,
					]
				)
				var enemy_stats_are_unchanged := true
				for enemy in coop_enemies:
					if not enemy is CharacterBody2D:
						continue
					var enemy_type := int(enemy.get("enemy_type"))
					if (
						int(enemy.get("maximum_health")) != [1, 4, 6, 4][enemy_type]
						or not is_equal_approx(float(enemy.get("fire_interval")), [1.55, 1.2, 1.8, 1.6][enemy_type])
					):
						enemy_stats_are_unchanged = false
						break
				_check(enemy_stats_are_unchanged, "Mission 1 enemy durability and firing rate stay fixed in co-op")
				coop_game.queue_free()
				await process_frame

	if _failures == 0:
		print("Large level layout checks passed.")
		quit()
	else:
		push_error("%d large level layout check(s) failed." % _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

func _obstacle_count(layout: Dictionary, kind: StringName) -> int:
	var count := 0
	for placement: Dictionary in layout["obstacles"]:
		if placement["kind"] == kind:
			count += 1
	return count

func _max_flank_gap(layout: Dictionary, left_edge: bool) -> float:
	var positions: Array[float] = [0.0, float(layout["map_size"].y)]
	var edge_x := 120.0 if left_edge else float(layout["map_size"].x) - 120.0
	for position: Vector2 in layout["infantry"]:
		var on_edge := position.x <= edge_x if left_edge else position.x >= edge_x
		if on_edge:
			positions.append(position.y)
	positions.sort()
	var maximum_gap := 0.0
	for index in range(1, positions.size()):
		maximum_gap = maxf(maximum_gap, positions[index] - positions[index - 1])
	return maximum_gap

func _point_to_segment_distance(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var projection := clampf((point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(start + segment * projection)

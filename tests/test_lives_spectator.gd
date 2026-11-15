extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var session: Node = root.get_node("NetworkSession")
	await _test_hud()
	session.call("start_solo", "LivesTester", 0)
	await _test_player_deaths(session)
	session.call("start_solo", "LivesTester", 0)
	session.set("players", {
		1: {"nickname": "One", "slot": 0},
		2: {"nickname": "Two", "slot": 1},
		3: {"nickname": "Three", "slot": 2},
		4: {"nickname": "Four", "slot": 3},
	})
	session.set("player_lives", {1: 1, 2: 1, 3: 4, 4: 5})
	session.call("consume_player_life", 1)
	session.call("consume_player_life", 2)
	var spectator_targets: Dictionary = session.get("spectator_targets")
	var assigned_targets: Array = spectator_targets.values()
	_check(spectator_targets.size() == 2, "Every eliminated player receives a spectator target")
	_check(
		assigned_targets.size() == 2 and assigned_targets[0] != assigned_targets[1],
		"Spectators follow different survivors when enough survivors are available"
	)
	_check(
		int(session.get("player_contributions")[1]["deaths"]) == 1,
		"Deaths are recorded in player statistics"
	)

	session.set("mission_completed", true)
	session.set("player_lives", {1: 2, 2: 4, 3: 5, 4: 0})
	_check(bool(session.call("advance_campaign")), "A cleared level advances the campaign")
	var lives_after_clear: Dictionary = session.get("player_lives")
	_check(
		int(lives_after_clear[1]) == 5
		and int(lives_after_clear[2]) == 5
		and int(lives_after_clear[3]) == 5
		and int(lives_after_clear[4]) == 3,
		"Level clear grants three lives without exceeding five"
	)

	session.set("players", {
		1: {"nickname": "One", "slot": 0},
		2: {"nickname": "Two", "slot": 1},
	})
	session.set("player_lives", {1: 1, 2: 0})
	session.call("consume_player_life", 1)
	_check(bool(session.get("game_over")), "The squad is eliminated when all players run out of lives")
	var game_over_state: Dictionary = session.call("mission_state_snapshot")
	_check(bool(game_over_state.get("game_over", false)), "Game-over state is included in mission synchronization")

	session.call("restart_campaign")
	var reset_lives: Dictionary = session.get("player_lives")
	_check(
		int(session.get("campaign_level_index")) == 0
		and not bool(session.get("game_over"))
		and int(reset_lives[1]) == 5,
		"Restarting after game over resets the campaign and restores five lives"
	)

	if _failures == 0:
		print("Lives and spectator checks passed.")
		quit()
	else:
		push_error("%d lives and spectator check(s) failed." % _failures)
		quit(1)

func _test_player_deaths(session: Node) -> void:
	session.set("players", {
		1: {"nickname": "One", "slot": 0},
		2: {"nickname": "Two", "slot": 1},
	})
	session.set("player_lives", {1: 2, 2: 2})
	var player_scene: PackedScene = load("res://scenes/player_jeep.tscn")
	var player: CharacterBody2D = player_scene.instantiate()
	player.configure(1, "One", 0)
	player.configure_lives(2)
	player.position = Vector2(500.0, 3000.0)
	var teammate: CharacterBody2D = player_scene.instantiate()
	teammate.configure(2, "Two", 1)
	teammate.configure_lives(2)
	teammate.position = Vector2(560.0, 3000.0)
	root.add_child(player)
	root.add_child(teammate)
	await process_frame
	var spawn_position: Vector2 = player.get("spawn_position")
	player.call("take_damage", 100)
	_check(
		int(player.get("lives")) == 1 and not player.visible,
		"A player spends one life and disappears while respawning"
	)
	await create_timer(1.1).timeout
	_check(
		player.visible
		and int(player.get("health")) == int(player.get("maximum_health"))
		and player.global_position == spawn_position,
		"A player with lives remaining returns to the level start"
	)
	player.call("take_damage", 100)
	_check(
		int(player.get("lives")) == 0
		and bool(player.get("_eliminated"))
		and not player.visible
		and int(session.call("spectator_target_for", 1)) == 2,
		"A player with no lives is eliminated and assigned a living spectator target"
	)
	await create_timer(1.1).timeout
	_check(
		not player.visible and int(player.get("health")) == 0,
		"An eliminated player does not automatically respawn"
	)
	player.queue_free()
	teammate.queue_free()
	await process_frame

func _test_hud() -> void:
	var hud_scene: PackedScene = load("res://scenes/hud.tscn")
	var hud: CanvasLayer = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame
	hud.call("update_lives", 2, 5)
	var lives_label: Label = hud.get_node("TopBackdrop/Row/HealthDisplay/LivesCount")
	_check(lives_label.text == "x2", "The tactical HUD shows the remaining lives")
	hud.call("update_spectator_state", true, "Two")
	var spectator_message: Label = hud.get_node("SpectatorMessage")
	_check(
		spectator_message.visible and spectator_message.text.contains("SPECTATING TWO"),
		"The HUD tells eliminated players who they are watching"
	)
	hud.call("update_mission_state", {
		"game_over": true,
		"campaign_level_index": 0,
		"player_lives": {1: 0},
		"player_contributions": {
			1: {
				"nickname": "One",
				"enemies_destroyed": 2,
				"passengers_rescued": 1,
				"final_bases_destroyed": 0,
				"deaths": 4,
			},
		},
	})
	var title: Label = hud.get_node("VictoryPanel/VBoxContainer/Title")
	var details: Label = hud.get_node("VictoryPanel/VBoxContainer/Details")
	var restart_button: Button = hud.get_node("VictoryPanel/VBoxContainer/ContinueButton")
	_check(
		hud.get_node("VictoryPanel").visible
		and title.text.contains("GAME OVER")
		and details.text.contains("4 deaths")
		and details.text.contains("0 lives")
		and restart_button.text == "RESTART CAMPAIGN"
		and not spectator_message.visible,
		"Game over displays the team statistics and campaign restart action"
	)
	hud.queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

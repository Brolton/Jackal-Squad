extends SceneTree

var _failures := 0

class MockPlayer extends Node2D:
	var player_peer_id := 1

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var expected := [
		[1, 1, 2, 2],
		[1, 2, 3, 3],
		[1, 2, 3, 4],
	]
	var boss_scene: PackedScene = load("res://scenes/final_base.tscn")
	for level_index in range(3):
		for player_count in range(1, 5):
			var boss: Node = boss_scene.instantiate()
			boss.call("configure_boss", level_index, player_count)
			root.add_child(boss)
			await process_frame
			var state: Dictionary = boss.call("boss_state_signature")
			_check(int(state["turrets"]) == expected[level_index][player_count - 1], "Mission %d with %d player(s) spawns %d boss turret(s)" % [level_index + 1, player_count, expected[level_index][player_count - 1]])
			_check(
				int(boss.get("maximum_health")) == 18 + level_index * 6,
				"Mission %d boss core health is unchanged for %d player(s)" % [level_index + 1, player_count]
			)
			_check(bool(state["shielded"]), "Boss core starts shielded")
			boss.queue_free()
			await process_frame

	var session: Node = root.get_node("NetworkSession")
	session.call("start_solo", "BossTester", 0)
	var boss: Node = boss_scene.instantiate()
	boss.call("configure_boss", 0, 1)
	root.add_child(boss)
	current_scene = boss
	await process_frame
	var health_before := int(boss.get("health"))
	boss.call("take_damage", 3, 1)
	_check(int(boss.get("health")) == health_before, "Shielded core ignores damage while a turret survives")
	var turret: Node = boss.get_node("BossTurret01")
	turret.call("take_damage", int(turret.get("health")), 1)
	await process_frame
	_check(not bool(boss.get("shielded")), "Destroying the final turret exposes the core")
	boss.call("take_damage", 3, 1)
	_check(int(boss.get("health")) == health_before - 3, "Exposed boss core takes damage")
	var audio: Node = root.get_node("AudioDirector")
	var explosions_before := _count_sfx(audio, "explosion")
	boss.call("take_damage", int(boss.get("health")), 1)
	_check(
		boss.is_queued_for_deletion() and _count_sfx(audio, "explosion") == explosions_before + 1,
		"Destroying the final base plays an explosion"
	)
	boss.queue_free()
	await process_frame

	var turret_scene: PackedScene = load("res://scenes/boss_turret.tscn")
	var first_turret: Node2D = turret_scene.instantiate()
	first_turret.call("configure", 0, 0)
	root.add_child(first_turret)
	var second_turret: Node2D = turret_scene.instantiate()
	second_turret.call("configure", 1, 0)
	root.add_child(second_turret)
	var near_player := MockPlayer.new()
	near_player.player_peer_id = 1
	near_player.position = Vector2(100, 0)
	near_player.add_to_group("players")
	root.add_child(near_player)
	var far_player := MockPlayer.new()
	far_player.player_peer_id = 2
	far_player.position = Vector2(1600, 0)
	far_player.add_to_group("players")
	root.add_child(far_player)
	await process_frame
	_check(first_turret.call("_assigned_target") == near_player, "First turret targets the only player in attack range")
	_check(second_turret.call("_assigned_target") == near_player, "Every turret focuses the only available player")
	far_player.position = Vector2(140, 0)
	_check(first_turret.call("_assigned_target") == near_player, "First turret keeps the first available squad target")
	_check(second_turret.call("_assigned_target") == far_player, "Turrets split targets when several players are available")
	first_turret.queue_free()
	second_turret.queue_free()
	near_player.queue_free()
	far_player.queue_free()
	await process_frame

	if _failures == 0:
		print("Boss scaling checks passed.")
		quit()
	else:
		push_error("%d boss scaling check(s) failed." % _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

func _count_sfx(audio: Node, kind: String) -> int:
	var cache: Dictionary = audio.get("_sfx_cache")
	var stream: AudioStream = cache.get(StringName(kind))
	if stream == null:
		return 0
	var count := 0
	for child in audio.get_children():
		if child is AudioStreamPlayer and child.stream == stream:
			count += 1
	return count

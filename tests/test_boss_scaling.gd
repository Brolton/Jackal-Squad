extends SceneTree

var _failures := 0

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
	boss.queue_free()
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

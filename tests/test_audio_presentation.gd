extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var audio: Node = root.get_node("AudioDirector")
	var manifest: Dictionary = audio.call("audio_manifest")
	_check(float(manifest["music_seconds"]) >= 6.0, "Mission music has a developed multi-phrase action loop")
	_check(int(manifest["tempo_bpm"]) >= 145, "Mission music uses a fast action tempo")
	_check((manifest["sfx"] as Array).size() >= 8, "Combat, death, impact, pickup, and vehicle sounds are covered")
	var engine: AudioStreamWAV = audio.call("engine_stream")
	_check(engine != null and engine.loop_mode == AudioStreamWAV.LOOP_FORWARD and engine.data.size() > 10000, "Jeep engine uses a generated looping waveform")

	var session: Node = root.get_node("NetworkSession")
	session.call("start_solo", "AudioTester", 0)
	var game: Node = load("res://scenes/level_01.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	var music := audio.get_node_or_null("MissionMusic") as AudioStreamPlayer
	_check(music != null and music.stream is AudioStreamWAV and (music.stream as AudioStreamWAV).data.size() > 100000, "Level startup creates and plays original chiptune PCM")
	var player: Node = game.get_node("Player_1")
	_check(player.get_node_or_null("EngineAudio") is AudioStreamPlayer, "Player jeep has responsive engine audio")
	player.call("_fire_primary")
	_check(audio.get_node_or_null("SFX_shot") != null, "Machine-gun fire triggers its sound effect")
	player.set("_secondary_cooldown", 0.0)
	player.call("_fire_secondary")
	_check(audio.get_node_or_null("SFX_grenade_throw") != null, "Grenade launch triggers its sound effect")
	var soldier: Node = game.get_node("Infantry01")
	soldier.call("take_damage", int(soldier.get("maximum_health")), 1)
	_check(audio.get_node_or_null("SFX_soldier_death") != null, "Infantry death triggers a distinct synthesized cry")
	player.call("try_add_passenger")
	_check(
		audio.get_node_or_null("SFX_passenger_boarded") != null,
		"Passenger boarding plays an audible confirmation"
	)
	var extraction_zone: Node = game.get_node("ExtractionZone")
	extraction_zone.call("_start_helicopter")
	_check(
		audio.get_node_or_null("SFX_helicopter_arrival") != null,
		"Helicopter arrival plays a distinct sound"
	)

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("Audio presentation checks passed.")
		quit()
	else:
		push_error("%d audio presentation check(s) failed." % _failures)
		quit(1)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures += 1
		push_error("FAIL: %s" % message)

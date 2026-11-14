extends Node

const SAMPLE_RATE := 16000
const BEAT_SECONDS := 60.0 / 148.0
const MUSIC_BEATS := 16

var _music_player: AudioStreamPlayer
var _music_stream: AudioStreamWAV
var _engine_stream: AudioStreamWAV
var _sfx_cache: Dictionary = {}

func start_music(level_index: int = 0) -> void:
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "MissionMusic"
		_music_player.volume_db = -15.0
		add_child(_music_player)
	if _music_stream == null:
		_music_stream = _build_music()
	_music_player.stream = _music_stream
	_music_player.pitch_scale = [1.0, 1.06, 0.94][clampi(level_index, 0, 2)]
	if not _music_player.playing:
		_music_player.play()

func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()

func stop_mission_audio() -> void:
	stop_music()
	if _music_player != null:
		_music_player.stream = null
	for child in get_children():
		if child is AudioStreamPlayer and child != _music_player:
			(child as AudioStreamPlayer).stop()
			(child as AudioStreamPlayer).stream = null
			child.free()

func _exit_tree() -> void:
	stop_mission_audio()
	_music_stream = null
	_engine_stream = null
	_sfx_cache.clear()

func play_sfx(kind: StringName, volume_db: float = 0.0) -> void:
	var stream: AudioStreamWAV = _sfx_cache.get(kind)
	if stream == null:
		stream = _build_sfx(kind)
		_sfx_cache[kind] = stream
	var voice := AudioStreamPlayer.new()
	voice.name = "SFX_%s" % kind
	voice.stream = stream
	voice.volume_db = _default_volume(kind) + volume_db
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func engine_stream() -> AudioStreamWAV:
	if _engine_stream == null:
		_engine_stream = _build_engine()
	return _engine_stream

func audio_manifest() -> Dictionary:
	return {
		"music_seconds": float(MUSIC_BEATS) * BEAT_SECONDS,
		"music_samples": int(float(MUSIC_BEATS) * BEAT_SECONDS * SAMPLE_RATE),
		"tempo_bpm": 148,
		"sfx": [&"shot", &"enemy_shot", &"grenade_throw", &"rocket_launch", &"rocket_blast", &"explosion", &"pickup", &"upgrade_gun", &"upgrade_blast", &"grenade_blast_0", &"grenade_blast_1", &"grenade_blast_2", &"grenade_blast_3", &"hit", &"trample", &"soldier_death", &"helicopter_arrival", &"passenger_boarded", &"helicopter_boarded"],
		"engine_loop": true,
	}

func _build_music() -> AudioStreamWAV:
	var sample_count := int(float(MUSIC_BEATS) * BEAT_SECONDS * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var melody: Array[int] = [
		76, 79, 81, 83, 81, 79, 76, 74,
		76, 79, 83, 86, 83, 81, 79, 76,
		74, 76, 79, 81, 79, 76, 74, 71,
		74, 76, 79, 83, 81, 79, 76, 74,
	]
	var bass: Array[int] = [40, 40, 43, 43, 38, 38, 45, 45, 40, 43, 38, 45, 40, 38, 35, 47]
	for index in range(sample_count):
		var time := float(index) / SAMPLE_RATE
		var beat_position := time / BEAT_SECONDS
		var beat_index := int(floor(beat_position)) % MUSIC_BEATS
		var eighth_index := int(floor(beat_position * 2.0)) % melody.size()
		var beat_phase := fposmod(time, BEAT_SECONDS)
		var eighth_seconds := BEAT_SECONDS * 0.5
		var eighth_phase := fposmod(time, eighth_seconds)
		var lead_envelope := minf(1.0, eighth_phase * 38.0) * pow(maxf(0.0, 1.0 - eighth_phase / eighth_seconds), 0.55)
		var lead_frequency := _midi_frequency(melody[eighth_index])
		var lead := _square(time, lead_frequency, 0.28) * lead_envelope
		lead += _square(time, lead_frequency * 0.5, 0.18) * lead_envelope * 0.24
		var bass_frequency := _midi_frequency(bass[beat_index])
		var bass_wave := _triangle(time, bass_frequency) * 0.72 + _square(time, bass_frequency, 0.44) * 0.28
		var offbeat_envelope := 0.0
		if eighth_index % 2 == 1:
			offbeat_envelope = pow(maxf(0.0, 1.0 - eighth_phase / eighth_seconds), 2.2)
		var action_stab := _square(time, bass_frequency * 4.0, 0.20) * offbeat_envelope
		var kick := sin(TAU * (86.0 - beat_phase * 88.0) * beat_phase) * exp(-15.0 * beat_phase)
		var noise := _noise(index, 19)
		var snare := noise * exp(-22.0 * beat_phase) if beat_index % 4 in [1, 3] else 0.0
		var hi_hat := noise * exp(-55.0 * eighth_phase)
		var tom := 0.0
		if beat_index >= 14:
			var tom_frequency := 145.0 if eighth_index % 2 == 0 else 104.0
			tom = sin(TAU * tom_frequency * eighth_phase) * exp(-13.0 * eighth_phase)
		var sample := lead * 0.21 + bass_wave * 0.13 + action_stab * 0.055
		sample += kick * 0.17 + snare * 0.105 + hi_hat * 0.035 + tom * 0.10
		_write_sample(bytes, index, sample)
	return _wav_from_bytes(bytes, true)

func _build_engine() -> AudioStreamWAV:
	var sample_count := int(0.5 * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in range(sample_count):
		var time := float(index) / SAMPLE_RATE
		var sample := _square(time, 52.0, 0.38) * 0.08
		sample += _triangle(time, 104.0) * 0.045
		sample += _noise(index, 71) * 0.018
		_write_sample(bytes, index, sample)
	return _wav_from_bytes(bytes, true)

func _build_sfx(kind: StringName) -> AudioStreamWAV:
	var duration: float = float({
		&"shot": 0.10,
		&"enemy_shot": 0.13,
		&"grenade_throw": 0.18,
		&"rocket_launch": 0.24,
		&"rocket_blast": 0.58,
		&"explosion": 0.48,
		&"pickup": 0.36,
		&"hit": 0.16,
		&"trample": 0.22,
		&"soldier_death": 0.44,
		&"helicopter_arrival": 0.72,
		&"passenger_boarded": 0.28,
		&"helicopter_boarded": 0.42,
		&"upgrade_gun": 0.42,
		&"upgrade_blast": 0.48,
		&"grenade_blast_0": 0.48,
		&"grenade_blast_1": 0.52,
		&"grenade_blast_2": 0.56,
		&"grenade_blast_3": 0.62,
	}.get(kind, 0.20))
	var sample_count := int(duration * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in range(sample_count):
		var time := float(index) / SAMPLE_RATE
		var progress: float = time / duration
		var envelope := pow(1.0 - progress, 1.7)
		var noise := _noise(index, int(kind.hash()))
		var sample := 0.0
		match kind:
			&"shot":
				sample = _square(time, lerpf(900.0, 260.0, progress), 0.34) * 0.38 + noise * 0.13
			&"enemy_shot":
				sample = _square(time, lerpf(430.0, 150.0, progress), 0.42) * 0.34 + noise * 0.12
			&"grenade_throw":
				sample = sin(TAU * lerpf(520.0, 920.0, progress) * time) * 0.24 + noise * 0.04
			&"rocket_launch":
				var ignition := _square(time, lerpf(210.0, 620.0, progress), 0.32) * 0.22
				sample = ignition + noise * (0.20 * (1.0 - progress))
			&"rocket_blast":
				sample = noise * 0.52 + sin(TAU * lerpf(118.0, 29.0, progress) * time) * 0.34
				sample += _square(time, 240.0, 0.18) * pow(1.0 - progress, 4.0) * 0.10
			&"explosion":
				sample = noise * 0.48 + sin(TAU * lerpf(92.0, 34.0, progress) * time) * 0.30
			&"pickup":
				var notes: Array[int] = [72, 76, 79, 84]
				var note: int = notes[mini(notes.size() - 1, int(progress * notes.size()))]
				sample = _square(time, _midi_frequency(note), 0.28) * 0.24
			&"upgrade_gun":
				var gun_notes: Array[int] = [67, 72, 76, 79, 84]
				var gun_note: int = gun_notes[mini(gun_notes.size() - 1, int(progress * gun_notes.size()))]
				sample = _square(time, _midi_frequency(gun_note), 0.22) * 0.27 + _triangle(time, _midi_frequency(gun_note - 12)) * 0.10
			&"upgrade_blast":
				var blast_notes: Array[int] = [52, 59, 64, 71]
				var blast_note: int = blast_notes[mini(blast_notes.size() - 1, int(progress * blast_notes.size()))]
				sample = _square(time, _midi_frequency(blast_note), 0.38) * 0.25 + sin(TAU * _midi_frequency(blast_note + 12) * time) * 0.12
			&"grenade_blast_0", &"grenade_blast_1", &"grenade_blast_2", &"grenade_blast_3":
				var blast_level := String(kind).right(1).to_int()
				var boom_frequency := lerpf(86.0 + blast_level * 16.0, 31.0, progress)
				sample = noise * (0.42 + blast_level * 0.035) + sin(TAU * boom_frequency * time) * 0.30
				if blast_level >= 1:
					sample += _square(time, 180.0 + blast_level * 70.0, 0.18) * 0.08
				if blast_level >= 3:
					sample += sin(TAU * 720.0 * time) * pow(1.0 - progress, 4.0) * 0.10
			&"hit":
				sample = noise * 0.35 + _square(time, 120.0, 0.5) * 0.18
			&"trample":
				sample = noise * 0.34 + _triangle(time, lerpf(130.0, 55.0, progress)) * 0.20
			&"soldier_death":
				var cry_frequency := lerpf(340.0, 520.0, progress / 0.18) if progress < 0.18 else lerpf(520.0, 135.0, (progress - 0.18) / 0.82)
				var vibrato := sin(TAU * 22.0 * time) * 24.0
				var voice := _square(time, cry_frequency + vibrato, 0.46) * 0.24
				var formant := sin(TAU * (cry_frequency * 2.15) * time) * 0.16
				sample = voice + formant + noise * 0.075
			&"helicopter_arrival":
				var rotor := _square(time, lerpf(92.0, 138.0, progress), 0.48) * 0.18
				var approach := sin(TAU * lerpf(170.0, 82.0, progress) * time) * 0.22
				sample = rotor + approach + noise * 0.12
			&"passenger_boarded":
				var note := _midi_frequency(72 + int(progress * 3.0) * 6)
				sample = _square(time, note, 0.30) * 0.20 + noise * 0.035
			&"helicopter_boarded":
				var note := _midi_frequency(76 + int(progress * 3.0) * 4)
				sample = _square(time, note, 0.26) * 0.18 + _triangle(time, note * 0.5) * 0.08
			_:
				sample = noise * 0.2
		_write_sample(bytes, index, sample * envelope)
	return _wav_from_bytes(bytes, false)

func _wav_from_bytes(bytes: PackedByteArray, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(bytes.size() / 2)
	return stream

func _write_sample(bytes: PackedByteArray, index: int, value: float) -> void:
	var encoded := int(clampf(value, -1.0, 1.0) * 32767.0)
	bytes[index * 2] = encoded & 0xff
	bytes[index * 2 + 1] = (encoded >> 8) & 0xff

func _square(time: float, frequency: float, duty: float) -> float:
	return 1.0 if fposmod(time * frequency, 1.0) < duty else -1.0

func _triangle(time: float, frequency: float) -> float:
	return absf(fposmod(time * frequency, 1.0) * 2.0 - 1.0) * 2.0 - 1.0

func _noise(index: int, seed_value: int) -> float:
	return fposmod(sin(float(index + seed_value) * 12.9898) * 43758.5453, 2.0) - 1.0

func _midi_frequency(note: int) -> float:
	return 440.0 * pow(2.0, (float(note) - 69.0) / 12.0)

func _default_volume(kind: StringName) -> float:
	match kind:
		&"shot": return -12.0
		&"enemy_shot": return -16.0
		&"grenade_throw": return -10.0
		&"rocket_launch": return -8.0
		&"rocket_blast": return -5.0
		&"explosion": return -7.0
		&"pickup": return -8.0
		&"upgrade_gun": return -5.0
		&"upgrade_blast": return -5.0
		&"grenade_blast_0", &"grenade_blast_1", &"grenade_blast_2", &"grenade_blast_3": return -6.0
		&"hit": return -9.0
		&"trample": return -11.0
		&"soldier_death": return -7.0
		&"helicopter_arrival": return -4.0
		&"passenger_boarded": return -5.0
		&"helicopter_boarded": return -5.0
		_: return -12.0

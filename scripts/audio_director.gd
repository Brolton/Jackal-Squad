extends Node

const SAMPLE_RATE := 16000
const BEAT_SECONDS := 0.5

var _music_player: AudioStreamPlayer
var _music_stream: AudioStreamWAV
var _engine_stream: AudioStreamWAV
var _sfx_cache: Dictionary = {}

func start_music(level_index: int = 0) -> void:
	if _music_player == null:
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "MissionMusic"
		_music_player.volume_db = -18.0
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
		"music_seconds": 8.0 * BEAT_SECONDS,
		"music_samples": int(8.0 * BEAT_SECONDS * SAMPLE_RATE),
		"sfx": [&"shot", &"enemy_shot", &"grenade_throw", &"explosion", &"pickup", &"hit", &"trample"],
		"engine_loop": true,
	}

func _build_music() -> AudioStreamWAV:
	var sample_count := int(8.0 * BEAT_SECONDS * SAMPLE_RATE)
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	var melody: Array[int] = [76, 79, 81, 79, 74, 76, 72, 74]
	var bass: Array[int] = [40, 40, 43, 43, 38, 38, 35, 35]
	for index in range(sample_count):
		var time := float(index) / SAMPLE_RATE
		var beat_position := time / BEAT_SECONDS
		var beat_index := int(floor(beat_position)) % melody.size()
		var beat_phase := fposmod(time, BEAT_SECONDS)
		var envelope := minf(1.0, beat_phase * 24.0) * minf(1.0, (BEAT_SECONDS - beat_phase) * 8.0)
		var lead_frequency := _midi_frequency(melody[beat_index])
		var lead := _square(time, lead_frequency, 0.25) * envelope
		var bass_wave := _triangle(time, _midi_frequency(bass[beat_index]))
		var kick_phase := beat_phase
		var kick := sin(TAU * (72.0 - kick_phase * 54.0) * kick_phase) * exp(-11.0 * kick_phase)
		var noise := _noise(index, 19)
		var snare := noise * exp(-20.0 * kick_phase) if beat_index % 2 == 1 else 0.0
		var sample := lead * 0.18 + bass_wave * 0.10 + kick * 0.13 + snare * 0.055
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
		&"explosion": 0.48,
		&"pickup": 0.36,
		&"hit": 0.16,
		&"trample": 0.22,
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
			&"explosion":
				sample = noise * 0.48 + sin(TAU * lerpf(92.0, 34.0, progress) * time) * 0.30
			&"pickup":
				var notes: Array[int] = [72, 76, 79, 84]
				var note: int = notes[mini(notes.size() - 1, int(progress * notes.size()))]
				sample = _square(time, _midi_frequency(note), 0.28) * 0.24
			&"hit":
				sample = noise * 0.35 + _square(time, 120.0, 0.5) * 0.18
			&"trample":
				sample = noise * 0.34 + _triangle(time, lerpf(130.0, 55.0, progress)) * 0.20
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
		&"explosion": return -7.0
		&"pickup": return -8.0
		&"hit": return -9.0
		&"trample": return -11.0
		_: return -12.0

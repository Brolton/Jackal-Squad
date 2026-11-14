extends Node

const GAME_SCENE := "res://scenes/level_01.tscn"
const TEST_SCENE := "res://tests/network_smoke.tscn"

var _failures := 0
var _role := ""
var _departed_positions: Dictionary = {}

func _ready() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		_role = str(arguments[0]).trim_prefix("--")
	NetworkSession.game_start_requested.connect(_on_game_start_requested)
	NetworkSession.player_left.connect(_on_player_left)
	call_deferred("_run")

func _run() -> void:
	if _role == "server" or _role == "server4":
		await _run_server(2 if _role == "server" else 4)
	elif _role in ["client", "client2", "client3"]:
		await _run_client()
	else:
		push_error("Pass --server or --client after the script path.")
		get_tree().quit(2)

func _run_server(expected_players: int) -> void:
	if not NetworkSession.host_game("Host"):
		_fail(NetworkSession.status_message)
		_finish()
		return
	print("SERVER_READY")

	var deadline := Time.get_ticks_msec() + 12000
	while NetworkSession.players.size() < expected_players and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(NetworkSession.players.size() == expected_players, "Host registered all expected players")
	if _failures > 0:
		_finish()
		return

	var remote_peer_ids: Array[int] = []
	var remote_slots: Dictionary = {}
	var assigned_slots: Array[int] = []
	for peer_id in NetworkSession.players:
		if int(peer_id) != 1:
			remote_peer_ids.append(int(peer_id))
			remote_slots[int(peer_id)] = int(NetworkSession.players[peer_id]["slot"])
			assigned_slots.append(int(NetworkSession.players[peer_id]["slot"]))
	remote_peer_ids.sort()
	_check(remote_peer_ids.size() == expected_players - 1, "Remote peers received player slots")
	assigned_slots.sort()
	var expected_slots: Array[int] = []
	for slot in range(1, expected_players):
		expected_slots.append(slot)
	_check(assigned_slots == expected_slots, "Remote peers received unique non-host color slots")
	if not NetworkSession.start_multiplayer_game():
		_fail("Host could not start the multiplayer match")
		_finish()
		return

	await get_tree().create_timer(2.6).timeout
	var all_remote_players_moved := true
	for peer_id in remote_peer_ids:
		var remote_player: Node = null
		if get_tree().current_scene != null:
			remote_player = get_tree().current_scene.get_node_or_null("Player_%d" % peer_id)
		var authoritative_position := Vector2.ZERO
		if remote_player != null:
			authoritative_position = remote_player.global_position
		elif _departed_positions.has(peer_id):
			authoritative_position = _departed_positions[peer_id]
		if remote_player != null or _departed_positions.has(peer_id):
			print("PASS: Host observed remote jeep %d." % peer_id)
			var slot := int(remote_slots[peer_id])
			var spawn_y := 2860.0 if slot < 2 else 2910.0
			if authoritative_position.y >= spawn_y - 20.0:
				all_remote_players_moved = false
		else:
			_fail("Host did not observe remote jeep %d." % peer_id)
	_check(all_remote_players_moved, "Host simulated every client's movement authoritatively")

	var upgrade_owner_id := 0
	for peer_id in remote_slots:
		if int(remote_slots[peer_id]) == 1:
			upgrade_owner_id = int(peer_id)
	var combat_target: Node = get_tree().current_scene.get_node("Player_%d" % upgrade_owner_id)
	var health_before_host_damage := int(combat_target.get("health"))
	combat_target.call("take_damage", 1)
	_check(
		int(combat_target.get("health")) == health_before_host_damage - 1,
		"Host applies authoritative damage to a remote player"
	)
	var primary_pickup: Node2D = get_tree().current_scene.get_node("PrimaryUpgrade01")
	var upgrade_owner: Node = get_tree().current_scene.get_node("Player_%d" % upgrade_owner_id)
	upgrade_owner.global_position = primary_pickup.global_position
	deadline = Time.get_ticks_msec() + 2000
	while (
		int(upgrade_owner.get("primary_upgrade_level")) == 0
		and Time.get_ticks_msec() < deadline
	):
		await get_tree().physics_frame
	_check(
		int(upgrade_owner.get("primary_upgrade_level")) == 1,
		"Host applies a weapon pickup to the collecting player"
	)
	_check(
		int(get_tree().current_scene.get_node("Player_1").get("primary_upgrade_level")) == 0,
		"Weapon upgrades remain player-specific"
	)

	deadline = Time.get_ticks_msec() + 7000
	while NetworkSession.players.size() > 1 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(NetworkSession.players.size() == 1, "Host removed a disconnected player")
	NetworkSession.leave_lobby()
	_finish()

func _run_client() -> void:
	var expected_slot := 1
	var nickname := "Client"
	if _role == "client2":
		expected_slot = 2
		nickname = "Client2"
	elif _role == "client3":
		expected_slot = 3
		nickname = "Client3"
	if not NetworkSession.join_game("127.0.0.1", nickname):
		_fail(NetworkSession.status_message)
		_finish()
		return

	var deadline := Time.get_ticks_msec() + 12000
	while NetworkSession.players.size() < 2 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(NetworkSession.players.size() >= 2, "Client received the lobby roster")
	if _failures > 0:
		NetworkSession.leave_lobby()
		_finish()
		return

	var local_peer_id := multiplayer.get_unique_id()
	var local_profile: Dictionary = NetworkSession.players[local_peer_id]
	_check(local_profile["nickname"] == nickname, "Client nickname was registered")
	_check(int(local_profile["slot"]) == expected_slot, "Client received the next available color slot")

	deadline = Time.get_ticks_msec() + 8000
	while (
		not NetworkSession.match_started
		or get_tree().current_scene == null
		or get_tree().current_scene.scene_file_path != GAME_SCENE
	) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_check(
		get_tree().current_scene != null and get_tree().current_scene.scene_file_path == GAME_SCENE,
		"Client entered the host-started match"
	)
	if get_tree().current_scene == null:
		NetworkSession.leave_lobby()
		_finish()
		return

	var local_player: Node = get_tree().current_scene.get_node_or_null("Player_%d" % local_peer_id)
	_check(local_player != null, "Client spawned its own jeep")
	if local_player == null:
		NetworkSession.leave_lobby()
		_finish()
		return

	var health_before_client_damage := int(local_player.get("health"))
	local_player.call("take_damage", 1)
	_check(
		int(local_player.get("health")) == health_before_client_damage,
		"Clients cannot apply authoritative damage locally"
	)
	var local_camera: Camera2D = local_player.get_node("Camera2D")
	var host_player: Node = get_tree().current_scene.get_node("Player_1")
	var host_camera: Camera2D = host_player.get_node("Camera2D")
	_check(local_camera.is_current(), "Client camera follows its own jeep")
	_check(not host_camera.is_current(), "Remote camera does not override the local camera")

	var start_position: Vector2 = local_player.global_position
	Input.action_press("move_up")
	for _frame in range(70):
		await get_tree().physics_frame
	Input.action_release("move_up")
	await get_tree().create_timer(0.35).timeout
	_check(local_player.global_position.y < start_position.y, "Client jeep responds to local movement")
	_check(int(local_player.get("authoritative_state_count")) > 0, "Client received host movement snapshots")
	var movement_snapshot_deadline := Time.get_ticks_msec() + 2000
	while (
		Vector2(local_player.get("last_authoritative_position")).y >= start_position.y
		and Time.get_ticks_msec() < movement_snapshot_deadline
	):
		await get_tree().process_frame
	var authoritative_position: Vector2 = local_player.get("last_authoritative_position")
	_check(
		authoritative_position.y < start_position.y,
		"Host snapshot reflects the client's movement input"
	)
	await get_tree().create_timer(2.5).timeout
	var primary_pickup_deadline := Time.get_ticks_msec() + 3000
	while (
		get_tree().current_scene.get_node_or_null("PrimaryUpgrade01") != null
		and Time.get_ticks_msec() < primary_pickup_deadline
	):
		await get_tree().process_frame
	_check(
		get_tree().current_scene.get_node_or_null("PrimaryUpgrade01") == null,
		"Host-collected weapon pickups disappear on clients"
	)
	var expected_primary_level := 1 if expected_slot == 1 else 0
	_check(
		int(local_player.get("primary_upgrade_level")) == expected_primary_level,
		"Host synchronizes upgrades only to their owner"
	)
	if expected_slot == 1:
		_check(
			int(local_player.get("health")) < int(local_player.get("maximum_health")),
			"Host synchronizes damage to the targeted player"
		)
	await get_tree().create_timer(float(expected_slot) * 0.75).timeout
	NetworkSession.leave_lobby()
	await get_tree().create_timer(0.2).timeout
	_finish()

func _on_player_left(peer_id: int) -> void:
	if get_tree().current_scene == null:
		return
	var player := get_tree().current_scene.get_node_or_null("Player_%d" % peer_id)
	if player != null:
		_departed_positions[peer_id] = player.global_position

func _on_game_start_requested() -> void:
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path != TEST_SCENE:
		return
	var game: Node = load(GAME_SCENE).instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_fail(message)

func _fail(message: String) -> void:
	_failures += 1
	push_error("FAIL: %s" % message)

func _finish() -> void:
	if _failures == 0:
		print("Multiplayer smoke test passed (%s)." % _role)
		get_tree().quit()
	else:
		push_error("%d multiplayer check(s) failed (%s)." % [_failures, _role])
		get_tree().quit(1)

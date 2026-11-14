extends Node

signal lobby_changed(players: Dictionary)
signal status_changed(message: String)
signal game_start_requested
signal player_left(peer_id: int)
signal rescue_score_changed(evacuated: int, rescued: int)

const PORT := 24567
const MAX_PLAYERS := 4
const MAIN_SCENE := "res://scenes/main.tscn"
const GAME_SCENE := "res://scenes/level_01.tscn"
const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const GRENADE_SCENE := preload("res://scenes/grenade.tscn")

var players: Dictionary = {}
var local_nickname := "Player"
var is_networked := false
var is_host := false
var match_started := false
var status_message := "Choose a game mode."
var evacuated_passengers := 0
var rescued_passengers := 0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func start_solo(nickname: String) -> void:
	_close_session()
	_reset_rescue_score()
	local_nickname = _clean_nickname(nickname)
	players = {1: _make_profile(local_nickname, 0)}
	match_started = true
	_set_status("Starting solo mission.")
	game_start_requested.emit()

func host_game(nickname: String) -> bool:
	_close_session()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_PLAYERS - 1)
	if error != OK:
		_set_status("Could not host on UDP %d: %s" % [PORT, error_string(error)])
		return false

	multiplayer.multiplayer_peer = peer
	local_nickname = _clean_nickname(nickname)
	is_networked = true
	is_host = true
	match_started = false
	_reset_rescue_score()
	players = {1: _make_profile(local_nickname, 0)}
	_publish_lobby()
	_set_status("Hosting on UDP %d." % PORT)
	return true

func join_game(address: String, nickname: String) -> bool:
	var host_address := address.strip_edges()
	if host_address.is_empty():
		_set_status("Enter the host's IP address.")
		return false
	_close_session()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host_address, PORT)
	if error != OK:
		_set_status("Could not connect to %s: %s" % [host_address, error_string(error)])
		return false

	multiplayer.multiplayer_peer = peer
	local_nickname = _clean_nickname(nickname)
	is_networked = true
	is_host = false
	match_started = false
	_reset_rescue_score()
	players.clear()
	_set_status("Connecting to %s:%d..." % [host_address, PORT])
	return true

func start_multiplayer_game() -> bool:
	if not is_host or match_started or players.is_empty():
		return false
	match_started = true
	_set_status("Mission started.")
	game_start_requested.emit()
	for peer_id in connected_peer_ids():
		rpc_id(peer_id, "rpc_begin_match")
	return true

func leave_lobby() -> void:
	_close_session()
	players.clear()
	_reset_rescue_score()
	lobby_changed.emit({})
	_set_status("Choose a game mode.")

func record_evacuated_passenger() -> void:
	if is_networked and not is_host:
		return
	evacuated_passengers += 1
	_publish_rescue_score()

func collect_evacuated_passengers() -> void:
	if is_networked and not is_host:
		return
	rescued_passengers += evacuated_passengers
	evacuated_passengers = 0
	_publish_rescue_score()

func spawn_projectile_visual(
	spawn_position: Vector2,
	direction: Vector2,
	hostile: bool,
	damage: int,
	speed: float
) -> void:
	if not is_networked or not is_host:
		return
	for peer_id in connected_peer_ids():
		rpc_id(peer_id, "rpc_show_projectile", spawn_position, direction, hostile, damage, speed)

func spawn_grenade_visual(spawn_position: Vector2, direction: Vector2, blast_radius: float) -> void:
	if not is_networked or not is_host:
		return
	for peer_id in connected_peer_ids():
		rpc_id(peer_id, "rpc_show_grenade", spawn_position, direction, blast_radius)

@rpc("any_peer", "call_remote", "reliable")
func rpc_register_player(requested_nickname: String) -> void:
	if not is_host or match_started:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if peer_id <= 1 or players.has(peer_id):
		return
	if players.size() >= MAX_PLAYERS:
		rpc_id(peer_id, "rpc_reject_connection", "The lobby is full.")
		multiplayer.multiplayer_peer.disconnect_peer(peer_id, true)
		return

	players[peer_id] = _make_profile(requested_nickname, _first_available_slot())
	_publish_lobby()
	_set_status("%s joined the lobby." % players[peer_id]["nickname"])

@rpc("authority", "call_remote", "reliable")
func rpc_receive_lobby(snapshot: Dictionary) -> void:
	if is_host:
		return
	var previous_players := players.duplicate()
	players = snapshot.duplicate(true)
	for peer_id in previous_players:
		if not players.has(peer_id):
			player_left.emit(int(peer_id))
	lobby_changed.emit(players.duplicate(true))

@rpc("authority", "call_remote", "reliable")
func rpc_begin_match() -> void:
	if is_host or match_started:
		return
	match_started = true
	_set_status("Mission started.")
	game_start_requested.emit()

@rpc("authority", "call_remote", "reliable")
func rpc_reject_connection(message: String) -> void:
	_set_status(message)
	_close_session()
	players.clear()
	lobby_changed.emit({})

@rpc("authority", "call_remote", "unreliable")
func rpc_show_projectile(
	spawn_position: Vector2,
	direction: Vector2,
	hostile: bool,
	damage: int,
	speed: float
) -> void:
	if is_host or get_tree().current_scene == null:
		return
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.configure(spawn_position, direction, null, hostile, damage, speed, false)
	get_tree().current_scene.add_child(projectile)

@rpc("authority", "call_remote", "unreliable")
func rpc_show_grenade(spawn_position: Vector2, direction: Vector2, blast_radius: float) -> void:
	if is_host or get_tree().current_scene == null:
		return
	var grenade := GRENADE_SCENE.instantiate()
	grenade.configure(spawn_position, direction, null, true, blast_radius)
	get_tree().current_scene.add_child(grenade)

func replicate_upgrade_pickup_collected(pickup_name: String) -> void:
	if not is_networked or not is_host:
		return
	for peer_id in connected_peer_ids():
		rpc_id(peer_id, "rpc_remove_upgrade_pickup", pickup_name)

@rpc("authority", "call_remote", "reliable")
func rpc_remove_upgrade_pickup(pickup_name: String) -> void:
	if is_host or get_tree().current_scene == null:
		return
	var pickup := get_tree().current_scene.get_node_or_null(pickup_name)
	if pickup != null:
		pickup.queue_free()

@rpc("authority", "call_remote", "reliable")
func rpc_receive_rescue_score(evacuated: int, rescued: int) -> void:
	if is_host:
		return
	evacuated_passengers = evacuated
	rescued_passengers = rescued
	rescue_score_changed.emit(evacuated_passengers, rescued_passengers)

func connected_peer_ids() -> Array[int]:
	var connected_ids: Array[int] = []
	if not is_host or multiplayer.multiplayer_peer == null:
		return connected_ids
	var enet_peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet_peer == null:
		return connected_ids
	for peer_id in multiplayer.get_peers():
		var remote_peer := enet_peer.get_peer(int(peer_id))
		if remote_peer != null and remote_peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
			connected_ids.append(int(peer_id))
	return connected_ids

func _on_peer_connected(peer_id: int) -> void:
	if is_host and match_started:
		rpc_id(peer_id, "rpc_reject_connection", "This match has already started.")
		multiplayer.multiplayer_peer.disconnect_peer(peer_id, true)

func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host or not players.has(peer_id):
		return
	player_left.emit(peer_id)
	var departed_name: String = players[peer_id]["nickname"]
	players.erase(peer_id)
	_publish_lobby(peer_id)
	_set_status("%s left the lobby." % departed_name)

func _on_connected_to_server() -> void:
	_set_status("Connected. Waiting for the lobby roster...")
	rpc_id(1, "rpc_register_player", local_nickname)

func _on_connection_failed() -> void:
	is_networked = false
	is_host = false
	match_started = false
	multiplayer.multiplayer_peer = null
	players.clear()
	_reset_rescue_score()
	lobby_changed.emit({})
	_set_status("Connection failed. Check the IP address and UDP port %d." % PORT)

func _on_server_disconnected() -> void:
	if not is_networked or is_host:
		return
	is_networked = false
	is_host = false
	match_started = false
	multiplayer.multiplayer_peer = null
	players.clear()
	_reset_rescue_score()
	lobby_changed.emit({})
	_set_status("Disconnected from the host.")
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path != MAIN_SCENE:
		get_tree().change_scene_to_file(MAIN_SCENE)

func _publish_lobby(excluded_peer_id: int = 0) -> void:
	var snapshot := players.duplicate(true)
	lobby_changed.emit(snapshot)
	if is_host:
		for peer_id in connected_peer_ids():
			if peer_id == excluded_peer_id:
				continue
			rpc_id(peer_id, "rpc_receive_lobby", snapshot)

func _publish_rescue_score() -> void:
	rescue_score_changed.emit(evacuated_passengers, rescued_passengers)
	if not is_host:
		return
	for peer_id in connected_peer_ids():
		rpc_id(peer_id, "rpc_receive_rescue_score", evacuated_passengers, rescued_passengers)

func _reset_rescue_score() -> void:
	evacuated_passengers = 0
	rescued_passengers = 0
	rescue_score_changed.emit(evacuated_passengers, rescued_passengers)

func _first_available_slot() -> int:
	var used_slots: Array[int] = []
	for profile in players.values():
		used_slots.append(int(profile["slot"]))
	for slot in range(MAX_PLAYERS):
		if not used_slots.has(slot):
			return slot
	return 0

func _make_profile(nickname: String, slot: int) -> Dictionary:
	return {"nickname": _clean_nickname(nickname), "slot": slot}

func _clean_nickname(value: String) -> String:
	var cleaned := value.strip_edges().substr(0, 16)
	return cleaned if not cleaned.is_empty() else "Player"

func _set_status(message: String) -> void:
	status_message = message
	status_changed.emit(message)

func _close_session() -> void:
	is_networked = false
	is_host = false
	match_started = false
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null

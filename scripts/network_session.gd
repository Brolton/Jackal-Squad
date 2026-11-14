extends Node

signal lobby_changed(players: Dictionary)
signal status_changed(message: String)
signal game_start_requested
signal player_left(peer_id: int)
signal rescue_score_changed(evacuated: int, rescued: int)
signal mission_state_changed(state: Dictionary)

const PORT := 24567
const MAX_PLAYERS := 4
const RESCUE_OBJECTIVE_TOTAL := 6
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
var mission_started := false
var mission_completed := false
var mission_elapsed := 0.0
var enemies_destroyed := 0
var final_base_destroyed := false
var player_contributions: Dictionary = {}
var campaign_level_index := 0
var loaded_level_index := -1
var _pending_passenger_contributions: Dictionary = {}
var _mission_state_timer := 0.0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta: float) -> void:
	if not mission_started or mission_completed or (is_networked and not is_host):
		return
	mission_elapsed += delta
	_mission_state_timer -= delta
	if _mission_state_timer <= 0.0:
		_mission_state_timer = 0.5
		_publish_mission_state()

func start_solo(nickname: String, selected_level: int = 0) -> void:
	_close_session()
	campaign_level_index = clampi(selected_level, 0, CampaignCatalog.count() - 1)
	_reset_rescue_score()
	local_nickname = _clean_nickname(nickname)
	players = {1: _make_profile(local_nickname, 0)}
	match_started = true
	_start_mission()
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
	_start_mission()
	_set_status("Mission started.")
	game_start_requested.emit()
	for peer_id in connected_peer_ids():
		rpc_id(peer_id, "rpc_begin_match", _get_mission_state())
	return true

func select_campaign_level(index: int) -> bool:
	if match_started or (is_networked and not is_host):
		return false
	campaign_level_index = clampi(index, 0, CampaignCatalog.count() - 1)
	return true

func current_level_scene() -> String:
	return CampaignCatalog.scene_path(campaign_level_index)

func set_loaded_level(index: int) -> void:
	loaded_level_index = clampi(index, 0, CampaignCatalog.count() - 1)

func has_next_campaign_level() -> bool:
	return not CampaignCatalog.is_last(campaign_level_index)

func advance_campaign() -> bool:
	if not mission_completed or not has_next_campaign_level():
		return false
	if is_networked and not is_host:
		return false
	campaign_level_index += 1
	_reset_rescue_score()
	_start_mission()
	game_start_requested.emit()
	if is_host:
		for peer_id in connected_peer_ids():
			rpc_id(peer_id, "rpc_advance_campaign", campaign_level_index, _get_mission_state())
	return true

func restart_current_mission() -> bool:
	if is_networked and not is_host:
		return false
	_reset_rescue_score()
	_start_mission()
	game_start_requested.emit()
	if is_host:
		for peer_id in connected_peer_ids():
			rpc_id(peer_id, "rpc_restart_mission", campaign_level_index, _get_mission_state())
	return true

@rpc("authority", "call_remote", "reliable")
func rpc_restart_mission(level_index: int, mission_state: Dictionary) -> void:
	if is_host:
		return
	campaign_level_index = clampi(level_index, 0, CampaignCatalog.count() - 1)
	_apply_mission_state(mission_state)
	game_start_requested.emit()

@rpc("authority", "call_remote", "reliable")
func rpc_advance_campaign(level_index: int, mission_state: Dictionary) -> void:
	if is_host:
		return
	campaign_level_index = clampi(level_index, 0, CampaignCatalog.count() - 1)
	_apply_mission_state(mission_state)
	game_start_requested.emit()

func leave_lobby() -> void:
	_close_session()
	players.clear()
	_reset_rescue_score()
	lobby_changed.emit({})
	_set_status("Choose a game mode.")

func record_evacuated_passenger() -> void:
	record_evacuated_passenger_for_player(0)

func record_evacuated_passenger_for_player(peer_id: int) -> void:
	if is_networked and not is_host:
		return
	evacuated_passengers += 1
	if peer_id > 0:
		_ensure_player_contribution(peer_id)
		_pending_passenger_contributions[peer_id] = (
			int(_pending_passenger_contributions.get(peer_id, 0)) + 1
		)
	_publish_rescue_score()

func collect_evacuated_passengers() -> void:
	if is_networked and not is_host:
		return
	for peer_id in _pending_passenger_contributions:
		_ensure_player_contribution(int(peer_id))
		var contribution: Dictionary = player_contributions[int(peer_id)]
		contribution["passengers_rescued"] = (
			int(contribution.get("passengers_rescued", 0))
			+ int(_pending_passenger_contributions[peer_id])
		)
		player_contributions[int(peer_id)] = contribution
	_pending_passenger_contributions.clear()
	rescued_passengers += evacuated_passengers
	evacuated_passengers = 0
	_publish_rescue_score()

func record_enemy_destroyed(attacker_peer_id: int) -> void:
	if (is_networked and not is_host) or mission_completed:
		return
	enemies_destroyed += 1
	if attacker_peer_id > 0:
		_ensure_player_contribution(attacker_peer_id)
		var contribution: Dictionary = player_contributions[attacker_peer_id]
		contribution["enemies_destroyed"] = int(contribution.get("enemies_destroyed", 0)) + 1
		player_contributions[attacker_peer_id] = contribution
	_publish_mission_state()

func record_final_base_destroyed(attacker_peer_id: int) -> void:
	if (is_networked and not is_host) or final_base_destroyed:
		return
	final_base_destroyed = true
	if attacker_peer_id > 0:
		_ensure_player_contribution(attacker_peer_id)
		var contribution: Dictionary = player_contributions[attacker_peer_id]
		contribution["final_bases_destroyed"] = int(
			contribution.get("final_bases_destroyed", 0)
		) + 1
		player_contributions[attacker_peer_id] = contribution
	_publish_mission_state()
	_check_mission_completion()

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
func rpc_begin_match(mission_state: Dictionary) -> void:
	if is_host or match_started:
		return
	match_started = true
	_apply_mission_state(mission_state)
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
	AudioDirector.play_sfx(&"enemy_shot" if hostile else &"shot")

@rpc("authority", "call_remote", "unreliable")
func rpc_show_grenade(spawn_position: Vector2, direction: Vector2, blast_radius: float) -> void:
	if is_host or get_tree().current_scene == null:
		return
	var grenade := GRENADE_SCENE.instantiate()
	grenade.configure(spawn_position, direction, null, true, blast_radius)
	get_tree().current_scene.add_child(grenade)
	AudioDirector.play_sfx(&"grenade_throw")

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
		AudioDirector.play_sfx(&"pickup")
		pickup.queue_free()

@rpc("authority", "call_remote", "reliable")
func rpc_receive_rescue_score(evacuated: int, rescued: int) -> void:
	if is_host:
		return
	evacuated_passengers = evacuated
	rescued_passengers = rescued
	rescue_score_changed.emit(evacuated_passengers, rescued_passengers)

@rpc("authority", "call_remote", "reliable")
func rpc_receive_mission_state(state: Dictionary) -> void:
	if is_host:
		return
	_apply_mission_state(state)

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

func mission_state_snapshot() -> Dictionary:
	return _get_mission_state()

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
		_publish_mission_state()
		_check_mission_completion()
		return
	for peer_id in connected_peer_ids():
		rpc_id(peer_id, "rpc_receive_rescue_score", evacuated_passengers, rescued_passengers)
	_check_mission_completion()
	_publish_mission_state()

func _reset_rescue_score() -> void:
	evacuated_passengers = 0
	rescued_passengers = 0
	mission_started = false
	mission_completed = false
	mission_elapsed = 0.0
	enemies_destroyed = 0
	final_base_destroyed = false
	player_contributions.clear()
	_pending_passenger_contributions.clear()
	_mission_state_timer = 0.0
	rescue_score_changed.emit(evacuated_passengers, rescued_passengers)
	mission_state_changed.emit(_get_mission_state())

func _start_mission() -> void:
	mission_started = true
	mission_completed = false
	mission_elapsed = 0.0
	enemies_destroyed = 0
	final_base_destroyed = false
	player_contributions.clear()
	_pending_passenger_contributions.clear()
	_mission_state_timer = 0.5
	for peer_id in players:
		_ensure_player_contribution(int(peer_id))
	mission_state_changed.emit(_get_mission_state())

func _get_mission_state() -> Dictionary:
	return {
		"mission_started": mission_started,
		"mission_completed": mission_completed,
		"mission_elapsed": mission_elapsed,
		"enemies_destroyed": enemies_destroyed,
		"final_base_destroyed": final_base_destroyed,
		"evacuated_passengers": evacuated_passengers,
		"rescued_passengers": rescued_passengers,
		"rescue_objective_total": CampaignCatalog.rescue_total(campaign_level_index),
		"campaign_level_index": campaign_level_index,
		"campaign_level_count": CampaignCatalog.count(),
		"level_name": CampaignCatalog.display_name(campaign_level_index),
		"campaign_completed": mission_completed and CampaignCatalog.is_last(campaign_level_index),
		"player_contributions": player_contributions.duplicate(true),
	}

func _apply_mission_state(state: Dictionary) -> void:
	campaign_level_index = clampi(
		int(state.get("campaign_level_index", campaign_level_index)),
		0,
		CampaignCatalog.count() - 1
	)
	mission_started = bool(state.get("mission_started", false))
	mission_completed = bool(state.get("mission_completed", false))
	mission_elapsed = float(state.get("mission_elapsed", 0.0))
	enemies_destroyed = int(state.get("enemies_destroyed", 0))
	final_base_destroyed = bool(state.get("final_base_destroyed", false))
	evacuated_passengers = int(state.get("evacuated_passengers", 0))
	rescued_passengers = int(state.get("rescued_passengers", 0))
	player_contributions = state.get("player_contributions", {}).duplicate(true)
	rescue_score_changed.emit(evacuated_passengers, rescued_passengers)
	mission_state_changed.emit(_get_mission_state())

func _publish_mission_state() -> void:
	var state := _get_mission_state()
	mission_state_changed.emit(state)
	if not is_host:
		return
	for peer_id in connected_peer_ids():
		rpc_id(peer_id, "rpc_receive_mission_state", state)

func _ensure_player_contribution(peer_id: int) -> void:
	if player_contributions.has(peer_id):
		return
	var profile: Dictionary = players.get(peer_id, {})
	player_contributions[peer_id] = {
		"nickname": str(profile.get("nickname", "Player %d" % peer_id)),
		"enemies_destroyed": 0,
		"passengers_rescued": 0,
		"final_bases_destroyed": 0,
	}

func _check_mission_completion() -> void:
	if (
		mission_started
		and not mission_completed
		and final_base_destroyed
	):
		mission_completed = true
		_publish_mission_state()

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

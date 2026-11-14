extends Node

signal servers_changed(servers: Array)

const DISCOVERY_PORT := 24568
const GAME_PORT := 24567
const PROTOCOL_ID := "jackal-squad-lan-v1"
const QUERY_INTERVAL := 1.0
const SERVER_TIMEOUT := 3.5

var response_count := 0
var _socket: PacketPeerUDP
var _mode := ""
var _query_timer := 0.0
var _servers: Dictionary = {}
var _host_nickname := "Host"
var _host_player_count := 1
var _host_capacity := 4

func _process(delta: float) -> void:
	if _socket == null:
		return
	_receive_packets()
	if _mode != "browser":
		return
	_query_timer -= delta
	if _query_timer <= 0.0:
		_query_timer = QUERY_INTERVAL
		_send_discovery_query()
	_prune_expired_servers()

func start_host(nickname: String, player_count: int = 1, capacity: int = 4) -> bool:
	stop()
	_socket = PacketPeerUDP.new()
	var error := _socket.bind(DISCOVERY_PORT, "*")
	if error != OK:
		_socket = null
		return false
	_socket.set_broadcast_enabled(true)
	_mode = "host"
	_host_nickname = nickname.strip_edges() if not nickname.strip_edges().is_empty() else "Host"
	_host_player_count = player_count
	_host_capacity = capacity
	response_count = 0
	set_process(true)
	return true

func update_host_lobby(player_count: int, capacity: int = 4) -> void:
	_host_player_count = player_count
	_host_capacity = capacity

func start_browser() -> bool:
	stop()
	_socket = PacketPeerUDP.new()
	var error := _socket.bind(0, "*")
	if error != OK:
		_socket = null
		return false
	_socket.set_broadcast_enabled(true)
	_mode = "browser"
	_query_timer = 0.0
	set_process(true)
	return true

func stop() -> void:
	var had_servers := not _servers.is_empty()
	if _socket != null:
		_socket.close()
	_socket = null
	_mode = ""
	_query_timer = 0.0
	_servers.clear()
	set_process(false)
	if had_servers:
		servers_changed.emit([])

func servers_snapshot() -> Array:
	var result: Array = []
	for address in _servers:
		result.append((_servers[address] as Dictionary).duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return str(left["address"]) < str(right["address"]))
	return result

func local_ipv4_addresses() -> Array[String]:
	var result: Array[String] = []
	for interface_variant in IP.get_local_interfaces():
		var interface: Dictionary = interface_variant
		var description := (
			str(interface.get("name", "")) + " " + str(interface.get("friendly", ""))
		).to_lower()
		if _is_virtual_interface(description):
			continue
		for address in interface.get("addresses", []):
			var candidate := str(address)
			if _is_private_ipv4(candidate) and candidate not in result:
				result.append(candidate)
	if not result.is_empty():
		result.sort()
		return result
	for address in IP.get_local_addresses():
		var candidate := str(address)
		if _is_private_ipv4(candidate) and candidate not in result:
			result.append(candidate)
	result.sort()
	return result

func _is_virtual_interface(description: String) -> bool:
	for marker in ["virtual", "vethernet", "hyper-v", "wsl", "docker", "vmware", "vbox", "loopback"]:
		if marker in description:
			return true
	return false

func _receive_packets() -> void:
	while _socket != null and _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		var sender_address := _socket.get_packet_ip()
		var sender_port := _socket.get_packet_port()
		var payload = JSON.parse_string(packet.get_string_from_utf8())
		if typeof(payload) != TYPE_DICTIONARY or str(payload.get("protocol", "")) != PROTOCOL_ID:
			continue
		var message_type := str(payload.get("type", ""))
		if _mode == "host" and message_type == "discover":
			_send_offer(sender_address, sender_port)
		elif _mode == "browser" and message_type == "offer":
			_accept_offer(sender_address, payload)

func _send_discovery_query() -> void:
	var payload := JSON.stringify({"protocol": PROTOCOL_ID, "type": "discover"}).to_utf8_buffer()
	var destinations: Array[String] = ["255.255.255.255"]
	for address in local_ipv4_addresses():
		var parts := address.split(".")
		if parts.size() == 4:
			var subnet_broadcast := "%s.%s.%s.255" % [parts[0], parts[1], parts[2]]
			if subnet_broadcast not in destinations:
				destinations.append(subnet_broadcast)
	for destination in destinations:
		_socket.set_dest_address(destination, DISCOVERY_PORT)
		_socket.put_packet(payload)

func _send_offer(address: String, port: int) -> void:
	var offer := {
		"protocol": PROTOCOL_ID,
		"type": "offer",
		"nickname": _host_nickname,
		"players": _host_player_count,
		"capacity": _host_capacity,
		"game_port": GAME_PORT,
	}
	_socket.set_dest_address(address, port)
	if _socket.put_packet(JSON.stringify(offer).to_utf8_buffer()) == OK:
		response_count += 1

func _accept_offer(address: String, payload: Dictionary) -> void:
	if int(payload.get("game_port", 0)) != GAME_PORT:
		return
	if not _matches_local_lan(address):
		return
	var previous: Dictionary = _servers.get(address, {})
	var server := {
		"address": address,
		"nickname": str(payload.get("nickname", "Host")),
		"players": clampi(int(payload.get("players", 1)), 1, 4),
		"capacity": clampi(int(payload.get("capacity", 4)), 1, 4),
		"last_seen": Time.get_ticks_msec(),
	}
	_servers[address] = server
	if previous.is_empty() or _offer_changed(previous, server):
		servers_changed.emit(servers_snapshot())

func _offer_changed(previous: Dictionary, current: Dictionary) -> bool:
	return (
		str(previous.get("nickname", "")) != str(current.get("nickname", ""))
		or int(previous.get("players", 0)) != int(current.get("players", 0))
		or int(previous.get("capacity", 0)) != int(current.get("capacity", 0))
	)

func _prune_expired_servers() -> void:
	var cutoff := Time.get_ticks_msec() - int(SERVER_TIMEOUT * 1000.0)
	var removed := false
	for address in _servers.keys():
		if int((_servers[address] as Dictionary).get("last_seen", 0)) < cutoff:
			_servers.erase(address)
			removed = true
	if removed:
		servers_changed.emit(servers_snapshot())

func _is_private_ipv4(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if not str(part).is_valid_int() or int(part) < 0 or int(part) > 255:
			return false
	var first := int(parts[0])
	var second := int(parts[1])
	return (
		first == 10
		or (first == 172 and second >= 16 and second <= 31)
		or (first == 192 and second == 168)
	)

func _matches_local_lan(address: String) -> bool:
	var remote_parts := address.split(".")
	if remote_parts.size() != 4:
		return false
	var local_addresses := local_ipv4_addresses()
	if local_addresses.is_empty():
		return true
	for local_address in local_addresses:
		var local_parts := local_address.split(".")
		if (
			local_parts.size() == 4
			and local_parts[0] == remote_parts[0]
			and local_parts[1] == remote_parts[1]
			and local_parts[2] == remote_parts[2]
		):
			return true
	return false

extends SceneTree

var _found_servers: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var role := str(arguments[0]) if not arguments.is_empty() else ""
	var discovery: Node = root.get_node("LanDiscovery")
	if role == "host":
		await _run_host(discovery)
	elif role == "client":
		await _run_client(discovery)
	else:
		push_error("Pass host or client after --.")
		quit(2)

func _run_host(discovery: Node) -> void:
	if not discovery.call("start_host", "Discovery Test Host", 1, 4):
		push_error("LAN discovery host could not bind its UDP port.")
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + 6000
	while int(discovery.get("response_count")) == 0 and Time.get_ticks_msec() < deadline:
		await process_frame
	if int(discovery.get("response_count")) > 0:
		print("LAN discovery host answered a browser query.")
		discovery.call("stop")
		quit()
	else:
		push_error("LAN discovery host did not receive a browser query.")
		discovery.call("stop")
		quit(1)

func _run_client(discovery: Node) -> void:
	discovery.servers_changed.connect(_on_servers_changed)
	if not discovery.call("start_browser"):
		push_error("LAN browser could not open its UDP socket.")
		quit(1)
		return
	var deadline := Time.get_ticks_msec() + 5000
	while _found_servers.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _found_servers.is_empty():
		var server: Dictionary = _found_servers[0]
		var valid := (
			str(server.get("nickname", "")) == "Discovery Test Host"
			and int(server.get("players", 0)) == 1
			and int(server.get("capacity", 0)) == 4
			and not str(server.get("address", "")).is_empty()
		)
		if valid:
			print("LAN browser found %s at %s." % [server["nickname"], server["address"]])
			discovery.call("stop")
			quit()
			return
	push_error("LAN browser did not receive a valid host offer.")
	discovery.call("stop")
	quit(1)

func _on_servers_changed(servers: Array) -> void:
	_found_servers = servers.duplicate(true)

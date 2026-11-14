extends Area2D

@export var helicopter_interval := 18.0
@export var helicopter_speed := 400.0

var _helicopter_timer := 0.0
var _helicopter_x := 0.0
var _helicopter_active := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = not NetworkSession.is_networked or multiplayer.is_server()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_helicopter_timer = helicopter_interval
	queue_redraw()

func _physics_process(delta: float) -> void:
	if _helicopter_active:
		_helicopter_x += helicopter_speed * delta
		queue_redraw()
		if _helicopter_x >= 700.0:
			_helicopter_active = false
			queue_redraw()
			if not NetworkSession.is_networked or multiplayer.is_server():
				NetworkSession.collect_evacuated_passengers()
				_helicopter_timer = helicopter_interval

	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	_helicopter_timer -= delta
	if _helicopter_timer <= 0.0 and not _helicopter_active:
		_start_helicopter()

func _start_helicopter() -> void:
	_helicopter_x = -700.0
	_helicopter_active = true
	queue_redraw()
	if NetworkSession.is_networked:
		for peer_id in NetworkSession.connected_peer_ids():
			rpc_id(peer_id, "rpc_start_helicopter")

@rpc("authority", "call_remote", "reliable")
func rpc_start_helicopter() -> void:
	if NetworkSession.is_host:
		return
	_helicopter_x = -700.0
	_helicopter_active = true
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("players") or not body.has_method("set_extraction_active"):
		return
	body.call("set_extraction_active", true)

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("players") or not body.has_method("set_extraction_active"):
		return
	body.call("set_extraction_active", false)

func _draw() -> void:
	draw_rect(Rect2(-220.0, -90.0, 440.0, 180.0), Color(0.12, 0.40, 0.47, 0.25))
	draw_rect(Rect2(-220.0, -90.0, 440.0, 180.0), Color(0.54, 0.77, 0.69, 0.8), false, 3.0)
	for x in range(-200, 201, 40):
		draw_line(Vector2(x, -82.0), Vector2(x, 82.0), Color(0.59, 0.76, 0.65, 0.30), 2.0)
	if _helicopter_active:
		var body_color := Color(0.72, 0.72, 0.55)
		draw_circle(Vector2(_helicopter_x, -115.0), 9.0, body_color)
		draw_line(
			Vector2(_helicopter_x - 8.0, -127.0),
			Vector2(_helicopter_x + 8.0, -127.0),
			Color(0.14, 0.18, 0.16),
			2.0
		)
		draw_line(
			Vector2(_helicopter_x + 23.0, -116.0),
			Vector2(_helicopter_x + 39.0, -122.0),
			body_color,
			3.0
		)

extends Area2D

@export var damage := 2
@export var trigger_radius := 26.0

var _armed := true
var _exploded := false
var _effect_time := 0.32

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = not NetworkSession.is_networked or multiplayer.is_server()
	body_entered.connect(_on_body_entered)
	add_to_group("hazards")
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not _exploded:
		return
	_effect_time -= delta
	queue_redraw()
	if _effect_time <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if not _armed or not body.is_in_group("players"):
		return
	_trigger(body)

func _trigger(body: Node2D = null) -> void:
	if not _armed:
		return
	_armed = false
	_exploded = true
	monitoring = false
	if body != null and body.has_method("take_damage"):
		body.call("take_damage", damage)
	if NetworkSession.is_networked and NetworkSession.is_host:
		rpc("rpc_trigger_visual")
	queue_redraw()

@rpc("authority", "call_remote", "reliable")
func rpc_trigger_visual() -> void:
	if NetworkSession.is_host:
		return
	_trigger()

func _draw() -> void:
	if _exploded:
		var progress := clampf(_effect_time / 0.32, 0.0, 1.0)
		draw_circle(Vector2.ZERO, 70.0 * (1.0 - progress * 0.35), Color(1.0, 0.26, 0.06, progress * 0.45))
		draw_circle(Vector2.ZERO, 34.0 * (1.0 - progress * 0.45), Color(1.0, 0.78, 0.24, progress * 0.82))
		return
	draw_circle(Vector2(3, 5), 13.0, Color(0, 0, 0, 0.32))
	draw_circle(Vector2.ZERO, 11.0, Color(0.16, 0.20, 0.15))
	draw_circle(Vector2.ZERO, 7.0, Color(0.37, 0.39, 0.27))
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		draw_line(Vector2.ZERO, Vector2.from_angle(angle) * 15.0, Color(0.22, 0.25, 0.19), 3.0)
	draw_circle(Vector2.ZERO, 2.2, Color(0.92, 0.24, 0.12))

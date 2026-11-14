extends StaticBody2D

const PASSENGER_SCENE := preload("res://scenes/rescue_passenger.tscn")
const MAX_HEALTH := 4
const PASSENGER_OFFSETS := [
	Vector2(-18.0, 0.0),
	Vector2(0.0, 16.0),
	Vector2(18.0, 0.0),
]

var health := MAX_HEALTH

func _ready() -> void:
	collision_layer = 4
	collision_mask = 2
	queue_redraw()

func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	health = maxi(health - amount, 0)
	queue_redraw()
	if health == 0:
		_release_passengers()

func _release_passengers() -> void:
	_spawn_passengers()
	if NetworkSession.is_networked and NetworkSession.is_host:
		rpc("rpc_release_passengers")
	queue_free()

@rpc("authority", "call_remote", "reliable")
func rpc_release_passengers() -> void:
	if NetworkSession.is_host:
		return
	_spawn_passengers()
	queue_free()

func _spawn_passengers() -> void:
	for index in range(PASSENGER_OFFSETS.size()):
		var passenger := PASSENGER_SCENE.instantiate()
		passenger.name = "Passenger_%s_%02d" % [name, index + 1]
		passenger.configure(passenger.name, global_position + PASSENGER_OFFSETS[index])
		get_parent().add_child(passenger)

func _draw() -> void:
	var damage_ratio := float(health) / float(MAX_HEALTH)
	var wall_color := Color(0.40, 0.37, 0.26).lerp(Color(0.48, 0.24, 0.17), 1.0 - damage_ratio)
	draw_rect(Rect2(-28.0, -16.0, 56.0, 43.0), Color(0.0, 0.0, 0.0, 0.28))
	draw_rect(Rect2(-24.0, -20.0, 48.0, 40.0), Color(0.13, 0.15, 0.12))
	draw_rect(Rect2(-19.0, -16.0, 38.0, 32.0), wall_color)
	draw_rect(Rect2(-8.0, -8.0, 16.0, 16.0), Color(0.20, 0.25, 0.22))
	draw_line(Vector2(-20.0, -20.0), Vector2(0.0, -29.0), Color(0.57, 0.31, 0.23), 5.0)
	draw_line(Vector2(0.0, -29.0), Vector2(20.0, -20.0), Color(0.57, 0.31, 0.23), 5.0)
	draw_rect(Rect2(-17, -13, 8, 8), Color(0.92, 0.67, 0.28, 0.78))
	draw_rect(Rect2(9, -13, 8, 8), Color(0.92, 0.67, 0.28, 0.78))
	draw_line(Vector2(-16, 11), Vector2(16, 11), Color(0.66, 0.58, 0.36), 2.0)

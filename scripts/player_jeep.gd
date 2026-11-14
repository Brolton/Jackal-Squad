extends CharacterBody2D

signal health_changed(current: int, maximum: int)

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const GRENADE_SCENE := preload("res://scenes/grenade.tscn")
const PLAYER_COLORS := [
	Color(0.78, 0.20, 0.17),
	Color(0.20, 0.43, 0.82),
	Color(0.90, 0.76, 0.19),
	Color(0.58, 0.31, 0.75),
]

@export var acceleration := 850.0
@export var maximum_speed := 220.0
@export var deceleration := 1050.0
@export var maximum_health := 5

var health := 5
var facing := Vector2.UP
var spawn_position := Vector2.ZERO
var player_peer_id := 1
var player_nickname := "Player"
var color_slot := 0
var _received_movement := Vector2.ZERO
var _received_primary := false
var _received_secondary := false
var _network_input_timer := 0.0
var _network_state_timer := 0.0
var _target_position := Vector2.ZERO
var _target_rotation := 0.0
var _has_authoritative_state := false
var authoritative_state_count := 0
var last_authoritative_position := Vector2.ZERO
var _primary_cooldown := 0.0
var _secondary_cooldown := 0.0
var _respawning := false

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _camera: Camera2D = $Camera2D
@onready var _nickname_label: Label = $Nickname

func configure(peer_id: int, nickname: String, slot: int) -> void:
	player_peer_id = peer_id
	player_nickname = nickname
	color_slot = clampi(slot, 0, PLAYER_COLORS.size() - 1)

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 5
	add_to_group("players")
	health = maximum_health
	spawn_position = global_position
	_install_input_actions()
	_nickname_label.text = player_nickname
	_nickname_label.add_theme_color_override("font_color", PLAYER_COLORS[color_slot])
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 1200
	_camera.limit_bottom = 3200
	if not NetworkSession.is_networked or player_peer_id == multiplayer.get_unique_id():
		_camera.make_current()
	health_changed.emit(health, maximum_health)

func _physics_process(delta: float) -> void:
	if _respawning:
		if NetworkSession.is_networked and multiplayer.is_server():
			_broadcast_state(delta)
		return
	if _primary_cooldown > 0.0:
		_primary_cooldown = maxf(0.0, _primary_cooldown - delta)
	if _secondary_cooldown > 0.0:
		_secondary_cooldown = maxf(0.0, _secondary_cooldown - delta)

	if not NetworkSession.is_networked:
		_simulate_player(Input.get_vector("move_left", "move_right", "move_up", "move_down"), _primary_pressed(), _secondary_pressed(), delta, true)
	elif multiplayer.is_server():
		_process_host_player(delta)
	else:
		_process_client_player(delta)

func _process_host_player(delta: float) -> void:
	var is_host_player := player_peer_id == 1
	var movement := _read_movement() if is_host_player else _received_movement
	var primary := _primary_pressed() if is_host_player else _received_primary
	var secondary := _secondary_pressed() if is_host_player else _received_secondary
	_simulate_player(movement, primary, secondary, delta, true)
	_broadcast_state(delta)

func _process_client_player(delta: float) -> void:
	if player_peer_id == multiplayer.get_unique_id():
		var movement := _read_movement()
		_network_input_timer -= delta
		if _network_input_timer <= 0.0:
			_network_input_timer = 0.05
			rpc_id(1, "rpc_submit_input", movement, _primary_pressed(), _secondary_pressed())
		_simulate_player(movement, false, false, delta, false)
	if _has_authoritative_state:
		var weight := minf(1.0, delta * 12.0)
		if global_position.distance_squared_to(_target_position) > 1600.0:
			global_position = _target_position
		else:
			global_position = global_position.lerp(_target_position, weight)
		rotation = lerp_angle(rotation, _target_rotation, weight)

func _simulate_player(
	movement: Vector2,
	fire_primary: bool,
	fire_secondary: bool,
	delta: float,
	allow_combat: bool
) -> void:
	if movement.length_squared() > 0.0:
		facing = movement.normalized()
		rotation = facing.angle() + PI * 0.5
		velocity = velocity.move_toward(facing * maximum_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
	move_and_slide()

	if not allow_combat:
		return
	if fire_primary:
		_fire_primary()
	if fire_secondary:
		_fire_secondary()

@rpc("any_peer", "call_remote", "unreliable_ordered")
func rpc_submit_input(movement: Vector2, fire_primary: bool, fire_secondary: bool) -> void:
	if not NetworkSession.is_host or multiplayer.get_remote_sender_id() != player_peer_id:
		return
	_received_movement = movement.limit_length(1.0)
	_received_primary = fire_primary
	_received_secondary = fire_secondary

@rpc("authority", "call_remote", "unreliable_ordered")
func rpc_receive_state(
	world_position: Vector2,
	world_rotation: float,
	current_health: int,
	is_visible: bool
) -> void:
	if not NetworkSession.is_networked or multiplayer.is_server():
		return
	_target_position = world_position
	_target_rotation = world_rotation
	_has_authoritative_state = true
	last_authoritative_position = world_position
	authoritative_state_count += 1
	if health != current_health:
		health = current_health
		health_changed.emit(health, maximum_health)
	if visible != is_visible:
		visible = is_visible
		_collision_shape.set_deferred("disabled", not is_visible)

func _broadcast_state(delta: float) -> void:
	if not NetworkSession.is_host:
		return
	_network_state_timer -= delta
	if _network_state_timer > 0.0:
		return
	_network_state_timer = 0.05
	rpc("rpc_receive_state", global_position, rotation, health, visible)

func _read_movement() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _primary_pressed() -> bool:
	return Input.is_action_pressed("fire_primary")

func _secondary_pressed() -> bool:
	return Input.is_action_pressed("fire_secondary") or Input.is_key_pressed(KEY_CTRL)

func take_damage(amount: int) -> void:
	if amount <= 0 or _respawning:
		return
	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, maximum_health)
	if health == 0:
		_respawn()

func _fire_primary() -> void:
	if _primary_cooldown > 0.0:
		return
	_primary_cooldown = 0.30
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.configure(global_position + facing * 25.0, facing, self, false, 1, 620.0)
	get_tree().current_scene.add_child(projectile)
	NetworkSession.spawn_projectile_visual(global_position + facing * 25.0, facing, false, 1, 620.0)

func _fire_secondary() -> void:
	if _secondary_cooldown > 0.0:
		return
	_secondary_cooldown = 1.2
	var grenade := GRENADE_SCENE.instantiate()
	grenade.configure(global_position + facing * 24.0, facing, self)
	get_tree().current_scene.add_child(grenade)
	NetworkSession.spawn_grenade_visual(global_position + facing * 24.0, facing)

func _respawn() -> void:
	if _respawning:
		return
	_respawning = true
	visible = false
	_collision_shape.set_deferred("disabled", true)
	await get_tree().create_timer(1.0).timeout
	if not is_inside_tree():
		return
	global_position = spawn_position
	velocity = Vector2.ZERO
	health = maximum_health
	visible = true
	_collision_shape.set_deferred("disabled", false)
	_respawning = false
	health_changed.emit(health, maximum_health)

func _draw() -> void:
	var wheel := Color(0.09, 0.10, 0.09)
	var body: Color = PLAYER_COLORS[color_slot]
	draw_rect(Rect2(-16.0, -13.0, 6.0, 13.0), wheel)
	draw_rect(Rect2(10.0, -13.0, 6.0, 13.0), wheel)
	draw_rect(Rect2(-16.0, 5.0, 6.0, 13.0), wheel)
	draw_rect(Rect2(10.0, 5.0, 6.0, 13.0), wheel)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-10.0, 17.0),
			Vector2(-13.0, -8.0),
			Vector2(-7.0, -18.0),
			Vector2(7.0, -18.0),
			Vector2(13.0, -8.0),
			Vector2(10.0, 17.0),
		]),
		body
	)
	draw_rect(Rect2(-7.0, -7.0, 14.0, 11.0), Color(0.25, 0.42, 0.43))
	draw_line(Vector2(-9.0, 7.0), Vector2(9.0, 7.0), Color(0.83, 0.65, 0.35), 2.0)
	draw_circle(Vector2.ZERO, 3.0, Color(0.86, 0.76, 0.52))

static func _install_input_actions() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("fire_primary", [KEY_SPACE])
	_add_mouse_action("fire_primary", MOUSE_BUTTON_LEFT)
	_add_mouse_action("fire_secondary", MOUSE_BUTTON_RIGHT)

static func _add_key_action(action_name: StringName, key_codes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	for key_code in key_codes:
		var event := InputEventKey.new()
		event.physical_keycode = key_code
		InputMap.action_add_event(action_name, event)

static func _add_mouse_action(action_name: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventMouseButton and existing_event.button_index == button:
			return
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action_name, event)

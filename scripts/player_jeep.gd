extends CharacterBody2D

signal health_changed(current: int, maximum: int)

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const GRENADE_SCENE := preload("res://scenes/grenade.tscn")

@export var acceleration := 850.0
@export var maximum_speed := 220.0
@export var deceleration := 1050.0
@export var maximum_health := 5

var health := 5
var facing := Vector2.UP
var spawn_position := Vector2.ZERO
var _primary_cooldown := 0.0
var _secondary_cooldown := 0.0
var _respawning := false

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _camera: Camera2D = $Camera2D

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 5
	add_to_group("players")
	health = maximum_health
	spawn_position = global_position
	_install_input_actions()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = 1200
	_camera.limit_bottom = 3200
	_camera.make_current()
	health_changed.emit(health, maximum_health)

func _physics_process(delta: float) -> void:
	if _respawning:
		return
	if _primary_cooldown > 0.0:
		_primary_cooldown = maxf(0.0, _primary_cooldown - delta)
	if _secondary_cooldown > 0.0:
		_secondary_cooldown = maxf(0.0, _secondary_cooldown - delta)

	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if movement.length_squared() > 0.0:
		facing = movement.normalized()
		rotation = facing.angle() + PI * 0.5
		velocity = velocity.move_toward(facing * maximum_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
	move_and_slide()

	if Input.is_action_pressed("fire_primary"):
		_fire_primary()
	if Input.is_action_pressed("fire_secondary") or Input.is_key_pressed(KEY_CTRL):
		_fire_secondary()

func take_damage(amount: int) -> void:
	if amount <= 0 or _respawning:
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

func _fire_secondary() -> void:
	if _secondary_cooldown > 0.0:
		return
	_secondary_cooldown = 1.2
	var grenade := GRENADE_SCENE.instantiate()
	grenade.configure(global_position + facing * 24.0, facing, self)
	get_tree().current_scene.add_child(grenade)

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
	var body := Color(0.66, 0.19, 0.16)
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

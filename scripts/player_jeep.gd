extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal weapon_upgrades_changed(primary_level: int, secondary_level: int)
signal passenger_count_changed(current: int, maximum: int)

const PROJECTILE_SCENE := preload("res://scenes/projectile.tscn")
const GRENADE_SCENE := preload("res://scenes/grenade.tscn")
const ROCKET_SCENE := preload("res://scenes/rocket.tscn")
const PLAYER_JEEP_TEXTURE := preload("res://assets/art/player_jeep_v2.png")
const PLAYER_COLORS := [
	Color(0.78, 0.20, 0.17),
	Color(0.20, 0.43, 0.82),
	Color(0.90, 0.76, 0.19),
	Color(0.58, 0.31, 0.75),
]
const MAX_WEAPON_UPGRADE_LEVEL := 3
const MAX_PASSENGERS := 6
const EXTRACTION_UNLOAD_INTERVAL := 0.75

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
var primary_upgrade_level := 0
var secondary_upgrade_level := 0
var passenger_count := 0
var passenger_capacity := MAX_PASSENGERS
var world_size := Vector2(1200.0, 3200.0)
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
var minimum_received_health := 999
var _primary_cooldown := 0.0
var _secondary_cooldown := 0.0
var _extraction_unload_timer := 0.0
var _extraction_active := false
var _respawning := false
var _hit_flash := 0.0
var _camera_trauma := 0.0
var _engine_audio: AudioStreamPlayer
var _upgrade_flash_time := 0.0
var _last_upgrade_type: StringName = &""

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D
@onready var _camera: Camera2D = $Camera2D
@onready var _nickname_label: Label = $Nickname
@onready var _trample_area: Area2D = $TrampleArea

func configure(peer_id: int, nickname: String, slot: int) -> void:
	player_peer_id = peer_id
	player_nickname = nickname
	color_slot = clampi(slot, 0, PLAYER_COLORS.size() - 1)

func configure_world_bounds(bounds: Vector2) -> void:
	world_size = bounds

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 37
	add_to_group("players")
	health = maximum_health
	minimum_received_health = maximum_health
	spawn_position = global_position
	_install_input_actions()
	_nickname_label.text = player_nickname
	_nickname_label.add_theme_color_override("font_color", PLAYER_COLORS[color_slot])
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(world_size.x)
	_camera.limit_bottom = int(world_size.y)
	if not NetworkSession.is_networked or player_peer_id == multiplayer.get_unique_id():
		_camera.make_current()
	_trample_area.body_entered.connect(_on_trample_body_entered)
	_engine_audio = AudioStreamPlayer.new()
	_engine_audio.name = "EngineAudio"
	_engine_audio.stream = AudioDirector.engine_stream()
	_engine_audio.volume_db = -25.0
	add_child(_engine_audio)
	_engine_audio.play()
	health_changed.emit(health, maximum_health)

func _on_trample_body_entered(body: Node2D) -> void:
	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	if body.has_method("can_be_trampled") and bool(body.call("can_be_trampled")):
		AudioDirector.play_sfx(&"trample")
		body.call("take_damage", int(body.get("maximum_health")), player_peer_id)

func _physics_process(delta: float) -> void:
	_update_feedback(delta)
	if _respawning:
		if NetworkSession.is_networked and multiplayer.is_server():
			_broadcast_state(delta)
		return
	if NetworkSession.mission_completed:
		velocity = Vector2.ZERO
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
	if not NetworkSession.is_networked or multiplayer.is_server():
		_process_extraction(delta)

func _exit_tree() -> void:
	if _engine_audio != null:
		_engine_audio.stop()
		_engine_audio.stream = null

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
	is_visible: bool,
	received_primary_level: int,
	received_secondary_level: int,
	received_passengers: int
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
		minimum_received_health = mini(minimum_received_health, current_health)
		health_changed.emit(health, maximum_health)
	if visible != is_visible:
		visible = is_visible
		_collision_shape.set_deferred("disabled", not is_visible)
	if (
		primary_upgrade_level != received_primary_level
		or secondary_upgrade_level != received_secondary_level
	):
		var gained_primary := received_primary_level > primary_upgrade_level
		var gained_secondary := received_secondary_level > secondary_upgrade_level
		if gained_primary or gained_secondary:
			_last_upgrade_type = &"primary" if gained_primary else &"secondary"
			_upgrade_flash_time = 1.25
		else:
			_last_upgrade_type = &""
			_upgrade_flash_time = 0.0
		primary_upgrade_level = received_primary_level
		secondary_upgrade_level = received_secondary_level
		weapon_upgrades_changed.emit(primary_upgrade_level, secondary_upgrade_level)
	if passenger_count != received_passengers:
		passenger_count = received_passengers
		passenger_count_changed.emit(passenger_count, passenger_capacity)

func _broadcast_state(delta: float) -> void:
	if not NetworkSession.is_host:
		return
	_network_state_timer -= delta
	if _network_state_timer > 0.0:
		return
	_network_state_timer = 0.05
	for peer_id in NetworkSession.connected_peer_ids():
		rpc_id(
			peer_id,
			"rpc_receive_state",
			global_position,
			rotation,
			health,
			visible,
			primary_upgrade_level,
			secondary_upgrade_level,
			passenger_count
		)

func _read_movement() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")

func _primary_pressed() -> bool:
	return Input.is_action_pressed("fire_primary")

func _secondary_pressed() -> bool:
	return Input.is_action_pressed("fire_secondary")

func take_damage(amount: int) -> void:
	if amount <= 0 or _respawning:
		return
	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	health = maxi(health - amount, 0)
	AudioDirector.play_sfx(&"hit")
	_hit_flash = 0.13
	_camera_trauma = minf(1.0, _camera_trauma + 0.55)
	queue_redraw()
	health_changed.emit(health, maximum_health)
	if health == 0:
		_respawn()

func apply_weapon_upgrade(upgrade_type: StringName) -> bool:
	if NetworkSession.is_networked and not multiplayer.is_server():
		return false
	match upgrade_type:
		&"primary":
			if primary_upgrade_level >= MAX_WEAPON_UPGRADE_LEVEL:
				return false
			primary_upgrade_level += 1
		&"secondary":
			if secondary_upgrade_level >= MAX_WEAPON_UPGRADE_LEVEL:
				return false
			secondary_upgrade_level += 1
		_:
			return false
	weapon_upgrades_changed.emit(primary_upgrade_level, secondary_upgrade_level)
	_last_upgrade_type = upgrade_type
	_upgrade_flash_time = 1.25
	queue_redraw()
	return true

func weapon_visual_signature() -> Dictionary:
	return {
		"barrels": 1 + primary_upgrade_level,
		"rocket_pods": secondary_upgrade_level,
		"primary_pips": primary_upgrade_level,
		"secondary_pips": secondary_upgrade_level,
		"projectile_style": primary_upgrade_level,
		"blast_style": secondary_upgrade_level,
		"secondary_weapon": "grenade" if secondary_upgrade_level == 0 else "rocket",
		"team_stripes": false,
		"pickup_flash": _last_upgrade_type,
	}

func try_add_passenger() -> bool:
	if NetworkSession.is_networked and not multiplayer.is_server():
		return false
	if passenger_count >= passenger_capacity:
		return false
	passenger_count += 1
	if health < maximum_health:
		health += 1
		health_changed.emit(health, maximum_health)
		AudioDirector.play_sfx(&"pickup", -4.0)
	passenger_count_changed.emit(passenger_count, passenger_capacity)
	return true

func has_passenger_space() -> bool:
	return passenger_count < passenger_capacity

func set_extraction_active(active: bool) -> void:
	if NetworkSession.is_networked and not multiplayer.is_server():
		return
	if active and not _extraction_active and _extraction_unload_timer <= 0.0:
		_extraction_unload_timer = EXTRACTION_UNLOAD_INTERVAL
	_extraction_active = active

func _process_extraction(delta: float) -> void:
	if not _extraction_active or passenger_count <= 0:
		return
	_extraction_unload_timer -= delta
	if _extraction_unload_timer > 0.0:
		return
	passenger_count -= 1
	passenger_count_changed.emit(passenger_count, MAX_PASSENGERS)
	NetworkSession.record_evacuated_passenger_for_player(player_peer_id)
	_extraction_unload_timer = EXTRACTION_UNLOAD_INTERVAL

func _fire_primary() -> void:
	if _primary_cooldown > 0.0:
		return
	_primary_cooldown = maxf(0.12, 0.30 - float(primary_upgrade_level) * 0.05)
	AudioDirector.play_sfx(&"shot")
	var projectile_damage := 1
	if primary_upgrade_level >= 2:
		projectile_damage = 2
	if primary_upgrade_level >= 3:
		projectile_damage = 3
	var projectile_speed := 620.0 + float(primary_upgrade_level) * 80.0
	var projectile_range := _visible_projectile_distance(90.0)
	var projectile := PROJECTILE_SCENE.instantiate()
	projectile.configure(
		global_position + facing * 25.0,
		facing,
		self,
		false,
		projectile_damage,
		projectile_speed,
		true,
		primary_upgrade_level,
		projectile_range
	)
	get_tree().current_scene.add_child(projectile)
	NetworkSession.spawn_projectile_visual(
		global_position + facing * 25.0,
		facing,
		false,
		projectile_damage,
		projectile_speed,
		primary_upgrade_level,
		projectile_range
	)

func _fire_secondary() -> void:
	if _secondary_cooldown > 0.0:
		return
	_secondary_cooldown = maxf(0.6, 1.2 - float(secondary_upgrade_level) * 0.15)
	if secondary_upgrade_level == 0:
		AudioDirector.play_sfx(&"grenade_throw")
		var grenade := GRENADE_SCENE.instantiate()
		grenade.configure(global_position + facing * 24.0, facing, self, false, 92.0, 0)
		get_tree().current_scene.add_child(grenade)
		NetworkSession.spawn_grenade_visual(global_position + facing * 24.0, facing, 92.0, 0)
		return
	AudioDirector.play_sfx(&"rocket_launch")
	var rocket_blast_radius := 108.0 + float(secondary_upgrade_level) * 10.0
	var rocket_damage := 2 + secondary_upgrade_level
	var rocket_range := _visible_projectile_distance(230.0)
	var rocket := ROCKET_SCENE.instantiate()
	rocket.configure(
		global_position + facing * 30.0,
		facing,
		self,
		false,
		rocket_blast_radius,
		secondary_upgrade_level,
		rocket_range,
		rocket_damage
	)
	get_tree().current_scene.add_child(rocket)
	NetworkSession.spawn_rocket_visual(
		global_position + facing * 30.0,
		facing,
		rocket_blast_radius,
		secondary_upgrade_level,
		rocket_range,
		rocket_damage
	)

func _visible_projectile_distance(offscreen_buffer: float) -> float:
	var viewport_size := get_viewport_rect().size
	var safe_zoom := Vector2(maxf(_camera.zoom.x, 0.01), maxf(_camera.zoom.y, 0.01))
	var half_extent := viewport_size * 0.5 / safe_zoom
	var relative_origin := global_position - _camera.global_position
	var edge_distance := INF
	if absf(facing.x) > 0.0001:
		var edge_x := half_extent.x if facing.x > 0.0 else -half_extent.x
		var distance_x := (edge_x - relative_origin.x) / facing.x
		if distance_x > 0.0:
			edge_distance = minf(edge_distance, distance_x)
	if absf(facing.y) > 0.0001:
		var edge_y := half_extent.y if facing.y > 0.0 else -half_extent.y
		var distance_y := (edge_y - relative_origin.y) / facing.y
		if distance_y > 0.0:
			edge_distance = minf(edge_distance, distance_y)
	if edge_distance == INF:
		edge_distance = maxf(half_extent.x, half_extent.y)
	return maxf(180.0, edge_distance + offscreen_buffer)

func _respawn() -> void:
	if _respawning:
		return
	_respawning = true
	_reset_weapon_upgrades()
	_extraction_active = false
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

func _reset_weapon_upgrades() -> void:
	if primary_upgrade_level == 0 and secondary_upgrade_level == 0:
		return
	primary_upgrade_level = 0
	secondary_upgrade_level = 0
	_last_upgrade_type = &""
	_upgrade_flash_time = 0.0
	weapon_upgrades_changed.emit(primary_upgrade_level, secondary_upgrade_level)
	queue_redraw()

func _draw() -> void:
	draw_ellipse_shadow(Vector2(2.0, 4.0), Vector2(19.0, 27.0), Color(0.0, 0.0, 0.0, 0.34))
	var texture_tint := Color(1.0, 0.94, 0.76) if _hit_flash > 0.0 else Color.WHITE
	draw_texture_rect(PLAYER_JEEP_TEXTURE, Rect2(-19.0, -29.0, 38.0, 57.0), false, texture_tint)
	_draw_weapon_upgrades()
	if _upgrade_flash_time > 0.0:
		var flash_progress := _upgrade_flash_time / 1.25
		var flash_color := Color(1.0, 0.72, 0.18) if _last_upgrade_type == &"primary" else Color(0.24, 0.84, 1.0)
		draw_arc(Vector2.ZERO, 34.0 + (1.0 - flash_progress) * 22.0, 0.0, TAU, 40, Color(flash_color.r, flash_color.g, flash_color.b, flash_progress), 3.0)
		draw_string(ThemeDB.fallback_font, Vector2(-22, -45), "MG UP!" if _last_upgrade_type == &"primary" else "BLAST UP!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, flash_color)

func _draw_weapon_upgrades() -> void:
	var steel := Color(0.23, 0.27, 0.27)
	var hot := Color(1.0, 0.70, 0.22)
	var barrel_count := 1 + primary_upgrade_level
	for index in range(barrel_count):
		var barrel_x := (float(index) - float(barrel_count - 1) * 0.5) * 4.5
		draw_line(Vector2(barrel_x, -8), Vector2(barrel_x, -34), steel, 3.0)
		draw_circle(Vector2(barrel_x, -34), 1.8, hot if primary_upgrade_level >= 2 else steel.lightened(0.3))
	for pod_index in range(secondary_upgrade_level):
		var side := -1.0 if pod_index % 2 == 0 else 1.0
		var row := int(pod_index / 2)
		var pod_center := Vector2(side * 18.0, -5.0 + row * 10.0)
		draw_rect(Rect2(pod_center - Vector2(4.5, 7), Vector2(9, 14)), Color(0.12, 0.17, 0.16), true)
		draw_rect(Rect2(pod_center - Vector2(4.5, 7), Vector2(9, 14)), Color(0.25, 0.78, 0.92), false, 1.5)
		for tube_y in [-4.0, 0.0, 4.0]:
			draw_circle(pod_center + Vector2(0, tube_y), 1.6, Color(0.82, 0.38, 0.16))
	for pip in range(primary_upgrade_level):
		draw_circle(Vector2(-8 + pip * 4, 24), 1.5, Color(0.26, 0.88, 0.98))
	for pip in range(secondary_upgrade_level):
		draw_circle(Vector2(8 - pip * 4, 24), 1.5, Color(1.0, 0.52, 0.18))

func draw_ellipse_shadow(center: Vector2, size: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * size.x, sin(angle) * size.y))
	draw_colored_polygon(points, color)

func _update_feedback(delta: float) -> void:
	if _upgrade_flash_time > 0.0:
		_upgrade_flash_time = maxf(0.0, _upgrade_flash_time - delta)
		queue_redraw()
	if _engine_audio != null:
		var speed_ratio := clampf(velocity.length() / maximum_speed, 0.0, 1.0)
		_engine_audio.pitch_scale = lerpf(0.82, 1.34, speed_ratio)
		_engine_audio.volume_db = lerpf(-25.0, -17.0, speed_ratio)
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		queue_redraw()
	if _camera_trauma > 0.0 and _camera.enabled:
		_camera_trauma = maxf(0.0, _camera_trauma - delta * 2.8)
		var magnitude := 7.0 * _camera_trauma * _camera_trauma
		_camera.offset = Vector2(randf_range(-magnitude, magnitude), randf_range(-magnitude, magnitude))
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO

static func _install_input_actions() -> void:
	_add_key_action("move_up", [KEY_W, KEY_UP])
	_add_key_action("move_down", [KEY_S, KEY_DOWN])
	_add_key_action("move_left", [KEY_A, KEY_LEFT])
	_add_key_action("move_right", [KEY_D, KEY_RIGHT])
	_add_key_action("fire_primary", [KEY_J])
	_add_key_action("fire_secondary", [KEY_K])
	_add_mouse_action("fire_primary", MOUSE_BUTTON_LEFT)
	_add_mouse_action("fire_secondary", MOUSE_BUTTON_RIGHT)

static func _add_key_action(action_name: StringName, key_codes: Array[int]) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for key_code in key_codes:
		var already_bound := false
		for existing_event in InputMap.action_get_events(action_name):
			if existing_event is InputEventKey and existing_event.physical_keycode == key_code:
				already_bound = true
				break
		if already_bound:
			continue
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

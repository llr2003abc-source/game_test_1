extends CharacterBody3D

const MovementMode = ActorNoiseEmitter.MovementMode

@export var mouse_sensitivity: float = 0.0025
@export var injury_component: BodyInjuryComponent
@export var normal_speed: float = 5.0
@export var aim_speed: float = 3.0
@export var sneak_speed: float = 2.5
@export var sprint_speed: float = 7.5
@export var injured_speed: float = 2.5

var movement_mode: ActorNoiseEmitter.MovementMode = MovementMode.WALK
var jump_velocity: float = 5.0
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _block_fire_until_release: bool = false
var _pending_recoil: Vector2 = Vector2.ZERO
var inventory_open: bool = false
var reload_input_resolver: ReloadInputResolver
var _reload_event_handled: bool = false

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var firearm: Firearm = $Head/Camera3D/WeaponRoot
@onready var noise_emitter: ActorNoiseEmitter = $ActorNoiseEmitter
@onready var inventory: PlayerInventoryComponent = $PlayerInventory

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	firearm.shot_fired.connect(_on_shot_fired)
	reload_input_resolver = ReloadInputResolver.new()
	add_child(reload_input_resolver)
	reload_input_resolver.reload_requested.connect(_on_reload_requested)
	add_child(load("res://scenes/ui/inventory_ui.tscn").instantiate())

func set_inventory_open(value: bool) -> void:
	inventory_open = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value else Input.MOUSE_MODE_CAPTURED
	reload_input_resolver.set_enabled(not value)
	_block_fire_until_release = true
	firearm.set_trigger(false)
	firearm.set_aiming(false)

func _on_reload_requested(type: WeaponRuntime.ReloadType) -> void:
	if not inventory_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		firearm.request_reload(type)

func _unhandled_input(event: InputEvent) -> void:
	if inventory_open: return
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_block_fire_until_release = true
		firearm.set_trigger(false)
		get_viewport().set_input_as_handled()
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseButton and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			_block_fire_until_release = true
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("reload",true):
		_reload_event_handled = true
		reload_input_resolver.press(event.echo if event is InputEventKey else false)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.screen_relative.x * mouse_sensitivity)
		head.rotation.x = clampf(
			head.rotation.x - event.screen_relative.y * mouse_sensitivity,
			deg_to_rad(-89.0), deg_to_rad(89.0)
		)

func _physics_process(delta: float) -> void:
	var controls_active: bool = not inventory_open and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var aiming: bool = controls_active and firearm.can_use_weapon() and Input.is_action_pressed("aim")
	movement_mode = _resolve_movement_mode(controls_active, aiming)
	var speed: float = normal_speed
	match movement_mode:
		MovementMode.SNEAK: speed = sneak_speed
		MovementMode.SPRINT: speed = sprint_speed
		MovementMode.INJURED: speed = injured_speed
		MovementMode.ADS:
			speed = minf(aim_speed, sneak_speed) if Input.is_action_pressed("sneak") else aim_speed
	if injury_component != null and movement_mode != MovementMode.INJURED:
		speed *= injury_component.get_movement_multiplier()
	camera.fov = lerpf(camera.fov, 55.0 if aiming else 75.0, 1.0 - exp(-12.0 * delta))

	if not is_on_floor():
		velocity.y -= gravity * delta
	if controls_active and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity * (injury_component.get_jump_multiplier() if injury_component != null else 1.0)

	var input_direction: Vector2 = Vector2.ZERO
	if controls_active:
		input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction: Vector3 = global_transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	noise_emitter.observe_movement(global_position, velocity, is_on_floor(), movement_mode, aiming)
	_apply_recoil(delta)

	if not Input.is_action_pressed("fire"):
		_block_fire_until_release = false
	var can_fire: bool = controls_active and not _block_fire_until_release
	firearm.set_aiming(aiming)
	firearm.set_trigger(
		can_fire and Input.is_action_pressed("fire"),
		can_fire and Input.is_action_just_pressed("fire")
	)
	reload_input_resolver.set_enabled(controls_active)
	if controls_active and Input.is_action_just_pressed("reload") and not _reload_event_handled:
		reload_input_resolver.press()
	_reload_event_handled = false
	reload_input_resolver.tick(delta)
	if controls_active:
		for slot in range(4):
			if Input.is_action_just_pressed(["weapon_primary","weapon_secondary","weapon_pistol","weapon_knife"][slot]): inventory.equipment.select_weapon_slot(slot)

func _resolve_movement_mode(controls_active: bool, aiming: bool) -> ActorNoiseEmitter.MovementMode:
	if injury_component != null and injury_component.legs_injured:
		return MovementMode.INJURED
	if aiming:
		return MovementMode.ADS
	if controls_active and Input.is_action_pressed("sneak"):
		return MovementMode.SNEAK
	if controls_active and Input.is_action_pressed("sprint"):
		return MovementMode.SPRINT
	return MovementMode.WALK

func _on_shot_fired(pitch: float, yaw: float) -> void:
	_pending_recoil += Vector2(pitch, yaw)

func _apply_recoil(delta: float) -> void:
	var applied: Vector2 = _pending_recoil * (1.0 - exp(-20.0 * delta))
	_pending_recoil -= applied
	head.rotation.x = clampf(head.rotation.x + applied.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	rotate_y(applied.y)

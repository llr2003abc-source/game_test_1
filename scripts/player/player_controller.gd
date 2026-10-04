extends CharacterBody3D

@export var mouse_sensitivity: float = 0.0025
@export var injury_component: BodyInjuryComponent

var normal_speed: float = 5.0
var aim_speed: float = 3.0
var jump_velocity: float = 5.0
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _block_fire_until_release: bool = false
var _pending_recoil: Vector2 = Vector2.ZERO

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var firearm: Firearm = $Head/Camera3D/WeaponRoot

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	firearm.shot_fired.connect(_on_shot_fired)

func _unhandled_input(event: InputEvent) -> void:
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

	if event is InputEventMouseMotion:
		rotate_y(-event.screen_relative.x * mouse_sensitivity)
		head.rotation.x = clampf(
			head.rotation.x - event.screen_relative.y * mouse_sensitivity,
			deg_to_rad(-89.0), deg_to_rad(89.0)
		)

func _physics_process(delta: float) -> void:
	var controls_active: bool = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var aiming: bool = controls_active and Input.is_action_pressed("aim")
	var speed: float = aim_speed if aiming else normal_speed
	if injury_component != null:
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
	_apply_recoil(delta)

	if not Input.is_action_pressed("fire"):
		_block_fire_until_release = false
	var can_fire: bool = controls_active and not _block_fire_until_release
	firearm.set_aiming(aiming)
	firearm.set_trigger(
		can_fire and Input.is_action_pressed("fire"),
		can_fire and Input.is_action_just_pressed("fire")
	)
	if controls_active and Input.is_action_just_pressed("reload"):
		firearm.request_reload()

func _on_shot_fired(pitch: float, yaw: float) -> void:
	_pending_recoil += Vector2(pitch, yaw)

func _apply_recoil(delta: float) -> void:
	var applied: Vector2 = _pending_recoil * (1.0 - exp(-20.0 * delta))
	_pending_recoil -= applied
	head.rotation.x = clampf(head.rotation.x + applied.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	rotate_y(applied.y)

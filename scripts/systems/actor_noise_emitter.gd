class_name ActorNoiseEmitter
extends Node

enum MovementMode { SNEAK, WALK, SPRINT, ADS, INJURED }
const DISTANCE_EPSILON: float = 0.00001
const FOOTSTEP_CATEGORIES: Array[StringName] = [
	AcousticEvent.FOOTSTEP_SNEAK, AcousticEvent.FOOTSTEP_WALK,
	AcousticEvent.FOOTSTEP_SPRINT, AcousticEvent.FOOTSTEP_ADS,
	AcousticEvent.FOOTSTEP_INJURED]

@export var source: Node
@export_range(0.0, 1000.0) var sneak_noise_radius: float = 5.0
@export_range(0.0, 1000.0) var walk_noise_radius: float = 15.0
@export_range(0.0, 1000.0) var sprint_noise_radius: float = 30.0
@export_range(0.0, 1000.0) var injured_noise_radius: float = 15.0
@export_range(0.0, 1000.0) var landing_noise_radius: float = 20.0
@export_range(0.05, 5.0) var sneak_step_distance: float = 0.9
@export_range(0.05, 5.0) var walk_step_distance: float = 1.2
@export_range(0.05, 5.0) var sprint_step_distance: float = 1.4
@export_range(0.05, 5.0) var injured_step_distance: float = 0.9
@export_range(0.0, 5.0) var sneak_stop_flush_min_distance: float = 0.25
@export_range(0.0, 5.0) var walk_stop_flush_min_distance: float = 0.30
@export_range(0.0, 5.0) var sprint_stop_flush_min_distance: float = 0.40
@export_range(0.0, 5.0) var injured_stop_flush_min_distance: float = 0.25
@export_range(0.001, 1.0) var movement_velocity_threshold: float = 0.05

var previous_position: Vector3
var distance_accumulator: float = 0.0
var _initialized: bool = false
var _was_grounded: bool = false
var _was_moving: bool = false
var _noise_mode: MovementMode = MovementMode.WALK

func reset_position(position: Vector3, grounded: bool, mode: MovementMode, aiming: bool = false) -> void:
	previous_position = position
	distance_accumulator = 0.0
	_was_grounded = grounded
	_was_moving = false
	_noise_mode = _effective_noise_mode(mode, aiming)
	_initialized = true

func observe_movement(position: Vector3, velocity: Vector3, grounded: bool, mode: MovementMode, aiming: bool = false) -> void:
	if not _initialized:
		reset_position(position, grounded, mode, aiming)
		return
	var displacement: Vector3 = position - previous_position
	var horizontal_distance: float = Vector2(displacement.x, displacement.z).length()
	previous_position = position
	var next_mode: MovementMode = _effective_noise_mode(mode, aiming)
	if not grounded:
		reset_position(position, false, mode, aiming)
		return
	if not _was_grounded:
		get_node("/root/GameplayAcoustics").emit_sound(position, landing_noise_radius, AcousticEvent.FOOTSTEP_LAND, source)
		reset_position(position, true, mode, aiming)
		return
	if next_mode != _noise_mode:
		_flush_partial(position)
		_noise_mode = next_mode
	var moving: bool = Vector2(velocity.x, velocity.z).length_squared() > movement_velocity_threshold * movement_velocity_threshold
	if moving:
		distance_accumulator += horizontal_distance
		var step_distance: float = _step_distance(_noise_mode)
		while distance_accumulator + DISTANCE_EPSILON >= step_distance:
			_emit_step(position)
			distance_accumulator = maxf(0.0, distance_accumulator - step_distance)
	elif _was_moving:
		_flush_partial(position)
	_was_moving = moving

func _effective_noise_mode(mode: MovementMode, aiming: bool) -> MovementMode:
	if mode == MovementMode.INJURED:
		return MovementMode.INJURED
	return MovementMode.ADS if aiming else mode

func _flush_partial(position: Vector3) -> void:
	if distance_accumulator > 0.0 and distance_accumulator + DISTANCE_EPSILON >= _flush_distance(_noise_mode):
		_emit_step(position)
	distance_accumulator = 0.0

func _emit_step(position: Vector3) -> void:
	get_node("/root/GameplayAcoustics").emit_sound(position, _radius(_noise_mode), FOOTSTEP_CATEGORIES[_noise_mode], source)

func _radius(mode: MovementMode) -> float:
	match mode:
		MovementMode.SNEAK, MovementMode.ADS: return sneak_noise_radius
		MovementMode.SPRINT: return sprint_noise_radius
		MovementMode.INJURED: return injured_noise_radius
	return walk_noise_radius

func _step_distance(mode: MovementMode) -> float:
	match mode:
		MovementMode.SNEAK, MovementMode.ADS: return sneak_step_distance
		MovementMode.SPRINT: return sprint_step_distance
		MovementMode.INJURED: return injured_step_distance
	return walk_step_distance

func _flush_distance(mode: MovementMode) -> float:
	match mode:
		MovementMode.SNEAK, MovementMode.ADS: return sneak_stop_flush_min_distance
		MovementMode.SPRINT: return sprint_stop_flush_min_distance
		MovementMode.INJURED: return injured_stop_flush_min_distance
	return walk_stop_flush_min_distance

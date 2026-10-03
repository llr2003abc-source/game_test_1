class_name Firearm
extends Node3D

signal ammo_changed(ammo: int, capacity: int, reloading: bool)
signal shot_fired(pitch: float, yaw: float)

enum FireMode { SEMI, AUTO }

const HIT_MARKER_SCENE: PackedScene = preload("res://scenes/weapons/hit_marker.tscn")
const MUZZLE_FLASH_DURATION: float = 0.05

@export var weapon_data: WeaponData
@export var fire_mode: FireMode = FireMode.AUTO

var current_ammo: int = 0
var is_reloading: bool = false
var is_aiming: bool = false
var _trigger_held: bool = false
var _trigger_pressed: bool = false
var _shot_cooldown: float = 0.0
var _reload_remaining: float = 0.0
var _flash_remaining: float = 0.0
var _random := RandomNumberGenerator.new()

@onready var camera: Camera3D = get_parent()
@onready var player: CharacterBody3D = get_node("../../..")
@onready var muzzle_flash: OmniLight3D = $Muzzle/MuzzleFlash

func _ready() -> void:
	# Run after PlayerController has supplied this physics tick's inputs.
	process_physics_priority = 1
	current_ammo = weapon_data.magazine_size
	_random.randomize()
	muzzle_flash.visible = false
	_notify_ammo()

func set_trigger(held: bool, just_pressed: bool = false) -> void:
	_trigger_held = held
	_trigger_pressed = _trigger_pressed or just_pressed

func set_aiming(aiming: bool) -> void:
	is_aiming = aiming

func request_reload() -> void:
	if is_reloading or current_ammo == weapon_data.magazine_size:
		return
	is_reloading = true
	_reload_remaining = weapon_data.reload_time
	_trigger_pressed = false
	_notify_ammo()
	print("Reloading...")

func _physics_process(delta: float) -> void:
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	muzzle_flash.visible = _flash_remaining > 0.0
	_shot_cooldown -= delta

	if is_reloading:
		_shot_cooldown = maxf(0.0, _shot_cooldown)
		_reload_remaining = maxf(0.0, _reload_remaining - delta)
		_trigger_pressed = false
		if _reload_remaining == 0.0:
			is_reloading = false
			current_ammo = weapon_data.magazine_size
			_notify_ammo()
			print("Reload complete")
		return

	var wants_shot: bool = _trigger_pressed if fire_mode == FireMode.SEMI else (_trigger_held or _trigger_pressed)
	if current_ammo > 0 and wants_shot and _shot_cooldown <= 0.0:
		var interval: float = 60.0 / weapon_data.rounds_per_minute
		if fire_mode == FireMode.SEMI:
			_fire_shot()
			_shot_cooldown = interval
		else:
			# Preserve elapsed-time remainder, including on long physics ticks.
			while _shot_cooldown <= 0.0 and current_ammo > 0:
				_fire_shot()
				_shot_cooldown += interval
				if not _trigger_held:
					break

	if not _trigger_held or fire_mode == FireMode.SEMI or current_ammo == 0:
		# Idle/reload/empty time must never accumulate a future burst.
		_shot_cooldown = maxf(0.0, _shot_cooldown)
	_trigger_pressed = false

func _get_shot_direction() -> Vector3:
	var spread: float = weapon_data.ads_spread_degrees if is_aiming else weapon_data.hip_spread_degrees
	var pitch: float = deg_to_rad(_random.randf_range(-spread, spread))
	var yaw: float = deg_to_rad(_random.randf_range(-spread, spread))
	var local_direction: Vector3 = Vector3.FORWARD.rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	return (camera.global_transform.basis * local_direction).normalized()

func _fire_shot() -> void:
	current_ammo -= 1
	_notify_ammo()
	print("Ammo: %d / %d" % [current_ammo, weapon_data.magazine_size])

	var origin: Vector3 = camera.global_position
	var direction: Vector3 = _get_shot_direction()
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + direction * weapon_data.range, 1, [player.get_rid()]
	)
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_position: Vector3 = hit["position"]
		var hit_normal: Vector3 = hit["normal"]
		var collider: Node3D = hit["collider"]
		var marker: MeshInstance3D = HIT_MARKER_SCENE.instantiate()
		get_tree().current_scene.add_child(marker)
		marker.global_position = hit_position + hit_normal * 0.01
		print("Hit %s at %s" % [collider.name, hit_position])

	_flash_remaining = MUZZLE_FLASH_DURATION
	muzzle_flash.visible = true
	shot_fired.emit(
		deg_to_rad(weapon_data.recoil_pitch),
		deg_to_rad(_random.randf_range(-weapon_data.recoil_yaw, weapon_data.recoil_yaw))
	)

func _notify_ammo() -> void:
	ammo_changed.emit(current_ammo, weapon_data.magazine_size, is_reloading)

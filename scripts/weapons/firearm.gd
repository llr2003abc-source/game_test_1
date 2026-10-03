class_name Firearm
extends Node3D

signal weapon_state_changed(magazine_rounds: int, chamber_loaded: bool, spare_magazine_count: int, state: State)
signal shot_fired(pitch: float, yaw: float)

enum State { READY, RELOADING, EMPTY }
const FireMode = WeaponData.FireMode

const HIT_MARKER_SCENE: PackedScene = preload("res://scenes/weapons/hit_marker.tscn")
const MUZZLE_FLASH_DURATION: float = 0.05
# Physics layers 1 (World) and 3 (Hurtbox); TargetBody only blocks movement.
const HITSCAN_COLLISION_MASK: int = 1 | 4

@export var weapon_data: WeaponData
var fire_mode: WeaponData.FireMode = WeaponData.FireMode.AUTO
var state: State = State.EMPTY
var chambered_round: AmmoData = null
var loaded_magazine: MagazineInstance
var spare_magazines: Array[MagazineInstance] = []
var is_aiming: bool = false
var _trigger_held: bool = false
var _trigger_pressed: bool = false
var _shot_cooldown: float = 0.0
var _reload_remaining: float = 0.0
var _reload_magazine: MagazineInstance
var _flash_remaining: float = 0.0
var _random := RandomNumberGenerator.new()

@onready var camera: Camera3D = get_parent()
@onready var player: CharacterBody3D = get_node("../../..")
@onready var muzzle_flash: OmniLight3D = $Muzzle/MuzzleFlash

func _ready() -> void:
	# Run after PlayerController has supplied this physics tick's inputs.
	process_physics_priority = 1
	fire_mode = weapon_data.fire_mode
	loaded_magazine = MagazineInstance.new()
	loaded_magazine.initialize_full(weapon_data.magazine_data)
	for i in range(2):
		var spare := MagazineInstance.new()
		spare.initialize_full(weapon_data.magazine_data)
		spare_magazines.append(spare)
	_random.randomize()
	muzzle_flash.visible = false
	chamber_next_round()

func chamber_next_round() -> bool:
	if state == State.RELOADING or chambered_round != null:
		return false
	if loaded_magazine == null or loaded_magazine.is_empty():
		state = State.EMPTY
		publish_weapon_state()
		return false
	chambered_round = loaded_magazine.pop_round()
	state = State.READY
	publish_weapon_state()
	return true

func select_reload_magazine() -> MagazineInstance:
	var selected: MagazineInstance = null
	for magazine in spare_magazines:
		if not magazine.is_empty() and (selected == null or magazine.get_round_count() > selected.get_round_count()):
			selected = magazine
	return selected

func set_trigger(held: bool, just_pressed: bool = false) -> void:
	_trigger_held = held
	_trigger_pressed = _trigger_pressed or just_pressed

func set_aiming(aiming: bool) -> void:
	is_aiming = aiming

func request_reload() -> void:
	if state == State.RELOADING:
		return
	if chambered_round != null and loaded_magazine != null and loaded_magazine.is_full():
		return
	_reload_magazine = select_reload_magazine()
	if _reload_magazine == null:
		return
	state = State.RELOADING
	_reload_remaining = weapon_data.reload_time
	_trigger_pressed = false
	publish_weapon_state()
	print("Reloading...")

func _physics_process(delta: float) -> void:
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	muzzle_flash.visible = _flash_remaining > 0.0
	_shot_cooldown -= delta

	if state == State.RELOADING:
		_shot_cooldown = maxf(0.0, _shot_cooldown)
		_reload_remaining = maxf(0.0, _reload_remaining - delta)
		_trigger_pressed = false
		if _reload_remaining == 0.0:
			_complete_reload()
			print("Reload complete")
		return

	var wants_shot: bool = _trigger_pressed if fire_mode == FireMode.SEMI else (_trigger_held or _trigger_pressed)
	if state == State.READY and chambered_round != null and wants_shot and _shot_cooldown <= 0.0:
		var interval: float = 60.0 / weapon_data.rounds_per_minute
		if fire_mode == FireMode.SEMI:
			_fire_shot()
			_shot_cooldown = interval
		else:
			# Preserve elapsed-time remainder, including on long physics ticks.
			while _shot_cooldown <= 0.0 and chambered_round != null:
				_fire_shot()
				_shot_cooldown += interval
				if not _trigger_held:
					break

	if not _trigger_held or fire_mode == FireMode.SEMI or chambered_round == null:
		# Idle/reload/empty time must never accumulate a future burst.
		_shot_cooldown = maxf(0.0, _shot_cooldown)
	_trigger_pressed = false

func _complete_reload() -> void:
	var previous_magazine: MagazineInstance = loaded_magazine
	spare_magazines.erase(_reload_magazine)
	loaded_magazine = _reload_magazine
	_reload_magazine = null
	if previous_magazine != null:
		spare_magazines.append(previous_magazine)
	state = State.READY if chambered_round != null else State.EMPTY
	if chambered_round == null:
		chamber_next_round()
	else:
		publish_weapon_state()

func _get_shot_direction() -> Vector3:
	var spread: float = weapon_data.ads_spread_degrees if is_aiming else weapon_data.hip_spread_degrees
	var pitch: float = deg_to_rad(_random.randf_range(-spread, spread))
	var yaw: float = deg_to_rad(_random.randf_range(-spread, spread))
	var local_direction: Vector3 = Vector3.FORWARD.rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	return (camera.global_transform.basis * local_direction).normalized()

func _fire_shot() -> void:
	if state != State.READY or chambered_round == null:
		return
	var fired_round: AmmoData = chambered_round
	chambered_round = null

	var origin: Vector3 = camera.global_position
	var direction: Vector3 = _get_shot_direction()
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + direction * weapon_data.max_range, HITSCAN_COLLISION_MASK, [player.get_rid()]
	)
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_position: Vector3 = hit["position"]
		var hit_normal: Vector3 = hit["normal"]
		var collider: Node3D = hit["collider"]
		var marker: MeshInstance3D = HIT_MARKER_SCENE.instantiate()
		get_tree().current_scene.add_child(marker)
		marker.global_position = hit_position + hit_normal * 0.01
		print("Hit %s at %s" % [collider.name, hit_position])
		if collider.has_method("receive_hit"):
			var damage_info := DamageInfo.new()
			damage_info.damage = fired_round.damage
			damage_info.hit_position = hit_position
			damage_info.hit_normal = hit_normal
			damage_info.hit_direction = direction
			damage_info.source = player
			damage_info.weapon = self
			damage_info.ammo_data = fired_round
			collider.receive_hit(damage_info)

	_flash_remaining = MUZZLE_FLASH_DURATION
	muzzle_flash.visible = true
	shot_fired.emit(
		deg_to_rad(weapon_data.recoil_pitch),
		deg_to_rad(_random.randf_range(-weapon_data.recoil_yaw, weapon_data.recoil_yaw))
	)
	chamber_next_round()
	print("MAG %d | CHAMBER %d | SPARE MAGS %d" % [
		loaded_magazine.get_round_count() if loaded_magazine != null else 0,
		1 if chambered_round != null else 0, spare_magazines.size()
	])

func publish_weapon_state() -> void:
	weapon_state_changed.emit(
		loaded_magazine.get_round_count() if loaded_magazine != null else 0,
		chambered_round != null, spare_magazines.size(), state
	)

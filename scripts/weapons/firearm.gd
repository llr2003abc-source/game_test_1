class_name Firearm
extends Node3D

signal weapon_state_changed(magazine_rounds: int, chamber_loaded: bool, spare_magazine_count: int, state: WeaponRuntime.State)
signal shot_fired(pitch: float, yaw: float)

const State = WeaponRuntime.State
const FireMode = WeaponData.FireMode

const HIT_MARKER_SCENE: PackedScene = preload("res://scenes/weapons/hit_marker.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/weapons/ballistic_projectile.tscn")
const MUZZLE_FLASH_DURATION: float = 0.05
# Physics layers 1 (World) and 3 (Hurtbox); TargetBody only blocks movement.
const HITSCAN_COLLISION_MASK: int = 1 | 4

@export var weapon_data: WeaponData:
	get:
		return weapon_runtime.weapon_data if weapon_runtime != null else weapon_data
	set(value):
		weapon_data = value
		if weapon_runtime != null:
			weapon_runtime.weapon_data = value
@export var injury_component: BodyInjuryComponent
@export var inventory_managed: bool = false
var reload_coordinator: ReloadCoordinator
var weapon_runtime: WeaponRuntime
var fire_mode: WeaponData.FireMode:
	get:
		return weapon_runtime.selected_fire_mode if weapon_runtime != null else FireMode.AUTO
	set(value):
		if weapon_runtime != null:
			weapon_runtime.selected_fire_mode = value
var state: WeaponRuntime.State:
	get:
		return weapon_runtime.state if weapon_runtime != null else State.EMPTY
	set(value):
		if weapon_runtime != null:
			weapon_runtime.state = value
var chambered_round: AmmoData:
	get:
		return weapon_runtime.chambered_round if weapon_runtime != null else null
	set(value):
		if weapon_runtime != null:
			weapon_runtime.chambered_round = value
var loaded_magazine: MagazineInstance:
	get:
		return weapon_runtime.loaded_magazine if weapon_runtime != null else null
	set(value):
		if weapon_runtime != null:
			weapon_runtime.loaded_magazine = value
# LEGACY TEST / PRE-INVENTORY PROVIDER. Phase 9 will replace this source.
var spare_magazines: Array[MagazineInstance] = []
var is_aiming: bool = false
var _trigger_held: bool = false
var _trigger_pressed: bool = false
var _flash_remaining: float = 0.0
var _random := RandomNumberGenerator.new()

@onready var camera: Camera3D = get_parent()
@onready var player: CharacterBody3D = get_node("../../..")
@onready var muzzle_flash: OmniLight3D = $Muzzle/MuzzleFlash
@onready var muzzle: Marker3D = $Muzzle

func _ready() -> void:
	# Run after PlayerController has supplied this physics tick's inputs.
	process_physics_priority = 1
	_random.randomize()
	muzzle_flash.visible = false
	if weapon_runtime == null and not inventory_managed:
		var magazine := MagazineInstance.new()
		magazine.initialize_full(weapon_data.magazine_data)
		var runtime := WeaponRuntime.new()
		runtime.initialize(weapon_data, magazine)
		for i in range(2):
			var spare := MagazineInstance.new()
			spare.initialize_full(weapon_data.magazine_data)
			spare_magazines.append(spare)
		bind_runtime(runtime)
		runtime.chamber_next_round()
	elif weapon_runtime != null:
		bind_runtime(weapon_runtime)

func can_use_weapon() -> bool:
	if weapon_runtime == null: return false
	if not inventory_managed: return true
	if reload_coordinator == null: return false
	var active: InventoryItemInstance = reload_coordinator.inventory.equipment.get_active_item()
	return active != null and active.runtime_state == weapon_runtime

func use_legacy_test_provider() -> void:
	# Explicit Phase 4/8B fixture only. Main never enables this provider.
	if not inventory_managed: return
	spare_magazines.clear()
	if reload_coordinator != null:
		var rig: RigContainerRuntime = reload_coordinator.inventory.get_equipped_rig()
		if rig != null:
			for grid in rig.grids:
				for placement in grid.placements:
					if placement.item.runtime_state is MagazineInstance: spare_magazines.append(placement.item.runtime_state)
	inventory_managed = false
	reload_coordinator = null
	publish_weapon_state()

func bind_runtime(runtime: WeaponRuntime) -> void:
	if weapon_runtime != null:
		if weapon_runtime.state_changed.is_connected(publish_weapon_state):
			weapon_runtime.state_changed.disconnect(publish_weapon_state)
		if weapon_runtime.reload_finished.is_connected(_on_reload_finished):
			weapon_runtime.reload_finished.disconnect(_on_reload_finished)
	weapon_runtime = runtime
	if runtime != null:
		weapon_data = runtime.weapon_data
		runtime.state_changed.connect(publish_weapon_state)
		runtime.reload_finished.connect(_on_reload_finished)
	_trigger_held = false
	_trigger_pressed = false
	is_aiming = false
	_flash_remaining = 0.0
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = false
	publish_weapon_state()

func unbind_runtime() -> WeaponRuntime:
	var previous: WeaponRuntime = weapon_runtime
	bind_runtime(null)
	return previous

func _exit_tree() -> void:
	unbind_runtime()

func chamber_next_round() -> bool:
	return weapon_runtime.chamber_next_round() if weapon_runtime != null else false

func select_reload_magazine() -> MagazineInstance:
	var selected: MagazineInstance = null
	for magazine in spare_magazines:
		if not magazine.is_empty() and (selected == null or magazine.get_round_count() > selected.get_round_count()):
			selected = magazine
	return selected

func set_trigger(held: bool, just_pressed: bool = false) -> void:
	_trigger_held = held and can_use_weapon()
	_trigger_pressed = (_trigger_pressed or just_pressed) and can_use_weapon()

func set_aiming(aiming: bool) -> void:
	is_aiming = aiming and can_use_weapon()

func request_reload(type: WeaponRuntime.ReloadType = WeaponRuntime.ReloadType.TACTICAL) -> void:
	if not can_use_weapon():
		return
	if inventory_managed:
		if reload_coordinator.request_reload(type):
			_trigger_pressed = false
			print("Reloading...")
		return
	var replacement: MagazineInstance = select_reload_magazine()
	var duration: float = weapon_data.reload_time * (injury_component.get_reload_multiplier() if injury_component != null else 1.0)
	if not weapon_runtime.begin_reload(replacement, duration):
		return
	_trigger_pressed = false
	print("Reloading...")

func _physics_process(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	_flash_remaining = maxf(0.0, _flash_remaining - delta)
	muzzle_flash.visible = _flash_remaining > 0.0
	if weapon_runtime == null:
		return
	var wants_shot: bool = _trigger_pressed if fire_mode == FireMode.SEMI else (_trigger_held or _trigger_pressed)
	var was_reloading: bool = state == State.RELOADING
	weapon_runtime.tick(delta, wants_shot and fire_mode == FireMode.AUTO and not was_reloading)

	if was_reloading:
		_trigger_pressed = false
		return

	if state == State.READY and wants_shot:
		while _fire_shot():
			if fire_mode == FireMode.SEMI or not _trigger_held:
				break
	_trigger_pressed = false

func _on_reload_finished(result: WeaponReloadResult) -> void:
	if inventory_managed:
		print("Reload complete")
		return
	spare_magazines.erase(result.new_magazine)
	if result.old_magazine != null:
		spare_magazines.append(result.old_magazine)
	print("Reload complete")

func _get_shot_direction() -> Vector3:
	var spread: float = weapon_data.ads_spread_degrees if is_aiming else weapon_data.hip_spread_degrees
	if injury_component != null:
		spread *= injury_component.get_spread_multiplier()
	var pitch: float = deg_to_rad(_random.randf_range(-spread, spread))
	var yaw: float = deg_to_rad(_random.randf_range(-spread, spread))
	var local_direction: Vector3 = Vector3.FORWARD.rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	return (camera.global_transform.basis * local_direction).normalized()

func get_camera_aim_point(direction: Vector3 = Vector3.ZERO) -> Vector3:
	if direction == Vector3.ZERO:
		direction = camera.global_basis * Vector3.FORWARD
	var origin: Vector3 = camera.global_position
	var endpoint: Vector3 = origin + direction.normalized() * weapon_data.max_range
	var query := PhysicsRayQueryParameters3D.create(origin, endpoint, HITSCAN_COLLISION_MASK, [player.get_rid()])
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return endpoint if hit.is_empty() else hit["position"]

func _fire_shot() -> bool:
	if not can_use_weapon():
		return false
	var result: WeaponFireResult = weapon_runtime.try_fire()
	if not result.success:
		return false
	var fired_round: AmmoData = result.fired_round

	var direction: Vector3 = _get_shot_direction()
	if weapon_data.fire_model == WeaponData.FireModel.PROJECTILE:
		var aim_point: Vector3 = get_camera_aim_point(direction)
		var projectile: BallisticProjectile = PROJECTILE_SCENE.instantiate()
		get_tree().current_scene.add_child(projectile)
		projectile.impacted.connect(process_impact)
		projectile.initialize(muzzle.global_position, aim_point - muzzle.global_position, fired_round, player, self, camera)
	else:
		_fire_hitscan(direction, fired_round)

	get_node("/root/GameplayAcoustics").emit_sound(muzzle.global_position, weapon_data.gunshot_hearing_radius, AcousticEvent.GUNSHOT, player)
	_flash_remaining = MUZZLE_FLASH_DURATION
	muzzle_flash.visible = true
	var recoil_multiplier: float = injury_component.get_recoil_multiplier() if injury_component != null else 1.0
	shot_fired.emit(
		deg_to_rad(weapon_data.recoil_pitch) * recoil_multiplier,
		deg_to_rad(_random.randf_range(-weapon_data.recoil_yaw, weapon_data.recoil_yaw)) * recoil_multiplier
	)
	print("MAG %d | CHAMBER %d | SPARE MAGS %d" % [
		loaded_magazine.get_round_count() if loaded_magazine != null else 0,
		1 if chambered_round != null else 0, reload_coordinator.get_available_magazine_count() if inventory_managed and reload_coordinator != null else spare_magazines.size()
	])
	return true

func _fire_hitscan(direction: Vector3, fired_round: AmmoData) -> void:
	var origin: Vector3 = camera.global_position
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + direction * weapon_data.max_range, HITSCAN_COLLISION_MASK, [player.get_rid()]
	)
	query.collide_with_areas = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		process_impact(hit["collider"], hit["position"], hit["normal"], direction, fired_round)

func process_impact(collider: Node3D, hit_position: Vector3, hit_normal: Vector3, shot_direction: Vector3, fired_round: AmmoData) -> void:
	var marker: MeshInstance3D = HIT_MARKER_SCENE.instantiate()
	get_tree().current_scene.add_child(marker)
	marker.global_position = hit_position + hit_normal * 0.01
	print("Hit %s at %s" % [collider.name, hit_position])
	if collider.has_method("receive_hit"):
		var damage_info := DamageInfo.new()
		damage_info.base_flesh_damage = fired_round.flesh_damage
		damage_info.bullet_level = fired_round.bullet_level
		damage_info.hit_position = hit_position
		damage_info.hit_normal = hit_normal
		damage_info.hit_direction = shot_direction
		damage_info.source = player
		damage_info.weapon = self
		damage_info.ammo_data = fired_round
		collider.receive_hit(damage_info)

func publish_weapon_state() -> void:
	weapon_state_changed.emit(
		loaded_magazine.get_round_count() if loaded_magazine != null else 0,
		chambered_round != null, reload_coordinator.get_available_magazine_count() if inventory_managed and reload_coordinator != null else spare_magazines.size(), state
	)

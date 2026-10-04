class_name BallisticProjectile
extends Node3D

signal impacted(collider: Node3D, hit_position: Vector3, hit_normal: Vector3, shot_direction: Vector3, round_data: AmmoData)

@export var debug_visible: bool = true

var velocity: Vector3 = Vector3.ZERO
var ammo_data: AmmoData
var source: Node
var weapon: Node
var remaining_lifetime: float = 0.0
var collision_mask: int = 1 | 4
var previous_position: Vector3 = Vector3.ZERO
var flight_time: float = 0.0
var traveled_distance: float = 0.0
var _gravity_vector: Vector3 = Vector3.ZERO
var _excluded_rids: Array[RID] = []
var _launch_path_start: Vector3 = Vector3.ZERO
var _launch_checked: bool = false
var _finished: bool = false

func _ready() -> void:
	$DebugMesh.visible = debug_visible
	set_physics_process(false)

func initialize(start_position: Vector3, initial_direction: Vector3, round_data: AmmoData, shot_source: Node, shot_weapon: Node, barrel_start: Node3D = null) -> void:
	global_position = start_position
	previous_position = start_position
	ammo_data = round_data
	source = shot_source
	weapon = shot_weapon
	velocity = initial_direction.normalized() * ammo_data.muzzle_velocity
	remaining_lifetime = ammo_data.max_flight_time
	_gravity_vector = ProjectSettings.get_setting("physics/3d/default_gravity_vector") * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	if source is CollisionObject3D:
		_excluded_rids.append(source.get_rid())
	_launch_path_start = start_position if barrel_start == null else barrel_start.global_position
	set_physics_process(true)
	print("Projectile fired: %s | %.1f m/s | %s" % [ammo_data.ammo_name, velocity.length(), global_position])

func _physics_process(delta: float) -> void:
	if _finished:
		return
	if remaining_lifetime <= 0.0:
		_finish()
		return

	# A clipped muzzle must not spawn a shot beyond an intervening wall.
	if not _launch_checked:
		_launch_checked = true
		if not _launch_path_start.is_equal_approx(global_position):
			var launch_hit: Dictionary = _segment_hit(_launch_path_start, global_position)
			if not launch_hit.is_empty():
				_impact(launch_hit, 0.0)
				return

	var step: float = minf(delta, remaining_lifetime)
	previous_position = global_position
	velocity += _gravity_vector * ammo_data.gravity_scale * step
	var next_position: Vector3 = previous_position + velocity * step
	var hit: Dictionary = _segment_hit(previous_position, next_position)
	if not hit.is_empty():
		var hit_position: Vector3 = hit["position"]
		var segment_length: float = previous_position.distance_to(next_position)
		var traveled: float = previous_position.distance_to(hit_position)
		traveled_distance += traveled
		_impact(hit, step * clampf(traveled / segment_length, 0.0, 1.0))
		return

	traveled_distance += previous_position.distance_to(next_position)
	global_position = next_position
	flight_time += step
	remaining_lifetime = maxf(0.0, remaining_lifetime - step)
	if remaining_lifetime == 0.0:
		_finish()

func _segment_hit(start: Vector3, end: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start, end, collision_mask, _excluded_rids)
	query.collide_with_areas = true
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func _impact(hit: Dictionary, elapsed: float) -> void:
	global_position = hit["position"]
	flight_time += elapsed
	remaining_lifetime = maxf(0.0, remaining_lifetime - elapsed)
	_finished = true
	set_physics_process(false)
	var collider: Node3D = hit["collider"]
	print("Projectile impact: %s | %.6f s | %.3f m | %s" % [collider.name, flight_time, traveled_distance, global_position])
	impacted.emit(collider, global_position, hit["normal"], velocity.normalized(), ammo_data)
	queue_free()

func _finish() -> void:
	_finished = true
	set_physics_process(false)
	queue_free()

extends SceneTree

var failures: int = 0
var projectile_scene: PackedScene

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func body(level: Node, body_name: String, position: Vector3, size: Vector3) -> StaticBody3D:
	var result := StaticBody3D.new()
	result.name = body_name
	result.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	result.add_child(collision)
	level.add_child(result)
	return result

func launch(level: Node, position: Vector3, direction: Vector3, ammo: Resource, source: Node = null, weapon: Node = null) -> Variant:
	var projectile: Variant = projectile_scene.instantiate()
	level.add_child(projectile)
	projectile.initialize(position, direction, ammo, source, weapon)
	projectile.set_physics_process(false)
	return projectile

func projectiles(level: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in level.get_children():
		if child.scene_file_path == "res://scenes/weapons/ballistic_projectile.tscn" and not child.is_queued_for_deletion():
			result.append(child)
	return result

func marker_count(level: Node) -> int:
	var count: int = 0
	for child in level.get_children():
		if child.scene_file_path == "res://scenes/weapons/hit_marker.tscn" and not child.is_queued_for_deletion():
			count += 1
	return count

func simulate(projectile: Node, delta: float) -> void:
	for i in range(1000):
		if projectile.is_queued_for_deletion():
			return
		projectile._physics_process(delta)
	check(false, "simulation terminates within lifetime")

func fire(firearm: Node, level: Node) -> Variant:
	firearm.set_trigger(false, false)
	firearm._physics_process(0.2)
	firearm.set_trigger(true, true)
	firearm._physics_process(0.001)
	var bullets: Array[Node] = projectiles(level)
	if bullets.is_empty():
		check(false, "Firearm spawns a projectile")
		return null
	var projectile: Node = bullets.back()
	projectile.set_physics_process(false)
	return projectile

func _run() -> void:
	for path in ["res://scripts/weapons/ballistic_projectile.gd", "res://scenes/weapons/ballistic_projectile.tscn", "res://data/ammo/test_slow_round.tres"]:
		check(FileAccess.file_exists(path), "required ballistic file: " + path)
	if failures > 0:
		print("BALLISTIC_RESULT failures=%d" % failures)
		quit(1)
		return
	projectile_scene = load("res://scenes/weapons/ballistic_projectile.tscn")
	var ammo: Variant = load("res://data/ammo/test_round.tres")
	var slow: Variant = load("res://data/ammo/test_slow_round.tres")
	check(ammo.muzzle_velocity == 800.0 and ammo.flesh_damage == 30.0 and ammo.gravity_scale == 1.0, "normal round remains 800 m/s, damage 30, gravity scale 1")
	check(slow.muzzle_velocity == 100.0 and slow.flesh_damage == 30.0 and slow.gravity_scale == 1.0, "slow test round is 100 m/s without changing normal round")
	var level: Node3D = load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player: Variant = level.get_node("Player")
	var firearm: Variant = player.get_node("Head/Camera3D/WeaponRoot")
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var muzzle: Node3D = firearm.get_node("Muzzle")
	player.set_physics_process(false)
	firearm.set_physics_process(false)
	firearm.weapon_data = firearm.weapon_data.duplicate()
	check(firearm.weapon_data.fire_model == 1, "test rifle defaults to PROJECTILE")
	firearm.weapon_data.hip_spread_degrees = 0.0
	firearm.weapon_data.ads_spread_degrees = 0.0
	firearm.weapon_data.recoil_pitch = 0.0
	firearm.weapon_data.recoil_yaw = 0.0
	firearm.fire_mode = 0
	await frames(3)

	var start := Vector3(1000, 20, 0)
	var projectile: Variant = launch(level, start, Vector3(0, 0, -4), ammo, player, firearm)
	check(projectile.global_position == start and projectile.previous_position == start, "initialize sets start and previous positions")
	check(projectile.velocity.is_equal_approx(Vector3.FORWARD * 800.0), "initial direction is normalized and scaled by muzzle velocity")
	check(projectile.ammo_data == ammo and projectile.source == player and projectile.weapon == firearm, "initialize retains actual ammo, source and weapon")
	check(projectile.remaining_lifetime == ammo.max_flight_time and projectile.collision_mask == 5, "lifetime and World + Hurtbox collision mask initialize")
	check(projectile.get_node("DebugMesh") is MeshInstance3D and projectile.get_child_count() == 1, "debug sphere adds no physical collider")
	var gravity: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector") * float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	var step: float = 0.02
	var expected_velocity: Vector3 = Vector3.FORWARD * 800.0 + gravity * step
	projectile._physics_process(step)
	check(projectile.velocity.is_equal_approx(expected_velocity), "gravity changes velocity from project settings")
	check(projectile.global_position.is_equal_approx(start + expected_velocity * step), "semi-implicit Euler integrates position using updated velocity")
	check(projectile.previous_position == start and is_equal_approx(projectile.flight_time, step), "previous position and elapsed flight time advance")
	projectile.queue_free()

	var short_ammo: Variant = ammo.duplicate()
	short_ammo.max_flight_time = 0.05
	short_ammo.gravity_scale = 0.0
	projectile = launch(level, start, Vector3.FORWARD, short_ammo)
	projectile._physics_process(0.2)
	check(projectile.is_queued_for_deletion() and is_zero_approx(projectile.remaining_lifetime), "lifetime expiry queues deletion")
	check(is_equal_approx(projectile.flight_time, 0.05) and projectile.global_position.distance_to(start + Vector3.FORWARD * 40.0) < 0.001, "last tick is capped to remaining lifetime")
	var hidden: Variant = projectile_scene.instantiate()
	hidden.debug_visible = false
	level.add_child(hidden)
	check(not hidden.get_node("DebugMesh").visible, "debug visualization can be disabled")
	hidden.queue_free()
	await frames(1)

	var configured_ammo: Variant = ammo.duplicate()
	configured_ammo.gravity_scale = 0.5
	var original_gravity_direction: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	var original_gravity_strength: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	ProjectSettings.set_setting("physics/3d/default_gravity_vector", Vector3.RIGHT)
	ProjectSettings.set_setting("physics/3d/default_gravity", 12.0)
	projectile = launch(level, Vector3(2500, 20, 0), Vector3.FORWARD, configured_ammo)
	ProjectSettings.set_setting("physics/3d/default_gravity_vector", original_gravity_direction)
	ProjectSettings.set_setting("physics/3d/default_gravity", original_gravity_strength)
	projectile._physics_process(0.2)
	check(projectile.velocity.is_equal_approx(Vector3(1.2, 0, -800)), "gravity respects configured direction, magnitude and ammo scale")
	projectile.queue_free()
	await frames(1)

	var metrics: Array[Dictionary] = []
	var lane: int = 0
	for round_data in [ammo, slow]:
		for distance in [10.0, 50.0, 100.0]:
			for hz in [30, 60, 120]:
				lane += 1
				start = Vector3(1000 + lane * 20, 20, 0)
				var thin_wall: StaticBody3D = body(level, "ThinWall%d" % lane, start + Vector3(0, 0, -distance), Vector3(10, 60, 0.02))
				await frames(2)
				projectile = launch(level, start, Vector3.FORWARD, round_data)
				var observed: Dictionary = {"hits": 0, "collider": null, "direction": Vector3.ZERO}
				projectile.impacted.connect(func(collider: Node3D, _position: Vector3, _normal: Vector3, direction: Vector3, _round: Resource) -> void:
					observed.hits += 1
					observed.collider = collider
					observed.direction = direction)
				simulate(projectile, 1.0 / float(hz))
				var drop: float = start.y - projectile.global_position.y
				var expected_time: float = (distance - 0.01) / round_data.muzzle_velocity
				check(observed.hits == 1 and observed.collider == thin_wall, "segment hits 0.02 m wall at %.0f m, %.0f m/s, %d Hz" % [distance, round_data.muzzle_velocity, hz])
				check(absf(projectile.flight_time - expected_time) < 0.001, "impact flight time follows distance / muzzle velocity")
				check(drop > 0.0 and projectile.global_position.z >= thin_wall.position.z, "impact drops below no-gravity line and stops at front surface")
				check(observed.direction.is_equal_approx(projectile.velocity.normalized()), "impact direction uses current velocity including gravity")
				projectile._physics_process(1.0)
				check(observed.hits == 1, "impact stops simulation and emits only once")
				metrics.append({"speed": round_data.muzzle_velocity, "distance": distance, "hz": hz, "time": projectile.flight_time, "drop": drop})
				print("BALLISTIC_METRIC speed=%.0f distance=%.0f hz=%d time=%.6f drop=%.6f" % [round_data.muzzle_velocity, distance, hz, projectile.flight_time, drop])
				thin_wall.queue_free()
				await frames(1)

	for speed in [800.0, 100.0]:
		var previous_time: float = 0.0
		for distance in [10.0, 50.0, 100.0]:
			var drops: Array[float] = []
			var times: Array[float] = []
			for metric in metrics:
				if metric.speed == speed and metric.distance == distance:
					drops.append(metric.drop)
					times.append(metric.time)
			check(times.min() > previous_time and times.max() - times.min() < 0.001, "flight time increases with distance and agrees at 30/60/120 Hz")
			check(drops.max() - drops.min() < (0.025 if speed == 800.0 else 0.13), "drop consistency stays within semi-implicit Euler tolerance")
			previous_time = times.max()
	print("PROJECT_GRAVITY ", gravity)

	var target: Variant = level.get_node("DamageableTarget")
	# Phase 6 regression fixture keeps Overall 100; new body tests use 150.
	target.get_node("HealthComponent").max_health = 100.0
	target.reset_target()
	# Preserve Phase 5 unarmored damage fixtures; armor is tested separately.
	target.get_node("ArmorComponent").unequip_armor()
	var health: Variant = target.get_node("HealthComponent")
	var events: Dictionary = {"info": null}
	health.damaged.connect(func(_amount: float, info: RefCounted) -> void: events.info = info)
	for zone in [{"name": "Head", "hp": 40.0}, {"name": "Torso", "hp": 70.0}, {"name": "Legs", "hp": 82.0}]:
		target.reset_target()
		events.info = null
		camera.look_at(target.get_node("Hurtboxes/" + zone.name).global_position, Vector3.UP)
		var expected_aim: Vector3 = firearm.get_camera_aim_point()
		var muzzle_position: Vector3 = muzzle.global_position
		var saved_round: Variant = firearm.chambered_round
		projectile = fire(firearm, level)
		check(health.current_health == 100.0 and events.info == null, "PROJECTILE does not apply instantaneous hitscan damage")
		check(projectile.global_position == muzzle_position and projectile.global_position != camera.global_position, "shot starts at actual Muzzle, not Camera")
		check(projectile.velocity.normalized().is_equal_approx((expected_aim - muzzle_position).normalized()), "Camera aim point determines Muzzle launch direction")
		check(projectile.ammo_data == saved_round and firearm.loaded_magazine.get_round_count() == 28 - ["Head", "Torso", "Legs"].find(zone.name), "projectile preserves fired_round while Firearm cycles next round")
		var before_markers: int = marker_count(level)
		simulate(projectile, 1.0 / 60.0)
		check(is_equal_approx(health.current_health, zone.hp) and events.info.ammo_data == saved_round, zone.name + " projectile damage uses body multiplier and fired round")
		check(marker_count(level) == before_markers + 1, "projectile uses existing HitMarker impact entry")
		check(events.info.source == player and events.info.weapon == firearm and events.info.hit_direction.is_equal_approx(projectile.velocity.normalized()), "projectile DamageInfo carries source, weapon and velocity direction")
		await frames(1)

	target.reset_target()
	for surface in ["Target_01", "Target_02", "Target_03", "Floor", "Wall_North", "ThinWall"]:
		var saved_player_position: Vector3 = player.position
		var aim_point: Vector3 = level.get_node(surface).global_position
		if surface == "Floor":
			aim_point = Vector3(8, 0, 5)
		if surface == "Wall_North":
			player.position.x = 14.0
			aim_point.x = 14.0
		camera.look_at(aim_point, Vector3.UP)
		projectile = fire(firearm, level)
		var world_hit: Dictionary = {"collider": null}
		projectile.impacted.connect(func(collider: Node3D, _position: Vector3, _normal: Vector3, _direction: Vector3, _round: Resource) -> void: world_hit.collider = collider)
		var surface_markers: int = marker_count(level)
		simulate(projectile, 1.0 / 60.0)
		check(world_hit.collider == level.get_node(surface), "projectile reaches original world surface " + surface)
		check(health.current_health == 100.0 and marker_count(level) == surface_markers + 1, "world impact only creates existing HitMarker")
		player.position = saved_player_position
		await frames(1)

	# Camera ray clears this corner obstacle; the lower/right muzzle ray cannot.
	target.reset_target()
	player.position = Vector3(-4, 0, 10)
	camera.rotation = Vector3.ZERO
	camera.look_at(target.get_node("Hurtboxes/Torso").global_position, Vector3.UP)
	muzzle.position = Vector3(0, 0, -0.3)
	var obstruction_position: Vector3 = muzzle.global_position.lerp(target.get_node("Hurtboxes/Torso").global_position, 0.1)
	var corner_wall: StaticBody3D = body(level, "CornerWall", obstruction_position, Vector3(0.1, 0.2, 0.02))
	await frames(2)
	check(firearm.get_camera_aim_point().distance_to(target.get_node("Hurtboxes/Torso").global_position) < 0.3, "camera sees Hurtbox past corner obstacle")
	projectile = fire(firearm, level)
	var before_markers: int = marker_count(level)
	simulate(projectile, 1.0 / 60.0)
	check(health.current_health == 100.0 and marker_count(level) == before_markers + 1, "muzzle projectile hits corner wall before Hurtbox")
	corner_wall.queue_free()
	await frames(1)

	# Also cover the muzzle already clipping beyond a thin wall.
	var barrel_wall: StaticBody3D = body(level, "BarrelWall", camera.global_position.lerp(muzzle.global_position, 0.5), Vector3(2, 2, 0.02))
	await frames(2)
	projectile = fire(firearm, level)
	before_markers = marker_count(level)
	simulate(projectile, 1.0 / 60.0)
	check(health.current_health == 100.0 and marker_count(level) == before_markers + 1 and is_zero_approx(projectile.flight_time), "launch path sweep prevents spawning through a wall behind muzzle")
	barrel_wall.queue_free()
	await frames(1)

	var ammo_a: Variant = ammo.duplicate()
	var ammo_b: Variant = ammo.duplicate()
	ammo_a.ammo_name = "Ammo A"
	ammo_b.ammo_name = "Ammo B"
	ammo_b.muzzle_velocity = 400.0
	ammo_b.flesh_damage = 50.0
	var mixed: Variant = firearm.loaded_magazine
	mixed.clear()
	mixed.push_round(ammo_a)
	mixed.push_round(ammo_b)
	mixed.push_round(ammo_a)
	firearm.chambered_round = null
	firearm.state = 2
	firearm.chamber_next_round()
	target.reset_target()
	camera.look_at(target.get_node("Hurtboxes/Torso").global_position, Vector3.UP)
	for shot in [{"ammo": ammo_a, "hp": 70.0}, {"ammo": ammo_b, "hp": 20.0}, {"ammo": ammo_a, "hp": 0.0}]:
		projectile = fire(firearm, level)
		check(projectile.ammo_data == shot.ammo and is_equal_approx(projectile.velocity.length(), shot.ammo.muzzle_velocity), "mixed projectile carries actual round and %.0f m/s velocity" % shot.ammo.muzzle_velocity)
		simulate(projectile, 1.0 / 60.0)
		check(events.info.ammo_data == shot.ammo and events.info.base_flesh_damage == shot.ammo.flesh_damage and is_equal_approx(health.current_health, shot.hp), "mixed projectile applies actual %.0f damage, HP %.0f" % [shot.ammo.flesh_damage, shot.hp])
		await frames(1)
	check(health.is_dead() and target.get_node("DebugHealthLabel").text.begins_with("DEAD"), "projectile death uses existing target visuals")
	await create_timer(3.2).timeout
	check(health.current_health == 100.0 and target.get_node("Mesh").visible, "projectile death uses existing three-second reset")

	# Compare deterministic spread to the actual spawned direction: exactly one sample.
	camera.rotation = Vector3(0.3, 0, 0)
	for aiming in [false, true]:
		firearm.set_aiming(aiming)
		firearm.weapon_data.hip_spread_degrees = 1.5
		firearm.weapon_data.ads_spread_degrees = 0.25
		firearm._random.seed = 1234
		var expected_direction: Vector3 = firearm._get_shot_direction()
		var expected_aim: Vector3 = firearm.get_camera_aim_point(expected_direction)
		var expected_launch: Vector3 = (expected_aim - muzzle.global_position).normalized()
		firearm._random.seed = 1234
		firearm.chambered_round = ammo
		firearm.state = 0
		projectile = fire(firearm, level)
		check(projectile.velocity.normalized().is_equal_approx(expected_launch), "projectile final launch applies %s spread exactly once" % ("ADS" if aiming else "Hip"))
		projectile.queue_free()
		await frames(1)

	firearm.weapon_data.fire_model = 0
	firearm.weapon_data.hip_spread_degrees = 0.0
	firearm.weapon_data.ads_spread_degrees = 0.0
	camera.look_at(target.get_node("Hurtboxes/Torso").global_position, Vector3.UP)
	firearm.chambered_round = ammo_b
	firearm.state = 0
	before_markers = marker_count(level)
	firearm.set_trigger(false, false)
	firearm._physics_process(0.2)
	firearm.set_trigger(true, true)
	firearm._physics_process(0.001)
	check(health.current_health == 50.0 and events.info.ammo_data == ammo_b and projectiles(level).is_empty(), "switching back to HITSCAN delivers immediate actual-round damage without projectile")
	check(marker_count(level) == before_markers + 1, "HITSCAN shares the same HitMarker impact entry")
	level.queue_free()
	await process_frame
	print("BALLISTIC_RESULT failures=%d" % failures)
	quit(1 if failures > 0 else 0)

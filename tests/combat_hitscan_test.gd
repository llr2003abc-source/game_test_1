extends SceneTree

var failures: int = 0

class MovementProbe extends Node:
	var player: CharacterBody3D
	func _physics_process(_delta: float) -> void:
		player.velocity = Vector3(0, -1, -5)
		player.move_and_slide()

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

func markers(level: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in level.get_children():
		if child.scene_file_path == "res://scenes/weapons/hit_marker.tscn":
			result.append(child)
	return result

func shoot(firearm: Node3D, camera: Camera3D, aim_point: Vector3) -> void:
	firearm.set_trigger(false, false)
	firearm._physics_process(0.2)
	camera.look_at(aim_point, Vector3.UP)
	firearm.set_trigger(true, true)
	firearm._physics_process(0.001)

func _run() -> void:
	var level: Node3D = load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player: Variant = level.get_node("Player")
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var firearm: Variant = player.get_node("Head/Camera3D/WeaponRoot")
	var target: Variant = level.get_node("DamageableTarget")
	# Phase 6 regression fixture keeps Overall 100; new body tests use 150.
	target.get_node("HealthComponent").max_health = 100.0
	target.reset_target()
	# Preserve Phase 5 unarmored damage fixtures; armor is tested separately.
	target.get_node("ArmorComponent").unequip_armor()
	var health: Variant = target.get_node("HealthComponent")
	var label: Label3D = target.get_node("DebugHealthLabel")
	var target_mesh: Node3D = target.get_node("Mesh")
	player.set_physics_process(false)
	firearm.set_physics_process(false)
	# Isolate aim and recoil randomness in the test instance, never in saved resources.
	firearm.weapon_data = firearm.weapon_data.duplicate()
	firearm.weapon_data.fire_model = WeaponData.FireModel.HITSCAN
	firearm.weapon_data.hip_spread_degrees = 0.0
	firearm.weapon_data.ads_spread_degrees = 0.0
	firearm.weapon_data.recoil_pitch = 0.0
	firearm.weapon_data.recoil_yaw = 0.0
	firearm.fire_mode = 0
	var events: Dictionary = {"deaths": 0, "hits": 0, "info": null}
	health.died.connect(func(_info: RefCounted) -> void: events.deaths += 1)
	health.damaged.connect(func(_amount: float, info: RefCounted) -> void:
		events.hits += 1
		events.info = info)
	await frames(5)
	check((label.text.begins_with("HP: 100 / 100\n") and label.text.ends_with("\nARMOR: NONE")) and target_mesh.visible, "target starts alive with health label")
	check(player.collision_layer == 2 and player.collision_mask == 9, "player retains its layer and collides with World + TargetBody")
	check(target.get_node("PhysicsBody").collision_layer == 8, "physical target body has independent movement layer")
	health.apply_damage(1.0)
	check(health.current_health == 99.0 and (label.text.begins_with("HP: 99 / 100\n") and label.text.ends_with("\nARMOR: NONE")), "debug target accepts HealthComponent damage without optional metadata")
	target.reset_target()

	for zone in [{"node": "Torso", "name": &"torso", "hp": [70.0, 40.0, 10.0, 0.0]}, {"node": "Head", "name": &"head", "hp": [40.0, 0.0]}, {"node": "Legs", "name": &"legs", "hp": [82.0, 64.0, 46.0, 28.0, 10.0, 0.0]}]:
		target.reset_target()
		firearm.loaded_magazine.initialize_full(firearm.weapon_data.magazine_data)
		firearm.chambered_round = null
		firearm.state = Firearm.State.EMPTY
		firearm.chamber_next_round()
		var area: Area3D = target.get_node("Hurtboxes/" + zone.node)
		check(area.collision_layer == 4 and area.collision_mask == 0, "%s Hurtbox uses layer 3 and no movement mask" % zone.node)
		var before_deaths: int = events.deaths
		for expected_hp in zone.hp:
			var before_markers: int = markers(level).size()
			shoot(firearm, camera, area.global_position)
			check(is_equal_approx(health.current_health, expected_hp), "real hitscan %s HP -> %.0f" % [zone.node, expected_hp])
			check(markers(level).size() == before_markers + 1, "Hurtbox hit preserves original HitMarker")
			var info: Variant = events.info
			check(info != null and info.hit_zone == zone.name and info.base_flesh_damage == 30.0, "DamageInfo carries correct zone and AmmoData damage")
		check(health.is_dead() and label.text.begins_with("DEAD") and not target_mesh.visible, "%s death updates debug visuals" % zone.node)
		check(events.deaths == before_deaths + 1, "target emits one death for this life")
		var before_hits: int = events.hits
		var before_markers: int = markers(level).size()
		shoot(firearm, camera, area.global_position)
		check(events.hits == before_hits and events.deaths == before_deaths + 1 and health.current_health == 0.0, "shooting dead target ignores damage")
		check(markers(level).size() == before_markers + 1, "dead Hurtbox still produces HitMarker")

	var info: Variant = events.info
	check(info.source == player and info.weapon == firearm and info.ammo_data == firearm.weapon_data.magazine_data.default_ammo, "hit metadata identifies source, weapon and actual loaded ammo")
	check(is_equal_approx(info.hit_direction.length(), 1.0) and is_equal_approx(info.hit_normal.length(), 1.0), "hit direction and surface normal are unit vectors")
	var last_marker: Node3D = markers(level).back()
	check(last_marker.global_position.distance_to(info.hit_position + info.hit_normal * 0.01) < 0.0001, "impact offset is exactly normal * 0.01")
	await create_timer(3.2).timeout
	check(health.current_health == 100.0 and not health.is_dead() and (label.text.begins_with("HP: 100 / 100\n") and label.text.ends_with("\nARMOR: NONE")) and target_mesh.visible, "debug timer resets target after about 3 seconds")
	check(markers(level).is_empty(), "existing HitMarkers expire after 3 seconds")

	for world_target in ["Target_01", "Target_02", "Target_03", "Wall_North", "Wall_East", "Floor"]:
		var saved_player_position: Vector3 = player.position
		var aim_point: Vector3 = level.get_node(world_target).global_position
		if world_target == "Wall_North":
			player.position.x = 14.0
			aim_point.x = 14.0
		if world_target == "Wall_East":
			aim_point.z = 6.0
		if world_target == "Floor":
			aim_point = Vector3(8, 0, 5)
		var before_hits: int = events.hits
		var before_markers: int = markers(level).size()
		shoot(firearm, camera, aim_point)
		check(markers(level).size() == before_markers + 1 and events.hits == before_hits and health.current_health == 100.0, world_target + " produces marker without damage")
		player.position = saved_player_position

	var saved_transform: Transform3D = camera.global_transform
	camera.global_position = Vector3(-3, 1.25, 17)
	var before_hits: int = events.hits
	var before_markers: int = markers(level).size()
	shoot(firearm, camera, target.get_node("Hurtboxes/Torso").global_position)
	check(events.hits == before_hits and health.current_health == 100.0 and markers(level).size() == before_markers + 1, "solid world wall blocks damage to target behind it")
	camera.global_transform = saved_transform
	before_markers = markers(level).size()
	shoot(firearm, camera, camera.global_position + Vector3(0, 100, -1))
	check(markers(level).size() == before_markers, "ray miss produces no marker and no damage")

	player.position = target.position + Vector3(0, 0.02, 3)
	player.rotation = Vector3.ZERO
	await frames(2)
	var probe := MovementProbe.new()
	probe.player = player
	root.add_child(probe)
	await frames(60)
	probe.queue_free()
	check(player.position.z > target.position.z + 0.6 and player.position.z < target.position.z + 0.9, "target PhysicsBody blocks walking while Hurtboxes do not affect movement")

	level.queue_free()
	await process_frame
	print("COMBAT_HITSCAN_RESULT failures=%d" % failures)
	quit(1 if failures > 0 else 0)

extends SceneTree

var failures: int = 0
var assertions: int = 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func shoot(firearm: Node, camera: Camera3D, point: Vector3, ammo: Resource) -> void:
	camera.look_at(point, Vector3.UP)
	firearm.set_trigger(false, false)
	firearm._physics_process(0.2)
	firearm.chambered_round = ammo
	firearm.state = 0
	firearm.set_trigger(true, true)
	firearm._physics_process(0.001)
	await frames(3)

func _run() -> void:
	var level: Node3D = load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var target: Variant = level.get_node("DamageableTarget")
	check(target.has_node("BodyHealthComponent") and target.has_node("BodyInjuryComponent") and target.has_node("Hurtboxes/Arms"), "saved target has four body zones and injury components")
	if failures > 0:
		level.queue_free()
		await process_frame
		finish()
		return
	var player: Variant = level.get_node("Player")
	var firearm: Variant = player.get_node("Head/Camera3D/WeaponRoot")
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var health: Variant = target.get_node("HealthComponent")
	var body: Variant = target.get_node("BodyHealthComponent")
	var injury: Variant = target.get_node("BodyInjuryComponent")
	var armor: Variant = target.get_node("ArmorComponent")
	var label: Label3D = target.get_node("DebugHealthLabel")
	check(body.health_component == health and injury.body_health == body and health.current_health == 150.0, "target body and injury references use its own Overall 150")
	for zone in ["Head", "Torso", "Arms", "Legs"]:
		var area: Variant = target.get_node("Hurtboxes/" + zone)
		check(area.body_health_component == body and area.health_component == health and area.armor_component == armor and area.collision_layer == 4 and area.collision_mask == 0, zone + " saved Hurtbox bindings preserve body/armor and collision layers")
	player.set_physics_process(false)
	firearm.set_physics_process(false)
	firearm.weapon_data = firearm.weapon_data.duplicate()
	firearm.weapon_data.hip_spread_degrees = 0.0
	firearm.weapon_data.ads_spread_degrees = 0.0
	firearm.weapon_data.recoil_pitch = 0.0
	firearm.weapon_data.recoil_yaw = 0.0
	firearm.fire_mode = 0
	var events: Dictionary = {"deaths": 0, "destroyed": {}, "info": null}
	health.died.connect(func(_info: RefCounted) -> void: events.deaths += 1)
	health.damaged.connect(func(_amount: float, info: RefCounted) -> void: events.info = info)
	body.zone_destroyed.connect(func(zone: StringName, _info: RefCounted) -> void: events.destroyed[zone] = events.destroyed.get(zone, 0) + 1)
	var ammo: Variant = load("res://data/ammo/test_level_3_round.tres")
	var snapshots: Array = []
	for mode in [0, 1]:
		firearm.weapon_data.fire_model = mode
		armor.equip_armor(load("res://data/armor/test_level_3_armor.tres"))
		target.reset_target()
		var torso: Node3D = target.get_node("Hurtboxes/Torso")
		await shoot(firearm, camera, torso.global_position, load("res://data/ammo/test_level_1_round.tres"))
		check(body.get_zone_health(&"torso") == 85.0 and health.current_health == 150.0 and armor.equipped_armor.current_durability == 88.0 and not injury.torso_injured, "mode %d blocked armor hit causes neither zone nor Overall injury" % mode)
		target.reset_target()
		await shoot(firearm, camera, torso.global_position, ammo)
		check(body.get_zone_health(&"torso") == 65.0 and health.current_health == 130.0 and armor.equipped_armor.current_durability == 70.0 and events.info.final_flesh_damage == 20.0, "mode %d armor 0.5 then body 1 then zone and Overall 20" % mode)
		check(label.text.contains("TORSO: 65 / 85") and label.text.begins_with("HP: 130 / 150"), "debug label updates zone and Overall independently")
		armor.equipped_armor.current_durability = 5.0
		await shoot(firearm, camera, torso.global_position, load("res://data/ammo/test_level_1_round.tres"))
		check(body.get_zone_health(&"torso") == 65.0 and health.current_health == 130.0 and armor.equipped_armor.is_broken(), "low-level breaking shot still causes zero zone and Overall damage")
		await shoot(firearm, camera, torso.global_position, ammo)
		check(body.get_zone_health(&"torso") == 25.0 and health.current_health == 90.0 and events.info.final_flesh_damage == 40.0, "broken armor passes full 40 to body and Overall")
		var mode_snapshot: Array = []
		for zone in [{"node": "Head", "name": &"head", "shots": 1, "damage": 80.0, "hp": 70.0}, {"node": "Torso", "name": &"torso", "shots": 3, "damage": 40.0, "hp": 30.0}, {"node": "Arms", "name": &"arms", "shots": 2, "damage": 40.0, "hp": 70.0}, {"node": "Legs", "name": &"legs", "shots": 3, "damage": 24.0, "hp": 78.0}]:
			armor.unequip_armor()
			target.reset_target()
			events.destroyed.clear()
			var before_deaths: int = events.deaths
			var aim_point: Vector3 = target.get_node("Hurtboxes/" + zone.node).global_position
			if zone.node == "Arms":
				aim_point = target.get_node("Hurtboxes/Arms/Right").global_position
			for i in range(zone.shots):
				await shoot(firearm, camera, aim_point, ammo)
			check(body.get_zone_health(zone.name) == 0.0 and health.current_health == zone.hp and not health.is_dead() and injury.is_zone_injured(zone.name), "mode %d %s destroyed while Overall %.0f remains alive" % [mode, zone.node, zone.hp])
			check(events.destroyed.get(zone.name, 0) == 1 and events.deaths == before_deaths and target.get_node("Mesh").visible and label.text.contains(zone.node.to_upper() + ": INJURED") and not label.text.begins_with("DEAD"), "one injury event and alive debug visual for " + zone.node)
			check(events.info.ammo_data == ammo and events.info.hit_zone == zone.name and events.info.final_flesh_damage == zone.damage, "actual fired round and Hurtbox multiplier reach " + zone.node)
			mode_snapshot.append([body.get_zone_health(zone.name), health.current_health])
			await shoot(firearm, camera, aim_point, ammo)
			check(body.get_zone_health(zone.name) == 0.0 and health.current_health == maxf(0.0, zone.hp - zone.damage) and events.destroyed.get(zone.name, 0) == 1, "repeated hit on zero " + zone.node + " still damages Overall once")
			while not health.is_dead():
				await shoot(firearm, camera, aim_point, ammo)
			check(health.current_health == 0.0 and events.deaths == before_deaths + 1 and label.text.begins_with("DEAD") and not target.get_node("Mesh").visible, "only Overall zero triggers death for " + zone.node)
			await shoot(firearm, camera, aim_point, ammo)
			check(events.deaths == before_deaths + 1 and events.destroyed.get(zone.name, 0) == 1, "dead target does not emit repeated death/injury")
			armor.equip_armor(load("res://data/armor/test_level_3_armor.tres"))
			armor.equipped_armor.apply_armor_damage(90.0)
			await create_timer(3.2).timeout
			check(health.current_health == 150.0 and armor.equipped_armor.current_durability == 100.0 and target.get_node("Mesh").visible, "three-second death reset restores Overall, armor and mesh")
			for reset_zone in [&"head", &"torso", &"arms", &"legs"]:
				check(body.get_zone_health(reset_zone) == body.get_zone_max_health(reset_zone) and not injury.is_zone_injured(reset_zone), "reset restores body and injury: " + reset_zone)
			events.destroyed.clear()
			target.get_node("BodyHealthComponent").apply_zone_damage(zone.name, body.get_zone_max_health(zone.name))
			check(events.destroyed.get(zone.name, 0) == 1, "reset allows another injury event: " + zone.node)
			target.reset_target()
		snapshots.append(mode_snapshot)
	check(snapshots[0] == snapshots[1], "HITSCAN and PROJECTILE have identical four-zone health and injury outcomes")
	check(player.get_node("HealthComponent").current_health == 150.0 and not player.get_node("BodyInjuryComponent").head_injured, "target injuries cannot modify the independent Player body")
	level.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("BODY_PIPELINE_RESULT assertions=%d failures=%d" % [assertions, failures])
	quit(1 if failures > 0 else 0)

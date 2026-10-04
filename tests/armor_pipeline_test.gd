extends SceneTree

var failures: int = 0
var assertions: int = 0

# Records the real pipeline metadata, including hits with zero flesh damage.
class HitProbe extends Hurtbox:
	var last_info: DamageInfo
	func receive_hit(info: DamageInfo) -> void:
		last_info = info
		super.receive_hit(info)

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

func marker_count(level: Node) -> int:
	var count: int = 0
	for child in level.get_children():
		if child.scene_file_path == "res://scenes/weapons/hit_marker.tscn" and not child.is_queued_for_deletion():
			count += 1
	return count

func shoot(firearm: Node, camera: Camera3D, aim_point: Vector3) -> void:
	camera.look_at(aim_point, Vector3.UP)
	firearm.set_trigger(false, false)
	firearm._physics_process(0.2)
	firearm.set_trigger(true, true)
	firearm._physics_process(0.001)
	await frames(3)

func direct_hit(area: Area3D, ammo: Resource) -> Variant:
	var info: Variant = load("res://scripts/combat/damage_info.gd").new()
	info.base_flesh_damage = ammo.flesh_damage
	info.bullet_level = ammo.bullet_level
	info.ammo_data = ammo
	area.receive_hit(info)
	return info

func _run() -> void:
	var level: Node3D = load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var target: Variant = level.get_node("DamageableTarget")
	# Phase 6 regression fixture keeps Overall 100; new body tests use 150.
	target.get_node("HealthComponent").max_health = 100.0
	target.reset_target()
	check(target.has_node("ArmorComponent"), "saved target contains equipped ArmorComponent")
	if failures > 0:
		level.queue_free()
		await process_frame
		finish()
		return
	var player: Variant = level.get_node("Player")
	var firearm: Variant = player.get_node("Head/Camera3D/WeaponRoot")
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var health: Variant = target.get_node("HealthComponent")
	var armor: Variant = target.get_node("ArmorComponent")
	var label: Label3D = target.get_node("DebugHealthLabel")
	player.set_physics_process(false)
	firearm.set_physics_process(false)
	firearm.weapon_data = firearm.weapon_data.duplicate()
	firearm.weapon_data.hip_spread_degrees = 0.0
	firearm.weapon_data.ads_spread_degrees = 0.0
	firearm.weapon_data.recoil_pitch = 0.0
	firearm.weapon_data.recoil_yaw = 0.0
	firearm.fire_mode = 0
	await frames(3)
	check(armor.equipped_armor.definition.armor_level == 3 and armor.equipped_armor.current_durability == 100.0 and (label.text.begins_with("HP: 100 / 100\n") and label.text.ends_with("\nARMOR: L3 100 / 100")), "default target shows full HP and torso L3 armor")
	for zone_node in ["Head", "Torso", "Legs"]:
		check(target.get_node("Hurtboxes/" + zone_node).armor_component == armor, zone_node + " saved scene references its real ArmorComponent")
	if failures > 0:
		level.queue_free()
		await process_frame
		finish()
		return
	for zone in [{"node": "Head", "zone": &"head", "multiplier": 2.0}, {"node": "Torso", "zone": &"torso", "multiplier": 1.0}, {"node": "Legs", "zone": &"legs", "multiplier": 0.6}]:
		var area: Area3D = target.get_node("Hurtboxes/" + zone.node)
		area.set_script(HitProbe)
		area.health_component = health
		area.armor_component = armor
		area.hit_zone = zone.zone
		area.damage_multiplier = zone.multiplier
	var torso: Variant = target.get_node("Hurtboxes/Torso")
	var ammo: Variant = load("res://data/ammo/test_level_3_round.tres")
	for zone in [{"node": "Head", "hp": 20.0, "damage": 80.0, "durability": 100.0, "protected": false}, {"node": "Torso", "hp": 80.0, "damage": 20.0, "durability": 70.0, "protected": true}, {"node": "Legs", "hp": 76.0, "damage": 24.0, "durability": 100.0, "protected": false}]:
		target.reset_target()
		var info: Variant = direct_hit(target.get_node("Hurtboxes/" + zone.node), ammo)
		check(is_equal_approx(health.current_health, zone.hp) and info.final_flesh_damage == zone.damage and info.base_flesh_damage == 40.0, zone.node + " applies armor before body multiplier")
		check(info.armor_hit_result.armor_hit == zone.protected and armor.equipped_armor.current_durability == zone.durability, zone.node + " coverage only changes protected durability")
	var head_armor: Variant = load("res://scripts/combat/armor_data.gd").new()
	head_armor.armor_level = 3
	head_armor.protection_zones.assign([&"head"])
	armor.equip_armor(head_armor)
	health.reset_health()
	var info: Variant = direct_hit(target.get_node("Hurtboxes/Head"), ammo)
	check(health.current_health == 60.0 and info.armor_hit_result.final_flesh_damage == 20.0 and info.final_flesh_damage == 40.0, "protected head proves flesh 40 x armor 0.5 x body 2 = 40")
	armor.equip_armor(load("res://data/armor/test_level_3_armor.tres"))

	var mode_snapshots: Array = []
	for mode in [0, 1]:
		firearm.weapon_data.fire_model = mode
		target.reset_target()
		var magazine: Variant = load("res://scripts/weapons/magazine_instance.gd").new()
		magazine.initialize_full(firearm.weapon_data.magazine_data)
		magazine.clear()
		for bullet_level in [2, 4, 1, 5]:
			magazine.push_round(load("res://data/ammo/test_level_%d_round.tres" % bullet_level))
		firearm.loaded_magazine = magazine
		firearm.chambered_round = null
		firearm.state = 2
		firearm.chamber_next_round()
		var snapshot: Array = []
		for shot in [{"level": 2, "hp": 100.0, "armor": 85.0, "armor_damage": 15.0, "flesh": 0.0}, {"level": 4, "hp": 80.0, "armor": 40.0, "armor_damage": 45.0, "flesh": 20.0}, {"level": 1, "hp": 80.0, "armor": 28.0, "armor_damage": 12.0, "flesh": 0.0}, {"level": 5, "hp": 60.0, "armor": 0.0, "armor_damage": 48.0, "flesh": 20.0}]:
			var fired_round: Variant = firearm.chambered_round
			var before_markers: int = marker_count(level)
			await shoot(firearm, camera, torso.global_position)
			info = torso.last_info
			check(info.ammo_data == fired_round and info.bullet_level == shot.level and info.base_flesh_damage == fired_round.flesh_damage and info.armor_hit_result.base_armor_damage == fired_round.armor_damage, "mode %d mixed B%d preserves actual fired round" % [mode, shot.level])
			check(is_equal_approx(health.current_health, shot.hp) and is_equal_approx(armor.equipped_armor.current_durability, shot.armor) and is_equal_approx(info.final_flesh_damage, shot.flesh) and is_equal_approx(info.armor_hit_result.final_armor_damage, shot.armor_damage), "mode %d mixed B%d gives expected HP/durability/damage" % [mode, shot.level])
			check(info.source == player and info.weapon == firearm and info.hit_zone == &"torso" and info.hit_direction.is_normalized(), "impact metadata survives armor resolution")
			check(marker_count(level) == before_markers + 1, "zero and nonzero flesh hits preserve existing HitMarker")
			snapshot.append([health.current_health, armor.equipped_armor.current_durability])
		mode_snapshots.append(snapshot)
		check(firearm.chambered_round == null and magazine.is_empty() and firearm.state == 2 and (label.text.begins_with("HP: 60 / 100\n") and label.text.ends_with("\nARMOR: L3 BROKEN")), "mixed fire cycle ends EMPTY and broken armor label")
		firearm.chambered_round = load("res://data/ammo/test_level_1_round.tres")
		firearm.state = 0
		await shoot(firearm, camera, torso.global_position)
		check(health.current_health == 20.0 and torso.last_info.final_flesh_damage == 40.0 and torso.last_info.armor_hit_result.final_armor_damage == 0.0, "broken armor no longer reduces subsequent low-level flesh damage")

		# Distinct payload catches accidentally using the magazine's default ammo.
		target.reset_target()
		var varied: Variant = load("res://data/ammo/test_level_4_round.tres").duplicate()
		varied.flesh_damage = 60.0
		varied.armor_damage = 10.0
		varied.muzzle_velocity = 400.0
		firearm.chambered_round = varied
		firearm.state = 0
		await shoot(firearm, camera, torso.global_position)
		check(health.current_health == 70.0 and armor.equipped_armor.current_durability == 85.0 and torso.last_info.ammo_data == varied, "both modes use distinct fired-round flesh 60 and armor 10")
		check((label.text.begins_with("HP: 70 / 100\n") and label.text.ends_with("\nARMOR: L3 85 / 100")), "label updates both flesh damage and durability")

		target.reset_target()
		armor.equipped_armor.current_durability = 5.0
		firearm.chambered_round = load("res://data/ammo/test_level_1_round.tres")
		firearm.state = 0
		await shoot(firearm, camera, torso.global_position)
		check(health.current_health == 100.0 and torso.last_info.armor_hit_result.armor_broken_after and not torso.last_info.armor_hit_result.armor_broken_before and torso.last_info.final_flesh_damage == 0.0 and (label.text.begins_with("HP: 100 / 100\n") and label.text.ends_with("\nARMOR: L3 BROKEN")), "real low-level breaking shot still blocks flesh and updates label")
		firearm.chambered_round = load("res://data/ammo/test_level_1_round.tres")
		firearm.state = 0
		await shoot(firearm, camera, torso.global_position)
		check(health.current_health == 60.0 and torso.last_info.armor_hit_result.armor_broken_before, "real next shot after breaking armor delivers 40")

		target.reset_target()
		firearm.chambered_round = ammo
		firearm.state = 0
		await shoot(firearm, camera, level.get_node("Target_01").global_position)
		check(health.current_health == 100.0 and armor.equipped_armor.current_durability == 100.0, "world hit never accesses target armor or health")
		for i in range(2):
			firearm.chambered_round = ammo
			firearm.state = 0
			await shoot(firearm, camera, target.get_node("Hurtboxes/Head").global_position)
		check(health.is_dead() and label.text.begins_with("DEAD") and not target.get_node("Mesh").visible, "unprotected head still causes death while armor remains intact")
		var durability_at_death: float = armor.equipped_armor.current_durability
		direct_hit(torso, ammo)
		check(armor.equipped_armor.current_durability == durability_at_death, "dead target ignores further armor damage")
		await create_timer(3.2).timeout
		check(health.current_health == 100.0 and armor.equipped_armor.current_durability == 100.0 and target.get_node("Mesh").visible and (label.text.begins_with("HP: 100 / 100\n") and label.text.ends_with("\nARMOR: L3 100 / 100")), "debug death reset restores health and armor together")
	check(mode_snapshots[0] == mode_snapshots[1], "HITSCAN and PROJECTILE produce identical mixed-ammo armor outcomes")
	level.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("ARMOR_PIPELINE_RESULT assertions=%d failures=%d" % [assertions, failures])
	quit(1 if failures > 0 else 0)

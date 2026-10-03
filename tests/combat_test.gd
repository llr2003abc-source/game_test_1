extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for path in ["res://scripts/weapons/ammo_data.gd", "res://data/ammo/test_round.tres", "res://scripts/combat/damage_info.gd", "res://scripts/combat/health_component.gd", "res://scripts/combat/hurtbox.gd"]:
		check(FileAccess.file_exists(path), "required combat file: " + path)
	if failures > 0:
		print("COMBAT_LOGIC_RESULT failures=%d" % failures)
		quit(1)
		return

	var ammo: Variant = load("res://data/ammo/test_round.tres")
	check(ammo.ammo_name == "Test Round" and is_equal_approx(ammo.damage, 30.0), "Test Round supplies 30 damage")
	check(is_equal_approx(ammo.muzzle_velocity, 800.0) and is_equal_approx(ammo.penetration, 20.0), "reserved ammo values are stored")
	var weapon: Variant = load("res://data/weapons/test_rifle.tres")
	check(weapon.magazine_data.default_ammo == ammo and is_equal_approx(weapon.max_range, 1000.0), "rifle references magazine default ammo and max_range")

	var health: Variant = load("res://scripts/combat/health_component.gd").new()
	var info: Variant = load("res://scripts/combat/damage_info.gd").new()
	info.damage = ammo.damage
	info.ammo_data = ammo
	var counts: Dictionary = {"changed": 0, "damaged": 0, "died": 0, "last_amount": 0.0, "last_info": null}
	health.health_changed.connect(func(_hp: float, _max_hp: float) -> void: counts.changed += 1)
	health.damaged.connect(func(amount: float, hit_info: RefCounted) -> void:
		counts.damaged += 1
		counts.last_amount = amount
		counts.last_info = hit_info)
	health.died.connect(func(_hit_info: RefCounted) -> void: counts.died += 1)
	root.add_child(health)
	check(is_equal_approx(health.current_health, 100.0) and not health.is_dead(), "initial HP = max_health")
	var initial_changes: int = counts.changed
	health.apply_damage(0.0)
	health.apply_damage(-20.0)
	check(health.current_health == 100.0 and counts.changed == initial_changes and counts.damaged == 0, "nonpositive damage is ignored")
	health.apply_damage(30.0, info)
	check(health.current_health == 70.0 and counts.damaged == 1 and counts.last_info == info, "apply_damage forwards damage metadata")
	health.apply_damage(500.0, info)
	check(health.current_health == 0.0 and health.is_dead(), "overkill clamps HP to zero")
	check(counts.died == 1 and counts.last_amount == 70.0, "death occurs once and damaged reports HP actually lost")
	var dead_changes: int = counts.changed
	health.apply_damage(30.0, info)
	check(counts.died == 1 and counts.damaged == 2 and counts.changed == dead_changes, "dead component ignores further damage")
	health.reset_health()
	check(health.current_health == 100.0 and not health.is_dead(), "reset restores HP and alive state")
	health.apply_damage(100.0, info)
	check(counts.died == 2, "a new life can die once again")

	for zone in [{"name": &"head", "multiplier": 2.0, "damage": 60.0}, {"name": &"torso", "multiplier": 1.0, "damage": 30.0}, {"name": &"legs", "multiplier": 0.6, "damage": 18.0}]:
		health.reset_health()
		var hurtbox: Variant = load("res://scripts/combat/hurtbox.gd").new()
		hurtbox.health_component = health
		hurtbox.hit_zone = zone.name
		hurtbox.damage_multiplier = zone.multiplier
		hurtbox.receive_hit(info)
		check(is_equal_approx(health.current_health, 100.0 - zone.damage) and is_equal_approx(counts.last_amount, zone.damage), "%s multiplier yields %.0f damage" % [zone.name, zone.damage])
		check(info.hit_zone == zone.name and info.damage == 30.0, "Hurtbox sets hit zone and preserves base ammo damage")
		hurtbox.free()

	health.max_health = 150.0
	health.reset_health()
	check(health.current_health == 150.0 and not health.is_dead(), "reset uses configured max_health")
	health.queue_free()
	await process_frame
	print("COMBAT_LOGIC_RESULT failures=%d" % failures)
	quit(1 if failures > 0 else 0)

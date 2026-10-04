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

func _run() -> void:
	for path in ["res://scripts/combat/body_health_component.gd", "res://scripts/combat/body_injury_component.gd"]:
		check(FileAccess.file_exists(path), "required body system: " + path)
	if failures > 0:
		finish()
		return
	var health: Variant = load("res://scripts/combat/health_component.gd").new()
	health.max_health = 150.0
	root.add_child(health)
	var body: Variant = load("res://scripts/combat/body_health_component.gd").new()
	body.health_component = health
	root.add_child(body)
	var injury: Variant = load("res://scripts/combat/body_injury_component.gd").new()
	injury.body_health = body
	root.add_child(injury)
	var events: Dictionary = {"destroyed": 0, "injured": 0, "died": 0, "reset": 0, "zone": &"", "info": null}
	body.zone_destroyed.connect(func(zone: StringName, info: RefCounted) -> void:
		events.destroyed += 1
		events.zone = zone
		events.info = info)
	injury.injury_started.connect(func(_zone: StringName) -> void: events.injured += 1)
	injury.injuries_reset.connect(func() -> void: events.reset += 1)
	health.died.connect(func(_info: RefCounted) -> void: events.died += 1)
	var info: Variant = load("res://scripts/combat/damage_info.gd").new()
	for zone in [{"name": &"head", "max": 35.0, "hit": 80.0}, {"name": &"torso", "max": 85.0, "hit": 120.0}, {"name": &"arms", "max": 60.0, "hit": 80.0}, {"name": &"legs", "max": 70.0, "hit": 80.0}]:
		health.reset_health()
		body.reset_body_health()
		injury.reset_injuries()
		check(body.get_zone_health(zone.name) == zone.max and body.get_zone_max_health(zone.name) == zone.max and not injury.is_zone_injured(zone.name), "zone initializes full: " + zone.name)
		var before_destroyed: int = events.destroyed
		var before_injured: int = events.injured
		var before_deaths: int = events.died
		body.apply_zone_damage(zone.name, zone.hit, info)
		check(body.get_zone_health(zone.name) == 0.0 and health.current_health == 150.0 - zone.hit and not health.is_dead(), "zero zone remains alive until Overall reaches zero: " + zone.name)
		check(events.destroyed == before_destroyed + 1 and events.injured == before_injured + 1 and events.zone == zone.name and events.info == info and injury.is_zone_injured(zone.name), "one zone/injury signal with original metadata: " + zone.name)
		body.apply_zone_damage(zone.name, 10.0, info)
		check(body.get_zone_health(zone.name) == 0.0 and health.current_health == 140.0 - zone.hit and events.destroyed == before_destroyed + 1 and events.injured == before_injured + 1, "destroyed zone keeps taking full Overall damage without repeated signals: " + zone.name)
		body.apply_zone_damage(zone.name, 1000.0, info)
		check(health.current_health == 0.0 and health.is_dead() and events.died == before_deaths + 1, "Overall zero alone emits death: " + zone.name)
		body.apply_zone_damage(zone.name, 1000.0, info)
		check(events.died == before_deaths + 1 and events.destroyed == before_destroyed + 1, "dead body ignores new damage: " + zone.name)
		body.reset_body_health()
		injury.reset_injuries()
		check(body.get_zone_health(zone.name) == zone.max and not injury.is_zone_injured(zone.name) and health.is_dead(), "body/injury reset cannot revive Overall on its own: " + zone.name)
		health.reset_health()
		body.apply_zone_damage(zone.name, zone.hit, info)
		check(events.destroyed == before_destroyed + 2, "reset permits a new destruction event: " + zone.name)

	health.reset_health()
	body.reset_body_health()
	injury.reset_injuries()
	body.apply_zone_damage(&"legs", 24.0, info)
	check(body.get_zone_health(&"legs") == 46.0 and health.current_health == 126.0, "Leg 24: zone 70 -> 46, Overall 150 -> 126")
	body.apply_zone_damage(&"legs", 0.0, info)
	body.apply_zone_damage(&"legs", -10.0, info)
	body.apply_zone_damage(&"unknown", 100.0, info)
	check(body.get_zone_health(&"legs") == 46.0 and health.current_health == 126.0, "nonpositive and unknown-zone damage are ignored")
	health.reset_health()
	body.reset_body_health()
	injury.reset_injuries()
	for step in [{"zone_hp": 45.0, "overall": 110.0}, {"zone_hp": 5.0, "overall": 70.0}, {"zone_hp": 0.0, "overall": 30.0}]:
		body.apply_zone_damage(&"torso", 40.0, info)
		check(body.get_zone_health(&"torso") == step.zone_hp and health.current_health == step.overall and not health.is_dead(), "Torso 40-damage sequence retains Overall %.0f" % step.overall)
	body.apply_zone_damage(&"torso", 40.0, info)
	check(health.is_dead() and body.get_zone_health(&"torso") == 0.0, "fourth torso hit kills only through Overall")

	health.max_health = 1000.0
	for zone in [&"head", &"torso", &"arms", &"legs"]:
		health.reset_health()
		body.reset_body_health()
		injury.reset_injuries()
		body.apply_zone_damage(zone, body.get_zone_max_health(zone), info)
		match zone:
			&"head":
				check(injury.head_injured and injury.get_recoil_multiplier() == 1.35 and injury.get_spread_multiplier() == 1.5, "head injury increases recoil and spread")
			&"torso":
				check(injury.torso_injured and injury.get_movement_multiplier() == 0.8 and injury.get_jump_multiplier() == 1.0, "torso injury reduces movement only")
			&"arms":
				check(injury.arms_injured and injury.get_recoil_multiplier() == 1.5 and injury.get_reload_multiplier() == 1.35, "arms injury increases recoil and reload duration")
			&"legs":
				check(injury.legs_injured and injury.get_movement_multiplier() == 1.0 and injury.get_jump_multiplier() == 0.5, "legs injury selects a movement mode and still reduces jump")
	health.reset_health()
	body.reset_body_health()
	injury.reset_injuries()
	for zone in [&"head", &"torso", &"arms", &"legs"]:
		body.apply_zone_damage(zone, body.get_zone_max_health(zone), info)
	check(is_equal_approx(injury.get_movement_multiplier(), 0.8) and is_equal_approx(injury.get_recoil_multiplier(), 2.025), "torso movement and combined recoil modifiers remain independent of leg movement mode")
	check(injury.get_spread_multiplier() == 1.5 and injury.get_reload_multiplier() == 1.35 and injury.get_jump_multiplier() == 0.5 and not health.is_dead(), "all injuries can coexist without killing a living Overall")
	injury.head_recoil_multiplier = 2.0
	injury.head_spread_multiplier = 3.0
	injury.arms_reload_multiplier = 2.0
	check(injury.get_recoil_multiplier() == 3.0 and injury.get_spread_multiplier() == 3.0 and injury.get_reload_multiplier() == 2.0, "exported injury parameters configure effective modifiers")
	var reset_count: int = events.reset
	injury.reset_injuries()
	check(events.reset == reset_count + 1 and injury.get_movement_multiplier() == 1.0 and injury.get_recoil_multiplier() == 1.0 and injury.get_reload_multiplier() == 1.0 and injury.get_spread_multiplier() == 1.0 and injury.get_jump_multiplier() == 1.0, "reset clears every flag and restores neutral modifiers")
	check(not injury.is_zone_injured(&"unknown") and body.get_zone_health(&"head") == 0.0, "injury query/reset never owns or modifies zone HP")
	injury.free()
	body.free()
	health.free()
	finish()

func finish() -> void:
	print("BODY_HEALTH_RESULT assertions=%d failures=%d" % [assertions, failures])
	quit(1 if failures > 0 else 0)

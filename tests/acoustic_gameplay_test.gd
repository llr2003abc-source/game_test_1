extends SceneTree

var failures: int = 0
var assertions: int = 0
var listener: Variant

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

func gunshots() -> Array:
	var result: Array = []
	for event in listener.events:
		if event.category == &"gunshot":
			result.append(event)
	return result

func set_rounds(firearm: Variant, count: int) -> void:
	firearm.set_trigger(false, false)
	firearm.state = 2
	firearm.chambered_round = null
	firearm.loaded_magazine.initialize_full(firearm.weapon_data.magazine_data)
	for i in range(30 - count):
		firearm.loaded_magazine.pop_round()
	firearm.chamber_next_round()
	firearm._physics_process(1.0)
	listener.clear_events()

func _run() -> void:
	var level: Node3D = load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player: Variant = level.get_node("Player")
	check(player.has_node("ActorNoiseEmitter"), "saved Player contains generic ActorNoiseEmitter")
	if failures > 0:
		level.queue_free()
		await process_frame
		finish()
		return
	listener = load("res://scripts/tests/debug_acoustic_listener.gd").new()
	root.add_child(listener)
	var emitter: Variant = player.get_node("ActorNoiseEmitter")
	check(emitter.source == player, "saved emitter source is its character")
	for action in [{"name": "sprint", "key": KEY_SHIFT}, {"name": "sneak", "key": KEY_CTRL}]:
		var binding_found: bool = false
		for event in InputMap.action_get_events(action.name):
			if event is InputEventKey and event.keycode == action.key:
				binding_found = true
		check(binding_found, "real Input Map binding: " + action.name)
	await frames(45)
	var firearm: Variant = player.get_node("Head/Camera3D/WeaponRoot")
	firearm.use_legacy_test_provider()
	player.set_physics_process(false)
	firearm.set_physics_process(false)
	var injury: Variant = player.get_node("BodyInjuryComponent")
	var health: Variant = player.get_node("HealthComponent")
	var body: Variant = player.get_node("BodyHealthComponent")
	Input.action_press("move_forward")
	for fixture in [{"mode": 1, "speed": 5.0, "aim": false, "sprint": false, "sneak": false}, {"mode": 2, "speed": 7.5, "aim": false, "sprint": true, "sneak": false}, {"mode": 0, "speed": 2.5, "aim": false, "sprint": true, "sneak": true}, {"mode": 3, "speed": 3.0, "aim": true, "sprint": true, "sneak": false}, {"mode": 3, "speed": 2.5, "aim": true, "sprint": false, "sneak": true}]:
		for action in ["aim", "sprint", "sneak"]:
			Input.action_release(action)
		if fixture.aim: Input.action_press("aim")
		if fixture.sprint: Input.action_press("sprint")
		if fixture.sneak: Input.action_press("sneak")
		player._physics_process(1.0 / 60.0)
		check(player.movement_mode == fixture.mode and is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), fixture.speed), "real movement resolves mode %d at %.1f m/s" % [fixture.mode, fixture.speed])
	for action in ["aim", "sprint", "sneak"]:
		Input.action_release(action)
	body.apply_zone_damage(&"legs", 24.0)
	player._physics_process(1.0 / 60.0)
	check(player.movement_mode == 1 and is_equal_approx(-player.velocity.z, 5.0), "partial leg HP does not start destroyed-zone injury mode")
	health.max_health = 1000.0
	health.reset_health()
	body.apply_zone_damage(&"legs", 70.0)
	body.apply_zone_damage(&"torso", 85.0)
	for aiming in [false, true]:
		if aiming: Input.action_press("aim")
		Input.action_press("sprint")
		player._physics_process(1.0 / 60.0)
		check(player.movement_mode == 4 and is_equal_approx(-player.velocity.z, 2.5), "injured speed is fixed 2.5 despite torso injury, Sprint and ADS")
		listener.clear_events()
		emitter.reset_position(Vector3.ZERO, true, 4, aiming)
		emitter.observe_movement(Vector3(0.9, 0, 0), Vector3(2.5, 0, 0), true, 4, aiming)
		check(listener.events.size() == 1 and listener.events[0].radius == 15.0 and listener.events[0].category == &"footstep_injured", "injured acoustic priority stays 15m including ADS")
	for action in ["aim", "sprint", "sneak", "move_forward"]:
		Input.action_release(action)
	var before_bases: Array = [player.normal_speed, player.aim_speed, player.sneak_speed, player.sprint_speed, player.injured_speed]
	body.reset_body_health()
	injury.reset_injuries()
	Input.action_press("move_forward")
	player._physics_process(1.0 / 60.0)
	check(player.movement_mode == 1 and is_equal_approx(-player.velocity.z, 5.0), "recovery resumes normal input mode")
	check(before_bases == [player.normal_speed, player.aim_speed, player.sneak_speed, player.sprint_speed, player.injured_speed], "injury does not overwrite exported base speeds")
	Input.action_release("move_forward")
	player.set_physics_process(true)
	listener.clear_events()
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(100)
	player.set_physics_process(false)
	var landing_events: Array = []
	for event in listener.events:
		if event.category == &"footstep_land": landing_events.append(event)
	check(landing_events.size() == 1 and landing_events[0].radius == 20.0 and landing_events[0].source == player and player.is_on_floor(), "real CharacterBody jump/land sends one 20m event")
	var actor: Variant = load("res://scenes/player/player.tscn").instantiate()
	actor.set_script(null)
	actor.name = "AI_TestActorWithoutBrain"
	actor.get_node("Head/Camera3D").current = false
	level.add_child(actor)
	actor.position = Vector3(8, 0, -20)
	var ai_emitter: Variant = actor.get_node("ActorNoiseEmitter")
	check(ai_emitter.source == actor, "non-Player actor uses saved component with its own source")
	var ai_firearm: Variant = actor.get_node("Head/Camera3D/WeaponRoot")
	ai_firearm.set_physics_process(false)
	for holder in [player, actor]:
		var gun: Variant = holder.get_node("Head/Camera3D/WeaponRoot")
		gun.use_legacy_test_provider()
		gun.weapon_data = gun.weapon_data.duplicate()
		gun.weapon_data.recoil_pitch = 0.0
		gun.weapon_data.recoil_yaw = 0.0
		gun.weapon_data.hip_spread_degrees = 0.0
		gun.weapon_data.ads_spread_degrees = 0.0
		var fired: Dictionary = {"count": 0}
		gun.shot_fired.connect(func(_pitch: float, _yaw: float) -> void: fired.count += 1)
		for model in [0, 1]:
			gun.weapon_data.fire_model = model
			gun.fire_mode = 0
			set_rounds(gun, 30)
			var before: int = fired.count
			var muzzle_position: Vector3 = gun.get_node("Muzzle").global_position
			gun.set_trigger(true, true)
			gun._physics_process(0.001)
			check(gunshots().size() == 1 and fired.count == before + 1, "%s model %d SEMI successful shot sends exactly one gunshot" % [holder.name, model])
			check(gunshots()[0].position == muzzle_position and gunshots()[0].source == holder and gunshots()[0].radius == 200.0, "gunshot contains actual muzzle, owner and WeaponData radius")
			for i in range(60):
				gun.set_trigger(true, false)
				gun._physics_process(1.0 / 60.0)
			check(gunshots().size() == 1, "held SEMI never spams noise")
			gun.set_trigger(false, false)
			var impacts: Dictionary = {"count": 0}
			if model == 1:
				for child in level.get_children():
					if child.scene_file_path == "res://scenes/weapons/ballistic_projectile.tscn" and child.source == holder:
						child.impacted.connect(func(_collider: Node3D, _position: Vector3, _normal: Vector3, _direction: Vector3, _ammo: Resource) -> void: impacts.count += 1)
			await frames(20)
			if model == 1:
				check(impacts.count > 0, "actual Projectile impact was observed by the test")
			check(gunshots().size() == 1, "Projectile impact or late processing cannot add gunshot")
			gun.fire_mode = 1
			for hz in [30, 60, 120]:
				set_rounds(gun, 30)
				before = fired.count
				for i in range(hz):
					gun.set_trigger(true, i == 0)
					gun._physics_process(1.0 / hz)
				check(gunshots().size() == fired.count - before and gunshots().size() >= 10 and gunshots().size() <= 11, "600RPM %dHz event count follows real AUTO shots" % hz)
				gun.set_trigger(false, false)
				set_rounds(gun, 30)
				gun.set_trigger(true, true)
				gun._physics_process(0.0)
				for i in range(1, hz):
					gun.set_trigger(true, false)
					gun._physics_process(1.0 / hz)
				check(gunshots().size() == 10, "600RPM emits exactly ten shots in [0,1) at %dHz" % hz)
				gun.set_trigger(false, false)
			set_rounds(gun, 2)
			gun.set_trigger(true, true)
			gun._physics_process(0.5)
			check(gunshots().size() == 2 and gun.chambered_round == null, "magazine empties after two actual gunshot events")
			listener.clear_events()
			gun.set_trigger(true, true)
			gun._physics_process(1.0)
			check(gunshots().is_empty(), "empty trigger sends no gunshot")
			gun.request_reload()
			gun.set_trigger(true, true)
			gun._physics_process(0.5)
			check(gun.state == 1 and gunshots().is_empty(), "reloading blocks gunshot events")
			gun.set_trigger(false, false)
			gun._physics_process(2.0)
			set_rounds(gun, 30)
			gun.fire_mode = 0
			gun.set_trigger(true, true)
			gun._physics_process(0.001)
			gun.set_trigger(false, false)
			gun.set_trigger(true, true)
			gun._physics_process(0.001)
			check(gunshots().size() == 1, "RPM-rejected click sends no gunshot")
			gun.set_trigger(false, false)
			gun._physics_process(0.2)
			var ammo_a: Variant = gun.weapon_data.magazine_data.default_ammo.duplicate()
			var ammo_b: Variant = ammo_a.duplicate()
			ammo_a.flesh_damage = 30.0
			ammo_b.flesh_damage = 50.0
			gun.chambered_round = ammo_a
			gun.loaded_magazine.clear()
			gun.loaded_magazine.push_round(ammo_b)
			gun.state = 0
			gun.weapon_data.gunshot_hearing_radius = 120.0
			listener.clear_events()
			for i in range(2):
				gun.set_trigger(true, true)
				gun._physics_process(0.001)
				gun.set_trigger(false, false)
				gun._physics_process(0.2)
			check(gunshots().size() == 2 and gunshots()[0].radius == 120.0 and gunshots()[1].radius == 120.0, "mixed ammo and alternative WeaponData use weapon hearing radius")
			gun.weapon_data.gunshot_hearing_radius = 200.0
			if model == 1:
				set_rounds(gun, 30)
				var short_lived_ammo: Variant = gun.weapon_data.magazine_data.default_ammo.duplicate()
				short_lived_ammo.max_flight_time = 0.01
				short_lived_ammo.gravity_scale = 0.0
				gun.chambered_round = short_lived_ammo
				var camera: Node3D = holder.get_node("Head/Camera3D")
				var original_rotation: Vector3 = camera.rotation
				camera.rotation.x = PI / 2.0
				gun.set_trigger(true, true)
				gun._physics_process(0.001)
				gun.set_trigger(false, false)
				var projectile: Node = level.get_child(level.get_child_count() - 1)
				await frames(3)
				check(not is_instance_valid(projectile) and gunshots().size() == 1, "Projectile expiration never adds gunshot events")
				camera.rotation = original_rotation
	listener.free()
	level.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("ACOUSTIC_GAMEPLAY_RESULT assertions=%d failures=%d" % [assertions, failures])
	quit(1 if failures > 0 else 0)

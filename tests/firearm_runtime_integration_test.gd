extends SceneTree

var assertions: int = 0
var failures: int = 0

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

func full_magazine(data: MagazineData, count: int = 30) -> MagazineInstance:
	var magazine := MagazineInstance.new()
	magazine.initialize_full(data)
	for i in range(data.capacity - count):
		magazine.pop_round()
	return magazine

func _run() -> void:
	var level: Node3D = load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player: Variant = level.get_node("Player")
	var firearm: Variant = player.get_node("Head/Camera3D/WeaponRoot")
	firearm.use_legacy_test_provider()
	player.set_physics_process(false)
	firearm.set_physics_process(false)
	check(firearm.has_method("bind_runtime") and firearm.has_method("unbind_runtime"), "Firearm exposes detachable Runtime binding")
	if failures > 0:
		level.queue_free()
		await process_frame
		finish()
		return
	var runtime_type: Variant = load("res://scripts/weapons/weapon_runtime.gd")
	var data: WeaponData = firearm.weapon_data.duplicate()
	data.hip_spread_degrees = 0.0
	data.ads_spread_degrees = 0.0
	data.recoil_pitch = 0.0
	data.recoil_yaw = 0.0
	var a: AmmoData = data.magazine_data.default_ammo.duplicate()
	var b: AmmoData = a.duplicate()
	a.flesh_damage = 30.0
	b.flesh_damage = 50.0
	var magazine: MagazineInstance = full_magazine(data.magazine_data, 17)
	var persistent: Variant = runtime_type.new()
	persistent.initialize(data, magazine, a)
	persistent.selected_fire_mode = 0
	persistent.fire_cooldown_remaining = 0.07
	var events: Dictionary = {"shots": 0, "updates": 0}
	firearm.shot_fired.connect(func(_pitch: float, _yaw: float) -> void: events.shots += 1)
	firearm.weapon_state_changed.connect(func(_mag: int, _chamber: bool, _spares: int, _state: int) -> void: events.updates += 1)
	var listener: Variant = load("res://scripts/tests/debug_acoustic_listener.gd").new()
	root.add_child(listener)
	firearm.bind_runtime(persistent)
	check(firearm.weapon_runtime == persistent and firearm.weapon_data == data and firearm.loaded_magazine == magazine and firearm.chambered_round == a and firearm.fire_mode == 0, "binding preserves original Runtime, definition, magazine, chamber and mode")
	check(persistent.fire_cooldown_remaining == 0.07 and magazine.get_round_count() == 17, "binding does not reset cooldown or refill ammunition")
	var hud: Label = level.get_node("CanvasLayer/AmmoLabel")
	check(hud.text == "MAG 17 | CHAMBER 1\nSPARE MAGS: 2", "existing HUD immediately reads new Runtime state")
	var detached: Variant = firearm.unbind_runtime()
	check(detached == persistent and persistent.loaded_magazine == magazine and persistent.chambered_round == a and persistent.selected_fire_mode == 0 and persistent.fire_cooldown_remaining == 0.07, "unbind returns intact independently-owned Runtime")
	var updates_before: int = events.updates
	persistent.chamber_next_round()
	persistent.state_changed.emit()
	check(events.updates == updates_before, "detached Runtime cannot notify former Firearm HUD")
	listener.clear_events()
	firearm.set_trigger(true, true)
	firearm.set_aiming(true)
	firearm._physics_process(1.0)
	check(events.shots == 0 and listener.events.is_empty() and not firearm.is_aiming and not firearm.get_node("Muzzle/MuzzleFlash").visible, "unbound Firearm produces no shot, acoustic, aim or muzzle feedback")
	var actor: Variant = load("res://scenes/player/player.tscn").instantiate()
	actor.set_script(null)
	actor.name = "SecondRuntimeExecutor"
	var second: Variant = actor.get_node("Head/Camera3D/WeaponRoot")
	second.bind_runtime(persistent)
	level.add_child(actor)
	second.set_physics_process(false)
	second.use_legacy_test_provider()
	check(second.weapon_runtime == persistent and persistent.loaded_magazine == magazine and persistent.chambered_round == a and persistent.fire_cooldown_remaining == 0.07, "binding before a new Firearm ready never initializes over restored state")
	actor.free()
	check(is_instance_valid(persistent) and persistent.loaded_magazine == magazine and magazine.get_round_count() == 17, "freeing an executor does not destroy externally-held Runtime")
	firearm.bind_runtime(persistent)
	check(persistent.fire_cooldown_remaining == 0.07 and events.shots == 0, "rebinding never carries an old trigger press into new execution")
	var target: Variant = level.get_node("DamageableTarget")
	target.get_node("ArmorComponent").unequip_armor()
	var health: Variant = target.get_node("HealthComponent")
	health.max_health = 1000.0
	var damage_events: Array = []
	health.damaged.connect(func(_amount: float, info: RefCounted) -> void: damage_events.append(info))
	var camera: Camera3D = player.get_node("Head/Camera3D")
	camera.look_at(target.get_node("Hurtboxes/Torso").global_position, Vector3.UP)
	for model in [0, 1]:
		data.fire_model = model
		target.reset_target()
		damage_events.clear()
		var mixed: MagazineInstance = full_magazine(data.magazine_data, 0)
		mixed.push_round(b)
		persistent.initialize(data, mixed, a)
		persistent.selected_fire_mode = 0
		firearm.publish_weapon_state()
		for expected in [a, b]:
			listener.clear_events()
			var before_shots: int = events.shots
			firearm.set_trigger(true, true)
			firearm._physics_process(0.001)
			firearm.set_trigger(false, false)
			await frames(4)
			check(events.shots == before_shots + 1 and listener.events.size() == 1 and listener.events[0].category == &"gunshot" and listener.events[0].source == player, "model %d Runtime success produces one shot and acoustic" % model)
			check(not damage_events.is_empty() and damage_events.back().ammo_data == expected and damage_events.back().base_flesh_damage == expected.flesh_damage, "model %d impact uses actual Runtime fired Ammo" % model)
			firearm._physics_process(0.2)
		check(health.current_health == 920.0 and persistent.state == 2 and mixed.is_empty(), "both real models preserve 30 + 50 torso damage and empty cycle")
		check(hud.text == "MAG 0 | CHAMBER 0\nSPARE MAGS: 2", "HUD reads actual empty Runtime")
		listener.clear_events()
		var before_shots: int = events.shots
		firearm.set_trigger(true, true)
		firearm._physics_process(0.01)
		check(events.shots == before_shots and listener.events.is_empty() and not firearm.get_node("Muzzle/MuzzleFlash").visible, "EMPTY rejection produces no feedback")
		persistent.initialize(data, null, a)
		persistent.fire_cooldown_remaining = 0.5
		firearm.set_trigger(true, true)
		firearm._physics_process(0.01)
		check(events.shots == before_shots and listener.events.is_empty() and persistent.chambered_round == a, "COOLDOWN rejection consumes no Ammo and produces no feedback")
		var replacement: MagazineInstance = full_magazine(data.magazine_data)
		persistent.begin_reload(replacement, 2.0)
		firearm.set_trigger(true, true)
		firearm._physics_process(0.1)
		check(events.shots == before_shots and listener.events.is_empty() and persistent.state == 1, "RELOADING rejection produces no feedback")
		firearm._physics_process(1.9)
		check(events.shots == before_shots and persistent.loaded_magazine == replacement and persistent.chambered_round == a, "reload completion preserves chamber and cannot fire in completion tick")
		firearm.set_trigger(false, false)
	var rebind_mag: MagazineInstance = full_magazine(data.magazine_data, 17)
	persistent.initialize(data, rebind_mag, b)
	persistent.selected_fire_mode = 0
	persistent.fire_cooldown_remaining = 0.08
	var final_replacement: MagazineInstance = full_magazine(data.magazine_data)
	persistent.begin_reload(final_replacement, 2.0)
	firearm.unbind_runtime()
	persistent.tick(0.5)
	check(persistent.state == 1 and persistent.reload_remaining == 1.5 and persistent.loaded_magazine == rebind_mag and persistent.chambered_round == b, "detached Runtime advances pure Reload timing without an executor")
	firearm.bind_runtime(persistent)
	check(hud.text.begins_with("Reloading...") and persistent.reload_remaining == 1.5 and persistent.selected_fire_mode == 0, "mid-reload rebind restores HUD and exact remaining state")
	firearm._physics_process(1.5)
	check(persistent.loaded_magazine == final_replacement and persistent.chambered_round == b and firearm.spare_magazines.has(rebind_mag) and rebind_mag.get_round_count() == 17, "rebound completion returns old reference to external Legacy provider")
	var state_updates: int = events.updates
	persistent.state_changed.emit()
	check(events.updates == state_updates + 1, "repeated binding cannot duplicate Runtime signal connections")
	listener.free()
	level.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("FIREARM_RUNTIME_INTEGRATION_RESULT assertions=%d failures=%d" % [assertions, failures])
	quit(1 if failures > 0 else 0)

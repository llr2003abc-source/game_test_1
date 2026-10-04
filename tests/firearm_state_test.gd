extends SceneTree

var failures: int = 0

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

func total_rounds(firearm: Node) -> int:
	var count: int = 1 if firearm.chambered_round != null else 0
	if firearm.loaded_magazine != null:
		count += firearm.loaded_magazine.get_round_count()
	for magazine in firearm.spare_magazines:
		count += magazine.get_round_count()
	return count

func shoot(firearm: Node) -> void:
	firearm.set_trigger(false, false)
	firearm._physics_process(0.2)
	firearm.set_trigger(true, true)
	firearm._physics_process(0.001)

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/weapons/magazine_instance.gd"), "MagazineInstance exists before Firearm tests")
	if failures > 0:
		print("FIREARM_STATE_RESULT failures=%d" % failures)
		quit(1)
		return
	var level: Node3D = load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player: Variant = level.get_node("Player")
	var firearm: Variant = player.get_node("Head/Camera3D/WeaponRoot")
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var target: Variant = level.get_node("DamageableTarget")
	# Preserve Phase 5 unarmored damage fixtures; armor is tested separately.
	target.get_node("ArmorComponent").unequip_armor()
	var health: Variant = target.get_node("HealthComponent")
	var hud: Label = level.get_node("CanvasLayer/AmmoLabel")
	player.set_physics_process(false)
	firearm.set_physics_process(false)
	firearm.weapon_data = firearm.weapon_data.duplicate()
	var projectile_mode: bool = OS.get_cmdline_user_args().has("--projectile")
	firearm.weapon_data.fire_model = WeaponData.FireModel.PROJECTILE if projectile_mode else WeaponData.FireModel.HITSCAN
	firearm.weapon_data.hip_spread_degrees = 0.0
	firearm.weapon_data.ads_spread_degrees = 0.0
	firearm.weapon_data.recoil_pitch = 0.0
	firearm.weapon_data.recoil_yaw = 0.0
	var events: Dictionary = {"shots": 0, "info": null, "mag": -1, "chamber": false, "spares": -1, "state": -1}
	firearm.shot_fired.connect(func(_pitch: float, _yaw: float) -> void: events.shots += 1)
	firearm.weapon_state_changed.connect(func(magazine_rounds: int, chamber_loaded: bool, spare_count: int, state: int) -> void:
		events.mag = magazine_rounds
		events.chamber = chamber_loaded
		events.spares = spare_count
		events.state = state)
	health.damaged.connect(func(_amount: float, info: RefCounted) -> void: events.info = info)
	await frames(3)
	firearm.publish_weapon_state()
	var default_ammo: Variant = firearm.weapon_data.magazine_data.default_ammo
	check(firearm.chambered_round == default_ammo and firearm.loaded_magazine.get_round_count() == 29 and firearm.state == 0, "initial state is READY with MAG 29 + CHAMBER 1")
	check(firearm.spare_magazines.size() == 2 and total_rounds(firearm) == 90, "start with exactly 90 rounds in three magazines and chamber")
	check(firearm.loaded_magazine != firearm.spare_magazines[0] and firearm.spare_magazines[0] != firearm.spare_magazines[1] and firearm.loaded_magazine != firearm.spare_magazines[1], "all three MagazineInstances are independent objects")
	check(firearm.fire_mode == firearm.weapon_data.fire_mode and firearm.fire_mode == 1, "fire mode initializes from WeaponData AUTO")
	check(events.mag == 29 and events.chamber and events.spares == 2 and events.state == 0, "state signal reports real magazine, chamber, spares and state")
	check(hud.text == "MAG 29 | CHAMBER 1\nSPARE MAGS: 2", "HUD consumes runtime state signal")
	var original_chamber: Variant = firearm.chambered_round
	check(not firearm.chamber_next_round() and firearm.chambered_round == original_chamber and firearm.loaded_magazine.get_round_count() == 29, "chamber operation never overwrites a loaded round")
	camera.look_at(camera.global_position + Vector3(0, 100, -1), Vector3.UP)
	firearm.fire_mode = 0
	shoot(firearm)
	check(events.shots == 1 and firearm.loaded_magazine.get_round_count() == 28 and firearm.chambered_round == default_ammo, "one shot consumes chamber then cycles MAG 28 + CHAMBER 1")
	check(total_rounds(firearm) == 89 and hud.text == "MAG 28 | CHAMBER 1\nSPARE MAGS: 2", "one shot reduces total ammunition by exactly one and updates HUD")

	for i in range(11):
		shoot(firearm)
	var old_magazine: Variant = firearm.loaded_magazine
	original_chamber = firearm.chambered_round
	var selected: Variant = firearm.select_reload_magazine()
	var before_reload_total: int = total_rounds(firearm)
	check(old_magazine.get_round_count() == 17 and original_chamber != null, "tactical fixture is MAG 17 + CHAMBER 1")
	check(selected != null and selected.get_round_count() == 30, "reload selects the fullest spare magazine")
	firearm.request_reload()
	check(firearm.state == 1 and firearm.loaded_magazine == old_magazine and firearm.chambered_round == original_chamber, "RELOADING preserves current magazine and chamber until completion")
	check(hud.text.begins_with("Reloading...") and events.state == 1, "HUD receives RELOADING through the state signal")
	var before_shots: int = events.shots
	firearm.set_trigger(true, true)
	firearm.request_reload()
	firearm._physics_process(1.9)
	check(events.shots == before_shots and firearm.state == 1 and total_rounds(firearm) == before_reload_total, "reload blocks firing and repeated R does not restart timer")
	firearm._physics_process(0.11)
	check(firearm.state == 0 and firearm.loaded_magazine == selected and firearm.loaded_magazine.get_round_count() == 30 and firearm.chambered_round == original_chamber, "tactical reload preserves chamber and installs a full 30-round magazine")
	check(firearm.spare_magazines.has(old_magazine) and old_magazine.get_round_count() == 17 and firearm.spare_magazines.size() == 2, "old 17-round magazine remains in spares without refilling")
	check(total_rounds(firearm) == before_reload_total and events.shots == before_shots, "reload conserves ammunition and completion tick does not fire")
	check(hud.text == "MAG 30 | CHAMBER 1\nSPARE MAGS: 2", "tactical reload HUD shows 30 + 1")
	firearm.request_reload()
	check(firearm.state == 0, "a full magazine with loaded chamber ignores redundant reload")

	# Exhaust the other spare in this fixture so selection returns the old partial one.
	for magazine in firearm.spare_magazines:
		if magazine != old_magazine:
			magazine.clear()
	shoot(firearm)
	check(firearm.select_reload_magazine() == old_magazine, "selection can return a previously removed partial magazine")
	original_chamber = firearm.chambered_round
	var removed_full_magazine: Variant = firearm.loaded_magazine
	firearm.request_reload()
	firearm._physics_process(2.01)
	check(firearm.loaded_magazine == old_magazine and old_magazine.get_round_count() == 17 and firearm.chambered_round == original_chamber, "reinstalling old magazine preserves its 17 rounds")
	check(firearm.spare_magazines.has(removed_full_magazine) and removed_full_magazine.get_round_count() == 29, "the newly removed magazine also keeps its remaining rounds")

	before_shots = events.shots
	for i in range(18):
		shoot(firearm)
	check(events.shots == before_shots + 18 and firearm.chambered_round == null and firearm.loaded_magazine.is_empty() and firearm.state == 2, "last chamber round fires and leaves EMPTY with MAG 0")
	before_shots = events.shots
	shoot(firearm)
	check(events.shots == before_shots and hud.text == "MAG 0 | CHAMBER 0\nSPARE MAGS: 2", "empty chamber cannot fire or consume phantom ammo")
	check(not firearm.chamber_next_round(), "empty magazine cannot chamber")
	for magazine in firearm.spare_magazines:
		magazine.initialize_full(firearm.weapon_data.magazine_data)
	old_magazine = firearm.loaded_magazine
	selected = firearm.select_reload_magazine()
	before_reload_total = total_rounds(firearm)
	firearm.request_reload()
	firearm._physics_process(2.01)
	check(firearm.loaded_magazine == selected and firearm.loaded_magazine.get_round_count() == 29 and firearm.chambered_round == default_ammo and firearm.state == 0, "empty reload chambers one from new 30-round magazine")
	check(firearm.spare_magazines.has(old_magazine) and old_magazine.is_empty() and total_rounds(firearm) == before_reload_total, "empty removed magazine is retained and reload generates no ammunition")

	for i in range(30):
		shoot(firearm)
	for magazine in firearm.spare_magazines:
		magazine.clear()
	check(firearm.select_reload_magazine() == null, "all empty spares yield no reload candidate")
	firearm.request_reload()
	check(firearm.state == 2 and firearm.chambered_round == null, "R with no ammunition does not start a fake reload")
	firearm.loaded_magazine = null
	check(not firearm.chamber_next_round() and firearm.state == 2, "no magazine cannot chamber")
	firearm.spare_magazines.clear()
	check(firearm.select_reload_magazine() == null, "no spare magazines yields no reload candidate")

	var ammo_a: Variant = load("res://scripts/weapons/ammo_data.gd").new()
	var ammo_b: Variant = load("res://scripts/weapons/ammo_data.gd").new()
	ammo_a.ammo_name = "Ammo A"
	ammo_a.flesh_damage = 30.0
	ammo_b.ammo_name = "Ammo B"
	ammo_b.flesh_damage = 50.0
	var mixed: Variant = load("res://scripts/weapons/magazine_instance.gd").new()
	mixed.initialize_full(firearm.weapon_data.magazine_data)
	mixed.clear()
	mixed.push_round(ammo_a)
	mixed.push_round(ammo_b)
	mixed.push_round(ammo_a)
	firearm.loaded_magazine = mixed
	check(firearm.chamber_next_round() and firearm.chambered_round == ammo_a and mixed.get_round_count() == 2, "mixed magazine chambers its first actual Ammo A")
	target.reset_target()
	camera.look_at(target.get_node("Hurtboxes/Torso").global_position, Vector3.UP)
	for shot in [{"ammo": ammo_a, "hp": 70.0, "next": ammo_b}, {"ammo": ammo_b, "hp": 20.0, "next": ammo_a}, {"ammo": ammo_a, "hp": 0.0, "next": null}]:
		var fired_round: Variant = firearm.chambered_round
		shoot(firearm)
		if projectile_mode:
			await frames(3)
		var info: Variant = events.info
		check(fired_round == shot.ammo and info != null and info.ammo_data == fired_round and info.base_flesh_damage == fired_round.flesh_damage, "DamageInfo uses the actual fired " + shot.ammo.ammo_name)
		check(is_equal_approx(health.current_health, shot.hp), "mixed-ammo torso HP -> %.0f" % shot.hp)
		check(firearm.chambered_round == shot.next, "cycle chambers the next actual round in order")
	check(health.is_dead() and firearm.state == 2 and mixed.is_empty(), "mixed-ammo damage reaches existing Death and weapon EMPTY")
	level.queue_free()
	await process_frame
	print("FIREARM_STATE_RESULT mode=%s failures=%d" % ["PROJECTILE" if projectile_mode else "HITSCAN", failures])
	quit(1 if failures > 0 else 0)

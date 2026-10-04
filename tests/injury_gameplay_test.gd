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

func _run() -> void:
	var level: Node3D = load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var player: Variant = level.get_node("Player")
	check(player.has_node("BodyInjuryComponent") and player.has_node("BodyHealthComponent") and player.has_node("HealthComponent"), "Player contains runtime body, injury and Overall components")
	if failures > 0:
		level.queue_free()
		await process_frame
		finish()
		return
	var firearm: Variant = player.get_node("Head/Camera3D/WeaponRoot")
	var body: Variant = player.get_node("BodyHealthComponent")
	var injury: Variant = player.get_node("BodyInjuryComponent")
	var health: Variant = player.get_node("HealthComponent")
	check(player.injury_component == injury and firearm.injury_component == injury and body.health_component == health and injury.body_health == body, "saved Player and Firearm share the Player injury provider")
	await frames(45)
	player.set_physics_process(false)
	firearm.set_physics_process(false)
	firearm.weapon_data = firearm.weapon_data.duplicate()
	firearm.weapon_data.fire_model = 0
	var data: Variant = firearm.weapon_data
	var base_values: Array = [player.normal_speed, player.aim_speed, player.jump_velocity, data.reload_time, data.recoil_pitch, data.recoil_yaw, data.hip_spread_degrees, data.ads_spread_degrees]
	var event: Dictionary = {"pitch": 0.0, "yaw": 0.0}
	firearm.shot_fired.connect(func(pitch: float, yaw: float) -> void:
		event.pitch = pitch
		event.yaw = yaw)
	firearm.fire_mode = 0
	firearm._random.seed = 54321
	firearm.set_trigger(true, true)
	firearm._physics_process(0.001)
	var baseline_recoil := Vector2(event.pitch, event.yaw)
	firearm.set_trigger(false, false)
	firearm._physics_process(0.2)
	var baseline_means: Array[float] = []
	for aiming in [false, true]:
		firearm.set_aiming(aiming)
		firearm._random.seed = 12345
		var total: float = 0.0
		for i in range(300):
			total += firearm._get_shot_direction().angle_to(Vector3.FORWARD)
		baseline_means.append(total / 300.0)
	body.apply_zone_damage(&"head", 80.0)
	check(health.current_health == 70.0 and not health.is_dead() and injury.head_injured, "Player head 80 injures head and leaves Overall 70 alive")
	var injured_means: Array[float] = []
	for aiming in [false, true]:
		firearm.set_aiming(aiming)
		firearm._random.seed = 12345
		var total: float = 0.0
		for i in range(300):
			total += firearm._get_shot_direction().angle_to(Vector3.FORWARD)
		injured_means.append(total / 300.0)
		check(absf(total / 300.0 / baseline_means[1 if aiming else 0] - 1.5) < 0.015, "actual %s shot spread increases by head injury 1.5" % ("ADS" if aiming else "Hip"))
	check(injured_means[0] > injured_means[1] * 5.0, "Hip/ADS spread difference survives injury")
	health.max_health = 1000.0
	health.reset_health()
	body.apply_zone_damage(&"arms", 60.0)
	player._pending_recoil = Vector2.ZERO
	firearm._random.seed = 54321
	firearm.set_trigger(true, true)
	firearm._physics_process(0.001)
	check(is_equal_approx(event.pitch, baseline_recoil.x * 2.025) and is_equal_approx(event.yaw, baseline_recoil.y * 2.025), "actual pitch and yaw recoil compose head 1.35 and arms 1.5")
	check(is_equal_approx(player._pending_recoil.x, event.pitch), "Player queues the modified recoil into its existing smoothing")
	var head: Node3D = player.get_node("Head")
	var before_pitch: float = head.rotation.x
	player._apply_recoil(1.0 / 60.0)
	check(head.rotation.x > before_pitch and head.rotation.x < before_pitch + event.pitch, "injured recoil remains smooth")
	firearm.set_trigger(false, false)
	firearm.request_reload()
	check(firearm.state == 1 and is_equal_approx(firearm._reload_remaining, 2.7) and data.reload_time == 2.0, "arms injury starts effective 2.7-second reload without mutating WeaponData")
	firearm._physics_process(2.69)
	check(firearm.state == 1, "injured reload does not finish before 2.7 seconds")
	firearm._physics_process(0.02)
	check(firearm.state == 0 and firearm.loaded_magazine.get_round_count() == 30, "injured tactical reload retains its existing magazine/chamber behavior")
	body.apply_zone_damage(&"torso", 85.0)
	body.apply_zone_damage(&"legs", 70.0)
	player.rotation = Vector3.ZERO
	Input.action_press("move_forward")
	player._physics_process(1.0 / 60.0)
	check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), 2.5), "actual leg-injured movement uses fixed 2.5 m/s despite torso injury")
	Input.action_press("aim")
	player._physics_process(1.0 / 60.0)
	check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), 2.5), "actual leg-injured ADS keeps fixed 2.5 m/s")
	Input.action_release("move_forward")
	Input.action_release("aim")
	Input.action_press("jump")
	var before_y: float = player.position.y
	player._physics_process(1.0 / 60.0)
	check(is_equal_approx(player.velocity.y, 2.5) and player.position.y > before_y, "injured legs still jump with velocity 5 x 0.5 = 2.5")
	Input.action_release("jump")
	check(base_values == [player.normal_speed, player.aim_speed, player.jump_velocity, data.reload_time, data.recoil_pitch, data.recoil_yaw, data.hip_spread_degrees, data.ads_spread_degrees], "all injuries leave original player and WeaponData base parameters unchanged")
	body.reset_body_health()
	injury.reset_injuries()
	check(injury.get_movement_multiplier() == 1.0 and injury.get_recoil_multiplier() == 1.0 and injury.get_spread_multiplier() == 1.0 and injury.get_reload_multiplier() == 1.0 and injury.get_jump_multiplier() == 1.0, "reset removes all gameplay modifiers")
	level.queue_free()
	await process_frame
	finish()

func finish() -> void:
	print("INJURY_GAMEPLAY_RESULT assertions=%d failures=%d" % [assertions, failures])
	quit(1 if failures > 0 else 0)

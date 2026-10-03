extends SceneTree

var failures: int = 0
var shots: int = 0

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

func _on_shot(_pitch: float, _yaw: float) -> void:
	shots += 1

func markers(level: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in level.get_children():
		if child.scene_file_path == "res://scenes/weapons/hit_marker.tscn":
			result.append(child)
	return result

func _run() -> void:
	for path in ["res://scripts/weapons/weapon_data.gd", "res://scripts/weapons/firearm.gd", "res://scripts/weapons/ammo_hud.gd", "res://data/weapons/test_rifle.tres"]:
		check(FileAccess.file_exists(path), "required file: " + path)
	if failures > 0:
		quit(1)
		return
	var packed: PackedScene = load("res://scenes/levels/test_level.tscn")
	var level: Node3D = packed.instantiate()
	root.add_child(level)
	current_scene = level
	var player: Variant = level.get_node("Player")
	var firearm: Variant = player.get_node("Head/Camera3D/WeaponRoot")
	var camera: Camera3D = player.get_node("Head/Camera3D")
	var head: Node3D = player.get_node("Head")
	var label: Label = level.get_node("CanvasLayer/AmmoLabel")
	var flash: OmniLight3D = firearm.get_node("Muzzle/MuzzleFlash")
	firearm.shot_fired.connect(_on_shot)
	await frames(45)
	check(firearm.current_ammo == 30 and label.text == "30 / 30", "initial magazine and HUD 30 / 30")
	check(firearm.fire_mode == 1, "default fire mode AUTO")
	check(player.is_on_floor(), "gravity and floor collision preserved")
	player.set_physics_process(false)
	firearm.set_physics_process(false)
	firearm.weapon_data = firearm.weapon_data.duplicate()
	var data: Variant = firearm.weapon_data
	data.hip_spread_degrees = 0.0
	data.ads_spread_degrees = 0.0
	data.recoil_pitch = 0.0
	data.recoil_yaw = 0.0
	firearm.fire_mode = 0
	var before: int = shots
	firearm.set_trigger(true, true)
	firearm._physics_process(0.001)
	check(shots == before + 1 and firearm.current_ammo == 29 and label.text == "29 / 30", "single click consumes one round and updates HUD")
	check(flash.visible, "shot briefly enables muzzle light")
	for i in range(60):
		firearm.set_trigger(true, false)
		firearm._physics_process(1.0 / 60.0)
	check(shots == before + 1, "SEMI does not repeat while held")
	check(not flash.visible, "muzzle light turns off")
	firearm.set_trigger(false, false)
	firearm._physics_process(0.5)
	firearm.set_trigger(true, true)
	firearm._physics_process(0.001)
	check(shots == before + 2, "SEMI second click fires")
	firearm.set_trigger(false, false)
	firearm._physics_process(0.01)
	firearm.set_trigger(true, true)
	firearm._physics_process(0.01)
	check(shots == before + 2, "rapid SEMI click respects RPM cooldown")
	var counts: Array[int] = []
	firearm.fire_mode = 1
	for hz in [30, 60, 120]:
		firearm.current_ammo = 30
		firearm.set_trigger(false, false)
		firearm._physics_process(0.5)
		before = shots
		for i in range(hz):
			firearm.set_trigger(true, i == 0)
			firearm._physics_process(1.0 / float(hz))
		var fired: int = shots - before
		counts.append(fired)
		check(fired >= 10 and fired <= 11, "600 RPM gives 10 shots/sec at " + str(hz) + " Hz (actual " + str(fired) + ")")
	check(counts.max() - counts.min() <= 1, "RPM independent of timestep")
	firearm.set_trigger(false, false)
	firearm._physics_process(5.0)
	firearm.current_ammo = 30
	before = shots
	firearm.set_trigger(true, true)
	firearm._physics_process(0.01)
	check(shots == before + 1, "idle time does not accumulate burst credit")
	firearm.set_trigger(false, false)
	firearm._physics_process(0.5)
	firearm.current_ammo = 3
	before = shots
	for i in range(60):
		firearm.set_trigger(true, i == 0)
		firearm._physics_process(1.0 / 60.0)
	check(shots == before + 3 and firearm.current_ammo == 0 and label.text == "0 / 30", "empty magazine stops AUTO exactly at zero")
	firearm._physics_process(2.0)
	check(shots == before + 3, "empty trigger cannot fire")
	firearm.request_reload()
	check(firearm.is_reloading and label.text == "Reloading...", "reload starts and HUD shows Reloading")
	before = shots
	firearm.set_trigger(true, true)
	firearm._physics_process(1.9)
	check(firearm.current_ammo == 0 and shots == before and firearm.is_reloading, "reload blocks fire and does not finish early")
	firearm._physics_process(0.11)
	check(not firearm.is_reloading and firearm.current_ammo == 30 and shots == before and label.text == "30 / 30", "reload completes after two seconds without firing on completion frame")
	firearm.set_trigger(false, false)
	firearm._physics_process(0.5)
	firearm.request_reload()
	check(not firearm.is_reloading, "full magazine ignores reload")
	data.hip_spread_degrees = 1.5
	data.ads_spread_degrees = 0.25
	player.rotation.y = PI / 2.0
	head.rotation.x = 0.3
	var forward: Vector3 = (camera.global_basis * Vector3.FORWARD).normalized()
	var spread_means: Array[float] = []
	for aiming in [false, true]:
		firearm.set_aiming(aiming)
		var sum_angle: float = 0.0
		var max_angle: float = 0.0
		for i in range(1000):
			var direction: Vector3 = firearm._get_shot_direction()
			var angle: float = rad_to_deg(forward.angle_to(direction))
			sum_angle += angle
			max_angle = maxf(max_angle, angle)
		spread_means.append(sum_angle / 1000.0)
		check(max_angle <= (0.36 if aiming else 2.13), "spread follows rotated and pitched camera basis")
	check(spread_means[0] > 0.5 and spread_means[0] > spread_means[1] * 4.0, "ADS spread clearly tighter than hip spread")
	print("SPREAD_MEANS_DEGREES hip=" + str(spread_means[0]) + " ads=" + str(spread_means[1]))
	data.hip_spread_degrees = 0.0
	data.ads_spread_degrees = 0.0
	data.recoil_pitch = 0.8
	data.recoil_yaw = 0.25
	player.rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	firearm.fire_mode = 0
	firearm.set_trigger(true, true)
	firearm._physics_process(0.01)
	check(absf(head.rotation.x) < 0.00001, "recoil is queued rather than instant camera teleport")
	player._apply_recoil(1.0 / 60.0)
	check(head.rotation.x > 0.0 and head.rotation.x < deg_to_rad(0.8), "pitch recoil applies smoothly upward")
	check(absf(player.rotation.y) > 0.0000001 and absf(player.rotation.y) < deg_to_rad(0.25), "small random yaw recoil works")
	data.recoil_pitch = 0.0
	data.recoil_yaw = 0.0
	player._pending_recoil = Vector2.ZERO
	player.rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	for marker in markers(level):
		marker.queue_free()
	await frames(2)
	for target_name in ["Target_01", "Target_02", "Target_03"]:
		camera.look_at(level.get_node(target_name).global_position, Vector3.UP)
		firearm.set_trigger(false, false)
		firearm._physics_process(0.5)
		before = markers(level).size()
		firearm.set_trigger(true, true)
		firearm._physics_process(0.01)
		check(markers(level).size() == before + 1, "existing HitMarker generated on " + target_name + " (self excluded)")
	camera.rotation = Vector3(PI / 2.0, 0, 0)
	firearm.set_trigger(false, false)
	firearm._physics_process(0.5)
	before = markers(level).size()
	firearm.set_trigger(true, true)
	firearm._physics_process(0.01)
	check(markers(level).size() == before, "hitscan miss does not create marker")
	await create_timer(3.2).timeout
	check(markers(level).is_empty(), "original HitMarker still expires after 3 seconds")
	camera.rotation = Vector3.ZERO
	player.set_physics_process(true)
	firearm.set_physics_process(true)
	firearm.fire_mode = 1
	firearm.set_trigger(false, false)
	await frames(5)
	var start: Vector3 = player.position
	Input.action_press("move_forward")
	await frames(12)
	check(player.position.z < start.z - 0.3 and is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), 5.0), "W movement still 5 m/s")
	Input.action_press("move_right")
	await frames(5)
	check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), 5.0), "diagonal movement speed preserved")
	Input.action_release("move_forward")
	Input.action_release("move_right")
	Input.action_press("aim")
	Input.action_press("move_right")
	await frames(30)
	check(absf(camera.fov - 55.0) < 0.15 and is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), 3.0), "ADS FOV and 3 m/s movement preserved")
	check(firearm.is_aiming, "Player passes ADS state to Firearm")
	Input.action_release("move_right")
	Input.action_release("aim")
	await frames(60)
	check(absf(camera.fov - 75.0) < 0.1, "ADS release restores FOV 75")
	for action in ["move_forward", "move_backward", "move_left", "move_right"]:
		start = player.position
		Input.action_press(action)
		await frames(8)
		Input.action_release(action)
		var displacement: Vector3 = player.position - start
		var expected: Vector3 = {"move_forward": Vector3.FORWARD, "move_backward": Vector3.BACK, "move_left": Vector3.LEFT, "move_right": Vector3.RIGHT}[action]
		check(displacement.dot(expected) > 0.3, "WASD direction works: " + action)
		await frames(2)
	var floor_y: float = player.position.y
	Input.action_press("jump")
	await frames(6)
	Input.action_release("jump")
	check(player.position.y > floor_y + 0.2, "Space jump preserved")
	await frames(100)
	check(player.is_on_floor(), "jump lands normally")
	var motion := InputEventMouseMotion.new()
	motion.screen_relative = Vector2(100, 100000)
	player._unhandled_input(motion)
	check(absf(player.rotation.y) > 0.01 and absf(head.rotation.x) <= deg_to_rad(89.0) + 0.00001, "mouse yaw and pitch clamp preserved")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	player._unhandled_input(escape)
	await frames(2)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not firearm._trigger_held, "Esc releases cursor and stops firing")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	before = shots
	Input.parse_input_event(click)
	await frames(3)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and shots == before, "recapture click does not fire")
	click.pressed = false
	Input.parse_input_event(click)
	await frames(2)
	firearm.current_ammo = 29
	Input.action_press("reload")
	await frames(2)
	Input.action_release("reload")
	check(firearm.is_reloading, "R reload request reaches Firearm")
	await create_timer(2.2).timeout
	check(not firearm.is_reloading and firearm.current_ammo == 30 and label.text == "30 / 30", "real-time reload completes and restores HUD")
	print("FPS_REGRESSION_RESULT failures=" + str(failures))
	level.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)

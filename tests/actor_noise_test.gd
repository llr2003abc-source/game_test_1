extends SceneTree

var failures: int = 0
var assertions: int = 0
var emitter: Variant
var listener: Variant

func check(condition: bool, message: String) -> void:
	assertions += 1
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func reset(mode: int, aiming: bool = false) -> void:
	emitter.reset_position(Vector3.ZERO, true, mode, aiming)
	listener.clear_events()

func sample(x: float, speed: float, grounded: bool, mode: int, aiming: bool = false, y: float = 0.0) -> void:
	emitter.observe_movement(Vector3(x, y, 0), Vector3(speed, 0, 0), grounded, mode, aiming)

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/systems/actor_noise_emitter.gd"), "ActorNoiseEmitter exists before distance tests")
	if failures > 0:
		finish()
		return
	listener = load("res://scripts/tests/debug_acoustic_listener.gd").new()
	root.add_child(listener)
	var sources: Array[Node3D] = [Node3D.new(), Node3D.new()]
	sources[0].name = "PlayerSource"
	sources[1].name = "AI_SourceWithoutInput"
	for source in sources:
		root.add_child(source)
	emitter = load("res://scripts/systems/actor_noise_emitter.gd").new()
	emitter.source = sources[0]
	root.add_child(emitter)
	var profiles: Array = [
		{"mode": 0, "speed": 2.5, "full": 2, "total": 3, "radius": 5.0, "category": &"footstep_sneak"},
		{"mode": 1, "speed": 5.0, "full": 4, "total": 4, "radius": 15.0, "category": &"footstep_walk"},
		{"mode": 2, "speed": 7.5, "full": 5, "total": 6, "radius": 30.0, "category": &"footstep_sprint"},
		{"mode": 3, "speed": 3.0, "full": 3, "total": 4, "radius": 5.0, "category": &"footstep_ads"},
		{"mode": 4, "speed": 2.5, "full": 2, "total": 3, "radius": 15.0, "category": &"footstep_injured"}]
	for source in sources:
		emitter.source = source
		for hz in [30, 60, 120]:
			for profile in profiles:
				reset(profile.mode, profile.mode == 3)
				for i in range(1, hz + 1):
					sample(profile.speed * i / hz, profile.speed, true, profile.mode, profile.mode == 3)
				check(listener.events.size() == profile.full, "%s mode %d %dHz one second produces distance steps, not frames" % [source.name, profile.mode, hz])
				sample(profile.speed, 0.0, true, profile.mode, profile.mode == 3)
				check(listener.events.size() == profile.total and emitter.distance_accumulator == 0.0, "stop settles once mode %d %dHz" % [profile.mode, hz])
				var fields_correct: bool = true
				for event in listener.events:
					fields_correct = fields_correct and event.source == source and event.radius == profile.radius and event.category == profile.category
				check(fields_correct, "complete-step and stop events retain mode, radius and real source")
				for i in range(hz):
					sample(profile.speed, 0.0, true, profile.mode, profile.mode == 3)
				check(listener.events.size() == profile.total, "stationary frames never repeat stop flush")
			for mode in [0, 3, 4]:
				for fixture in [{"distance": 0.1, "count": 0}, {"distance": 0.3, "count": 1}, {"distance": 0.8, "count": 1}, {"distance": 0.95, "count": 1}]:
					reset(mode, mode == 3)
					for i in range(1, hz + 1):
						sample(fixture.distance * i / hz, fixture.distance, true, mode, mode == 3)
					sample(fixture.distance, 0.0, true, mode, mode == 3)
					check(listener.events.size() == fixture.count, "partial %.2fm mode %d %dHz" % [fixture.distance, mode, hz])
			for fixture in [{"mode": 1, "distance": 0.29, "count": 0}, {"mode": 1, "distance": 0.30, "count": 1}, {"mode": 1, "distance": 1.25, "count": 1}, {"mode": 2, "distance": 0.39, "count": 0}, {"mode": 2, "distance": 0.40, "count": 1}, {"mode": 2, "distance": 1.45, "count": 1}]:
				reset(fixture.mode)
				for i in range(1, hz + 1):
					sample(fixture.distance * i / hz, fixture.distance, true, fixture.mode)
				sample(fixture.distance, 0.0, true, fixture.mode)
				check(listener.events.size() == fixture.count, "Walk/Sprint partial %.2fm mode %d %dHz" % [fixture.distance, fixture.mode, hz])
			reset(1)
			for i in range(hz):
				sample(0.0, 5.0, true, 1)
			check(listener.events.is_empty(), "blocked movement input with no displacement is silent")
			for i in range(hz):
				sample(float(i + 1), 5.0, false, 1, false, float(i))
			check(listener.events.is_empty(), "airborne and vertical travel produce no footsteps")
			sample(float(hz), 0.0, true, 1)
			check(listener.events.size() == 1 and listener.events[0].category == &"footstep_land" and listener.events[0].radius == 20.0 and listener.events[0].source == source, "air to ground emits one independent 20m landing")
			for i in range(hz):
				sample(float(hz), 0.0, true, 1)
			check(listener.events.size() == 1, "grounded frames never repeat landing")
			for transition in [[1, 2], [1, 3], [1, 4], [3, 4], [4, 3]]:
				var old_profile: Dictionary = profiles[transition[0]]
				var new_profile: Dictionary = profiles[transition[1]]
				reset(old_profile.mode, old_profile.mode == 3)
				for i in range(1, hz + 1):
					sample(0.4 * i / hz, 1.0, true, old_profile.mode, old_profile.mode == 3)
				sample(0.4, 0.0, true, new_profile.mode, new_profile.mode in [3, 4])
				check(listener.events.size() == 1 and listener.events[0].category == old_profile.category and listener.events[0].radius == old_profile.radius and listener.events[0].source == source and emitter.distance_accumulator == 0.0, "%s %dHz mode %d to %d settles old profile once" % [source.name, hz, old_profile.mode, new_profile.mode])
				var next_step: float = 1.4 if new_profile.mode == 2 else 0.9
				for i in range(1, hz + 1):
					sample(0.4 + next_step * i / hz, new_profile.speed, true, new_profile.mode, new_profile.mode in [3, 4])
				sample(0.4 + next_step, 0.0, true, new_profile.mode, new_profile.mode in [3, 4])
				check(listener.events.size() == 2 and listener.events[1].category == new_profile.category and listener.events[1].radius == new_profile.radius and listener.events[1].source == source, "new mode uses its own step/radius without inherited residual or duplicate stop")
		for mode in range(5):
			reset(mode)
			sample(0.4, 1.0, true, mode)
			sample(3.0, 1.0, false, mode, true, 2.0)
			sample(5.0, 1.0, true, mode, true)
			check(listener.events.size() == 1 and listener.events[0].category == &"footstep_land" and emitter.distance_accumulator == 0.0, "landing clears residual and suppresses simultaneous step/flush in mode " + str(mode))
	reset(1)
	sample(0.4, 5.0, true, 1)
	sample(0.4, 0.0, true, 2)
	check(listener.events.size() == 1 and listener.events[0].category == &"footstep_walk" and emitter.distance_accumulator == 0.0, "mode change plus stop settles old Walk once")
	sample(1.8, 7.5, true, 2)
	check(listener.events.size() == 2 and listener.events.back().category == &"footstep_sprint", "new Sprint starts its own distance accumulation")
	reset(1)
	sample(0.1, 1.0, true, 1)
	sample(0.1, 0.0, true, 2)
	check(listener.events.is_empty() and emitter.distance_accumulator == 0.0, "tiny old-mode residual is discarded")
	for i in range(10):
		var x: float = 0.1 + (i + 1) * 0.01
		sample(x, 1.0, true, 2)
		sample(x, 0.0, true, 2)
	check(listener.events.is_empty(), "independent tiny inputs cannot accumulate into a step")
	reset(3, true)
	sample(0.3, 3.0, true, 3, true)
	sample(0.3, 2.5, true, 4, true)
	check(listener.events.size() == 1 and listener.events[0].category == &"footstep_ads" and emitter.distance_accumulator == 0.0, "new leg injury settles old ADS once")
	sample(0.7, 2.5, true, 4, true)
	sample(0.7, 2.5, true, 4, false)
	check(listener.events.size() == 1 and is_equal_approx(emitter.distance_accumulator, 0.4), "ADS toggle while injured preserves residual")
	sample(1.2, 2.5, true, 4, true)
	check(listener.events.size() == 2 and listener.events.back().category == &"footstep_injured" and listener.events.back().radius == 15.0, "injury beats ADS with 15m steps")
	sample(1.5, 2.5, true, 4, true)
	sample(1.5, 3.0, true, 3, true)
	check(listener.events.size() == 3 and listener.events.back().category == &"footstep_injured" and emitter.distance_accumulator == 0.0, "recovery into ADS settles injury residual first")
	reset(1)
	sample(6.0, 5.0, true, 1)
	check(listener.events.size() == 5 and absf(emitter.distance_accumulator) < 0.00001, "large displacement uses while loop without losing distance")
	emitter.reset_position(Vector3(100, 50, 0), true, 1, false)
	listener.clear_events()
	emitter.observe_movement(Vector3(100, 50, 0), Vector3.ZERO, true, 1, false)
	check(listener.events.is_empty(), "explicit teleport baseline does not emit motion or landing")
	var fresh: Variant = load("res://scripts/systems/actor_noise_emitter.gd").new()
	fresh.source = sources[1]
	root.add_child(fresh)
	fresh.observe_movement(Vector3(500, 0, 0), Vector3.ZERO, true, 1, false)
	check(listener.events.is_empty(), "first grounded spawn only establishes a baseline")
	fresh.reset_position(Vector3(0, 5, 0), false, 1, false)
	fresh.observe_movement(Vector3.ZERO, Vector3.ZERO, true, 1, false)
	check(listener.events.size() == 1 and listener.events.back().category == &"footstep_land", "real airborne spawn landing is audible")
	reset(0)
	emitter.sneak_noise_radius = 8.0
	emitter.sneak_step_distance = 0.5
	emitter.sneak_stop_flush_min_distance = 0.2
	sample(1.1, 3.0, true, 3, true)
	sample(1.1, 0.0, true, 3, true)
	check(listener.events.size() == 2 and listener.events[0].radius == 8.0 and listener.events[0].category == &"footstep_ads", "ADS follows configured Sneak parameters instead of copied defaults")
	fresh.free()
	emitter.free()
	listener.free()
	for source in sources:
		source.free()
	finish()

func finish() -> void:
	print("ACTOR_NOISE_RESULT assertions=%d failures=%d" % [assertions, failures])
	quit(1 if failures > 0 else 0)

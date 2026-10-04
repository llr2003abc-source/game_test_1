extends SceneTree

var assertions: int = 0
var failures: int = 0
var runtime_type: Variant
var fire_result_type: Variant

func check(condition: bool, message: String) -> void:
	assertions += 1
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func magazine(data: MagazineData, count: int) -> MagazineInstance:
	var result := MagazineInstance.new()
	result.initialize_full(data)
	for i in range(data.capacity - count):
		result.pop_round()
	return result

func _run() -> void:
	for path in ["res://scripts/weapons/weapon_runtime.gd", "res://scripts/weapons/weapon_fire_result.gd", "res://scripts/weapons/weapon_reload_result.gd"]:
		check(FileAccess.file_exists(path), "required runtime boundary: " + path)
	if failures > 0:
		finish()
		return
	runtime_type = load("res://scripts/weapons/weapon_runtime.gd")
	fire_result_type = load("res://scripts/weapons/weapon_fire_result.gd")
	var data: WeaponData = load("res://data/weapons/test_rifle.tres")
	var ammo: AmmoData = data.magazine_data.default_ammo
	var runtime: Variant = runtime_type.new()
	runtime.initialize(data)
	check(runtime.weapon_data == data and runtime.loaded_magazine == null and runtime.chambered_round == null and runtime.state == 2, "empty initialization retains definition and is EMPTY")
	check(runtime.selected_fire_mode == 1, "selected mode starts from static AUTO default")
	check(not runtime.chamber_next_round(), "no magazine cannot chamber")
	var result: Variant = runtime.try_fire()
	check(not result.success and result.fired_round == null and result.failure_reason == fire_result_type.FailureReason.EMPTY, "empty fire returns EMPTY with no fictitious round")
	check(runtime.fire_cooldown_remaining == 0.0, "failed empty fire cannot start cooldown")
	var original: MagazineInstance = magazine(data.magazine_data, 30)
	runtime.initialize(data, original)
	check(runtime.loaded_magazine == original and original.get_round_count() == 30 and runtime.chambered_round == null, "initialization never clones or automatically chambers a supplied magazine")
	check(runtime.chamber_next_round() and runtime.chambered_round == ammo and original.get_round_count() == 29, "explicit initial chamber gives exactly 29 + 1")
	check(not runtime.chamber_next_round() and original.get_round_count() == 29, "a loaded chamber is never overwritten")
	result = runtime.try_fire()
	check(result.success and result.fired_round == ammo and result.failure_reason == 0, "successful fire returns the actual chamber round")
	check(runtime.chambered_round == ammo and original.get_round_count() == 28 and runtime.loaded_magazine == original, "fire cycles same magazine reference to 28 + 1")
	check(is_equal_approx(runtime.fire_cooldown_remaining, 0.1), "600RPM starts a 0.1 second cooldown")
	result = runtime.try_fire()
	check(not result.success and result.failure_reason == fire_result_type.FailureReason.COOLDOWN and original.get_round_count() == 28, "cooldown rejection consumes no round")
	runtime.tick(0.09)
	check(not runtime.try_fire().success, "0.09 seconds is too early")
	runtime.tick(0.01)
	check(runtime.try_fire().success and original.get_round_count() == 27, "0.1 elapsed seconds allows next round")
	for invalid_delta in [-1.0, NAN, INF, -INF]:
		var cooldown_before: float = runtime.fire_cooldown_remaining
		runtime.tick(invalid_delta)
		check(runtime.fire_cooldown_remaining == cooldown_before and original.get_round_count() == 27, "invalid delta leaves timer and rounds unchanged")
	runtime.tick(100.0)
	check(runtime.fire_cooldown_remaining == 0.0 and runtime.try_fire().success and not runtime.try_fire().success, "idle time cannot bank an immediate future burst")
	var a: AmmoData = ammo.duplicate()
	var b: AmmoData = ammo.duplicate()
	var c: AmmoData = ammo.duplicate()
	a.flesh_damage = 30.0
	b.flesh_damage = 50.0
	c.flesh_damage = 17.0
	var mixed: MagazineInstance = magazine(data.magazine_data, 0)
	for round_data in [a, b, a, c]:
		mixed.push_round(round_data)
	runtime.initialize(data, mixed)
	runtime.chamber_next_round()
	for expected in [a, b, a, c]:
		result = runtime.try_fire()
		check(result.success and result.fired_round == expected and result.fired_round.flesh_damage == expected.flesh_damage, "mixed sequence returns actual A/B/A/C resource")
		runtime.tick(0.1)
	check(runtime.chambered_round == null and mixed.is_empty() and runtime.state == 2 and not runtime.try_fire().success, "last mixed round leaves EMPTY without phantom cycling")
	runtime.initialize(data, null, b)
	check(runtime.loaded_magazine == null and runtime.chambered_round == b and runtime.state == 0, "explicit chamber-only initialization preserves that real round")
	check(runtime.try_fire().fired_round == b and runtime.state == 2, "chamber-only weapon can fire its one round")
	var old: MagazineInstance = magazine(data.magazine_data, 17)
	var replacement: MagazineInstance = magazine(data.magazine_data, 30)
	runtime.initialize(data, old, a)
	check(not runtime.can_begin_reload(null) and not runtime.can_begin_reload(old), "null or current magazine cannot be replacement")
	check(not runtime.can_begin_reload(magazine(data.magazine_data, 0)), "empty external replacement is rejected")
	for duration in [-2.0, NAN, INF]:
		check(not runtime.begin_reload(replacement, duration) and runtime.loaded_magazine == old and runtime.state == 0, "invalid reload duration leaves state unchanged")
	check(runtime.begin_reload(replacement, 2.7) and runtime.state == 1 and runtime.reload_type == 1, "external effective duration starts Tactical Reload")
	check(runtime.loaded_magazine == old and runtime.chambered_round == a and runtime.reload_remaining == 2.7, "reload wait preserves old magazine and chamber")
	check(not runtime.try_fire().success and runtime.try_fire().failure_reason == fire_result_type.FailureReason.RELOADING, "runtime itself rejects firing while reloading")
	check(not runtime.begin_reload(replacement, 2.0) and runtime.reload_remaining == 2.7, "repeated reload never restarts the timer")
	for invalid_delta in [-1.0, NAN, INF]:
		runtime.tick(invalid_delta)
		check(runtime.reload_remaining == 2.7 and runtime.loaded_magazine == old, "invalid reload tick preserves state")
	runtime.tick(2.6)
	check(runtime.state == 1 and runtime.reload_remaining > 0.0, "reload cannot finish early")
	check(not runtime.finish_reload().success and runtime.loaded_magazine == old, "finish_reload cannot bypass remaining time")
	var completions: Array = []
	runtime.reload_finished.connect(func(completed: RefCounted) -> void: completions.append(completed))
	runtime.tick(0.1)
	check(runtime.state == 0 and runtime.loaded_magazine == replacement and runtime.chambered_round == a and replacement.get_round_count() == 30, "Tactical completion keeps exact chamber and new 30-round magazine")
	check(completions.size() == 1 and completions[0].success and completions[0].old_magazine == old and completions[0].new_magazine == replacement and old.get_round_count() == 17, "completion returns both original magazine identities once")
	runtime.tick(10.0)
	check(completions.size() == 1 and not runtime.finish_reload().success, "completed reload cannot swap or notify twice")
	check(not runtime.begin_reload(old, 2.0), "full magazine plus chamber ignores redundant reload")
	var empty_old: MagazineInstance = magazine(data.magazine_data, 0)
	var full: MagazineInstance = magazine(data.magazine_data, 30)
	runtime.initialize(data, empty_old)
	check(runtime.begin_reload(full, 2.0), "external provider can reload empty weapon without Firearm")
	runtime.tick(2.0)
	check(runtime.loaded_magazine == full and full.get_round_count() == 29 and runtime.chambered_round == ammo and runtime.state == 0, "Empty Reload produces 29 + 1 from exactly 30 rounds")
	var peers: Array = []
	for i in range(3):
		var peer: Variant = runtime_type.new()
		peer.initialize(data, magazine(data.magazine_data, 17 + i), a if i == 0 else null)
		peer.selected_fire_mode = 1 if i == 0 else 0
		peers.append(peer)
	peers[0].try_fire()
	peers[0].begin_reload(magazine(data.magazine_data, 30), 2.0)
	check(peers[1].loaded_magazine.get_round_count() == 18 and peers[1].chambered_round == null and peers[1].selected_fire_mode == 0 and peers[1].fire_cooldown_remaining == 0.0 and peers[1].state == 2 and peers[1].reload_remaining == 0.0, "operating A cannot modify same-definition B")
	check(peers[2].loaded_magazine.get_round_count() == 19 and peers[2].chambered_round == null and peers[2].state == 2 and peers[2].weapon_data == data and data.fire_mode == 1, "third runtime and shared static data remain independent")
	for hz in [30, 60, 120]:
		runtime.initialize(data, magazine(data.magazine_data, 30))
		runtime.chamber_next_round()
		var shots: int = 1 if runtime.try_fire().success else 0
		for i in range(1, hz):
			runtime.tick(1.0 / hz, true)
			while runtime.try_fire().success:
				shots += 1
		check(shots == 10 and runtime.get_magazine_round_count() == 19, "600RPM interval [0,1) gives exactly ten rounds at %dHz" % hz)
		runtime.initialize(data, magazine(data.magazine_data, 30))
		runtime.chamber_next_round()
		runtime.tick(0.5, true)
		shots = 0
		while runtime.try_fire().success:
			shots += 1
		check(shots == 6, "long AUTO tick preserves elapsed-time remainder")
	var invalid_data: WeaponData = data.duplicate()
	for rpm in [0.0, -1.0, NAN, INF, float("1e-308")]:
		invalid_data.rounds_per_minute = rpm
		runtime.initialize(invalid_data, null, a)
		result = runtime.try_fire()
		check(not result.success and result.failure_reason == fire_result_type.FailureReason.DISABLED and runtime.chambered_round == a, "invalid RPM disables firing without consuming chamber")
	finish()

func finish() -> void:
	print("WEAPON_RUNTIME_RESULT assertions=%d failures=%d" % [assertions, failures])
	quit(1 if failures > 0 else 0)

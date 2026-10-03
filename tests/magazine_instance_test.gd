extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for path in ["res://scripts/weapons/magazine_data.gd", "res://scripts/weapons/magazine_instance.gd", "res://data/magazines/test_30rd_magazine.tres"]:
		check(FileAccess.file_exists(path), "required magazine file: " + path)
	if failures > 0:
		print("MAGAZINE_RESULT failures=%d" % failures)
		quit(1)
		return
	var definition: Variant = load("res://data/magazines/test_30rd_magazine.tres")
	var instance_script: Script = load("res://scripts/weapons/magazine_instance.gd")
	var ammo: Variant = load("res://data/ammo/test_round.tres")
	var magazine: Variant = instance_script.new()
	magazine.initialize_full(definition)
	check(definition.magazine_name == "Test 30-Round Magazine" and definition.capacity == 30 and definition.default_ammo == ammo, "magazine definition contains name, capacity and default ammo")
	check(magazine.definition == definition and magazine.get_round_count() == 30, "full initialization supplies 30 real rounds")
	check(magazine.is_full() and not magazine.is_empty(), "full and empty flags reflect actual rounds")
	check(magazine.peek_round() == ammo and magazine.get_round_count() == 30, "peek returns AmmoData without removing it")
	check(not magazine.push_round(ammo) and magazine.get_round_count() == 30, "push cannot overfill capacity")
	check(magazine.pop_round() == ammo and magazine.get_round_count() == 29, "pop returns the removed AmmoData and reduces count")
	check(not magazine.is_full(), "pop makes magazine non-full")
	check(magazine.push_round(ammo) and magazine.is_full(), "push restores one round")

	var other: Variant = instance_script.new()
	other.initialize_full(definition)
	check(other != magazine and other.definition == magazine.definition, "instances differ while sharing static definition")
	magazine.pop_round()
	check(other.get_round_count() == 30 and magazine.get_round_count() == 29, "round arrays are independent")
	magazine.clear()
	check(magazine.is_empty() and magazine.get_round_count() == 0 and not magazine.is_full(), "clear removes only runtime rounds")
	check(other.get_round_count() == 30 and definition.capacity == 30, "clear does not change another magazine or definition")
	check(magazine.pop_round() == null and magazine.peek_round() == null, "empty pop and peek return null")
	check(not magazine.push_round(null) and magazine.is_empty(), "null is not accepted as a round")

	var ammo_a: Variant = load("res://scripts/weapons/ammo_data.gd").new()
	var ammo_b: Variant = load("res://scripts/weapons/ammo_data.gd").new()
	ammo_a.ammo_name = "Ammo A"
	ammo_a.damage = 30.0
	ammo_b.ammo_name = "Ammo B"
	ammo_b.damage = 50.0
	magazine.push_round(ammo_a)
	magazine.push_round(ammo_b)
	magazine.push_round(ammo_a)
	check(magazine.get_round_count() == 3 and magazine.peek_round() == ammo_a, "mixed rounds are stored in feed order")
	check(magazine.pop_round() == ammo_a, "mixed pop 1 is Ammo A")
	check(magazine.pop_round() == ammo_b, "mixed pop 2 is Ammo B")
	check(magazine.pop_round() == ammo_a and magazine.is_empty(), "mixed pop 3 is Ammo A")
	magazine.push_round(ammo_b)
	magazine.push_round(ammo_a)
	check(magazine.pop_round() == ammo_b and magazine.pop_round() == ammo_a, "feed order is FIFO rather than a stack")
	magazine.initialize_full(definition)
	check(magazine.get_round_count() == 30 and magazine.peek_round() == ammo, "reinitialization replaces old rounds with definition defaults")
	print("MAGAZINE_RESULT failures=%d" % failures)
	quit(1 if failures > 0 else 0)

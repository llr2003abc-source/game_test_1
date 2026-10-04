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
	for path in ["res://scripts/combat/armor_data.gd", "res://scripts/combat/armor_instance.gd", "res://scripts/combat/armor_hit_result.gd", "res://scripts/combat/armor_calculator.gd", "res://scripts/combat/armor_component.gd"]:
		check(FileAccess.file_exists(path), "required armor model: " + path)
	if failures > 0:
		finish()
		return
	var instance_script: Variant = load("res://scripts/combat/armor_instance.gd")
	var data_script: Variant = load("res://scripts/combat/armor_data.gd")
	var calculator: Variant = load("res://scripts/combat/armor_calculator.gd")
	var ammo_resources: Array[Resource] = []
	for level in range(1, 6):
		var ammo: Variant = load("res://data/ammo/test_level_%d_round.tres" % level)
		ammo_resources.append(ammo)
		check(ammo.bullet_level == level and ammo.flesh_damage == 40.0 and ammo.armor_damage == 30.0, "level %d test ammo supplies its own flesh/armor damage" % level)
	for level in [1, 3, 6]:
		var definition: Variant = load("res://data/armor/test_level_%d_armor.tres" % level)
		check(definition.armor_level == level and definition.max_durability == 100.0 and definition.protection_zones == [&"torso"], "L%d armor resource protects torso only" % level)
	var definition: Variant = load("res://data/armor/test_level_3_armor.tres")
	var armor: Variant = instance_script.new(definition)
	var other: Variant = instance_script.new(definition)
	check(armor.current_durability == 100.0 and not armor.is_broken() and armor.get_durability_fraction() == 1.0, "new armor initializes full")
	armor.apply_armor_damage(-20.0)
	armor.apply_armor_damage(0.0)
	check(armor.current_durability == 100.0, "nonpositive armor damage cannot repair or damage armor")
	armor.apply_armor_damage(25.0)
	check(armor.current_durability == 75.0 and armor.get_durability_fraction() == 0.75, "armor damage changes runtime durability and fraction")
	check(other.current_durability == 100.0 and definition.max_durability == 100.0, "instances remain independent and definition stays static")
	armor.apply_armor_damage(500.0)
	check(armor.is_broken() and armor.current_durability == 0.0 and armor.get_durability_fraction() == 0.0, "overkill clamps armor to zero")
	armor.reset()
	check(not armor.is_broken() and armor.current_durability == 100.0, "reset restores armor")
	var zero_definition: Variant = data_script.new()
	zero_definition.max_durability = 0.0
	var zero_armor: Variant = instance_script.new(zero_definition)
	check(zero_armor.is_broken() and zero_armor.get_durability_fraction() == 0.0, "zero-capacity armor has a finite zero fraction")

	# Literal expectations catch incorrect branches, gaps and flesh multipliers.
	var armor_matrix: Array = [
		[1.0, 0.5, 0.4, 0.3, 0.2, 0.1],
		[1.5, 1.0, 0.5, 0.4, 0.3, 0.2],
		[1.6, 1.5, 1.0, 0.5, 0.4, 0.3],
		[1.7, 1.6, 1.5, 1.0, 0.5, 0.4],
		[1.8, 1.7, 1.6, 1.5, 1.0, 0.5]]
	var flesh_matrix: Array = [
		[0.5, 0.0, 0.0, 0.0, 0.0, 0.0],
		[0.5, 0.5, 0.0, 0.0, 0.0, 0.0],
		[0.5, 0.5, 0.5, 0.0, 0.0, 0.0],
		[0.5, 0.5, 0.5, 0.5, 0.0, 0.0],
		[0.5, 0.5, 0.5, 0.5, 0.5, 0.0]]
	for bullet_index in range(5):
		for armor_index in range(6):
			var matrix_definition: Variant = data_script.new()
			matrix_definition.armor_level = armor_index + 1
			matrix_definition.max_durability = 100.0
			armor = instance_script.new(matrix_definition)
			var result: Variant = calculator.calculate_hit(ammo_resources[bullet_index], armor)
			var pair: String = "B%d/A%d" % [bullet_index + 1, armor_index + 1]
			check(is_equal_approx(result.armor_damage_multiplier, armor_matrix[bullet_index][armor_index]) and is_equal_approx(result.final_armor_damage, 30.0 * armor_matrix[bullet_index][armor_index]), pair + " armor matrix")
			check(is_equal_approx(result.flesh_damage_multiplier, flesh_matrix[bullet_index][armor_index]) and is_equal_approx(result.final_flesh_damage, 40.0 * flesh_matrix[bullet_index][armor_index]), pair + " flesh matrix")
			check(result.armor_hit and not result.armor_broken_before and not result.armor_broken_after and result.bullet_level == bullet_index + 1 and result.armor_level == armor_index + 1 and result.base_flesh_damage == 40.0 and result.base_armor_damage == 30.0, pair + " hit metadata")
			check(result.durability_before == 100.0 and is_equal_approx(result.durability_after, 100.0 - result.final_armor_damage) and armor.current_durability == 100.0, pair + " calculator is pure and reports durability preview")
			armor.apply_armor_damage(100.0)
			result = calculator.calculate_hit(ammo_resources[bullet_index], armor)
			check(result.armor_broken_before and result.armor_broken_after and result.final_armor_damage == 0.0 and result.armor_damage_multiplier == 0.0 and result.flesh_damage_multiplier == 1.0 and result.final_flesh_damage == 40.0 and result.durability_after == 0.0, pair + " broken armor passes full flesh and takes no armor damage")

	var component: Variant = load("res://scripts/combat/armor_component.gd").new()
	root.add_child(component)
	var events: Dictionary = {"changes": 0}
	component.armor_changed.connect(func() -> void: events.changes += 1)
	component.equip_armor(definition)
	check(component.has_armor_for_zone(&"torso") and not component.has_armor_for_zone(&"head") and not component.has_armor_for_zone(&"legs"), "equipped torso armor respects coverage")
	var result: Variant = component.resolve_hit(ammo_resources[2], &"head")
	check(not result.armor_hit and result.final_flesh_damage == 40.0 and component.equipped_armor.current_durability == 100.0, "unprotected hit does not consume durability")
	result = component.resolve_hit(ammo_resources[2], &"torso")
	check(result.final_armor_damage == 30.0 and result.final_flesh_damage == 20.0 and component.equipped_armor.current_durability == 70.0, "same level: armor loses 30 and body receives 20")
	component.equipped_armor.current_durability = 5.0
	result = component.resolve_hit(ammo_resources[0], &"torso")
	check(not result.armor_broken_before and result.armor_broken_after and result.durability_before == 5.0 and result.durability_after == 0.0 and result.final_armor_damage == 12.0 and result.final_flesh_damage == 0.0, "low-level breaking shot damages armor but delivers zero flesh")
	result = component.resolve_hit(ammo_resources[0], &"torso")
	check(result.armor_broken_before and result.final_armor_damage == 0.0 and result.final_flesh_damage == 40.0, "shot after break delivers full flesh")
	component.reset_armor()
	check(component.equipped_armor.current_durability == 100.0 and events.changes == 4, "equip, damage, break and reset publish armor changes")
	var second_component: Variant = load("res://scripts/combat/armor_component.gd").new()
	second_component.equip_armor(definition)
	component.resolve_hit(ammo_resources[4], &"torso")
	check(second_component.equipped_armor.current_durability == 100.0, "two equipped armors never share durability")
	component.unequip_armor()
	result = component.resolve_hit(ammo_resources[4], &"torso")
	check(component.equipped_armor == null and not component.has_armor_for_zone(&"torso") and not result.armor_hit and result.final_flesh_damage == 40.0 and result.final_armor_damage == 0.0, "unequipped armor passes full flesh")
	component.free()
	second_component.free()
	finish()

func finish() -> void:
	print("ARMOR_LOGIC_RESULT assertions=%d failures=%d" % [assertions, failures])
	quit(1 if failures > 0 else 0)

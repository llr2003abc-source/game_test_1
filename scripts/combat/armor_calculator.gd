class_name ArmorCalculator
extends RefCounted

# Pure calculation: only ArmorComponent applies the durability change.
static func calculate_hit(ammo: AmmoData, armor: ArmorInstance = null) -> ArmorHitResult:
	var result := ArmorHitResult.new()
	result.bullet_level = ammo.bullet_level
	result.base_flesh_damage = ammo.flesh_damage
	result.base_armor_damage = ammo.armor_damage
	result.final_flesh_damage = maxf(0.0, ammo.flesh_damage)
	if armor == null:
		return result
	result.armor_hit = true
	result.armor_level = armor.definition.armor_level
	result.durability_before = armor.current_durability
	result.durability_after = armor.current_durability
	result.armor_broken_before = armor.is_broken()
	result.armor_broken_after = result.armor_broken_before
	if result.armor_broken_before:
		return result

	if ammo.bullet_level < result.armor_level:
		var gap: int = result.armor_level - ammo.bullet_level
		result.armor_damage_multiplier = maxf(0.1, 0.5 - 0.1 * (gap - 1))
		result.flesh_damage_multiplier = 0.0
	elif ammo.bullet_level == result.armor_level:
		result.armor_damage_multiplier = 1.0
		result.flesh_damage_multiplier = 0.5
	else:
		var gap: int = ammo.bullet_level - result.armor_level
		result.armor_damage_multiplier = 1.5 + 0.1 * (gap - 1)
		result.flesh_damage_multiplier = 0.5
	result.final_armor_damage = maxf(0.0, ammo.armor_damage) * result.armor_damage_multiplier
	result.final_flesh_damage = maxf(0.0, ammo.flesh_damage) * result.flesh_damage_multiplier
	result.durability_after = maxf(0.0, result.durability_before - result.final_armor_damage)
	result.armor_broken_after = result.durability_after <= 0.0
	return result

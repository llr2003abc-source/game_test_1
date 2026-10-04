class_name ArmorComponent
extends Node

signal armor_changed()

@export var armor_data: ArmorData
var equipped_armor: ArmorInstance

func _ready() -> void:
	if armor_data != null:
		equip_armor(armor_data)

func equip_armor(definition: ArmorData) -> void:
	equipped_armor = ArmorInstance.new(definition)
	armor_changed.emit()

func unequip_armor() -> void:
	equipped_armor = null
	armor_changed.emit()

func has_armor_for_zone(hit_zone: StringName) -> bool:
	return equipped_armor != null and equipped_armor.definition.protection_zones.has(hit_zone)

func resolve_hit(ammo: AmmoData, hit_zone: StringName) -> ArmorHitResult:
	var armor: ArmorInstance = equipped_armor if has_armor_for_zone(hit_zone) else null
	var result: ArmorHitResult = ArmorCalculator.calculate_hit(ammo, armor)
	if armor != null:
		armor.apply_armor_damage(result.final_armor_damage)
		if result.durability_after != result.durability_before:
			armor_changed.emit()
		print("Armor hit: B%d / A%d | Flesh %.2f x %.2f = %.2f | Armor %.2f x %.2f = %.2f | Durability %.2f -> %.2f" % [result.bullet_level, result.armor_level, result.base_flesh_damage, result.flesh_damage_multiplier, result.final_flesh_damage, result.base_armor_damage, result.armor_damage_multiplier, result.final_armor_damage, result.durability_before, result.durability_after])
	return result

func reset_armor() -> void:
	if equipped_armor != null:
		equipped_armor.reset()
		armor_changed.emit()

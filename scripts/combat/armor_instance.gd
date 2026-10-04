class_name ArmorInstance
extends RefCounted

var definition: ArmorData
var current_durability: float = 0.0

func _init(armor_definition: ArmorData) -> void:
	definition = armor_definition
	reset()

func apply_armor_damage(amount: float) -> void:
	if amount <= 0.0 or is_broken():
		return
	current_durability = maxf(0.0, current_durability - amount)

func is_broken() -> bool:
	return current_durability <= 0.0

func reset() -> void:
	current_durability = maxf(0.0, definition.max_durability)

func get_durability_fraction() -> float:
	return 0.0 if definition.max_durability <= 0.0 else clampf(current_durability / definition.max_durability, 0.0, 1.0)

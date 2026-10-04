class_name ArmorData
extends Resource

@export var armor_name: String = "Armor"
@export_range(1, 6) var armor_level: int = 1
@export var max_durability: float = 100.0
@export var protection_zones: Array[StringName] = [&"torso"]

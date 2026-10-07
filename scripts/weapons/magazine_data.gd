class_name MagazineData
extends Resource

@export var magazine_name: String = "Magazine"
@export var definition_id: StringName
# Shared mechanical interface, distinct from this magazine's unique ID.
@export var magazine_type_id: StringName
@export var compatible_ammo_type_ids: Array[StringName] = []
@export var empty_weight_kg: float = 0.0
@export var animation_family: StringName
@export_range(1, 300, 1) var capacity: int = 30
@export var default_ammo: AmmoData

class_name MagazineData
extends Resource

@export var magazine_name: String = "Magazine"
@export var magazine_type_id: StringName = &"magazine_1"
@export var compatible_ammo_type_ids: Array[StringName] = [&"weapon1_ammo"]
@export_range(1, 300, 1) var capacity: int = 30
@export var default_ammo: AmmoData

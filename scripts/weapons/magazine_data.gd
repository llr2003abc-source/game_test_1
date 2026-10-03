class_name MagazineData
extends Resource

@export var magazine_name: String = "Magazine"
@export_range(1, 300, 1) var capacity: int = 30
@export var default_ammo: AmmoData

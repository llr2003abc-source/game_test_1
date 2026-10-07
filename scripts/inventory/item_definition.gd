class_name ItemDefinition
extends Resource

enum Category { GENERIC, AMMO, MAGAZINE, PRIMARY_WEAPON, SECONDARY_WEAPON, PISTOL, MELEE, RIG, BACKPACK }
@export var item_id: StringName
@export var display_name: String
@export var category: Category = Category.GENERIC
@export var grid_size: Vector2i = Vector2i.ONE
@export var max_stack: int = 1
@export var weight: float = 0.0
@export var allowed_equipment_slots: Array[int] = []
@export var ammo_data: AmmoData
@export var magazine_data: MagazineData
@export var weapon_data: WeaponData
@export var magazine_item_definition: ItemDefinition
@export var visual_scene: PackedScene
@export var container_data: PortableContainerData

func has_capability(capability: StringName) -> bool:
	match capability:
		&"weapon": return category in [Category.PRIMARY_WEAPON,Category.SECONDARY_WEAPON,Category.PISTOL]
		&"magazine": return category==Category.MAGAZINE
		&"ammo_stack": return category==Category.AMMO
		&"portable_container": return category in [Category.RIG,Category.BACKPACK]
	return false

func is_valid() -> bool:
	return grid_size.x >= 1 and grid_size.y >= 1 and max_stack >= 1

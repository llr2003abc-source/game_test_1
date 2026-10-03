extends Label

@export var firearm_path: NodePath
@onready var firearm: Firearm = get_node(firearm_path)

func _ready() -> void:
	firearm.ammo_changed.connect(_update_ammo)
	_update_ammo(firearm.current_ammo, firearm.weapon_data.magazine_size, firearm.is_reloading)

func _update_ammo(ammo: int, capacity: int, reloading: bool) -> void:
	text = "Reloading..." if reloading else "%d / %d" % [ammo, capacity]

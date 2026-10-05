extends Label

@export var firearm_path: NodePath
@onready var firearm: Firearm = get_node(firearm_path)

func _ready() -> void:
	firearm.weapon_state_changed.connect(_update_weapon_state)
	firearm.publish_weapon_state()

func _update_weapon_state(magazine_rounds: int, chamber_loaded: bool, spare_magazine_count: int, state: int) -> void:
	if firearm.inventory_managed and firearm.weapon_runtime == null:
		text = "NO ACTIVE WEAPON"
		return
	text = "MAG %d | CHAMBER %d\nSPARE MAGS: %d" % [magazine_rounds, 1 if chamber_loaded else 0, spare_magazine_count]
	if state == Firearm.State.RELOADING:
		text = "Reloading...\n" + text

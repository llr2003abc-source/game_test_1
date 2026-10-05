extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	check(FileAccess.file_exists("res://scripts/inventory/equipment_component.gd"),"equipment exists")
	check(FileAccess.file_exists("res://scripts/inventory/player_inventory_component.gd"),"inventory aggregate exists")
	if failures==0:
		var inv: Variant = load("res://scripts/inventory/player_inventory_component.gd").new()
		var gun: Variant = item(5,2)
		gun.definition.category=3
		gun.definition.allowed_equipment_slots.append(0)
		gun.runtime_state=WeaponRuntime.new()
		gun.runtime_state.initialize(load("res://data/weapons/test_rifle.tres"))
		check(inv.transactions.equip(gun,0),"equip primary")
		check(inv.equipment.get_active_item()==gun,"primary active reference")
		for slot in [1,2,3,4,5]:
			check(not inv.equipment.select_weapon_slot(slot),"empty/nonweapon slot keeps primary")
			check(inv.equipment.get_active_item()==gun,"active remains exact primary")
		check(not inv.transactions.equip(gun,1),"primary-only weapon rejects secondary")
		var spare: Variant = item(1,1)
		check(not inv.transactions.equip(spare,2),"generic cannot equip pistol")
		inv.transactions.locked=true
		check(not inv.equipment.select_weapon_slot(0) and not inv.transactions.remove(gun),"reload lock covers equipment")
		inv.transactions.locked=false
		check(inv.transactions.remove(gun) and inv.equipment.get_active_item()==null,"unequip removes active ownership")
		check(inv.pockets.size()==6,"aggregate six pockets")
		check(inv.secure.grid.size==Vector2i(3,3),"aggregate secure")
		inv.free()
	print("EQUIPMENT_COMPONENT_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

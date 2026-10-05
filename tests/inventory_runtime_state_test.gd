extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	if not FileAccess.file_exists("res://scripts/inventory/player_inventory_component.gd"):
		check(false,"runtime aggregate exists")
	else:
		var inv: Variant=load("res://scripts/inventory/player_inventory_component.gd").new()
		var bag: Variant=item(3,4)
		bag.definition.category=8
		bag.runtime_state=load("res://scripts/inventory/backpack_container_runtime.gd").new()
		check(inv.transactions.equip(bag,5),"equip actual bag runtime")
		var gun: Variant=item(5,2)
		gun.definition.category=3
		gun.runtime_state=WeaponRuntime.new()
		var data: WeaponData=load("res://data/weapons/test_rifle.tres")
		var mag:=MagazineInstance.new()
		mag.initialize_full(data.magazine_data)
		for i in range(13): mag.pop_round()
		gun.runtime_state.initialize(data,mag,data.magazine_data.default_ammo)
		gun.runtime_state.selected_fire_mode=0
		gun.runtime_state.fire_cooldown_remaining=0.07
		var original: RefCounted=gun.runtime_state
		check(inv.transactions.equip(gun,0),"equip supplied weapon runtime")
		check(inv.transactions.move(gun,bag.runtime_state.grid,Vector2i.ZERO),"weapon to backpack")
		check(inv.equipment.get_active_item()==null and gun.runtime_state==original,"unequipped runtime preserved")
		check(inv.transactions.equip(gun,0),"re-equip same object")
		check(gun.runtime_state==original and mag.get_round_count()==17 and gun.runtime_state.chambered_round!=null,"17 + chamber preserved")
		check(gun.runtime_state.selected_fire_mode==0 and gun.runtime_state.fire_cooldown_remaining==0.07,"mode/cooldown preserved")
		check(not inv.transactions.register_item(load("res://scripts/inventory/inventory_item_instance.gd").new(gun.definition,1,original)),"duplicate wrapper rejected by identity registry")
		check(inv.transactions.find_runtime_item(original)==gun,"registry returns original item")
		inv.free()
	print("INVENTORY_RUNTIME_STATE_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

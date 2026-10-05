extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	var level: Node=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	var p: Node=level.get_node("Player")
	check(p.has_node("PlayerInventory"),"main has formal inventory loadout")
	if failures==0:
		var inv: Variant=p.get_node("PlayerInventory")
		var f: Variant=p.get_node("Head/Camera3D/WeaponRoot")
		var gun: Variant=inv.equipment.get_active_item()
		var runtime: RefCounted=gun.runtime_state
		check(f.weapon_runtime==runtime and f.spare_magazines.is_empty(),"main owns weapon through item, no legacy spares")
		check(f.loaded_magazine.get_round_count()==29 and f.chambered_round!=null,"initial29+1")
		check(inv.reload_coordinator.get_available_magazine_count()==2,"two compatible rig magazines")
		check(inv.get_equipped_backpack().grid.placements[0].item.stack_count==60,"backpack L2 stack60")
		check(inv.transactions.move(gun,inv.get_equipped_backpack().grid,Vector2i(0,1)),"weapon moves into backpack")
		check(f.weapon_runtime==null and not f.can_use_weapon(),"unequip unbinds executor")
		f.set_aiming(true)
		f.set_trigger(true,true)
		f.request_reload()
		check(not f.is_aiming and not f._fire_shot() and gun.runtime_state==runtime,"backpack weapon cannot ADS/fire/reload")
		check(runtime.loaded_magazine.get_round_count()==29 and runtime.chambered_round!=null,"inactive weapon retains ammo")
		check(inv.transactions.equip(gun,0) and inv.equipment.select_weapon_slot(0),"re-equip and select")
		check(f.weapon_runtime==runtime and f.can_use_weapon(),"rebind original runtime")
		for slot in [1,2,3]: check(not inv.equipment.select_weapon_slot(slot) and f.weapon_runtime==runtime,"empty quick slot retains primary")
	level.queue_free()
	await process_frame
	print("WEAPON_EQUIPMENT_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

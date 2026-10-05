extends "res://tests/inventory_grid_test.gd"
func reload_key(player: Node, echo: bool=false) -> void:
	var event:=InputEventKey.new()
	event.keycode=KEY_R
	event.pressed=true
	event.echo=echo
	player._unhandled_input(event)
func _run() -> void:
	var level: Node=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	await physics_frame
	var p: Variant=level.get_node("Player")
	var inv: Variant=p.inventory
	var f: Firearm=p.firearm
	p.set_physics_process(false)
	f.set_physics_process(false)
	var runtime: WeaponRuntime=f.weapon_runtime
	var gun: InventoryItemInstance=inv.equipment.get_active_item()
	for action in ["weapon_primary","weapon_secondary","weapon_pistol","weapon_knife"]:
		Input.action_press(action)
		p._physics_process(1.0/60.0)
		check(f.weapon_runtime==runtime,"real input quick slot preserves valid active weapon: "+action)
		Input.action_release(action)
		await physics_frame
	check(f._fire_shot(),"formal equipped firearm fires")
	check(runtime.get_magazine_round_count()==28 and runtime.chambered_round!=null,"one formal shot cycles real ammo")
	p.injury_component.arms_injured=true
	reload_key(p)
	p._physics_process(0.1)
	check(runtime.state!=WeaponRuntime.State.RELOADING,"first R waits confirmation window")
	p._physics_process(0.13)
	check(runtime.state==WeaponRuntime.State.RELOADING and runtime.reload_type==WeaponRuntime.ReloadType.TACTICAL,"single R routes tactical coordinator")
	check(is_equal_approx(runtime.reload_remaining,2.7) and runtime.weapon_data.reload_time==2.0,"injury multiplier outside immutable weapon base")
	check(not inv.transactions.move(gun,inv.get_equipped_backpack().grid,Vector2i(0,1)),"live reload prevents weapon unequip")
	check(not f._fire_shot(),"formal reload blocks firing")
	runtime.tick(2.69)
	check(runtime.state==WeaponRuntime.State.RELOADING,"injured reload waits full duration")
	runtime.tick(0.02)
	check(runtime.state==WeaponRuntime.State.READY and runtime.get_magazine_round_count()==30,"tactical completion30+1")
	check(inv.reload_coordinator.get_available_magazine_count()==2,"old28 round magazine returned to rig")
	runtime.tick(1.0)
	check(f._fire_shot(),"firing after tactical reload")
	reload_key(p)
	p._physics_process(0.05)
	reload_key(p,true)
	check(p.reload_input_resolver.pending,"echo does not become double R")
	reload_key(p)
	check(runtime.state==WeaponRuntime.State.RELOADING and runtime.reload_type==WeaponRuntime.ReloadType.DROP,"real double R yields drop only")
	runtime.tick(2.7)
	check(inv.transactions.world_items.size()==1,"double R generates one real drop")
	var drop: InventoryItemInstance=inv.transactions.world_items.keys()[0]
	check(drop.runtime_state.get_round_count()==29,"dropped magazine preserves remaining29 rounds")
	var rig_item: InventoryItemInstance=inv.equipment.slots[4]
	check(inv.transactions.move(rig_item,inv.secure.grid,Vector2i.ZERO),"rig may be stowed in secure")
	check(not p.get_node("EquipmentVisuals/Rig").visible and inv.reload_coordinator.select_reload_magazine()==null,"unequipped rig hides visual and disables reload source")
	check(inv.transactions.equip(rig_item,4) and p.get_node("EquipmentVisuals/Rig").visible,"re-equip original rig restores source/visual")
	var bag_item: InventoryItemInstance=inv.equipment.slots[5]
	check(inv.transactions.remove(bag_item) and not p.get_node("EquipmentVisuals/Backpack").visible,"backpack visual follows equipment")
	check(inv.transactions.equip(bag_item,5) and p.get_node("EquipmentVisuals/Backpack").visible,"backpack re-equip preserves contents")
	level.queue_free()
	await process_frame
	print("INVENTORY_GAMEPLAY_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

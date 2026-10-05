extends "res://tests/inventory_grid_test.gd"

func _run() -> void:
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	var inv: PlayerInventoryComponent=p.inventory
	var gun: InventoryItemInstance=inv.equipment.get_active_item()
	var runtime: WeaponRuntime=gun.runtime_state
	var chamber: AmmoData=runtime.chambered_round
	var magazine: MagazineInstance=runtime.loaded_magazine
	check(inv.equipment.can_equip(gun,0),"Weapon1 valid long gun slot1")
	check(inv.equipment.can_equip(gun,1),"Weapon1 valid long gun slot2")
	check(not inv.equipment.can_equip(gun,2) and not inv.equipment.can_equip(gun,3),"Weapon1 invalid pistol/knife")
	check(inv.transactions.equip(gun,1),"slot1 to slot2 commits original")
	check(inv.equipment.slots[1]==gun and inv.equipment.slots[0]==null and gun.runtime_state==runtime,"long gun move preserves item/runtime")
	check(inv.equipment.select_weapon_slot(1) and p.firearm.weapon_runtime==runtime,"slot2 binds moved original runtime")
	check(inv.transactions.equip(gun,0) and inv.equipment.select_weapon_slot(0),"slot2 to slot1 commits original")
	check(runtime.chambered_round==chamber and runtime.loaded_magazine==magazine and runtime.get_magazine_round_count()==29,"slot roundtrip never resets chamber/magazine")
	var second:=InventoryItemFactory.create(gun.definition,1,17)
	second.runtime_state.selected_fire_mode=WeaponData.FireMode.SEMI
	check(inv.transactions.equip(second,1),"second independent gun equipped slot2")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	root.grab_focus()
	p.set_physics_process(true)
	for slot in [1,0,1,0]:
		var key:=InputEventKey.new()
		key.keycode=KEY_1 if slot==0 else KEY_2
		key.pressed=true
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await create_timer(0.08).timeout
		check(p.firearm.weapon_runtime==inv.equipment.slots[slot].runtime_state,"real1/2 action binds requested original runtime")
		key=key.duplicate()
		key.pressed=false
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		await create_timer(0.04).timeout
	check(second.runtime_state.get_magazine_round_count()==17 and second.runtime_state.chambered_round!=null and second.runtime_state.selected_fire_mode==WeaponData.FireMode.SEMI,"switch preserves second gun17/chamber/SEMI")
	var definition: ItemDefinition=gun.definition.duplicate()
	definition.allowed_equipment_slots.clear()
	definition.category=ItemDefinition.Category.SECONDARY_WEAPON
	var fallback:=InventoryItemFactory.create(definition)
	check(inv.equipment.can_equip(fallback,0) and inv.equipment.can_equip(fallback,1),"both long-gun categories share identical fallback compatibility")
	level.queue_free()
	await process_frame
	print("LONG_GUN_SLOT_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

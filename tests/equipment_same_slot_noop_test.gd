extends "res://tests/inventory_drag_ux_test.gd"

class CountingTransactions extends InventoryTransactionService:
	var mutation_calls: int=0
	func register_item(value: InventoryItemInstance) -> bool:
		mutation_calls+=1
		return super.register_item(value)
	func _commit_registration(group: Array[InventoryItemInstance]) -> void:
		mutation_calls+=1
		super._commit_registration(group)
	func _release_registration(value: InventoryItemInstance) -> void:
		mutation_calls+=1
		super._release_registration(value)
	func _clear_location(value: InventoryItemInstance, location: Dictionary) -> void:
		mutation_calls+=1
		super._clear_location(value,location)

func snapshot(item_value: InventoryItemInstance) -> Array:
	var result: Array=[item_value.get_instance_id(),item_value.get_owner_registry(),item_value.get_owner_registry().get_location(item_value),item_value.rotated]
	var state: RefCounted=item_value.runtime_state
	if state is WeaponRuntime:
		result.append_array([state.get_instance_id(),state.chambered_round,state.loaded_magazine,state.loaded_magazine.get_instance_id(),state.loaded_magazine.rounds.duplicate(),state.selected_fire_mode,state.fire_cooldown_remaining,state.reload_remaining,state.reload_type,state.state])
	elif state is RigContainerRuntime:
		for grid in state.grids:
			for placement in grid.placements: result.append([grid,placement.item,placement.position,placement.item.runtime_state,placement.item.runtime_state.rounds.duplicate()])
	elif state is BackpackContainerRuntime:
		for placement in state.grid.placements: result.append([state.grid,placement.item,placement.position,placement.item.stack_count])
	return result

func _run() -> void:
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	if DisplayServer.get_name()!="headless": root.grab_focus()
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	var inv: PlayerInventoryComponent=p.inventory
	var ui: InventoryUI=p.get_node("InventoryUI")
	var crate: LootContainer=level.get_node("LootCrateA")
	p.global_position=crate.global_position+Vector3(0,0,1.8)
	p.camera.look_at(crate.get_interaction_position())
	var rifle: ItemDefinition=load("res://data/items/primary_weapon_1_item.tres")
	inv.transactions.equip(InventoryItemFactory.create(rifle,1,17),1)
	var pistol: ItemDefinition=rifle.duplicate()
	pistol.category=ItemDefinition.Category.PISTOL
	pistol.allowed_equipment_slots=[2]
	inv.transactions.equip(InventoryItemFactory.create(pistol,1,12),2)
	var knife:=ItemDefinition.new()
	knife.category=ItemDefinition.Category.MELEE
	inv.transactions.equip(InventoryItemInstance.new(knife),3)
	var active: WeaponRuntime=p.firearm.weapon_runtime
	active.try_fire()
	active.tick(0.025)
	active.selected_fire_mode=WeaponData.FireMode.SEMI
	var signals: Dictionary={"registry":0,"inventory":0,"weapon":0,"runtime":0,"external":0}
	var callbacks: Array=[]
	for pair in [[inv.transactions.changed,"registry"],[inv.inventory_changed,"inventory"],[p.firearm.weapon_state_changed,"weapon"],[active.state_changed,"runtime"],[crate.runtime.changed,"external"]]:
		var callback: Callable=func(_a: Variant=null,_b: Variant=null,_c: Variant=null,_d: Variant=null): signals[pair[1]]+=1
		pair[0].connect(callback)
		callbacks.append([pair[0],callback])
	await physics_frame
	check(ui.open_container(crate),"open actual external inventory fixture")
	await process_frame
	var access:=ui.container_access
	for slot in range(6):
		var original: InventoryItemInstance=inv.equipment.slots[slot]
		var before:=snapshot(original)
		var active_slot: int=inv.equipment.active_weapon_slot
		var bound: WeaponRuntime=p.firearm.weapon_runtime
		for counter in signals: signals[counter]=0
		check(ExternalInventoryTransfer.transfer(access,original,inv.transactions,{"kind":&"equipment","slot":slot}),"same-owner transaction successful no-op slot%d"%slot)
		check(snapshot(original)==before and inv.equipment.active_weapon_slot==active_slot and p.firearm.weapon_runtime==bound,"transaction preserves all item/runtime/equipment state slot%d"%slot)
		check(signals.values().all(func(count): return count==0),"no mutation or binding signals slot%d"%slot)
	for mode in [InventoryUI.Mode.PLAYER,InventoryUI.Mode.CONTAINER_LOOT,InventoryUI.Mode.VICINITY]:
		if ui.visible: ui.toggle()
		if mode==InventoryUI.Mode.PLAYER: ui.toggle()
		elif mode==InventoryUI.Mode.CONTAINER_LOOT: ui.open_container(crate)
		else:
			var dropped:=WorldItemFactory.spawn(InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres"),1,17),inv.transactions,level,Transform3D(Basis.IDENTITY,p.global_position+Vector3(0,0.1,0.8)))
			ui.open_vicinity(dropped)
		await process_frame
		await process_frame
		for slot in range(6):
			var original: InventoryItemInstance=inv.equipment.slots[slot]
			var before:=snapshot(original)
			var control: InventoryEquipmentSlot=ui.equipment_views[slot]
			for counter in signals: signals[counter]=0
			var data:=ui.begin_drag(original,Vector2(24,24))
			var candidate:=ui.update_drag_candidate(control.get_global_rect().get_center(),data)
			check(candidate.valid and candidate.kind==&"equipment" and candidate.slot==slot,"valid same-slot preview mode%d slot%d"%[mode,slot])
			check(ui.commit_drag_candidate(data),"UI successful no-op mode%d slot%d"%[mode,slot])
			ui.finish_drag()
			check(snapshot(original)==before and p.firearm.weapon_runtime==active,"UI preserves ownership/runtime/binding mode%d slot%d"%[mode,slot])
			check(signals.values().all(func(count): return count==0),"UI no mutation signals mode%d slot%d"%[mode,slot])
			check(ui.equipment_views[slot]==control and not ui._pending_refresh,"no inventory rebuild mode%d slot%d"%[mode,slot])
			check(ui.drag_context==null and ui.drag_preview==null and not ui.placement_preview.visible and control.modulate.a==1,"drag visuals/context cleared mode%d slot%d"%[mode,slot])
		if DisplayServer.get_name()!="headless": await native_noop(ui,inv,signals)
	await negative_and_transfer_cases(p,ui,crate,signals)
	for pair in callbacks: pair[0].disconnect(pair[1])
	level.queue_free()
	await process_frame
	registration_noop()
	print("EQUIPMENT_SAME_SLOT_NOOP_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

func native_noop(ui: InventoryUI, inv: PlayerInventoryComponent, signals: Dictionary) -> void:
	var original:=inv.equipment.slots[0] as InventoryItemInstance
	var before:=snapshot(original)
	var control: InventoryEquipmentSlot=ui.equipment_views[0]
	var point:=control.get_global_rect().get_center()
	for counter in signals: signals[counter]=0
	await start_native_drag(point,point)
	check(root.gui_is_dragging() and ui.drag_context!=null and ui.drag_context.is_valid,"native same-slot drag green")
	release_mouse(point)
	await process_frame
	await process_frame
	check(snapshot(original)==before,"native drop preserves all source state")
	check(signals.values().all(func(count): return count==0),"native drop no mutation/binding signals")
	check(ui.drag_context==null and ui.drag_preview==null and not root.gui_is_dragging() and not ui.placement_preview.visible and control.modulate.a==1,"native no-op ends ghost/highlight/dim/context")

func negative_and_transfer_cases(p: Node3D, ui: InventoryUI, crate: LootContainer, signals: Dictionary) -> void:
	if ui.visible: ui.toggle()
	ui.open_container(crate)
	await process_frame
	var inv: PlayerInventoryComponent=p.inventory
	var a:=inv.equipment.slots[0] as InventoryItemInstance
	var b:=inv.equipment.slots[1] as InventoryItemInstance
	var a_before:=snapshot(a)
	var b_before:=snapshot(b)
	check(a!=b and a.definition==b.definition and a.runtime_state!=b.runtime_state,"same Definition does not imply same Item or runtime")
	check(not inv.transactions.equip(b,0),"different same-definition item cannot no-op into occupied slot")
	check(not ExternalInventoryTransfer.transfer(ui.container_access,b,inv.transactions,{"kind":&"equipment","slot":0}),"occupied same-registry target still fails")
	check(snapshot(a)==a_before and snapshot(b)==b_before,"occupied rejection preserves both originals")
	var data:=ui.begin_drag(a,Vector2(24,24))
	ui.update_drag_candidate(ui.equipment_views[0].get_global_rect().get_center(),data)
	inv.equipment.slots[0]=b
	check(not ui.commit_drag_candidate(data),"replaced source slot rejects stale green candidate")
	check(not inv.transactions.equip(a,0),"no longer equipped source cannot claim old occupied slot")
	inv.equipment.slots[0]=a
	ui.finish_drag()
	var definition: ItemDefinition=a.definition
	a.definition=definition.duplicate()
	a.definition.allowed_equipment_slots=[1]
	check(not inv.transactions.equip(a,0),"same-item no-op still validates equipment compatibility")
	a.definition=definition
	inv.transactions.locked=true
	check(not inv.transactions.equip(a,0) and not ui.drop_on_equipment({"item":a},0),"reload lock applies before no-op")
	inv.transactions.locked=false
	check(not inv.transactions.equip(null,0) and not inv.transactions.equip(a,-1),"null item and invalid slot rejected")
	var foreign:=PlayerInventoryComponent.new()
	var other:=InventoryItemFactory.create(definition)
	foreign.transactions.equip(other,0)
	inv.equipment.slots[0]=other
	check(not inv.transactions.equip(other,0),"slot reference cannot impersonate foreign ownership")
	inv.equipment.slots[0]=a
	foreign.free()
	inv.get_equipped_backpack().grid._commit_place(a,Vector2i(0,1),false)
	check(not inv.transactions.equip(a,0),"actual grid location cannot be classified same-equipment no-op")
	inv.get_equipped_backpack().grid._commit_remove(a)
	inv.transactions.remove(b)
	for route in [[0,1],[1,0]]:
		for counter in signals: signals[counter]=0
		check(ui.drop_on_equipment({"item":a},route[1]),"different slots real move %d->%d"%route)
		check(inv.equipment.slots[route[0]]==null and inv.equipment.slots[route[1]]==a and inv.transactions.get_location(a).slot==route[1],"real slot move changes actual source/target")
		check(signals.registry==1 and signals.inventory>0,"real move emits mutation notification")
		check(a.runtime_state.get_instance_id()==a_before[4],"real move keeps WeaponRuntime identity")
	var spare:=MagazineInstance.new()
	spare.initialize_full(a.runtime_state.loaded_magazine.definition)
	check(a.runtime_state.begin_reload(spare,1.7),"set real runtime reload in progress for snapshot")
	var reloading:=snapshot(a)
	check(inv.transactions.equip(a,0) and snapshot(a)==reloading,"no-op preserves reload state/duration/chamber/magazine")
	var source_grid:=crate.runtime.inventory_grid
	var external:=source_grid.get_item_at_cell(Vector2i.ZERO)
	check(not ExternalInventoryTransfer.transfer(ui.container_access,external,inv.transactions,{"kind":&"equipment","slot":0}),"CONTAINER->occupied Player slot is not no-op")
	var external_before:=snapshot(external)
	check(ui.drop_on_equipment({"item":external},1),"CONTAINER->empty Slot2 remains real external transfer")
	check(inv.equipment.slots[1]==external and external.runtime_state.get_instance_id()==external_before[4],"external original runtime preserved")
	check(ExternalInventoryTransfer.transfer(ui.container_access,a,crate.runtime.transactions,{"kind":&"grid","grid":source_grid,"position":Vector2i.ZERO}),"Player Slot1->Container remains real external transfer")
	check(p.firearm.weapon_runtime==null and crate.runtime.transactions.get_location(a).kind==&"container","external active move unbinds as before")
	check(ui.drop_on_equipment({"item":a},0),"CONTAINER->empty Slot1 remains real external transfer")
	check(p.firearm.weapon_runtime==a.runtime_state,"returned active slot binds original runtime")
	var world_item:=WorldItemFactory.spawn(InventoryItemFactory.create(definition),inv.transactions,p.get_tree().current_scene,Transform3D(Basis.IDENTITY,p.global_position+Vector3(0,0.1,0.8)))
	check(not inv.transactions.pickup_world_item(world_item,{"kind":&"equipment","slot":0},true).success,"WORLD same-definition weapon cannot no-op into occupied slot")
	check(inv.transactions.get_location(world_item.item).kind==&"world","failed WORLD pickup keeps real WORLD ownership")

func registration_noop() -> void:
	var actor:=Node3D.new()
	root.add_child(actor)
	var inv:=PlayerInventoryComponent.new()
	var service:=CountingTransactions.new()
	service.inventory=inv
	inv.transactions=service
	service.changed.connect(inv._on_inventory_changed)
	actor.add_child(inv)
	var original:=InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres"),1,17)
	service.equip(original,0)
	service.mutation_calls=0
	check(service.equip(original,0) and service.mutation_calls==0,"no-op never clears/unregisters/re-registers original")
	var owner: Variant=load("res://tests/container_test_owner.gd").new()
	root.add_child(owner)
	owner.runtime.transactions.register_external_container(owner.runtime)
	var access:=LootContainerAccess.new(actor,owner,service)
	check(ExternalInventoryTransfer.transfer(access,original,service,{"kind":&"equipment","slot":0}) and service.mutation_calls==0,"same-owner transfer no-op never invokes registration pipeline")
	owner.free()
	actor.free()

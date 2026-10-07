extends "res://tests/recursive_weight_test.gd"

func _run() -> void:
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	var inv: PlayerInventoryComponent=p.inventory
	var ui: InventoryUI=p.get_node("InventoryUI")
	ui.toggle()
	var a: InventoryItemInstance=inv.equipment.slots[5]
	var wa:=ui.open_portable_container(a)
	await process_frame
	await process_frame
	var equipment_rect: Rect2=ui.equipment_views[0].get_global_rect()
	wa.position=equipment_rect.position
	var gun: InventoryItemInstance=inv.equipment.get_active_item()
	var data:=ui.begin_drag(gun)
	var candidate:=ui.update_drag_candidate(equipment_rect.position+Vector2(20,20),data)
	check(candidate.kind==&"none" and not candidate.valid,"floating chrome blocks concealed equipment target")
	ui.finish_drag()
	ui.portable_windows.close_all()
	ui.mode=InventoryUI.Mode.VICINITY
	ui.refresh()
	wa=ui.open_portable_container(a)
	await process_frame
	var vicinity_rect: Rect2=ui.nearby_scroll.get_global_rect()
	wa.position=vicinity_rect.position
	data=ui.begin_drag(gun)
	candidate=ui.update_drag_candidate(vicinity_rect.position+Vector2(20,20),data)
	check(candidate.kind==&"none" and not candidate.valid,"floating chrome blocks concealed WORLD drop target")
	ui.finish_drag()
	ui.portable_windows.close_all()
	var storage:=InventoryGrid.new(32,6,&"external")
	inv.transactions.register_grid(storage)
	for index in range(8):
		var member:=bag()
		storage.place_item(member,Vector2i(index*4,0))
		ui.open_portable_container(member)
	await process_frame
	await process_frame
	var viewport: Vector2=root.get_visible_rect().size
	for window: PortableContainerWindow in ui.portable_windows.windows.values():
		check(window.position.x>=0 and window.position.y>=0 and window.position.x<=viewport.x-32 and window.position.y<=viewport.y-32,"every initial window keeps usable title within viewport")
	wa=ui.portable_windows.windows.values()[0]
	wa.move_title(Vector2(-10000,-10000))
	check(wa.position.x>=0 and wa.position.y>=0,"title cannot be dragged completely offscreen")
	ui.portable_windows.close_all()
	var loose: InventoryItemInstance=storage.get_item_at_cell(Vector2i.ZERO)
	var lease:=inv.transactions.reserve_item(loose)
	check(not inv.transactions.place_complete_subtree(loose,storage,Vector2i.ZERO),"complete placement cannot steal an active reservation")
	check(inv.transactions.is_reserved(loose) and inv.transactions.get_location(loose).kind==&"transit","refusal retains active logical root")
	inv.transactions.cancel_reservation(lease)
	ui.toggle()
	var crate: LootContainer=level.get_node("LootCrateA")
	p.global_position=crate.global_position+Vector3(0,0,1.8)
	p.camera.look_at(crate.get_interaction_position())
	await physics_frame
	check(ui.open_container(crate),"review fixture opens real crate")
	for placement in crate.runtime.inventory_grid.placements.duplicate(): crate.runtime.transactions.remove(placement.item)
	check(ExternalInventoryTransfer.transfer(ui.container_access,a,crate.runtime.transactions,{"kind":&"grid","grid":crate.runtime.inventory_grid,"position":Vector2i(4,0)}),"portable enters actual crate")
	wa=ui.open_portable_container(a)
	var window_id: int=wa.get_instance_id()
	var unrelated:=ammo(1)
	inv.pockets[0].place_item(unrelated,Vector2i.ZERO)
	check(ExternalInventoryTransfer.transfer(ui.container_access,unrelated,crate.runtime.transactions,{"kind":&"grid","grid":crate.runtime.inventory_grid,"position":Vector2i.ZERO}),"unrelated cross registry commits under temporary locks")
	check(ui.portable_windows.windows.has(a) and ui.portable_windows.windows[a].get_instance_id()==window_id,"unchanged Crate window survives transaction lock notifications")
	wa=ui.open_portable_container(a)
	window_id=wa.get_instance_id()
	var source: InventoryItemInstance=a.runtime_state.grid.get_item_at_cell(Vector2i.ZERO)
	check(crate.runtime.transactions.split_stack(source,5)!=null,"split inside Crate portable commits under temporary lock")
	check(ui.portable_windows.windows.has(a) and ui.portable_windows.windows[a].get_instance_id()==window_id,"Crate split redraw preserves actual window")
	ui.toggle()
	level.queue_free()
	await process_frame
	print("B2_REVIEW_REGRESSION_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

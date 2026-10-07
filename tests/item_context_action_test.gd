extends "res://tests/recursive_weight_test.gd"

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/inventory/item_action_resolver.gd"),"capability action resolver exists")
	if failures:
		finish_actions()
		return
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	var ui: Variant=p.get_node("InventoryUI")
	ui.toggle()
	var inv: PlayerInventoryComponent=p.inventory
	var resolver: Variant=load("res://scripts/inventory/item_action_resolver.gd")
	var executor: Variant=ui.action_executor
	var a: InventoryItemInstance=inv.equipment.slots[5]
	var source: InventoryItemInstance=a.runtime_state.grid.get_item_at_cell(Vector2i.ZERO)
	check(ids(resolver.resolve(a,ui))==[&"inspect",&"drop",&"open_container"],"portable capabilities expose Inspect Drop Open")
	check(ids(resolver.resolve(source,ui))==[&"inspect",&"drop",&"split"],"ammo capability exposes Split, no placeholder actions")
	var gun: InventoryItemInstance=inv.equipment.get_active_item()
	check(ids(resolver.resolve(gun,ui))==[&"inspect",&"drop"],"weapon does not expose future reload/unload")
	var before: Array=[source.stack_count,source.rotated,source.runtime_state,inv.get_total_weight(),ui.item_location_signature(source)]
	var detail: Dictionary=executor.execute(&"inspect",a)
	check(detail.external_size==Vector2i(4,5) and detail.storage_sizes==[Vector2i(5,5)] and is_equal_approx(detail.base_weight_kg,1.5),"Inspect bag authored external/internal/shell details")
	detail=executor.execute(&"inspect",gun)
	check(detail.chamber_loaded and detail.magazine_rounds==29 and is_equal_approx(detail.total_weight_kg,4.01) and detail.has("base_ergonomics") and not detail.has("final_recoil"),"Inspect weapon actual CH/MAG and base stats only")
	check(before==[source.stack_count,source.rotated,source.runtime_state,inv.get_total_weight(),ui.item_location_signature(source)],"Inspect changes no gameplay state")
	var magazine: InventoryItemInstance=inv.get_equipped_rig().grids[0].get_item_at_cell(Vector2i.ZERO)
	detail=executor.execute(&"inspect",magazine)
	check(detail.round_count==30 and detail.capacity==30 and detail.composition.size()==1 and is_equal_approx(detail.total_weight_kg,0.51),"Inspect magazine actual composition and weight")
	ui.busy_query=func(_item: InventoryItemInstance): return true
	check(resolver.resolve(source,ui).is_empty(),"future BUSY contract exposes no menu at all")
	ui.show_item_context(source,Vector2(400,300))
	check(not ui.item_context.visible,"BUSY RMB creates no visible menu")
	ui.busy_query=Callable()
	var lease:=inv.transactions.reserve_item(source)
	check(resolver.resolve(source,ui).is_empty(),"reservation is busy with no menu")
	inv.transactions.cancel_reservation(lease)
	ui.show_item_context(source,Vector2(400,300))
	check(ui.item_context.visible,"normal RMB menu appears")
	ui.begin_drag(source)
	check(not ui.item_context.visible,"drag starts close stale menu")
	ui.finish_drag()
	var dialog: Variant=ui.open_split_dialog(source)
	check(dialog!=null and dialog.slider.max_value==59 and dialog.amount.max_value==59,"split dialog max derives actual60 minus1")
	dialog.slider.value=13
	check(dialog.amount.value==13,"Slider updates SpinBox")
	dialog.amount.value=7
	check(dialog.slider.value==7,"SpinBox updates Slider")
	var weight: float=inv.get_total_weight()
	var original_count: int=source.stack_count
	check(dialog.confirm_split(),"dialog atomic split commits into same grid")
	check(source.stack_count==original_count-7 and is_equal_approx(inv.get_total_weight(),weight),"split count conserved and whole carried weight unchanged")
	dialog=ui.open_split_dialog(source)
	check(dialog.amount.max_value==52,"split range follows remaining actual53")
	var signature: Array=ui.action_signature(source)
	source.stack_count=10
	check(not dialog.confirm_split() and source.stack_count==10,"stale count confirm rejects without mutation")
	check(executor.execute(&"split",source,{"amount":1,"signature":signature})==null,"stale snapshot action is revalidated")
	source.stack_count=53
	var grid: InventoryGrid=a.runtime_state.grid
	for y in range(grid.size.y):
		for x in range(grid.size.x):
			if grid.get_item_at_cell(Vector2i(x,y))==null: grid.place_item(item(1,1),Vector2i(x,y))
	before=[source.stack_count,inv.get_total_weight(),grid.placements.size()]
	check(executor.execute(&"split",source,{"amount":5})==null,"no space split fails before decrement")
	check(before==[source.stack_count,inv.get_total_weight(),grid.placements.size()],"no space split zero mutation")
	ui.show_item_context(source,Vector2(400,300))
	inv.transactions.changed.emit()
	check(not ui.item_context.visible,"inventory mutation invalidates menu")
	var wa: Variant=ui.open_portable_container(a)
	ui.show_item_context(source,Vector2(400,300),wa)
	ui.portable_windows.close_window(wa)
	check(not ui.item_context.visible,"window close invalidates its item context")
	weight=inv.get_total_weight()
	var bag_weight: float=a.get_weight()
	var dropped: Variant=executor.execute(&"drop",a)
	check(dropped is DroppedItem and inv.transactions.world_items.has(a),"Drop uses real WORLD root")
	check(is_equal_approx(inv.get_total_weight(),weight-bag_weight) and inv.transactions.get_location(source).kind==&"grid","Drop whole subtree loses exact weight with descendants still actual")
	check(inv.transactions.pickup_world_item(dropped).success and is_equal_approx(inv.get_total_weight(),weight),"short F equivalent pickup returns actual entire subtree")
	ui.toggle()
	check(not ui.item_context.visible,"inventory close clears context")
	level.queue_free()
	await process_frame
	finish_actions()

func ids(descriptors: Array) -> Array:
	var result: Array=[]
	for descriptor in descriptors: result.append(descriptor.id)
	return result

func finish_actions() -> void:
	print("ITEM_CONTEXT_ACTION_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

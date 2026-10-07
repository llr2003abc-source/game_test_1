extends "res://tests/inventory_drag_ux_test.gd"

func click_at(pointer: Vector2, button: MouseButton=MOUSE_BUTTON_LEFT, twice: bool=false) -> void:
	Input.warp_mouse(pointer)
	var event:=InputEventMouseButton.new()
	event.position=pointer
	event.global_position=pointer
	event.button_index=button
	event.pressed=true
	event.double_click=twice
	root.push_input(event)
	await process_frame
	event=InputEventMouseButton.new()
	event.position=pointer
	event.global_position=pointer
	event.button_index=button
	root.push_input(event)
	await process_frame

func _run() -> void:
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	root.grab_focus()
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	var ui: InventoryUI=p.get_node("InventoryUI")
	var inv: PlayerInventoryComponent=p.inventory
	ui.toggle()
	await process_frame
	await process_frame
	var a: InventoryItemInstance=inv.equipment.slots[5]
	var b:=InventoryItemFactory.create(load("res://data/items/backpack_1.tres"))
	a.runtime_state.grid.place_item(b,Vector2i(1,0))
	await process_frame
	await click_at(ui.equipment_views[5].get_global_rect().get_center(),MOUSE_BUTTON_LEFT,true)
	check(ui.portable_windows.windows.has(a),"native equipment double click opens root portable")
	if not ui.portable_windows.windows.has(a):
		level.queue_free()
		await process_frame
		finish_native()
		return
	var wa: PortableContainerWindow=ui.portable_windows.windows[a]
	wa.position=Vector2(550,100)
	await process_frame
	var a_id: int=wa.get_instance_id()
	await click_at(ui.equipment_views[5].get_global_rect().get_center(),MOUSE_BUTTON_LEFT,true)
	check(ui.portable_windows.windows.size()==1 and ui.portable_windows.windows[a].get_instance_id()==a_id,"native duplicate opens same window")
	await click_at(wa.views[0].get_global_rect().position+Vector2(55,12),MOUSE_BUTTON_LEFT,true)
	check(ui.portable_windows.windows.has(b),"native window item double click opens nested portable")
	if not ui.portable_windows.windows.has(b):
		level.queue_free()
		await process_frame
		finish_native()
		return
	var wb: PortableContainerWindow=ui.portable_windows.windows[b]
	wb.position=Vector2(860,100)
	await process_frame
	check(wb.parent_window==wa,"native opened child retains source window ancestry")
	var original: Vector2=wa.position
	var title: Vector2=wa.global_position+Vector2(35,20)
	await start_native_drag(title,title+Vector2(20,18))
	release_mouse(title+Vector2(20,18))
	await process_frame
	check(wa.position!=original and ui.drag_context==null and not root.gui_is_dragging(),"native title drag moves window without item ghost")
	var source: InventoryItemInstance=a.runtime_state.grid.get_item_at_cell(Vector2i.ZERO)
	var before: float=inv.get_total_weight()
	var destination: Vector2=wb.views[0].get_global_rect().position+Vector2(10,10)
	await start_native_drag(wa.views[0].get_global_rect().position+Vector2(10,10),destination)
	check(ui.drag_context!=null and ui.drag_context.candidate.get("valid",false),"native A to B drag uses existing valid placement preview")
	release_mouse(destination)
	await process_frame
	check(b.runtime_state.grid.get_placement(source)!=null and is_equal_approx(inv.get_total_weight(),before),"native cross-window drop commits actual identity with stable weight")
	await click_at(wb.views[0].get_global_rect().position+Vector2(10,10),MOUSE_BUTTON_RIGHT)
	check(ui.item_context.visible and ui.item_context.get_item_count()==3,"native window RMB renders ammo capability menu")
	ui.item_context.id_pressed.emit(2)
	await process_frame
	check(ui.split_dialog!=null and ui.split_dialog.slider.max_value==source.stack_count-1,"native menu action creates dynamically bounded split")
	if ui.split_dialog==null:
		level.queue_free()
		await process_frame
		finish_native()
		return
	ui.split_dialog.amount.value=10
	check(ui.split_dialog.slider.value==10,"native split controls synchronize")
	ui.split_dialog.confirm_split()
	await process_frame
	check(source.stack_count==50 and is_equal_approx(inv.get_total_weight(),before),"window split preserves shared weight")
	ui.portable_windows.close_window(wa)
	check(ui.portable_windows.windows.is_empty(),"native parent window close removes descendants")
	ui.toggle()
	level.queue_free()
	await process_frame
	finish_native()

func finish_native() -> void:
	print("PORTABLE_WINDOW_NATIVE_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

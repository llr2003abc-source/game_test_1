extends "res://tests/inventory_drag_ux_test.gd"

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
	var data: ItemDefinition=load("res://data/items/backpack_1.tres").duplicate()
	data.grid_size=Vector2i.ONE
	data.container_data=PortableContainerData.new()
	data.container_data.grid_sizes=[Vector2i(5,15)]
	var tall:=InventoryItemFactory.create(data)
	inv.get_equipped_backpack().grid.place_item(tall,Vector2i(1,0))
	await process_frame
	await process_frame
	var window:=ui.open_portable_container(tall)
	window.position=Vector2(700,50)
	await process_frame
	var view: InventoryGridView=window.views[0]
	var scroll: ScrollContainer=view.get_parent().get_parent()
	var source: InventoryItemInstance=inv.get_equipped_rig().grids[0].placements[0].item
	var destination: Vector2=view.get_global_rect().position+Vector2(12,12)
	await start_native_drag(ui.views[0].get_global_rect().position+Vector2(12,12),destination)
	check(ui.drag_preview.is_visible_in_tree() and ui.placement_preview.visible,"native drag into clipped tall window has ghost and preview")
	scroll.scroll_vertical=192
	await process_frame
	await process_frame
	check(ui.drag_context.candidate.position==Vector2i(0,4),"stationary pointer re-resolves actual scrolled grid coordinates")
	check(ui.drag_preview.position.is_equal_approx(destination) and ui.drag_preview.get_parent()==ui.drag_overlay,"scroll never clips or repositions cursor ghost")
	check(ui.placement_preview.visible,"visible cells retain preview after scroll")
	# Lower edge shows the visible part of a legal2-cell footprint.
	var edge: Vector2=scroll.get_global_rect().position+Vector2(12,scroll.size.y-24)
	point_mouse(edge)
	await process_frame
	check(ui.drag_context.candidate.valid,"legal target spans beyond current scroll viewport")
	check(ui.placement_preview.visible,"partially scrolled legal footprint still renders visible preview")
	root.gui_cancel_drag()
	ui.finish_drag()
	check(inv.get_equipped_rig().grids[0].get_placement(source)!=null and not ui.placement_preview.visible,"scroll cancellation leaves source and no preview")
	ui.toggle()
	level.queue_free()
	await process_frame
	print("GLOBAL_DRAG_SCROLL_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

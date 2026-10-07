extends "res://tests/inventory_drag_ux_test.gd"

func _run() -> void:
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	var ui: InventoryUI=p.get_node("InventoryUI")
	ui.toggle()
	await process_frame
	var mag: InventoryItemInstance=p.inventory.get_equipped_rig().grids[0].placements[0].item
	ui.begin_drag(mag,Vector2(12,20))
	check(is_instance_valid(ui.drag_preview),"begin alone creates global cursor ghost")
	var anchor: Control=ui.create_preview(mag)
	check(is_instance_valid(ui.drag_preview) and ui.drag_preview.get_parent() is CanvasLayer,"actual ghost belongs to global CanvasLayer")
	check(anchor!=ui.drag_preview,"native preview is non-rendering anchor rather than second cursor ghost")
	var ghost: InventoryDragGhost=ui.drag_preview
	if is_instance_valid(ghost):
		check(ghost.mouse_filter==Control.MOUSE_FILTER_IGNORE,"global visual ignores input")
		check(ghost.get_body_rect().size==Vector2(48,96),"global footprint shows unrotated magazine")
	ui.rotate_drag()
	if is_instance_valid(ghost): check(ghost.get_body_rect().size==Vector2(96,48) and not mag.rotated,"global rotation visual does not mutate item")
	ui.finish_drag()
	check(ui.drag_preview==null and ui.drag_context==null,"finish clears actual ghost and context")
	if is_instance_valid(anchor): anchor.free()
	await process_frame
	level.queue_free()
	await process_frame
	print("GLOBAL_DRAG_GHOST_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

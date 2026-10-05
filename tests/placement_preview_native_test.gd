extends "res://tests/inventory_drag_ux_test.gd"

func _run() -> void:
	var level: Node=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	root.grab_focus()
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	var inv: PlayerInventoryComponent=p.inventory
	var ui: InventoryUI=p.get_node("InventoryUI")
	inv.transactions.remove(inv.get_equipped_backpack().grid.placements[0].item)
	ui.toggle()
	await process_frame
	await process_frame
	var magazine: InventoryItemInstance=inv.get_equipped_rig().grids[0].placements[0].item
	var gun: InventoryItemInstance=inv.equipment.get_active_item()
	for original in [magazine,gun]:
		for view_index in [2,10,11]:
			var view: InventoryGridView=ui.views[view_index]
			for direction in [Vector2.RIGHT,Vector2.DOWN]:
				for pixels in [8,16,17,80]:
					var grab:=Vector2(24,24)
					var data:=ui.begin_drag(original,grab)
					var ghost:=ui.create_preview(original)
					ui.panel.force_drag(data,ghost)
					var extent: Vector2=Vector2(original.get_size())*48
					var ideal: Vector2=view.get_global_rect().position+(view.size-extent).max(Vector2.ZERO)+direction*pixels
					var pointer: Vector2=ideal+grab
					point_mouse(pointer)
					await process_frame
					var candidate:=ui.update_drag_candidate(pointer,data)
					check(root.gui_is_dragging() and is_instance_valid(ui.drag_preview),"native Ghost retained at edge "+str([original.get_size(),view_index,direction,pixels]))
					if ui.placement_preview.visible and candidate.has("grid_rect"):
						check(candidate.grid_rect.encloses(ui.placement_preview.preview_rect),"native visible footprint fully inside actual target grid")
					elif candidate.kind==&"placement" and not candidate.valid:
						check(not ui.placement_preview.visible,"native invalid edge has no floating red footprint")
					else:
						check(not ui.placement_preview.visible or candidate.kind==&"equipment","native edge exposes no fabricated grid cells")
					root.gui_cancel_drag()
					ui.finish_drag()
					await process_frame
			check(inv.transactions.get_location(original).kind==(&"equipment" if original==gun else &"grid"),"native boundary cancellation preserves original owner")
	level.queue_free()
	await process_frame
	print("PLACEMENT_PREVIEW_NATIVE_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

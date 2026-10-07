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
	await process_frame
	var inv: PlayerInventoryComponent=p.inventory
	var mag: InventoryItemInstance=inv.get_equipped_rig().grids[0].placements[0].item
	var data:=ui.begin_drag(mag,Vector2(12,12))
	var blocked:=ui.update_drag_candidate(ui.views[1].get_global_rect().position+Vector2(12,12),data)
	check(not blocked.valid and ui.placement_preview.visible,"in-bounds occupied grid renders red preview")
	check(ui.placement_preview.get_parent() is CanvasLayer and ui.placement_preview.get_parent().layer>ui.layer,"grid preview overlay is above all floating windows")
	check(inv.get_equipped_rig().grids[0].get_placement(mag)!=null,"preview never reserves or moves source")
	var same:=ui.update_drag_candidate(ui.views[0].get_global_rect().position+Vector2(12,12),data)
	check(same.valid and ui.placement_preview.visible,"same exact grid location green preview")
	var notifications: Array=[]
	var observer: Callable=func(): notifications.append(true)
	inv.transactions.changed.connect(observer)
	check(ui.commit_drag_candidate(data),"same exact grid location succeeds")
	check(notifications.is_empty(),"same exact grid location is zero-signal no-op")
	inv.transactions.changed.disconnect(observer)
	ui.finish_drag()
	data=ui.begin_drag(mag,Vector2(12,12))
	var equipped_content:=ui.update_drag_candidate(ui.equipment_views[5].get_global_rect().get_center(),data)
	check(equipped_content.kind==&"container_content" and equipped_content.valid,"equipped portable visual is also an actual content target")
	check(equipped_content.get("grid")==inv.get_equipped_backpack().grid,"equipped closed target reads actual runtime grid")
	ui.finish_drag()
	check(not ui.placement_preview.visible,"drag end clears all placement preview")
	level.queue_free()
	await process_frame
	print("DRAG_PREVIEW_CONSISTENCY_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

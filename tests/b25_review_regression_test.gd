extends "res://tests/closed_container_deposit_test.gd"

func _run() -> void:
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	var ui: InventoryUI=p.get_node("InventoryUI")
	var inv: PlayerInventoryComponent=p.inventory
	ui.toggle()
	await process_frame
	await process_frame
	var tall:=portable(Vector2i.ONE,[Vector2i(5,15)])
	inv.get_equipped_backpack().grid.place_item(tall,Vector2i(1,0))
	var hidden:=portable(Vector2i.ONE,[Vector2i(5,5)])
	tall.get_storage_grids()[0].place_item(hidden,Vector2i(0,3))
	var lower:=ui.open_portable_container(tall)
	lower.position=Vector2(500,50)
	await process_frame
	var view: InventoryGridView=lower.views[0]
	var scroll: ScrollContainer=view.get_parent().get_parent()
	scroll.scroll_vertical=192
	await process_frame
	await process_frame
	var mag_source: InventoryGrid=inv.get_equipped_rig().grids[0]
	var incoming: InventoryItemInstance=mag_source.placements[0].item
	var drag:=ui.begin_drag(incoming,Vector2(2,2))
	var chrome: Vector2=view.get_interaction_rect().position+Vector2(4,-8)
	var candidate:=ui.update_drag_candidate(chrome,drag)
	check(candidate.kind==&"none" and not candidate.valid,"scrolled chrome cannot target hidden previous-row portable")
	check(not ui.commit_drag_candidate(drag),"invisible chrome target cannot commit")
	check(hidden.get_storage_grids()[0].placements.is_empty() and mag_source.get_placement(incoming)!=null,"hidden target reject leaves source and storage unchanged")
	ui.finish_drag()
	if mag_source.get_placement(incoming)==null: inv.transactions.move(incoming,mag_source,Vector2i.ZERO)
	scroll.scroll_vertical=0
	await process_frame
	drag=ui.begin_drag(incoming,Vector2(12,12))
	ui.update_drag_candidate(view.get_global_rect().position+Vector2(12,3*48+12),drag)
	check(ui.drag_context.candidate.kind==&"container_content" and ui.drag_context.is_valid,"visible content target fixture before window close")
	ui.portable_windows.close_window(lower)
	check(ui.drag_context==null and not ui.placement_preview.visible,"closing visual target window clears nested content candidate")
	ui.finish_drag()
	lower=ui.open_portable_container(tall)
	lower.position=Vector2(500,50)
	await process_frame
	view=lower.views[0]
	var upper_item:=portable(Vector2i.ONE,[Vector2i(5,5)])
	inv.get_equipped_backpack().grid.place_item(upper_item,Vector2i(2,0))
	var upper:=ui.open_portable_container(upper_item)
	upper.position=Vector2(560,100)
	await process_frame
	await process_frame
	var wide: InventoryItemInstance=item(3,2)
	inv.get_equipped_backpack().grid.place_item(wide,Vector2i(0,2))
	await process_frame
	await process_frame
	var covered_pixel:=Vector2i(565,128)
	await RenderingServer.frame_post_draw
	var baseline_pixel: Color=root.get_texture().get_image().get_pixelv(covered_pixel)
	drag=ui.begin_drag(wide,Vector2(12,12))
	candidate=ui.update_drag_candidate(view.get_global_rect().position+Vector2(12,12),drag)
	check(candidate.valid and candidate.grid==tall.get_storage_grids()[0],"exposed lower grid keeps legal multi-cell candidate")
	ui.drag_preview.visible=false
	await RenderingServer.frame_post_draw
	var actual_pixel: Color=root.get_texture().get_image().get_pixelv(covered_pixel)
	check(actual_pixel.is_equal_approx(baseline_pixel),"lower placement overlay cannot paint upper window title pixel")
	check(ui.placement_preview.has_method("get_render_regions"),"overlay provides actual occlusion-clipped draw regions")
	if ui.placement_preview.has_method("get_render_regions"):
		var regions: Array=ui.placement_preview.call("get_render_regions")
		check(not regions.is_empty(),"exposed lower cells remain visibly previewed")
		for region: Rect2 in regions: check(not region.intersects(upper.get_global_rect()),"every actual draw region excludes upper chrome")
	ui.finish_drag()
	ui.portable_windows.close_all()
	await process_frame
	var no_op: InventoryItemInstance=item(1,1)
	inv.pockets[5].place_item(no_op,Vector2i.ZERO)
	await process_frame
	await process_frame
	no_op.runtime_state=incoming.runtime_state
	drag=ui.begin_drag(no_op,Vector2(12,12))
	ui.update_drag_candidate(ui.views[9].get_global_rect().position+Vector2(12,12),drag)
	check(not ui.commit_drag_candidate(drag),"same-location no-op cannot bypass existing runtime alias validation")
	ui.finish_drag()
	no_op.runtime_state=null
	ui.toggle()
	level.queue_free()
	await process_frame
	print("B25_REVIEW_REGRESSION_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

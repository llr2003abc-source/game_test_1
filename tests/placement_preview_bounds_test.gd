extends "res://tests/inventory_grid_test.gd"

func _run() -> void:
	var preview:=InventoryPlacementPreview.new()
	root.add_child(preview)
	for extent in [Vector2i(1,2),Vector2i(5,2)]:
		var original: InventoryItemInstance=item(extent.x,extent.y)
		var grid:=InventoryGrid.new(extent.x,extent.y)
		var context:=InventoryDragContext.new(original)
		for edge in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
			for distance in [8.0,16.0,17.0,80.0]:
				var candidate:=InventoryDragCandidateResolver.resolve_grid(context,grid,edge*distance,Vector2.ZERO)
				candidate.footprint_size=extent
				candidate.preview_rect=Rect2(Vector2(candidate.position)*48,Vector2(extent)*48)
				candidate.grid_rect=Rect2(Vector2.ZERO,Vector2(grid.size)*48)
				preview.show_candidate(candidate,48)
				var legal_raw: bool=(edge.x>0 or edge.y>0) and distance<48
				check(candidate.valid==(legal_raw or distance<=16),"legal raw or inclusive8/16 snap;17/far no invalid preview %s/%s"%[extent,edge])
				check(preview.visible==candidate.valid,"invalid no-snap shows no cell preview")
				check(not preview.visible or candidate.grid_rect.encloses(preview.preview_rect),"all visible preview footprints contained")
		var occupied: InventoryItemInstance=item(extent.x,extent.y)
		grid.place_item(occupied,Vector2i.ZERO)
		var blocked:=InventoryDragCandidateResolver.resolve_grid(context,grid,Vector2.ZERO,Vector2.ZERO)
		blocked.footprint_size=extent
		blocked.preview_rect=Rect2(Vector2.ZERO,Vector2(extent)*48)
		blocked.grid_rect=blocked.preview_rect
		preview.show_candidate(blocked,48)
		check(not preview.visible and not blocked.valid,"in-bounds occupied raw without snap also hides placement")
	var forced: Dictionary={"kind":&"placement","valid":true,"preview_rect":Rect2(-48,0,48,96),"grid_rect":Rect2(0,0,48,96),"footprint_size":Vector2i(1,2)}
	preview.show_candidate(forced,48)
	check(not preview.visible,"renderer rejects otherwise valid footprint outside grid bounds")
	preview.queue_free()
	await process_frame
	print("PLACEMENT_PREVIEW_BOUNDS_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

extends "res://tests/inventory_grid_test.gd"

func point_mouse(position: Vector2) -> void:
	Input.warp_mouse(position)
	var motion:=InputEventMouseMotion.new()
	motion.position=position
	motion.global_position=position
	root.push_input(motion)

func release_mouse(position: Vector2) -> void:
	var release:=InputEventMouseButton.new()
	release.button_index=MOUSE_BUTTON_LEFT
	release.position=position
	release.global_position=position
	root.push_input(release)

func start_native_drag(start: Vector2, destination: Vector2) -> void:
	Input.warp_mouse(start)
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.button_mask=MOUSE_BUTTON_MASK_LEFT
	press.position=start
	press.global_position=start
	root.push_input(press)
	await process_frame
	for position in [start+Vector2(12,0),destination]:
		var motion:=InputEventMouseMotion.new()
		motion.position=position
		motion.global_position=position
		motion.relative=position-start
		motion.button_mask=MOUSE_BUTTON_MASK_LEFT
		Input.warp_mouse(position)
		root.push_input(motion)
		await process_frame

func _run() -> void:
	for script_path in ["inventory_drag_ghost","inventory_placement_preview"]:
		check(FileAccess.file_exists("res://scripts/ui/%s.gd"%script_path),"required drag visual: "+script_path)
	if failures==0:
		var level: Node=load("res://scenes/levels/test_level.tscn").instantiate()
		root.add_child(level)
		current_scene=level
		root.grab_focus()
		await process_frame
		var p: Variant=level.get_node("Player")
		var inv: Variant=p.inventory
		var ui: Variant=p.get_node("InventoryUI")
		ui.toggle()
		await process_frame
		var source: InventoryGrid=inv.get_equipped_rig().grids[0]
		var target: InventoryGrid=inv.get_equipped_rig().grids[2]
		var mag: InventoryItemInstance=source.placements[0].item
		for grab in [Vector2(24,12),Vector2(24,48),Vector2(24,75)]:
			var destination: Vector2=ui.views[2].get_global_rect().position+grab
			await start_native_drag(ui.views[0].get_global_rect().position+grab,destination)
			check(ui.drag_context!=null and root.gui_is_dragging(),"actual click starts native drag")
			check(ui.drag_context.grab_offset_pixels==grab,"actual click preserves original top/middle/bottom offset")
			check(ui.drag_context.is_valid and ui.drag_context.current_target_container==target,"actual click resolves empty target")
			release_mouse(destination)
			await process_frame
			check(target.get_placement(mag)!=null,"actual click release moves original magazine")
			inv.transactions.move(mag,source,Vector2i.ZERO)
			await process_frame
		for grab in [Vector2(24,12),Vector2(24,48),Vector2(24,75)]:
			var target_view: Variant=ui.views[2]
			var destination: Vector2=target_view.get_global_rect().position+grab
			var data: Dictionary=ui.begin_drag(mag,grab)
			var ghost: Variant=ui.create_preview(mag)
			ui.views[0].force_drag(data,ghost)
			point_mouse(destination)
			await process_frame
			var candidate: Dictionary=ui.update_drag_candidate(destination,data).duplicate()
			check(candidate.valid and candidate.grid==target and candidate.position==Vector2i.ZERO,"native top/middle/bottom preview resolves target")
			check(ui.placement_preview.visible and ui.placement_preview.footprint_size==Vector2i(1,2),"whole magazine footprint preview")
			check(ghost.mouse_filter==Control.MOUSE_FILTER_IGNORE and ui.placement_preview.mouse_filter==Control.MOUSE_FILTER_IGNORE,"both overlay visuals ignore pointer")
			check(ghost.get_body_rect().position==-grab and ghost.get_body_rect().size==Vector2(48,96),"ghost body offset keeps original grab")
			check(ghost.caption.contains("Magazine 1") and ghost.caption.contains("30/30"),"ghost displays live name and magazine rounds")
			check(source.get_placement(mag)!=null and target.placements.is_empty(),"source item retained throughout native drag")
			release_mouse(destination)
			await process_frame
			check(target.get_placement(mag)!=null and target.get_placement(mag).position==candidate.position,"native drop commits exact displayed candidate")
			check(ui.drag_context==null and not ui.placement_preview.visible and not root.gui_is_dragging(),"successful native drop clears ghost and preview")
			inv.transactions.move(mag,source,Vector2i.ZERO)
			await process_frame
		var grab:=Vector2(24,75)
		var origin: Vector2=ui.views[2].get_global_rect().position
		var data: Dictionary=ui.begin_drag(mag,grab)
		var ghost: Variant=ui.create_preview(mag)
		ui.views[0].force_drag(data,ghost)
		var near_position: Vector2=origin+grab-Vector2(8,0)
		point_mouse(near_position)
		await process_frame
		var candidate: Dictionary=ui.update_drag_candidate(near_position,data).duplicate()
		check(candidate.valid and candidate.snapped and is_equal_approx(candidate.snap_distance,8.0),"native near miss snaps8pixels")
		check(ui.placement_preview.preview_rect.position==origin,"snapped footprint shows exact rig origin")
		release_mouse(near_position)
		await process_frame
		check(target.get_placement(mag)!=null and target.get_placement(mag).position==candidate.position,"snapped native drop matches preview")
		inv.transactions.move(mag,source,Vector2i.ZERO)
		await process_frame
		for pixels in [16,17]:
			data=ui.begin_drag(mag,grab)
			ghost=ui.create_preview(mag)
			ui.views[0].force_drag(data,ghost)
			var boundary: Vector2=origin+grab-Vector2(pixels,0)
			point_mouse(boundary)
			await process_frame
			check(ui.drag_context.is_valid==(pixels==16) and ui.drag_context.is_snapped==(pixels==16),"native snap inclusive16 excludes17")
			release_mouse(boundary)
			await process_frame
			check((target.get_placement(mag)!=null)==(pixels==16),"native boundary drop follows preview")
			if pixels==16:
				inv.transactions.move(mag,source,Vector2i.ZERO)
				await process_frame
		# Pointer is in the gap; the parent drop surface must accept a local snap.
		data=ui.begin_drag(mag,Vector2.ZERO)
		ghost=ui.create_preview(mag)
		ui.views[0].force_drag(data,ghost)
		point_mouse(origin-Vector2(3,0))
		await process_frame
		check(ui.drag_context.is_valid and ui.drag_context.current_target_container==target and ui.drag_context.is_snapped,"grid gap resolves nearby original target")
		release_mouse(origin-Vector2(3,0))
		await process_frame
		check(target.get_placement(mag)!=null,"parent drop surface accepts gap snap")
		inv.transactions.move(mag,source,Vector2i.ZERO)
		await process_frame
		data=ui.begin_drag(mag,grab)
		ghost=ui.create_preview(mag)
		ui.views[0].force_drag(data,ghost)
		point_mouse(origin+grab)
		await process_frame
		ui.rotate_drag()
		check(ui.drag_context.preview_rotation and not mag.rotated,"R changes only preview rotation")
		check(ghost.get_body_rect().size==Vector2(96,48) and ui.drag_context.grab_offset_pixels==Vector2(48,37.5),"R immediately updates ghost dimensions and anchor")
		check(not ui.drag_context.is_valid and ui.placement_preview.footprint_size==Vector2i(2,1),"R invalidates old rig candidate and redraws full footprint")
		check(not ui.placement_preview.is_valid,"invalid preview explicitly marked")
		ui.rotate_drag()
		check(ui.drag_context.grab_offset_pixels==grab and not data.rotated,"second R restores grab with no drift")
		point_mouse(Vector2(1100,40))
		await process_frame
		check(not ui.placement_preview.visible and root.gui_is_dragging(),"leaving containers hides placement but keeps ghost")
		release_mouse(Vector2(1100,40))
		await process_frame
		check(source.get_placement(mag)!=null and not mag.rotated and ui.drag_context==null,"outside drop cancels without inventory mutation")
		# A legal rotated drop commits move and rotation together, never during preview.
		data=ui.begin_drag(mag,grab)
		ghost=ui.create_preview(mag)
		ui.views[0].force_drag(data,ghost)
		ui.rotate_drag()
		var rotated_destination: Vector2=ui.views[10].get_global_rect().position+Vector2(144,144)+ui.drag_context.grab_offset_pixels
		point_mouse(rotated_destination)
		await process_frame
		check(ui.drag_context.is_valid and not mag.rotated,"valid rotated placement keeps real orientation until release")
		candidate=ui.drag_context.candidate.duplicate()
		release_mouse(rotated_destination)
		await process_frame
		check(mag.rotated and inv.get_equipped_backpack().grid.get_placement(mag).position==candidate.position,"rotated release atomically commits displayed footprint")
		inv.transactions.move(mag,source,Vector2i.ZERO,false)
		await process_frame
		var ammo: InventoryItemInstance=inv.get_equipped_backpack().grid.placements[0].item
		for i in range(13): mag.runtime_state.pop_round()
		data=ui.begin_drag(ammo,Vector2(24,24))
		var load_position: Vector2=ui.views[0].get_global_rect().position+Vector2(24,75)
		candidate=ui.update_drag_candidate(load_position,data)
		check(candidate.valid and candidate.kind==&"load" and ui.placement_preview.footprint_size==Vector2i(1,2),"ammo load highlights whole magazine instead of placement")
		check(ammo.stack_count==60 and mag.runtime_state.get_round_count()==17,"special preview does not load rounds")
		check(ui.commit_drag_candidate(data) and ammo.stack_count==47 and mag.runtime_state.get_round_count()==30,"special candidate commits existing loading transaction")
		ui.finish_drag()
		await process_frame
		var split: InventoryItemInstance=inv.transactions.split_stack(ammo,20)
		await process_frame
		data=ui.begin_drag(split,Vector2(24,24))
		var stack_position: Vector2=ui.views[10].get_global_rect().position+Vector2(24,24)
		candidate=ui.update_drag_candidate(stack_position,data)
		check(candidate.valid and candidate.kind==&"stack" and ui.placement_preview.footprint_size==Vector2i.ONE,"merge target shown as one special stack footprint")
		check(ui.commit_drag_candidate(data) and ammo.stack_count==47,"stack commits unchanged merge transaction")
		ui.finish_drag()
		await process_frame
		var gun: InventoryItemInstance=inv.equipment.get_active_item()
		data=ui.begin_drag(gun,Vector2(120,48))
		candidate=ui.update_drag_candidate(ui.equipment_views[0].get_global_rect().get_center(),data)
		check(candidate.valid and candidate.kind==&"equipment","whole primary slot valid highlight")
		check(ui.placement_preview.preview_rect==ui.equipment_views[0].get_global_rect(),"equipment preview uses whole slot rectangle")
		candidate=ui.update_drag_candidate(ui.equipment_views[2].get_global_rect().get_center(),data)
		check(not candidate.valid and not ui.placement_preview.is_valid,"wrong pistol slot invalid highlight")
		var bag_origin: Vector2=ui.views[10].get_global_rect().position
		candidate=ui.update_drag_candidate(bag_origin+Vector2(120,96),data)
		check(candidate.valid and ui.placement_preview.footprint_size==Vector2i(5,2),"weapon preview covers5x2")
		ui.rotate_drag()
		check(ui.placement_preview.footprint_size==Vector2i(2,5) and not gun.rotated,"weapon R instantly updates2x5 without item mutation")
		ui.finish_drag()
		# Supported external transactions must not leave an old green preview alive.
		data=ui.begin_drag(mag,grab)
		ghost=ui.create_preview(mag)
		ui.views[0].force_drag(data,ghost)
		point_mouse(origin+grab)
		await process_frame
		var other: InventoryItemInstance=inv.get_equipped_rig().grids[1].placements[0].item
		inv.transactions.move(other,target,Vector2i.ZERO)
		check(ui.drag_context==null and not root.gui_is_dragging() and not ui.placement_preview.visible,"external target occupancy cancels stale native preview")
		check(source.get_placement(mag)!=null,"external target change never moves dragged item")
		inv.transactions.move(other,inv.get_equipped_rig().grids[1],Vector2i.ZERO)
		await process_frame
		data=ui.begin_drag(mag,grab)
		ghost=ui.create_preview(mag)
		ui.views[0].force_drag(data,ghost)
		point_mouse(ui.views[2].get_global_rect().position+grab)
		await process_frame
		inv.transactions.move(mag,inv.get_equipped_backpack().grid,Vector2i(3,3))
		check(ui.drag_context==null and not root.gui_is_dragging(),"external source ownership change cancels native drag")
		check(inv.get_equipped_backpack().grid.get_placement(mag)!=null,"cancel preserves external transaction result")
		inv.transactions.move(mag,source,Vector2i.ZERO)
		await process_frame
		data=ui.begin_drag(ammo,Vector2(24,24))
		ghost=ui.create_preview(ammo)
		ui.views[10].force_drag(data,ghost)
		point_mouse(ui.views[4].get_global_rect().get_center())
		await process_frame
		split=inv.transactions.split_stack(ammo,10)
		check(ui.drag_context==null and not root.gui_is_dragging(),"external ammo count change cancels stale ghost")
		check(ammo.stack_count==37 and split.stack_count==10,"cancel keeps externally split ammo count")
		check(ui.drag_preview==null and not ui.placement_preview.visible,"external change clears all overlay state")
		inv.transactions.merge_stacks(split,ammo)
		await process_frame
		data=ui.begin_drag(mag,grab)
		ghost=ui.create_preview(mag)
		ui.views[0].force_drag(data,ghost)
		point_mouse(origin+grab)
		await process_frame
		var escape:=InputEventKey.new()
		escape.keycode=KEY_ESCAPE
		escape.pressed=true
		root.push_input(escape)
		await process_frame
		check(not ui.visible and ui.drag_context==null and not ui.placement_preview.visible and not root.gui_is_dragging(),"ESC clears actual drag and overlays")
		check(source.get_placement(mag)!=null and inv.equipment.get_active_item()==gun,"ESC leaves source and weapon states unchanged")
		level.queue_free()
		await process_frame
	print("INVENTORY_DRAG_UX_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

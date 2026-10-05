extends "res://tests/inventory_drag_ux_test.gd"
func _run() -> void:
	var probe:=InventoryUI.new()
	check(probe.has_method("open_container"),"shared inventory container mode exists")
	probe.free()
	if failures==0: await exercise()
	print("CONTAINER_UI_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

func view_for(ui: InventoryUI, grid: InventoryGrid) -> InventoryGridView:
	for view in ui.views:
		if view.grid==grid: return view
	return null

func native_move(ui: InventoryUI, item_value: InventoryItemInstance, grid: InventoryGrid, cell: Vector2i) -> void:
	var source: InventoryGrid=item_value.get_owner_registry().get_location(item_value).grid
	var start: Vector2=view_for(ui,source).get_global_rect().position+Vector2(source.get_placement(item_value).position)*48+Vector2(24,24)
	var finish: Vector2=view_for(ui,grid).get_global_rect().position+Vector2(cell)*48+Vector2(24,24)
	await start_native_drag(start,finish)
	check(root.gui_is_dragging() and ui.drag_context!=null,"native container drag uses existing context")
	check(ui.drag_context.is_valid,"native container candidate green")
	release_mouse(finish)
	await process_frame
	await process_frame

func exercise() -> void:
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	root.grab_focus()
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	var ui: InventoryUI=p.get_node("InventoryUI")
	var inv: PlayerInventoryComponent=p.inventory
	var crate: LootContainer=level.get_node("LootCrateA")
	p.global_position=crate.global_position+Vector3(0,0,1.8)
	p.camera.look_at(crate.get_interaction_position())
	await physics_frame
	check(ui.open_container(crate),"existing InventoryUI opens crate")
	await process_frame
	await process_frame
	var grid:=crate.runtime.inventory_grid
	var ext:=crate.runtime.transactions
	var view:=view_for(ui,grid)
	check(ui.mode==InventoryUI.Mode.CONTAINER_LOOT and ui.nearby_panel==null,"container replaces Nearby")
	check(view!=null and view.size==Vector2(384,288) and ui.views.size()==13,"right grid8x6 at48px; all prior player grids kept")
	check(root.get_visible_rect().encloses(view.get_global_rect()),"whole external grid fits screen")
	var view_id: int=view.get_instance_id()
	await create_timer(0.3).timeout
	check(view_for(ui,grid).get_instance_id()==view_id,"idle UI never rebuilds per-frame")
	var mag:=grid.get_item_at_cell(Vector2i(6,1))
	var state: MagazineInstance=mag.runtime_state
	await native_move(ui,mag,inv.get_equipped_rig().grids[2],Vector2i.ZERO)
	check(inv.get_equipped_rig().grids[2].get_placement(mag)!=null and state.get_round_count()==17,"actual crate MAG17->Rig retains state")
	check(inv.reload_coordinator.get_available_magazine_count()==3,"actual Rig transfer immediately eligible for reload")
	check(view_for(ui,grid).get_instance_id()==view_id,"data-driven transfer redraw keeps controls")
	await native_move(ui,mag,grid,Vector2i(7,1))
	check(grid.get_placement(mag)!=null and inv.reload_coordinator.get_available_magazine_count()==2,"return mag to crate removes reload eligibility")
	await native_move(ui,mag,inv.secure.grid,Vector2i.ZERO)
	check(inv.secure.grid.get_placement(mag)!=null and mag.runtime_state==state,"manual crate->Secure exact instance")
	var ammo:=grid.get_item_at_cell(Vector2i(5,0))
	await native_move(ui,ammo,inv.get_equipped_backpack().grid,Vector2i(1,0))
	check(inv.get_equipped_backpack().grid.get_placement(ammo)!=null and ammo.stack_count==40,"actual crate ammo->Backpack40")
	await native_move(ui,ammo,grid,Vector2i(7,0))
	check(grid.get_placement(ammo).position==Vector2i(7,0),"actual player->crate ammo retains position")
	var gun:=grid.get_item_at_cell(Vector2i.ZERO)
	var active: WeaponRuntime=p.firearm.weapon_runtime
	var start: Vector2=view_for(ui,grid).get_global_rect().position+Vector2(24,24)
	var finish: Vector2=ui.equipment_views[1].get_global_rect().get_center()
	await start_native_drag(start,finish)
	check(ui.drag_context.is_valid and ui.drag_context.candidate.kind==&"equipment","native gun Slot2 green")
	release_mouse(finish)
	await process_frame
	check(inv.equipment.slots[1]==gun and p.firearm.weapon_runtime==active,"native gun->Slot2 preserves activeSlot1")
	check(gun.runtime_state.get_magazine_round_count()==17 and gun.runtime_state.chambered_round!=null,"native weapon CH1MAG17 maintained")
	var data:=ui.begin_drag(ammo,Vector2(24,24))
	var point: Vector2=view_for(ui,grid).get_global_rect().position+Vector2(24,24)
	var candidate:=ui.update_drag_candidate(point,data)
	check(candidate.valid and candidate.position==Vector2i.ZERO and not candidate.snapped,"valid raw cell has priority")
	ui.rotate_drag()
	check(not ammo.rotated and ui.drag_context.preview_rotation,"R preview never modifies source rotation")
	check(ui.commit_drag_candidate(data),"cached container candidate commits")
	ui.finish_drag()
	check(ammo.rotated and grid.get_placement(ammo).position==Vector2i.ZERO,"container rotate persists original item")
	var player_stack:=inv.get_equipped_backpack().grid.get_item_at_cell(Vector2i.ZERO)
	player_stack.stack_count=50
	inv.transactions.changed.emit()
	await native_move(ui,ammo,inv.get_equipped_backpack().grid,Vector2i.ZERO)
	check(player_stack.stack_count==60 and ammo.stack_count==30 and grid.get_placement(ammo)!=null,"native partial cross merge keeps source C30")
	await native_move(ui,ammo,inv.secure.grid,Vector2i.ZERO)
	check(state.get_round_count()==30 and ammo.stack_count==17,"native cross LOAD consumes13; original source remains C17")
	var other_stack:=grid.get_item_at_cell(Vector2i(6,0))
	await native_move(ui,player_stack,grid,Vector2i(6,0))
	check(other_stack.stack_count==60 and player_stack.stack_count==25,"native reverse merge max60 leaves PLAYER25")
	ui.selected_item=ammo
	ui.split_amount.value=5
	ui._split_selected()
	check(ammo.stack_count==12 and grid.placements.any(func(place): return place.item!=ammo and place.item.definition==ammo.definition and place.item.stack_count==5),"existing split action uses selected external registry")
	check(view_for(ui,grid).get_instance_id()==view_id,"merge/load/split redraw keeps original grid view")
	ui.toggle()
	check(not ui.visible and ui.container_access==null and ui.current_open_container==null,"close cleans session")
	check(ui.open_container(crate),"reopen same crate")
	await process_frame
	check(grid.get_placement(ammo).position==Vector2i.ZERO and ammo.rotated and mag.runtime_state==state,"reopen preserves moved/rotated/runtime state")
	check(ext.world_items.is_empty() and inv.transactions.world_items.is_empty(),"native transfers never create world items")
	level.queue_free()
	await process_frame

extends "res://tests/inventory_drag_ux_test.gd"

var ui: InventoryUI
var inv: PlayerInventoryComponent

func native_move(start: Vector2, destination: Vector2, expected_valid: bool=true, expected_kind: StringName=&"placement") -> Dictionary:
	await start_native_drag(start,destination)
	var candidate: Dictionary=ui.drag_context.candidate.duplicate() if ui.drag_context!=null else {}
	check(root.gui_is_dragging() and is_instance_valid(ui.drag_preview) and ui.drag_preview.is_visible_in_tree(),"actual native global ghost survives route")
	check(ui.drag_preview.get_parent()==ui.drag_overlay and ui.drag_overlay.layer>ui.preview_overlay.layer,"ghost parent and z-order above preview/window")
	check(ui.drag_overlay.get_child_count()==1,"one visible ghost per native session")
	check(candidate.get("valid",false)==expected_valid and candidate.get("kind")==expected_kind,"actual native candidate validity/type")
	check(ui.placement_preview.visible and ui.placement_preview.is_valid==expected_valid,"actual native green/red preview visible")
	if is_instance_valid(ui.drag_preview): check(ui.drag_preview.position.is_equal_approx(destination),"global cursor ghost follows pointer")
	release_mouse(destination)
	await process_frame
	await process_frame
	check(ui.drag_context==null and ui.drag_preview==null and ui.drag_overlay.get_child_count()==0 and not ui.placement_preview.visible,"native release clears ghost and preview")
	return candidate

func grid_point(view: InventoryGridView, cell: Vector2i=Vector2i.ZERO) -> Vector2:
	return view.get_global_rect().position+Vector2(cell)*48+Vector2(12,12)

func _run() -> void:
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	root.grab_focus()
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	ui=p.get_node("InventoryUI")
	inv=p.inventory
	ui.toggle()
	await process_frame
	await process_frame
	var a: InventoryItemInstance=inv.equipment.slots[5]
	var ammo: InventoryItemInstance=a.get_storage_grids()[0].get_item_at_cell(Vector2i.ZERO)
	var main: InventoryGridView=ui.views[10]
	var weight: float=inv.get_total_weight()
	await native_move(grid_point(main),grid_point(main,Vector2i(0,1)))
	check(a.get_storage_grids()[0].get_placement(ammo).position==Vector2i(0,1),"Main same-grid uses displayed destination")
	var wa:=ui.open_portable_container(a)
	wa.position=Vector2(550,100)
	await process_frame
	await native_move(grid_point(wa.views[0],Vector2i(0,1)),grid_point(wa.views[0],Vector2i(0,2)))
	check(a.get_storage_grids()[0].get_placement(ammo).position==Vector2i(0,2),"opened root same-grid preview/commit matches")
	await native_move(grid_point(wa.views[0],Vector2i(0,2)),grid_point(ui.views[4]))
	check(inv.pockets[0].get_placement(ammo)!=null,"Window to Main actual pocket")
	var b:=InventoryItemFactory.create(load("res://data/items/backpack_1.tres"))
	a.get_storage_grids()[0].place_item(b,Vector2i(1,0))
	await process_frame
	await process_frame
	var wb:=ui.open_portable_container(b,wa)
	wb.position=Vector2(860,100)
	await process_frame
	await native_move(grid_point(ui.views[4]),grid_point(wb.views[0]))
	check(b.get_storage_grids()[0].get_placement(ammo)!=null,"Main to nested Window actual grid")
	await native_move(grid_point(wb.views[0]),grid_point(wa.views[0],Vector2i(0,3)))
	check(a.get_storage_grids()[0].get_placement(ammo).position==Vector2i(0,3),"Window B to Window A actual grid")
	await native_move(grid_point(wa.views[0],Vector2i(0,3)),grid_point(wb.views[0],Vector2i(2,2)))
	check(b.get_storage_grids()[0].get_placement(ammo).position==Vector2i(2,2),"Window A to Window B actual grid")
	await native_move(grid_point(wb.views[0],Vector2i(2,2)),grid_point(ui.views[4]))
	ui.portable_windows.close_window(wb)
	await process_frame
	await native_move(grid_point(ui.views[4]),grid_point(wa.views[0],Vector2i(1,0)),true,&"container_content")
	check(b.get_storage_grids()[0].get_placement(ammo).position==Vector2i.ZERO,"closed B receives actual ammo at deterministic0,0")
	check(not ui.portable_windows.windows.has(b),"closed deposit never opens B window")
	check(is_equal_approx(inv.get_total_weight(),weight+1.5),"native same-registry deposit weight unchanged except fixture bag")
	wb=ui.open_portable_container(b,wa)
	wb.position=Vector2(860,100)
	await process_frame
	check(wb.views[0].grid.get_item_at_cell(Vector2i.ZERO)==ammo,"native opening afterwards sees original ammo")
	await native_move(grid_point(wb.views[0]),grid_point(ui.views[4]))
	ui.portable_windows.close_window(wb)
	var blocker:=InventoryItemInstance.new(ItemDefinition.new())
	blocker.definition.grid_size=Vector2i(5,5)
	b.get_storage_grids()[0].place_item(blocker,Vector2i.ZERO)
	await process_frame
	await native_move(grid_point(ui.views[4]),grid_point(wa.views[0],Vector2i(1,0)),false,&"container_content")
	check(inv.pockets[0].get_placement(ammo)!=null,"native full target reject keeps source")
	check(not ui.portable_windows.windows.has(b),"rejection does not open window")
	b.get_storage_grids()[0].remove_item(blocker)
	await process_frame
	# Title chrome blocks candidates while ghost remains visible.
	await start_native_drag(grid_point(ui.views[4]),wa.global_position+Vector2(35,20))
	check(ui.drag_preview.is_visible_in_tree() and ui.drag_context.candidate.kind==&"none" and not ui.placement_preview.visible,"title chrome leaves cursor ghost and no hidden lower preview")
	root.gui_cancel_drag()
	ui.finish_drag()
	check(ui.drag_overlay.get_child_count()==0,"native cancel removes sole global ghost")
	# Source window close safely cancels active native drag.
	await start_native_drag(grid_point(wa.views[0],Vector2i(1,0)),grid_point(ui.views[10],Vector2i(0,4)))
	ui.portable_windows.close_window(wa)
	check(ui.drag_context==null and ui.drag_preview==null and not ui.placement_preview.visible,"source window close clears native state")
	var crate: LootContainer=level.get_node("LootCrateA")
	p.global_position=crate.global_position+Vector3(0,0,1.8)
	p.camera.look_at(crate.get_interaction_position())
	await physics_frame
	check(ui.open_container(crate),"native external fixture opens actual crate")
	await process_frame
	await process_frame
	wb=ui.open_portable_container(b)
	wb.position=Vector2(0,80)
	await process_frame
	var external_view: InventoryGridView=ui.views.back()
	var crate_ammo: InventoryItemInstance=crate.runtime.inventory_grid.get_item_at_cell(Vector2i(5,0))
	await native_move(grid_point(external_view,Vector2i(5,0)),grid_point(wb.views[0]))
	check(b.get_storage_grids()[0].get_item_at_cell(Vector2i.ZERO)==crate_ammo,"native Crate to Window preserves actual item")
	await native_move(grid_point(wb.views[0]),grid_point(external_view,Vector2i(5,0)))
	check(crate.runtime.inventory_grid.get_item_at_cell(Vector2i(5,0))==crate_ammo,"native Window to Crate existing transfer")
	ui.portable_windows.close_window(wb)
	await process_frame
	var external_before: float=crate.runtime.get_contents_weight()
	var carried_before: float=inv.get_total_weight()
	var ammo_weight: float=crate_ammo.get_weight()
	await native_move(grid_point(external_view,Vector2i(5,0)),grid_point(ui.views[10],Vector2i(1,0)),true,&"container_content")
	check(inv.transactions.get_direct_parent(crate_ammo).parent_item==b,"native Crate directly to closed B no Root intermediate")
	check(is_equal_approx(inv.get_total_weight(),carried_before+ammo_weight) and is_equal_approx(crate.runtime.get_contents_weight(),external_before-ammo_weight),"native closed external equal opposite weight")
	check(ui.portable_windows.windows.is_empty(),"native external deposit no auto open")
	# Change targets mid-drag: one overlay reflects only the current candidate.
	await start_native_drag(grid_point(ui.views[4]),grid_point(ui.views[5]))
	var first_rect: Rect2=ui.placement_preview.preview_rect
	point_mouse(grid_point(ui.views[6]))
	await process_frame
	check(ui.drag_preview.is_visible_in_tree() and ui.placement_preview.preview_rect!=first_rect and ui.drag_context.candidate.grid==inv.pockets[2],"old target preview cleared and new target drawn")
	ui.toggle()
	check(ui.drag_context==null and ui.drag_preview==null and not root.gui_is_dragging(),"Inventory close cancels native ghost everywhere")
	level.queue_free()
	await process_frame
	print("CLOSED_CONTAINER_NATIVE_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

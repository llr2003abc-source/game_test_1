extends "res://tests/closed_container_deposit_test.gd"

func view_for(ui: InventoryUI, grid: InventoryGrid) -> InventoryGridView:
	for view: InventoryGridView in ui.portable_windows.get_views():
		if view.grid==grid: return view
	for view: InventoryGridView in ui.views:
		if view.grid==grid: return view
	return null

func content_candidate(ui: InventoryUI, incoming: InventoryItemInstance, target: InventoryItemInstance) -> Dictionary:
	var outer: InventoryGrid=target.get_owner_registry().get_location(target).grid
	var view:=view_for(ui,outer)
	ui.begin_drag(incoming,Vector2(12,12))
	return ui.update_drag_candidate(view.get_global_rect().position+Vector2(outer.get_placement(target).position)*48+Vector2(12,12),ui.drag_data)

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
	var a: InventoryItemInstance=inv.equipment.slots[5]
	var b:=bag()
	check(a.get_storage_grids()[0].place_item(b,Vector2i(1,0)),"nested actual target fixture")
	await process_frame
	await process_frame
	var incoming: InventoryItemInstance=a.get_storage_grids()[0].get_item_at_cell(Vector2i.ZERO)
	var before: float=inv.get_total_weight()
	var candidate:=content_candidate(ui,incoming,b)
	check(candidate.valid and ui.placement_preview.visible and ui.placement_preview.kind==&"container_content","green whole closed footprint overlay")
	check(inv.transactions.reservations.is_empty() and is_equal_approx(inv.get_total_weight(),before),"preview has zero reservations and stable weight")
	var observed: Array=[]
	var listener: Callable=func(): observed.append(inv.get_total_weight())
	inv.transactions.changed.connect(listener)
	check(ui.commit_drag_candidate(ui.drag_data),"same-registry closed deposit succeeds")
	check(b.get_storage_grids()[0].get_item_at_cell(Vector2i.ZERO)==incoming,"commit uses preview0,0 exact item")
	check(observed==[before] and inv.transactions.reservations.is_empty() and inv.get_total_weight()==before,"committed notification and lease release preserve carried weight")
	inv.transactions.changed.disconnect(listener)
	check(ui.portable_windows.windows.is_empty(),"closed deposit does not auto open any window")
	ui.finish_drag()
	var wa:=ui.open_portable_container(a)
	wa.position=Vector2(550,100)
	var wb:=ui.open_portable_container(b,wa)
	wb.position=Vector2(860,100)
	await process_frame
	check(wb.views[0].grid.get_item_at_cell(Vector2i.ZERO)==incoming,"open afterwards displays actual deposited item")
	inv.transactions.move(incoming,inv.pockets[0],Vector2i.ZERO)
	await process_frame
	candidate=content_candidate(ui,incoming,b)
	check(candidate.valid,"open window does not change external footprint deposit semantics")
	inv.transactions.reserve_item(b,false)
	check(not ui.commit_drag_candidate(ui.drag_data) and inv.pockets[0].get_placement(incoming)!=null,"target reserved after green rejects with intact source")
	inv.transactions.finish_reservation(inv.transactions.reservations[b])
	ui.finish_drag()
	candidate=content_candidate(ui,incoming,b)
	var blocker: InventoryItemInstance=item(5,5)
	b.get_storage_grids()[0].place_item(blocker,Vector2i.ZERO)
	check(not ui.commit_drag_candidate({"item":incoming}) and inv.pockets[0].get_placement(incoming)!=null,"space consumed after preview causes zero source mutation")
	b.get_storage_grids()[0].remove_item(blocker)
	ui.finish_drag()
	ui.portable_windows.close_all()
	var crate: LootContainer=level.get_node("LootCrateA")
	p.global_position=crate.global_position+Vector3(0,0,1.8)
	p.camera.look_at(crate.get_interaction_position())
	await physics_frame
	check(ui.open_container(crate),"external actual access opens crate")
	await process_frame
	await process_frame
	var ext:=crate.runtime.transactions
	var crate_mag: InventoryItemInstance=crate.runtime.inventory_grid.get_item_at_cell(Vector2i(6,1))
	var rounds: Array[AmmoData]=crate_mag.runtime_state.rounds.duplicate()
	var runtime_id: int=crate_mag.runtime_state.get_instance_id()
	var player_before: float=inv.get_total_weight()
	var crate_before: float=crate.runtime.get_contents_weight()
	var mass: float=crate_mag.get_weight()
	candidate=content_candidate(ui,crate_mag,b)
	check(candidate.valid and candidate.grid==b.get_storage_grids()[0],"crate directly resolves nested target not Player Root")
	check(ui.commit_drag_candidate(ui.drag_data),"single external content commit succeeds")
	check(crate_mag.get_owner_registry()==inv.transactions and inv.transactions.get_direct_parent(crate_mag).parent_item==b,"one commit final parent B and Player registry")
	check(crate_mag.runtime_state.get_instance_id()==runtime_id and crate_mag.runtime_state.rounds==rounds,"runtime and actual rounds order preserved")
	check(is_equal_approx(inv.get_total_weight(),player_before+mass) and is_equal_approx(crate.runtime.get_contents_weight(),crate_before-mass),"external weights equal and opposite")
	check(ext.reservations.is_empty() and inv.transactions.reservations.is_empty() and not ext.locked and not inv.transactions.locked,"external deposit leaves no leases or locks")
	ui.finish_drag()
	var nested:=portable(Vector2i.ONE,[Vector2i(5,5)])
	var nested_rig:=InventoryItemFactory.create(load("res://data/items/rig_1.tres"))
	var nested_mag:=mag(0)
	var round_a: AmmoData=load("res://data/ammo/test_round.tres")
	var round_b: AmmoData=round_a.duplicate()
	round_b.flesh_damage=50.0
	for round_data: AmmoData in [round_a,round_b,round_a]: nested_mag.runtime_state.push_round(round_data)
	nested_rig.get_storage_grids()[0].place_item(nested_mag,Vector2i.ZERO)
	nested.get_storage_grids()[0].place_item(nested_rig,Vector2i.ZERO)
	check(inv.transactions.place_complete_subtree(nested,a.get_storage_grids()[0],Vector2i.ZERO),"actual complete C Rig mixed-Mag source fixture")
	var nested_before: float=inv.get_total_weight()
	var nested_runtime: RefCounted=nested.runtime_state
	var mag_runtime: MagazineInstance=nested_mag.runtime_state
	var lease:=inv.transactions.reserve_item(nested)
	check(lease!=null and is_equal_approx(inv.get_total_weight(),nested_before),"complete subtree weight remains continuous during actual reservation")
	check(inv.transactions.cancel_reservation(lease) and is_equal_approx(inv.get_total_weight(),nested_before),"reservation cancel restores complete subtree and weight")
	await process_frame
	await process_frame
	candidate=content_candidate(ui,nested,b)
	check(candidate.valid and ui.commit_drag_candidate(ui.drag_data),"complete portable subtree deposits into closed B")
	check(inv.transactions.get_direct_parent(nested).parent_item==b and inv.transactions.get_direct_parent(nested_rig).parent_item==nested and inv.transactions.get_direct_parent(nested_mag).parent_item==nested_rig,"all complete subtree identities and real edges retained")
	check(nested.runtime_state==nested_runtime and nested_mag.runtime_state==mag_runtime and mag_runtime.rounds==[round_a,round_b,round_a],"nested runtime and mixed A B A order unchanged")
	check(is_equal_approx(inv.get_total_weight(),nested_before),"complete subtree same-registry before and after weight identical")
	ui.finish_drag()
	var crate_cell: Vector2i=crate.runtime.inventory_grid.find_first_free_position(nested)
	check(ExternalInventoryTransfer.transfer(ui.container_access,nested,ext,{"kind":&"grid","grid":crate.runtime.inventory_grid,"position":crate_cell,"rotated":false}),"complete nested portable returns to external registry")
	await process_frame
	await process_frame
	var nested_player_before: float=inv.get_total_weight()
	var nested_crate_before: float=crate.runtime.get_contents_weight()
	var nested_mass: float=nested.get_weight()
	candidate=content_candidate(ui,nested,b)
	check(candidate.valid and ui.commit_drag_candidate(ui.drag_data),"one external closed deposit moves complete subtree directly to B")
	check(nested.get_owner_registry()==inv.transactions and nested_rig.get_owner_registry()==inv.transactions and nested_mag.get_owner_registry()==inv.transactions and inv.transactions.get_direct_parent(nested).parent_item==b,"external root and descendants share actual destination registry")
	check(is_equal_approx(inv.get_total_weight(),nested_player_before+nested_mass) and is_equal_approx(crate.runtime.get_contents_weight(),nested_crate_before-nested_mass) and mag_runtime.rounds==[round_a,round_b,round_a],"complete external transfer weight equal-opposite and rounds unchanged")
	ui.finish_drag()
	check(ExternalInventoryTransfer.transfer(ui.container_access,crate_mag,ext,{"kind":&"grid","grid":crate.runtime.inventory_grid,"position":Vector2i(7,1),"rotated":false}),"existing nested-to-crate transfer preserved")
	await process_frame
	candidate=content_candidate(ui,crate_mag,b)
	p.global_position+=Vector3(0,0,12)
	check(not ui.commit_drag_candidate(ui.drag_data) and crate_mag.get_owner_registry()==ext,"external access loss rejects without owner change")
	ui.finish_drag()
	ui.toggle()
	var world_ammo:=ammo(10)
	var world_node:=WorldItemFactory.spawn(world_ammo,inv.transactions,level,Transform3D(Basis.IDENTITY,p.global_position+Vector3(0,0.11,-0.8)))
	p.camera.look_at(world_node.global_position+Vector3.UP*0.2)
	await physics_frame
	ui.open_vicinity(world_node)
	await process_frame
	await process_frame
	check(ui.is_vicinity_item(world_ammo),"actual WORLD item accessible through vicinity")
	var world_before: float=inv.get_total_weight()
	candidate=content_candidate(ui,world_ammo,b)
	check(candidate.valid and ui.drag_data.has("world"),"WORLD source resolves closed content through existing drag")
	check(ui.commit_drag_candidate(ui.drag_data),"WORLD complete pickup directly to nested container")
	check(inv.transactions.get_direct_parent(world_ammo).parent_item==b and not inv.transactions.world_items.has(world_ammo),"WORLD retirement and actual parent complete together")
	check(is_equal_approx(inv.get_total_weight(),world_before+0.12),"WORLD incoming actual10 rounds add0.12kg")
	ui.finish_drag()
	ui.toggle()
	level.queue_free()
	await process_frame
	print("CLOSED_CONTAINER_TRANSFER_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

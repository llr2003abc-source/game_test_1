extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	var probe:=InventoryUI.new()
	check(probe.has_method("close_container"),"container session cleanup exists")
	probe.free()
	if failures==0: await exercise()
	print("CONTAINER_SAFETY_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

func exercise() -> void:
	for scenario in ["distance","wall","delete","runtime","source_move","source_remove","lock","foreign","full","close"]:
		var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
		root.add_child(level)
		current_scene=level
		var p: Variant=level.get_node("Player")
		p.set_physics_process(false)
		p.firearm.set_physics_process(false)
		var inv: PlayerInventoryComponent=p.inventory
		var ui: InventoryUI=p.get_node("InventoryUI")
		var crate: LootContainer=level.get_node("LootCrateA")
		p.global_position=crate.global_position+Vector3(0,0,1.8)
		p.camera.look_at(crate.get_interaction_position())
		await physics_frame
		check(ui.open_container(crate),"safety open "+scenario)
		await process_frame
		var ext:=crate.runtime.transactions
		var runtime:=crate.runtime
		var grid:=runtime.inventory_grid
		var ammo:=grid.get_item_at_cell(Vector2i(5,0))
		var data:=ui.begin_drag(ammo,Vector2(24,24))
		var access:=ui.container_access
		var view: InventoryGridView
		for candidate_view in ui.views:
			if candidate_view.grid==inv.pockets[0]: view=candidate_view
		check(ui.update_drag_candidate(view.get_global_rect().get_center(),data).valid,"cached green before invalidation "+scenario)
		match scenario:
			"distance": p.global_position.x+=4
			"wall":
				var wall:=StaticBody3D.new()
				var shape:=CollisionShape3D.new()
				var box:=BoxShape3D.new()
				box.size=Vector3(3,4,0.1)
				shape.shape=box
				wall.add_child(shape)
				level.add_child(wall)
				wall.global_position=crate.global_position+Vector3(0,1,1)
				await physics_frame
			"delete": crate.queue_free()
			"runtime": crate.runtime=LootContainerFactory.create(&"replaced","Replacement",1)
			"source_move": ext.move(ammo,grid,Vector2i(7,0))
			"source_remove": ext.remove(ammo)
			"lock": inv.transactions.locked=true
			"foreign":
				check(not ExternalInventoryTransfer.transfer(access,ammo,level.get_node("LootCrateB").runtime.transactions,{"kind":&"grid","grid":level.get_node("LootCrateB").runtime.inventory_grid,"position":Vector2i(7,5)}),"session cannot reach other crate registry")
				ext.locked=true
			"full": inv.transactions.place(item(1,1),inv.pockets[0],Vector2i.ZERO)
			"close": ui.toggle()
		check(not ui.commit_drag_candidate(data),"stale/invalid commit rejected "+scenario)
		check(ammo.stack_count==40 and not inv.transactions.items.has(ammo) and ext.world_items.is_empty(),"failed commit keeps count/ownership/noWORLD "+scenario)
		inv.transactions.locked=false
		ext.locked=false
		await process_frame
		if scenario in ["distance","wall","delete","runtime","close"]:
			check(not ui.visible and ui.container_access==null and ui.drag_context==null,"lost access closes and cancels "+scenario)
		level.queue_free()
		await process_frame
	await press_safety()

func press_safety() -> void:
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	var ui: InventoryUI=p.get_node("InventoryUI")
	var crate: LootContainer=level.get_node("LootCrateA")
	p.global_position=crate.global_position+Vector3(0,0,1.8)
	p.camera.look_at(crate.get_interaction_position())
	await physics_frame
	ui.open_container(crate)
	var view: InventoryGridView=ui.views[-1]
	var grid:=crate.runtime.inventory_grid
	var original:=grid.get_item_at_cell(Vector2i(5,0))
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT
	press.pressed=true
	press.position=Vector2(5*48+24,24)
	view._gui_input(press)
	crate.runtime.transactions.move(original,grid,Vector2i(7,0))
	check(view._get_drag_data(press.position)==null,"moved pressed source cannot drag new cell")
	crate.runtime.transactions.move(original,grid,Vector2i(5,0))
	view._gui_input(press)
	crate.runtime.transactions.remove(original)
	var replacement:=InventoryItemInstance.new(original.definition,25)
	crate.runtime.transactions.place(replacement,grid,Vector2i(5,0))
	check(view._get_drag_data(press.position)==null,"replacement cannot hijack pending press")
	check(ui.drag_context==null,"invalid press creates no context/ghost")
	level.queue_free()
	await process_frame

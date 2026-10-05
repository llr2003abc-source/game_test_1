extends "res://tests/inventory_grid_test.gd"

func _run() -> void:
	await _test_wall_drop()
	await _test_pending_press()
	print("VICINITY_SAFETY_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

func fixture() -> Node3D:
	var world:=Node3D.new()
	root.add_child(world)
	current_scene=world
	var p: Variant=load("res://scenes/player/player.tscn").instantiate()
	world.add_child(p)
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	return world

func drag_data_probe(panel: VicinityLootPanel, point: Vector2) -> Variant:
	panel.force_drag({"probe":true},Control.new())
	var result: Variant=panel._get_drag_data(point)
	root.gui_cancel_drag()
	return result

func _test_wall_drop() -> void:
	var world:=fixture()
	var p: Variant=world.get_node("Player")
	var inv: PlayerInventoryComponent=p.inventory
	var ui: InventoryUI=p.get_node("InventoryUI")
	var nearby:=WorldItemFactory.spawn(InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres")),inv.transactions,world,Transform3D(Basis.IDENTITY,Vector3(0.7,0.12,0)))
	ui.open_vicinity(nearby)
	var wall:=StaticBody3D.new()
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(2,3,0.1)
	collision.shape=shape
	wall.add_child(collision)
	world.add_child(wall)
	wall.position=Vector3(0,1,-0.5)
	await physics_frame
	await physics_frame
	var original: InventoryItemInstance=inv.equipment.get_active_item()
	var runtime: WeaponRuntime=original.runtime_state
	var data:=ui.begin_drag(original,Vector2.ZERO)
	ui.update_drag_candidate(ui.nearby_scroll.get_global_rect().position+Vector2(150,150),data)
	check(not ui.commit_drag_candidate(data),"wall blocks Nearby world drop before ownership mutation")
	check(inv.transactions.get_location(original).kind==&"equipment" and not inv.transactions.world_items.has(original),"rejected wall drop retains equipment owner")
	check(original.runtime_state==runtime and p.firearm.weapon_runtime==runtime and runtime.get_magazine_round_count()==29,"wall rejection retains active weapon/chamber/magazine")
	check(inv.transactions.world_items.size()==1,"wall rejection creates no extra world visual")
	ui.finish_drag()
	wall.queue_free()
	await physics_frame
	await physics_frame
	data=ui.begin_drag(original,Vector2.ZERO)
	ui.update_drag_candidate(ui.nearby_scroll.get_global_rect().position+Vector2(150,150),data)
	check(ui.commit_drag_candidate(data),"unblocked Nearby world drop still succeeds")
	var dropped: DroppedItem=inv.transactions.world_items.get(original)
	check(is_instance_valid(dropped) and dropped.item==original and original.runtime_state==runtime,"unblocked drop preserves original runtime/visual")
	check(VicinityLootQuery.find_visible(p,inv.transactions,3.0).has(dropped),"successful drop remains visible and reachable on player side")
	ui.finish_drag()
	world.queue_free()
	await process_frame

func _test_pending_press() -> void:
	var world:=fixture()
	var p: Variant=world.get_node("Player")
	var inv: PlayerInventoryComponent=p.inventory
	var ui: InventoryUI=p.get_node("InventoryUI")
	var definition: ItemDefinition=load("res://data/items/weapon1_level2_ammo_item.tres")
	var a:=WorldItemFactory.spawn(InventoryItemInstance.new(definition,5),inv.transactions,world,Transform3D.IDENTITY)
	var b:=WorldItemFactory.spawn(InventoryItemInstance.new(definition,6),inv.transactions,world,Transform3D.IDENTITY)
	var large:=WorldItemFactory.spawn(InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres"),1,17),inv.transactions,world,Transform3D.IDENTITY)
	ui.open_vicinity(a)
	await process_frame
	var panel: VicinityLootPanel=ui.nearby_panel
	var nodes: Array[DroppedItem]=[a,b]
	panel.set_items(nodes,a.item)
	var press:=InputEventMouseButton.new()
	press.pressed=true
	press.button_index=MOUSE_BUTTON_LEFT
	press.position=Vector2(24,24)
	panel._gui_input(press)
	var refreshed: Array[DroppedItem]=[b]
	panel.set_items(refreshed,b.item)
	check(drag_data_probe(panel,Vector2(36,24))==null,"refresh replacing pressed cell cannot drag unrelated item")
	check(inv.transactions.owns_world_item(a.item,a) and inv.transactions.owns_world_item(b.item,b),"pending press cancellation preserves both WORLD owners")
	panel.set_items(nodes,a.item)
	press.position=Vector2(72,24)
	panel._gui_input(press)
	panel.set_items(refreshed,b.item)
	check(drag_data_probe(panel,Vector2(84,24))==null,"refresh moving originally pressed item cancels pending drag")
	panel.set_items(nodes,a.item)
	press.position=Vector2(72,24)
	panel._gui_input(press)
	panel.set_items(nodes,a.item)
	var data: Variant=drag_data_probe(panel,Vector2(84,24))
	check(data is Dictionary and data.item==b.item,"stable refresh starts exact originally pressed item")
	check(data.context.grab_offset_pixels==Vector2(24,24),"stable refresh retains original press grab offset")
	ui.finish_drag()
	panel.set_items(nodes,a.item)
	press.position=Vector2(24,24)
	panel._gui_input(press)
	a.queue_free()
	await physics_frame
	panel.set_items(refreshed,b.item)
	check(drag_data_probe(panel,Vector2(36,24))==null,"deleted pressed WORLD node never substitutes next item")
	var with_large: Array[DroppedItem]=[b,large]
	panel.set_items(with_large,b.item)
	press.position=Vector2(72,24)
	panel._gui_input(press)
	var only_large: Array[DroppedItem]=[large]
	panel.set_items(only_large,large.item)
	check(drag_data_probe(panel,Vector2(84,24))==null,"shifted large footprint covering old cell cancels pending grab")
	check(inv.transactions.owns_world_item(large.item,large) and large.item.runtime_state.get_magazine_round_count()==17,"pending large-item cancellation retains runtime17")
	world.queue_free()
	await process_frame

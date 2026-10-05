extends "res://tests/inventory_drag_ux_test.gd"

func _run() -> void:
	var probe:=InventoryUI.new()
	check(probe.has_method("open_vicinity"),"existing inventory supports vicinity mode")
	probe.free()
	if failures==0: await _test_workflow()
	print("VICINITY_UI_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

func key(code: Key, pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	root.push_input(event)

func view_for(ui: InventoryUI, grid: InventoryGrid) -> InventoryGridView:
	for view in ui.views:
		if view.grid==grid: return view
	return null

func drag_between(start: Vector2, finish: Vector2) -> void:
	await start_native_drag(start,finish)
	release_mouse(finish)
	await process_frame
	await process_frame

func _test_workflow() -> void:
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	root.grab_focus()
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	var inv: PlayerInventoryComponent=p.inventory
	var ui: InventoryUI=p.get_node("InventoryUI")
	var bag: InventoryGrid=inv.get_equipped_backpack().grid
	var bag_ammo: InventoryItemInstance=bag.placements[0].item
	for grid in inv.get_equipped_rig().grids:
		if grid.placements.is_empty(): grid.place_item(item(1,2),Vector2i.ZERO)
	for y in range(5):
		for x in range(5):
			if bag.get_item_at_cell(Vector2i(x,y))==null: bag.place_item(item(1,1),Vector2i(x,y))
	var original:=InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres"),1,17)
	var runtime: RefCounted=original.runtime_state
	var node:=WorldItemFactory.spawn(original,inv.transactions,level,Transform3D(Basis.IDENTITY,p.global_position+Vector3(0,0.11,-0.8)))
	p.camera.look_at(node.global_position,Vector3.UP)
	await physics_frame
	await physics_frame
	var interactor: PlayerInteractor=p.get_node("PlayerInteractor")
	check(interactor.update_target()==node and node.get_interaction_prompt(p).contains("背包已满"),"full inventory aim prompt before hold")
	key(KEY_F,true)
	await create_timer(0.4).timeout
	key(KEY_F,false)
	await process_frame
	check(ui.visible and ui.get("vicinity_mode"),"real hold F opens shared UI vicinity mode")
	check(inv.transactions.get_location(original).kind==&"world","hold never performs short pickup")
	check(ui.get("highlighted_item")==original,"aimed loot highlighted")
	var nearby: Control=ui.get("nearby_panel")
	var scroll: ScrollContainer=ui.get("nearby_scroll")
	var panel_id: int=nearby.get_instance_id()
	await create_timer(0.5).timeout
	check(ui.get("nearby_panel").get_instance_id()==panel_id,"stationary vicinity never rebuilds controls every frame")
	var filler: InventoryItemInstance=bag.get_item_at_cell(Vector2i(0,1))
	for dropped in [bag_ammo,filler]:
		var view:=view_for(ui,bag)
		var start: Vector2=view.get_global_rect().position+Vector2(bag.get_placement(dropped).position)*48+Vector2(24,24)
		var destination: Vector2=ui.get("nearby_scroll").get_global_rect().position+Vector2(150,150)
		await drag_between(start,destination)
		check(inv.transactions.get_location(dropped).kind==&"world" and inv.transactions.world_items.has(dropped),"actual player->Nearby drag drops original world item")
	check(bag.can_place(original,Vector2i.ZERO),"full-inventory workflow creates1x2 backpack space")
	nearby=ui.get("nearby_panel")
	var placement: Dictionary=nearby.get("layout").placements.filter(func(place): return place.item==original)[0]
	var start: Vector2=nearby.get_global_rect().position+Vector2(placement.position)*48+Vector2(24,24)
	var destination: Vector2=view_for(ui,bag).get_global_rect().position+Vector2(24,24)
	await drag_between(start,destination)
	check(bag.get_placement(original)!=null and not inv.transactions.world_items.has(original),"actual Nearby->backpack removes WORLD ownership")
	check(original.runtime_state==runtime and runtime.get_round_count()==17,"actual world drag preserves magazine17 runtime")
	var rig: InventoryGrid=inv.get_equipped_rig().grids[0]
	var old: InventoryItemInstance=rig.placements[0].item
	await drag_between(view_for(ui,rig).get_global_rect().position+Vector2(24,24),ui.get("nearby_scroll").get_global_rect().position+Vector2(150,150))
	check(inv.transactions.get_location(old).kind==&"world","rig->Nearby drop retains original magazine")
	await drag_between(view_for(ui,bag).get_global_rect().position+Vector2(24,24),view_for(ui,rig).get_global_rect().position+Vector2(24,24))
	check(rig.get_placement(original)!=null and inv.reload_coordinator.get_available_magazine_count()==2,"recovered magazine in Rig immediately reload candidate")
	await drag_between(view_for(ui,rig).get_global_rect().position+Vector2(24,24),ui.get("nearby_scroll").get_global_rect().position+Vector2(150,150))
	check(inv.transactions.get_location(original).kind==&"world" and original.runtime_state==runtime,"player-world roundtrip original runtime retained")
	nearby=ui.get("nearby_panel")
	placement=nearby.get("layout").placements.filter(func(place): return place.item==original)[0]
	await drag_between(nearby.get_global_rect().position+Vector2(placement.position)*48+Vector2(24,24),view_for(ui,inv.secure.grid).get_global_rect().position+Vector2(24,24))
	check(inv.secure.grid.get_placement(original)!=null and runtime.get_round_count()==17,"actual manual Nearby->Secure keeps17 unlike auto policy")
	var gun:=InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres"),1,17)
	WorldItemFactory.spawn(gun,inv.transactions,level,Transform3D(Basis.IDENTITY,p.global_position+Vector3(0,0.11,-0.8)))
	await process_frame
	await process_frame
	nearby=ui.get("nearby_panel")
	placement=nearby.get("layout").placements.filter(func(place): return place.item==gun)[0]
	var active: WeaponRuntime=p.firearm.weapon_runtime
	await drag_between(nearby.get_global_rect().position+Vector2(placement.position)*48+Vector2(24,24),ui.equipment_views[1].get_global_rect().get_center())
	check(inv.equipment.slots[1]==gun and gun.runtime_state.get_magazine_round_count()==17,"actual Nearby world gun->slot2 same runtime17")
	check(p.firearm.weapon_runtime==active,"slot2 pickup does not switch active slot1")
	var ammo_definition: ItemDefinition=load("res://data/items/weapon1_level2_ammo_item.tres")
	var stack:=InventoryItemInstance.new(ammo_definition,50)
	inv.transactions.place(stack,bag,Vector2i.ZERO)
	var source:=InventoryItemInstance.new(ammo_definition,60)
	var world_ammo:=WorldItemFactory.spawn(source,inv.transactions,level,Transform3D(Basis.IDENTITY,p.global_position+Vector3(0,0.11,-0.8)))
	await process_frame
	await process_frame
	nearby=ui.nearby_panel
	placement=nearby.layout.placements.filter(func(place): return place.item==source)[0]
	await drag_between(nearby.get_global_rect().position+Vector2(placement.position)*48+Vector2(24,24),view_for(ui,bag).get_global_rect().position+Vector2(24,24))
	check(stack.stack_count==60 and source.stack_count==50 and world_ammo.item==source,"native partial WORLD merge conserves60+50")
	check(inv.transactions.owns_world_item(source,world_ammo) and ui.nearby_panel.layout.placements.any(func(place): return place.item==source),"partial merge refresh retains WORLD remaining50")
	nearby=ui.nearby_panel
	placement=nearby.layout.placements.filter(func(place): return place.item==source)[0]
	await drag_between(nearby.get_global_rect().position+Vector2(placement.position)*48+Vector2(24,24),view_for(ui,bag).get_global_rect().position+Vector2(24,24))
	check(stack.stack_count==60 and source.stack_count==50 and inv.transactions.world_items.values().count(world_ammo)==1,"full target failed native drop cannot duplicate")
	nearby=ui.nearby_panel
	placement=nearby.layout.placements.filter(func(place): return place.item==source)[0]
	await drag_between(nearby.get_global_rect().position+Vector2(placement.position)*48+Vector2(24,24),view_for(ui,inv.secure.grid).get_global_rect().position+Vector2(24,24))
	check(runtime.get_round_count()==30 and source.stack_count==37 and inv.transactions.owns_world_item(source,world_ammo),"native WORLD LOAD uses existing magazine/AmmoData transaction")
	nearby=ui.nearby_panel
	placement=nearby.layout.placements.filter(func(place): return place.item==source)[0]
	await drag_between(nearby.get_global_rect().position+Vector2(placement.position)*48+Vector2(24,24),ui.nearby_scroll.get_global_rect().position+Vector2(300,250))
	check(inv.transactions.owns_world_item(source,world_ammo) and source.stack_count==37,"Nearby-to-Nearby is unsupported and leaves WORLD unchanged")
	var data: Dictionary=ui.begin_drag(source,Vector2(24,24))
	var candidate: Dictionary=ui.update_drag_candidate(view_for(ui,inv.pockets[0]).get_global_rect().get_center(),data)
	check(candidate.valid,"valid explicit pocket candidate before runtime lock")
	inv.transactions.locked=true
	check(not ui.commit_drag_candidate(data) and inv.transactions.owns_world_item(source,world_ammo),"lock revalidated at actual commit")
	inv.transactions.locked=false
	ui.finish_drag()
	data=ui.begin_drag(source,Vector2(24,24))
	candidate=ui.update_drag_candidate(view_for(ui,inv.pockets[0]).get_global_rect().get_center(),data)
	world_ammo.queue_free()
	check(not ui.commit_drag_candidate(data),"queued WORLD deletion cannot commit cached green candidate")
	await physics_frame
	ui._refresh_nearby()
	check(ui.drag_context==null and not inv.transactions.world_items.has(source),"deleted WORLD node cancels drag and disappears from list")
	var old_position: Vector3=p.global_position
	p.global_position+=Vector3.RIGHT*10
	await create_timer(0.25).timeout
	check(ui.nearby_panel.layout.placements.is_empty(),"player displacement removes out-of-range vicinity entries")
	p.global_position=old_position
	for i in range(24): WorldItemFactory.spawn(InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres")),inv.transactions,level,Transform3D(Basis.IDENTITY,p.global_position+Vector3(0,0.11,-0.8)))
	await process_frame
	await process_frame
	ui.nearby_scroll.scroll_vertical=100000
	await process_frame
	check(ui.nearby_panel.layout.rows>6 and ui.nearby_scroll.scroll_vertical>0,"real ScrollContainer scrolls large auto-layout")
	var last: Dictionary=ui.nearby_panel.layout.placements[-1]
	check(ui.nearby_scroll.get_global_rect().has_point(ui.nearby_panel.get_global_rect().position+Vector2(last.position)*48+Vector2(24,24)),"last world entry reachable in scrolled panel")
	key(KEY_ESCAPE,true)
	await process_frame
	check(not ui.visible and ui.drag_context==null,"ESC closes vicinity and clears drag")
	level.queue_free()
	await process_frame

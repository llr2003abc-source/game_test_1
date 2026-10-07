extends "res://tests/inventory_grid_test.gd"

func bag() -> InventoryItemInstance:
	return InventoryItemFactory.create(load("res://data/items/backpack_1.tres"))

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/inventory/inventory_ownership_graph.gd"),"generic ownership graph foundation exists")
	if failures:
		finish()
		return
	var graph: Variant=load("res://scripts/inventory/inventory_ownership_graph.gd")
	var a:=bag()
	var b:=bag()
	var rig:=InventoryItemFactory.create(load("res://data/items/rig_1.tres"))
	var mag:=InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres"),1,17)
	check(a.runtime_state.grid.place_item(b,Vector2i.ZERO),"same Definition independent Backpack may nest")
	check(b.runtime_state.grid.place_item(rig,Vector2i.ZERO),"Rig nests inside Backpack")
	check(rig.runtime_state.grids[1].place_item(mag,Vector2i.ZERO),"actual magazine placement within nested Rig")
	var result: Dictionary=graph.collect_item_subtree(a)
	check(result.valid and result.items==[a,b,rig,mag],"collector finds entire A/B/Rig/Mag identities in order")
	check(result.edges.size()==3 and result.grids.size()==6,"collector retains child edges and all physical compartments")
	check(result.edges[2].parent_item==rig and result.edges[2].child_item==mag and result.edges[2].grid==rig.runtime_state.grids[1],"direct parent edge differs from registry domain")
	for kind in [&"rig",&"pocket",&"secure"]:
		var grid:=InventoryGrid.new(10,10,kind)
		check(not grid.can_place(b,Vector2i.ZERO),"policy rejects portable independent of sufficient geometry: "+str(kind))
	check(not a.runtime_state.grid.can_place(a,Vector2i.ZERO),"self containment rejects")
	check(not b.runtime_state.grid.can_place(a,Vector2i.ZERO),"ancestor into direct descendant rejects")
	check(not rig.runtime_state.grids[0].can_place(a,Vector2i.ZERO),"ancestor into deep descendant rejects")
	var registry:=InventoryTransactionService.new()
	var outside:=InventoryGrid.new(10,10,&"external")
	registry.register_grid(outside)
	check(not registry.place(a,outside,Vector2i.ZERO),"simple populated placement refuses incomplete registration")
	check(registry.items.is_empty() and registry.runtime_registry.is_empty() and outside.placements.is_empty(),"simple refusal leaves registry and geometry unchanged")
	check(registry.last_failure_reason==&"COMPLETE_SUBTREE_REQUIRED","simple refusal has explicit diagnostic")
	check(registry.register_complete_subtree(a),"complete populated registration succeeds atomically")
	check(registry.place(a,outside,Vector2i.ZERO),"registered complete root may subsequently place")
	for member in [a,b,rig,mag]:
		check(member.get_owner_registry()==registry and registry.items.count(member)==1,"every member shares exactly one registry identity")
		check(registry.find_runtime_item(member.runtime_state)==member,"every actual runtime has one stable wrapper")
	check(registry.get_direct_parent(mag).parent_item==rig and registry.get_direct_parent(b).parent_item==a,"direct parents resolve actual nested placements")
	check(graph.collect_item_subtree(a,registry).valid,"registered graph remains valid")
	var gun:=InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres"))
	var unregistered: Dictionary=graph.collect_item_subtree(gun)
	check(unregistered.valid and unregistered.items.size()==2,"unregistered factory gun already owns stable loaded wrapper")
	var wrapper: InventoryItemInstance=unregistered.items[1]
	check(graph.collect_item_subtree(gun).items[1]==wrapper,"repeated traversal never clones magazine wrapper")
	check(registry.register_complete_subtree(gun),"weapon child complete registration")
	check(registry.get_direct_parent(wrapper).parent_item==gun and registry.get_direct_parent(wrapper).edge_role==&"weapon_magazine","loaded magazine edge has distinct role")
	var invalid_runtime:=InventoryItemInstance.new(gun.definition,1,gun.runtime_state)
	check(not registry.register_complete_subtree(invalid_runtime),"aliased existing runtime cannot publish another weapon wrapper")
	check(registry.find_runtime_item(gun.runtime_state)==gun,"failed alias preserves original mapping")
	var late_bag: InventoryItemInstance=item(3,4)
	late_bag.definition.category=ItemDefinition.Category.BACKPACK
	late_bag.runtime_state=BackpackContainerRuntime.new()
	check(registry.register_complete_subtree(late_bag),"legacy late runtime assignment establishes actual storage parent before validation")
	var late_gun: InventoryItemInstance=item(5,2)
	late_gun.definition.category=ItemDefinition.Category.PRIMARY_WEAPON
	late_gun.runtime_state=WeaponRuntime.new()
	var data: WeaponData=load("res://data/weapons/test_rifle.tres")
	var late_mag:=MagazineInstance.new()
	late_mag.initialize_full(data.magazine_data)
	late_gun.runtime_state.initialize(data,late_mag,data.magazine_data.default_ammo)
	check(registry.register_complete_subtree(late_gun),"legacy supplied runtime initialization links a stable magazine item before validation")
	check(graph.collect_item_subtree(late_gun,registry).items.size()==2,"legacy supplied runtime now exposes actual magazine child")
	await bad_graphs(graph)
	await registered_corruption(graph)
	finish()

func registered_corruption(graph: Variant) -> void:
	var registry:=InventoryTransactionService.new()
	var a:=bag()
	registry.register_complete_subtree(a)
	var grid: InventoryGrid=a.runtime_state.grid
	registry.grids.erase(grid)
	check(not graph.collect_item_subtree(a,registry).valid,"registered storage omitted from registry is corrupt")
	check(not registry.register_complete_subtree(a) and not registry.grids.has(grid),"registered storage corruption refuses silent repair")
	registry.grids.append(grid)
	var leaf: InventoryItemInstance=item(1,1)
	grid._commit_place(leaf,Vector2i.ZERO,false)
	check(not graph.collect_item_subtree(a,registry).valid,"registered parent cannot have unpublished child")
	check(not registry.register_complete_subtree(a) and leaf.get_owner_registry()==null and not registry.items.has(leaf),"unregistered child corruption refuses silent adoption")
	grid.placements.clear()
	var pending:=bag()
	pending.runtime_state.grid.place_item(item(1,1),Vector2i.ZERO)
	var fresh:=InventoryTransactionService.new()
	check(not fresh.register_grid(pending.runtime_state.grid),"direct grid adoption cannot orphan portable shell")
	check(fresh.items.is_empty() and fresh.grids.is_empty() and pending.get_owner_registry()==null,"direct owned-grid refusal performs zero mutation")
	check(fresh.register_complete_subtree(pending),"explicit root registration remains usable after owned-grid refusal")
	var gun:=InventoryItemInstance.new(load("res://data/items/primary_weapon_1_item.tres"),1,WeaponRuntime.new())
	check(not graph.collect_item_subtree(gun).valid,"uninitialized weapon data safely rejects")
	check(not InventoryWeightCalculator.get_item_total_weight(gun).valid,"uninitialized weapon returns explicit invalid weight without runtime error")
	var broken:=bag()
	broken.runtime_state.grid._commit_place(item(1,1),Vector2i.ZERO,false)
	broken.runtime_state.grid.placements.append(null)
	check(not graph.collect_item_subtree(broken).valid,"null placement safely rejects before overlap scan")
	check(not fresh.register_complete_subtree(broken) and broken.get_owner_registry()==null,"null-placement rejection publishes nothing")
	broken.runtime_state.grid.placements.clear()
	await process_frame

func bad_graphs(graph: Variant) -> void:
	for corruption in [&"cycle",&"alias",&"runtime",&"overlap",&"bounds",&"policy",&"loaded",&"parent"]:
		var a:=bag()
		var b:=bag()
		var grid: InventoryGrid=a.runtime_state.grid
		var c: InventoryItemInstance=item(1,1)
		match corruption:
			&"cycle": grid._commit_place(a,Vector2i.ZERO,false)
			&"alias":
				grid._commit_place(c,Vector2i.ZERO,false)
				grid._commit_place(c,Vector2i(1,0),false)
			&"runtime":
				grid._commit_place(b,Vector2i.ZERO,false)
				grid._commit_place(InventoryItemInstance.new(b.definition,1,b.runtime_state),Vector2i.ZERO,false)
			&"overlap":
				grid._commit_place(c,Vector2i.ZERO,false)
				grid._commit_place(item(1,1),Vector2i.ZERO,false)
			&"bounds": grid._commit_place(c,Vector2i(5,0),false)
			&"policy":
				a=InventoryItemFactory.create(load("res://data/items/rig_1.tres"))
				grid=a.runtime_state.grids[0]
				var tiny: ItemDefinition=b.definition.duplicate()
				tiny.grid_size=Vector2i.ONE
				grid._commit_place(InventoryItemFactory.create(tiny),Vector2i.ZERO,false)
			&"loaded":
				a=InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres"))
				a.runtime_state.loaded_magazine=MagazineInstance.new()
			&"parent": grid.owner_item=weakref(b)
		var registry:=InventoryTransactionService.new()
		var before: Array=[registry.items.duplicate(),registry.grids.duplicate(),registry.runtime_registry.duplicate()]
		check(not graph.collect_item_subtree(a).valid,"graph rejects corrupted "+str(corruption))
		check(not registry.register_complete_subtree(a),"complete registration rejects corrupted "+str(corruption))
		check(before==[registry.items,registry.grids,registry.runtime_registry] and a.get_owner_registry()==null,"corrupted registration performs zero mutation "+str(corruption))
		grid.placements.clear()
	var top:=bag()
	var cursor: InventoryItemInstance=top
	for i in range(32):
		var next:=bag()
		cursor.runtime_state.grid._commit_place(next,Vector2i.ZERO,false)
		cursor=next
	check(graph.collect_item_subtree(top).valid,"32 descendant levels allowed, no gameplay one-level cap")
	var depth_registry:=InventoryTransactionService.new()
	depth_registry.register_complete_subtree(top)
	check(not depth_registry.place(item(1,1),cursor.runtime_state.grid,Vector2i.ZERO),"placement cannot extend already registered depth32 into invalid depth33")
	cursor.runtime_state.grid._commit_place(bag(),Vector2i.ZERO,false)
	check(not graph.collect_item_subtree(top).valid,"33 descendant levels fail safety guard")
	await process_frame

func finish() -> void:
	print("OWNERSHIP_SUBTREE_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

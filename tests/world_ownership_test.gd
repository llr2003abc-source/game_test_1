extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	check(FileAccess.file_exists("res://scripts/items/world_item_factory.gd"),"world ownership factory exists")
	if failures==0:
		var factory: Variant=load("res://scripts/items/world_item_factory.gd")
		var inv:=PlayerInventoryComponent.new()
		var other:=PlayerInventoryComponent.new()
		var world:=Node3D.new()
		root.add_child(world)
		var original: InventoryItemInstance=item(1,1)
		var node: Variant=factory.spawn(original,inv.transactions,world,Transform3D.IDENTITY)
		check(node!=null and inv.transactions.owns_world_item(original,node),"registry has exactly original world owner")
		check(factory.spawn(original,inv.transactions,world,Transform3D.IDENTITY)==null,"duplicate world visual rejected")
		check(factory.spawn(original,other.transactions,world,Transform3D.IDENTITY)==null,"cross registry duplicate rejected")
		check(world.get_child_count()==1,"only one visual exists")
		check(not inv.transactions.move(original,inv.pockets[0],Vector2i.ZERO),"ordinary move cannot bypass explicit pickup")
		check(inv.transactions.get_location(original).kind==&"world","failed transfer preserves WORLD")
		node.queue_free()
		await process_frame
		check(inv.transactions.get_location(original).kind==&"transit","external visual deletion safely unregisters world representation")
		check(factory.spawn(original,inv.transactions,world,Transform3D.IDENTITY)!=null,"same transit instance can acquire new representation")
		inv.transactions.locked=true
		var blocked: InventoryItemInstance=item(1,1)
		check(factory.spawn(blocked,inv.transactions,world,Transform3D.IDENTITY)==null,"locked registry rejects world spawn")
		inv.transactions.locked=false
		check(inv.transactions.place(blocked,inv.pockets[0],Vector2i.ZERO),"owned fixture placed")
		check(factory.spawn(blocked,inv.transactions,world,Transform3D.IDENTITY)==null,"spawn cannot duplicate inventory ownership")
		check(inv.transactions.get_location(blocked).kind==&"grid","rejected spawn keeps original inventory")
		check(inv.transactions.has_method("drop_item_to_world"),"generic inventory-to-world transaction exists")
		if inv.transactions.has_method("drop_item_to_world"):
			inv.transactions.locked=true
			check(inv.transactions.drop_item_to_world(blocked,world,Transform3D.IDENTITY)==null,"locked generic drop preserves inventory")
			inv.transactions.locked=false
			var dropped: Variant=inv.transactions.drop_item_to_world(blocked,world,Transform3D.IDENTITY)
			check(dropped!=null and dropped.item==blocked and inv.pockets[0].placements.is_empty(),"generic drop moves original item to exactly WORLD")
			check(inv.transactions.drop_item_to_world(blocked,world,Transform3D.IDENTITY)==null,"second generic drop cannot duplicate visual")
			check(inv.transactions.pickup_world_item(dropped).success and inv.pockets[0].get_placement(blocked)!=null,"generic inventory-world-inventory round trip")
		world.queue_free()
		await process_frame
		inv.free()
		other.free()
		await _test_runtime_ownership()
	print("WORLD_OWNERSHIP_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

func _test_runtime_ownership() -> void:
	var definition: ItemDefinition=load("res://data/items/magazine_1_item.tres")
	var gun_definition: ItemDefinition=load("res://data/items/primary_weapon_1_item.tres")
	var world:=Node3D.new()
	root.add_child(world)
	var inv:=PlayerInventoryComponent.new()
	var other:=PlayerInventoryComponent.new()
	var original:=InventoryItemFactory.create(definition,1,17)
	var node:=WorldItemFactory.spawn(original,inv.transactions,world,Transform3D.IDENTITY)
	var alias:=InventoryItemInstance.new(definition,1,original.runtime_state)
	check(WorldItemFactory.spawn(alias,other.transactions,world,Transform3D.IDENTITY)==null,"different registry rejects different wrapper sharing magazine runtime")
	check(other.transactions.items.is_empty() and other.transactions.world_items.is_empty(),"rejected runtime alias leaves destination registry untouched")
	check(node.can_interact(null) and original.runtime_state.get_round_count()==17,"rejected alias preserves original world runtime17")
	var gun:=InventoryItemFactory.create(gun_definition,1,17)
	var gun_node:=WorldItemFactory.spawn(gun,inv.transactions,world,Transform3D.IDENTITY)
	var gun_alias:=InventoryItemInstance.new(gun_definition,1,gun.runtime_state)
	check(WorldItemFactory.spawn(gun_alias,other.transactions,world,Transform3D.IDENTITY)==null,"cross-registry shared WeaponRuntime rejected")
	check(gun_node.can_interact(null) and inv.transactions.register_item(gun),"valid original weapon may re-register its own loaded wrapper")
	world.queue_free()
	await process_frame
	inv.free()
	other.free()
	for ownership in [&"world",&"grid",&"weapon_magazine"]:
		world=Node3D.new()
		root.add_child(world)
		inv=PlayerInventoryComponent.new()
		original=InventoryItemFactory.create(definition,1,17)
		var old_weapon: InventoryItemInstance
		if ownership==&"world": node=WorldItemFactory.spawn(original,inv.transactions,world,Transform3D.IDENTITY)
		elif ownership==&"grid":
			var grid:=InventoryGrid.new(1,2,&"rig")
			inv.transactions.register_grid(grid)
			inv.transactions.place(original,grid,Vector2i.ZERO)
		else:
			old_weapon=InventoryItemFactory.create(gun_definition,1,17)
			WorldItemFactory.spawn(old_weapon,inv.transactions,world,Transform3D.IDENTITY)
			original=inv.find_runtime_item(old_weapon.runtime_state.loaded_magazine)
		var initial_count: int=inv.transactions.items.size()
		var stolen_runtime:=WeaponRuntime.new()
		stolen_runtime.initialize(gun_definition.weapon_data,original.runtime_state)
		var stolen:=InventoryItemInstance.new(gun_definition,1,stolen_runtime)
		check(WorldItemFactory.spawn(stolen,inv.transactions,world,Transform3D.IDENTITY)==null,"loaded magazine already owned by %s cannot be adopted by another gun"%ownership)
		check(inv.transactions.get_location(original).kind==ownership and original.runtime_state.get_round_count()==17,"failed loaded-magazine adoption preserves original location/count: "+str(ownership))
		check(inv.transactions.items.size()==initial_count and not inv.transactions.items.has(stolen),"failed loaded-magazine adoption is atomic: "+str(ownership))
		if ownership==&"world": check(node.can_interact(null),"original magazine remains interactable after rejected adoption")
		if ownership==&"weapon_magazine": check(inv.transactions.get_location(original).weapon==old_weapon,"original owning weapon remains sole magazine owner")
		world.queue_free()
		await process_frame
		inv.free()

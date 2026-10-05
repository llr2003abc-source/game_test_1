extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	var probe:=InventoryTransactionService.new()
	check(probe.has_method("pickup_world_item"),"explicit world pickup transaction exists")
	if failures==0:
		var inv:=PlayerInventoryComponent.new()
		var world:=Node3D.new()
		root.add_child(world)
		var grid:=InventoryGrid.new(1,2,&"rig")
		inv.transactions.register_grid(grid)
		var original: InventoryItemInstance=InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres"),1,17)
		var runtime: RefCounted=original.runtime_state
		var node: DroppedItem=WorldItemFactory.spawn(original,inv.transactions,world,Transform3D.IDENTITY)
		var destination: Dictionary={"kind":&"grid","grid":grid,"position":Vector2i.ZERO,"rotated":false}
		grid.place_item(item(1,2),Vector2i.ZERO)
		var result: Dictionary=inv.transactions.pickup_world_item(node,destination)
		check(not result.success and result.accepted_count==0,"no-space pickup rejected")
		check(inv.transactions.owns_world_item(original,node) and not node.is_queued_for_deletion(),"failed pickup preserves WORLD/node")
		check(original.runtime_state==runtime and runtime.get_round_count()==17,"failed pickup preserves runtime")
		grid.remove_item(grid.placements[0].item)
		inv.transactions.locked=true
		check(not inv.transactions.pickup_world_item(node,destination).success,"reload lock rejects pickup")
		check(grid.placements.is_empty() and inv.transactions.owns_world_item(original,node),"locked transaction cannot partially commit")
		inv.transactions.locked=false
		var other:=PlayerInventoryComponent.new()
		check(not other.transactions.pickup_world_item(node,destination).success,"foreign registry cannot steal original")
		var unregistered:=InventoryGrid.new(1,2)
		check(not inv.transactions.pickup_world_item(node,{"kind":&"grid","grid":unregistered,"position":Vector2i.ZERO}).success,"unregistered destination rejected")
		result=inv.transactions.pickup_world_item(node,destination)
		check(result.success and result.accepted_count==1 and result.remaining_count==0,"whole magazine pickup committed")
		check(grid.get_placement(original)!=null and inv.transactions.get_location(original).kind==&"grid","original instance has exactly inventory ownership")
		check(original.runtime_state==runtime and runtime.get_round_count()==17,"successful pickup keeps17 and same runtime")
		check(not node.can_interact(null) and node.is_queued_for_deletion() and node.get_node("Area3D").collision_layer==0,"successful pickup immediately retires interaction before free")
		for i in range(5): check(not inv.transactions.pickup_world_item(node,destination).success,"pickup spam cannot duplicate")
		check(grid.placements.size()==1 and inv.transactions.world_items.is_empty(),"one owner and no duplicate placements")
		await process_frame
		check(not is_instance_valid(node),"successful visual freed after commit")
		world.queue_free()
		await process_frame
		inv.free()
		other.free()
		await _test_partial_ammo()
	print("WORLD_PICKUP_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

func _test_partial_ammo() -> void:
	for initial in [20,60]:
		for free_space in [false,true]:
			var inv:=PlayerInventoryComponent.new()
			inv.transactions.equip(InventoryItemFactory.create(load("res://data/items/backpack_1.tres")),5)
			var bag: InventoryGrid=inv.get_equipped_backpack().grid
			var definition: ItemDefinition=load("res://data/items/weapon1_level2_ammo_item.tres")
			var existing:=InventoryItemInstance.new(definition,50)
			bag.place_item(existing,Vector2i.ZERO)
			bag.place_item(item(5,4),Vector2i(0,1))
			for x in range(1,5):
				if free_space and x==1: continue
				bag.place_item(item(1,1),Vector2i(x,0))
			for pocket in inv.pockets: pocket.place_item(item(1,1),Vector2i.ZERO)
			var secure:=InventoryItemInstance.new(definition,50)
			inv.secure.grid.place_item(secure,Vector2i.ZERO)
			var original:=InventoryItemInstance.new(definition,initial)
			var world:=Node3D.new()
			root.add_child(world)
			var node: DroppedItem=WorldItemFactory.spawn(original,inv.transactions,world,Transform3D.IDENTITY)
			var result: Dictionary=inv.transactions.pickup_world_item(node)
			check(result.success and result.accepted_count==(initial if free_space else 10),"ammo merges before remainder placement")
			check(existing.stack_count==60 and secure.stack_count==50,"only normal storage merged; Secure excluded")
			if free_space:
				check(bag.get_placement(original)!=null and original.stack_count==initial-10,"remaining stack enters inventory as original instance")
				check(result.remaining_count==0 and node.is_queued_for_deletion(),"full pickup retires visual only after remainder placed")
			else:
				check(original.stack_count==initial-10 and result.remaining_count==initial-10,"partial remainder exact")
				check(inv.transactions.owns_world_item(original,node) and not node.is_queued_for_deletion(),"partial retains same WORLD item/node")
				check(node.get_interaction_prompt(null).contains("x%d"%(initial-10)),"partial prompt immediately reads new count")
				check(not inv.transactions.pickup_world_item(node).success,"no more capacity rejects without consuming remainder")
			check(existing.stack_count+original.stack_count==50+initial,"stack sum conserved")
			world.queue_free()
			await process_frame
			inv.free()
	var inv:=PlayerInventoryComponent.new()
	var definition: ItemDefinition=load("res://data/items/weapon1_level2_ammo_item.tres")
	for count in [50,45,60,60,60,60]: inv.pockets[inv.transactions.items.size()].place_item(InventoryItemInstance.new(definition,count),Vector2i.ZERO)
	var world:=Node3D.new()
	root.add_child(world)
	var original:=InventoryItemInstance.new(definition,60)
	var node: DroppedItem=WorldItemFactory.spawn(original,inv.transactions,world,Transform3D.IDENTITY)
	var result: Dictionary=inv.transactions.pickup_world_item(node)
	check(result.accepted_count==25 and result.remaining_count==35 and original.stack_count==35,"multiple stacks accept25 keep35 in world")
	check(inv.pockets[0].placements[0].item.stack_count==60 and inv.pockets[1].placements[0].item.stack_count==60,"ordered multi-stack merge fills both")
	world.queue_free()
	await process_frame
	inv.free()
	inv=PlayerInventoryComponent.new()
	var existing:=InventoryItemInstance.new(definition,50)
	inv.pockets[0].place_item(existing,Vector2i.ZERO)
	world=Node3D.new()
	root.add_child(world)
	original=InventoryItemInstance.new(definition,10)
	node=WorldItemFactory.spawn(original,inv.transactions,world,Transform3D.IDENTITY)
	result=inv.transactions.pickup_world_item(node)
	check(result.success and result.accepted_count==10 and result.remaining_count==0,"entire world stack merged without remainder placement")
	check(existing.stack_count==60 and original.stack_count==0,"complete merge conserves all60 rounds")
	check(not inv.transactions.items.has(original) and inv.transactions.world_items.is_empty() and original.get_owner_registry()==null,"fully consumed source removed from ownership registry")
	check(node.is_queued_for_deletion() and node.get_node("Area3D").collision_layer==0,"fully merged world visual immediately retired")
	world.queue_free()
	await process_frame
	inv.free()

extends "res://tests/inventory_grid_test.gd"

func _run() -> void:
	var inv:=PlayerInventoryComponent.new()
	check(inv.transactions.has_method("preview_world_pickup"),"readonly pickup preview exists")
	check(inv.transactions.has_method("pickup_world_item_to_grid"),"explicit WORLD grid entry exists")
	check(inv.transactions.has_method("pickup_world_ammo_into"),"explicit WORLD stack/load entry exists")
	if failures==0:
		var world:=Node3D.new()
		root.add_child(world)
		var definition: ItemDefinition=load("res://data/items/weapon1_level2_ammo_item.tres")
		var source:=InventoryItemInstance.new(definition,60)
		var node:=WorldItemFactory.spawn(source,inv.transactions,world,Transform3D.IDENTITY)
		for grid in inv.pockets: grid.place_item(InventoryItemInstance.new(definition,60),Vector2i.ZERO)
		var existing: InventoryItemInstance=inv.pockets[0].placements[0].item
		existing.stack_count=50
		var changes: Array[int]=[0]
		inv.transactions.changed.connect(func(): changes[0]+=1)
		for i in range(3):
			var result: Variant=inv.transactions.preview_world_pickup(node)
			check(not result.can_accept_all and result.accepted_count==10 and result.remaining_count==50 and String(result.reason)=="PARTIAL_SPACE","readonly preview exact partial10/60")
		check(existing.stack_count==50 and source.stack_count==60 and changes[0]==0,"preview never changes inventory or emits changes")
		inv.transactions.locked=true
		check(String(inv.transactions.preview_world_pickup(node).reason)=="INVENTORY_LOCKED","locked preview reason")
		check(not inv.transactions.pickup_world_item_to_grid(node,inv.secure.grid,Vector2i.ZERO,false).success,"manual Secure obeys lock")
		inv.transactions.locked=false
		existing.stack_count=60
		check(String(inv.transactions.preview_world_pickup(node).reason)=="NO_SPACE","full pockets do not auto-use empty Secure")
		check(not inv.transactions.pickup_world_item(node,{"kind":&"grid","grid":inv.secure.grid,"position":Vector2i.ZERO}).success,"old automatic entry still rejects explicit Secure")
		check(inv.transactions.pickup_world_item_to_grid(node,inv.secure.grid,Vector2i.ZERO,false).success,"manual world->Secure allowed")
		check(inv.secure.grid.placements[0].item==source and inv.transactions.world_items.is_empty(),"manual Secure commits original single owner")
		node=WorldItemFactory.spawn(InventoryItemInstance.new(definition,60),inv.transactions,world,Transform3D.IDENTITY)
		source=node.item
		existing.stack_count=50
		var merged: Dictionary=inv.transactions.pickup_world_ammo_into(node,existing)
		check(merged.success and merged.accepted_count==10 and merged.remaining_count==50,"explicit target merge accepts10 leaves50")
		check(node.item==source and inv.transactions.owns_world_item(source,node) and existing.stack_count==60,"partial manual merge retains world node and reference")
		check(not inv.transactions.pickup_world_ammo_into(node,existing).success,"full stack no duplicate transfer")
		check(String(inv.transactions.preview_world_pickup(null).reason)=="INVALID_TARGET","deleted/missing target preview safe")
		check(not inv.transactions.pickup_world_ammo_into(node,null).success,"missing explicit merge target fails safely")
		var foreign:=InventoryItemInstance.new(definition,1)
		check(not inv.transactions.pickup_world_ammo_into(node,foreign).success,"foreign target cannot receive WORLD ammo")
		check(source.stack_count==50 and node.can_interact(null),"failed explicit targets preserve original WORLD stack")
		inv.pockets[1].remove_item(inv.pockets[1].placements[0].item)
		var preview: PickupPreviewResult=inv.transactions.preview_world_pickup(node)
		check(preview.can_accept_all and preview.accepted_count==50 and preview.remaining_count==0 and preview.reason==&"NONE","enough-space readonly preview")
		var magazine:=InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres"),1,17)
		var runtime: MagazineInstance=magazine.runtime_state
		inv.transactions.place(magazine,inv.secure.grid,Vector2i(1,0))
		merged=inv.transactions.pickup_world_ammo_into(node,magazine)
		check(merged.success and merged.accepted_count==13 and merged.remaining_count==37,"WORLD ammo loads only actual magazine capacity")
		check(magazine.runtime_state==runtime and runtime.get_round_count()==30 and source.stack_count==37,"load preserves magazine identity and ammo count")
		inv.transactions.place(InventoryItemInstance.new(definition,23),inv.pockets[1],Vector2i.ZERO)
		merged=inv.transactions.pickup_world_ammo_into(node,inv.pockets[1].placements[0].item)
		check(merged.success and merged.accepted_count==37 and merged.remaining_count==0,"complete WORLD stack merge retires source")
		check(node.is_queued_for_deletion() and not inv.transactions.world_items.has(source) and inv.pockets[1].placements[0].item.stack_count==60,"full merge no remaining world visual/owner")
		world.queue_free()
		await process_frame
	inv.free()
	print("PICKUP_PREVIEW_TRANSACTION_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

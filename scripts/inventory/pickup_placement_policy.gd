class_name PickupPlacementPolicy
extends RefCounted

static func storage_grids(inventory: PlayerInventoryComponent) -> Array[InventoryGrid]:
	var grids: Array[InventoryGrid]=[]
	var bag: BackpackContainerRuntime=inventory.get_equipped_backpack()
	if bag!=null: grids.append(bag.grid)
	grids.append_array(inventory.pockets)
	var rig: RigContainerRuntime=inventory.get_equipped_rig()
	if rig!=null: grids.append_array(rig.grids)
	return grids

static func find_destination(inventory: PlayerInventoryComponent, item: InventoryItemInstance) -> Dictionary:
	var category: int=item.definition.category
	if category in [ItemDefinition.Category.PRIMARY_WEAPON,ItemDefinition.Category.SECONDARY_WEAPON,ItemDefinition.Category.PISTOL,ItemDefinition.Category.MELEE,ItemDefinition.Category.RIG,ItemDefinition.Category.BACKPACK]:
		for slot in range(6):
			if inventory.equipment.slots[slot]==null and inventory.equipment.can_equip(item,slot): return {"kind":&"equipment","slot":slot}
		var bag: BackpackContainerRuntime=inventory.get_equipped_backpack()
		return _find_in_grids(item,[bag.grid],category==ItemDefinition.Category.BACKPACK) if bag!=null else {}
	if category==ItemDefinition.Category.MAGAZINE:
		var candidates: Array[InventoryGrid]=[]
		var rig: RigContainerRuntime=inventory.get_equipped_rig()
		if rig!=null: candidates.append_array(rig.grids)
		var bag: BackpackContainerRuntime=inventory.get_equipped_backpack()
		if bag!=null: candidates.append(bag.grid)
		return _find_in_grids(item,candidates)
	return _find_in_grids(item,storage_grids(inventory))

static func plan_pickup(inventory: PlayerInventoryComponent, item: InventoryItemInstance) -> Dictionary:
	var transfers: Array[Dictionary]=[]
	var remainder: int=item.stack_count
	if item.definition.category==ItemDefinition.Category.AMMO and item.definition.max_stack>1:
		for grid in storage_grids(inventory):
			for placement in grid.placements:
				var target: InventoryItemInstance=placement.item
				if target.definition.category!=ItemDefinition.Category.AMMO or target.definition.item_id!=item.definition.item_id: continue
				var amount: int=mini(remainder,target.definition.max_stack-target.stack_count)
				if amount>0:
					transfers.append({"item":target,"amount":amount})
					remainder-=amount
	var destination: Dictionary=find_destination(inventory,item) if remainder>0 else {}
	return {"merges":transfers,"destination":destination}

static func _find_in_grids(item: InventoryItemInstance, grids: Array[InventoryGrid], allow_rotation: bool = false) -> Dictionary:
	for grid in grids:
		var position: Vector2i=grid.find_first_free_position(item,item.rotated)
		if position.x>=0: return {"kind":&"grid","grid":grid,"position":position,"rotated":item.rotated}
		if allow_rotation:
			position=grid.find_first_free_position(item,not item.rotated)
			if position.x>=0: return {"kind":&"grid","grid":grid,"position":position,"rotated":not item.rotated}
	return {}

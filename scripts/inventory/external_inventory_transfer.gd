class_name ExternalInventoryTransfer
extends RefCounted

static func transfer(access: LootContainerAccess, item: InventoryItemInstance, destination: InventoryTransactionService, location: Dictionary) -> bool:
	if item==null or access==null: return false
	var source:=item.get_owner_registry()
	if source==null or destination==null or not access.permits(source,destination): return false
	var original:=source.get_location(item)
	if original.kind not in [&"grid",&"container",&"equipment"]: return false
	if not destination._valid_pickup_destination(item,location,true): return false
	if source==destination:
		return source.move(item,location.grid,location.position,location.get("rotated",item.rotated)) if location.kind==&"grid" else source.equip(item,location.slot)
	var group:=source._registration_group(item)
	if not destination._can_register(group,source): return false
	var contents: Array[InventoryGrid]=[]
	for member in group:
		if not source.items.has(member) or member.get_owner_registry()!=source: return false
		for grid in source._contents_grids(member):
			if not source.grids.has(grid) or grid.get_transactions()!=source or contents.has(grid): return false
			for placement in grid.placements:
				if not group.has(placement.item) or not grid.can_place(placement.item,placement.position,placement.item.rotated): return false
			contents.append(grid)
	# All validation precedes this synchronous, signal-locked commit.
	source.locked=true
	destination.locked=true
	source._clear_location(item,original)
	for member in group: source._release_registration(member)
	for grid in contents:
		source.grids.erase(grid)
		destination.grids.append(grid)
		grid.set_transactions(destination)
	destination._commit_registration(group)
	destination._commit_pickup_destination(item,location)
	source.changed.emit()
	destination.changed.emit()
	source.locked=false
	destination.locked=false
	return true

static func transfer_ammo(access: LootContainerAccess, source_item: InventoryItemInstance, target: InventoryItemInstance) -> int:
	if access==null or source_item==null or target==null: return 0
	var source:=source_item.get_owner_registry()
	var destination:=target.get_owner_registry()
	if source==null or destination==null or not access.permits(source,destination): return 0
	if source.get_location(source_item).kind not in [&"grid",&"container"] or destination.get_location(target).kind not in [&"grid",&"container"]: return 0
	var load_mag: bool=target.definition.category==ItemDefinition.Category.MAGAZINE
	var amount: int=source._load_amount(source_item,target,source_item.stack_count) if load_mag else source._merge_amount(source_item,target)
	if amount<=0: return 0
	source.locked=true
	destination.locked=true
	if load_mag: source._commit_load(source_item,target,amount)
	else: source._commit_merge(source_item,target,amount)
	source.changed.emit()
	if source!=destination: destination.changed.emit()
	source.locked=false
	destination.locked=false
	return amount

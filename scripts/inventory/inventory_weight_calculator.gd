class_name InventoryWeightCalculator
extends RefCounted

static func get_item_total_weight(item: InventoryItemInstance) -> Dictionary:
	return _weigh(InventoryOwnershipGraph.collect_item_subtree(item))

static func get_world_root_total_weight(item: InventoryItemInstance) -> Dictionary:
	return get_item_total_weight(item)

static func get_grid_total_weight(grid: InventoryGrid) -> Dictionary:
	var roots: Array[InventoryItemInstance]=[]
	for placement in grid.placements:
		if not grid.can_place_geometry(placement.item,placement.position,placement.item.rotated): return _invalid(&"INVALID_PLACEMENT")
		roots.append(placement.item)
	return _weigh(InventoryOwnershipGraph.collect_roots(roots,grid.get_transactions()))

static func get_registry_total_weight(registry: InventoryTransactionService) -> Dictionary:
	var roots: Array[InventoryItemInstance]=[]
	var all_roots: Array[InventoryItemInstance]=[]
	for item in registry.items:
		var location: Dictionary=registry.get_location(item)
		if registry.get_direct_parent(item).parent_item==null: all_roots.append(item)
		if location.kind==&"equipment" or (location.get("grid")!=null and location.grid.get_owner_item()==null) or (location.kind==&"transit" and registry.is_reserved(item)): roots.append(item)
	var whole_registry: Dictionary=InventoryOwnershipGraph.collect_roots(all_roots,registry)
	if not whole_registry.valid: return _invalid(whole_registry.reason)
	if whole_registry.items.size()!=registry.items.size(): return _invalid(&"ORPHAN_OR_CYCLE")
	return _weigh(InventoryOwnershipGraph.collect_roots(roots,registry))

static func get_external_container_contents_weight(registry: InventoryTransactionService) -> Dictionary:
	return get_registry_total_weight(registry)

static func _invalid(reason: StringName) -> Dictionary:
	return {"valid":false,"reason":reason,"weight_kg":-1.0}

static func _weigh(graph: Dictionary) -> Dictionary:
	if not graph.valid: return _invalid(graph.reason)
	var total: float=0.0
	# The shared graph already visits each owned child once, for every edge role.
	for item: InventoryItemInstance in graph.items:
		var own_weight: float
		if item.runtime_state is WeaponRuntime:
			var runtime: WeaponRuntime=item.runtime_state
			own_weight=runtime.weapon_data.bare_weight_kg
			if runtime.chambered_round!=null: own_weight+=runtime.chambered_round.round_weight_kg
		elif item.runtime_state is MagazineInstance:
			var magazine: MagazineInstance=item.runtime_state
			if magazine.definition==null: return _invalid(&"INVALID_MAGAZINE")
			own_weight=magazine.definition.empty_weight_kg
			for round_data in magazine.rounds:
				if round_data==null: return _invalid(&"INVALID_ROUND")
				own_weight+=round_data.round_weight_kg
		elif item.definition.category==ItemDefinition.Category.AMMO:
			if item.definition.ammo_data==null: return _invalid(&"INVALID_AMMO")
			own_weight=item.definition.ammo_data.round_weight_kg*item.stack_count
		else:
			own_weight=item.definition.weight*item.stack_count
		if not is_finite(own_weight) or own_weight<0.0: return _invalid(&"INVALID_WEIGHT")
		total+=own_weight
	return {"valid":true,"reason":&"NONE","weight_kg":total}

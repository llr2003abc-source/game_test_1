class_name InventoryOwnershipGraph
extends RefCounted

const MAX_TRAVERSAL_DEPTH: int=32

static func collect_item_subtree(item: InventoryItemInstance, registry: InventoryTransactionService=null) -> Dictionary:
	return collect_roots([item],registry if registry!=null else (item.get_owner_registry() if item!=null else null))

static func collect_roots(roots: Array[InventoryItemInstance], registry: InventoryTransactionService=null) -> Dictionary:
	var members: Array[InventoryItemInstance]=[]
	var storage: Array[InventoryGrid]=[]
	var result: Dictionary={"valid":true,"reason":&"NONE","items":members,"grids":storage,"edges":[],"runtimes":{},"visited":{},"max_depth":0}
	for item in roots:
		if not _visit(item,registry,0,result): break
	return result

static func _fail(result: Dictionary, reason: StringName) -> bool:
	result.valid=false
	result.reason=reason
	return false

static func _visit(item: InventoryItemInstance, registry: InventoryTransactionService, depth: int, result: Dictionary) -> bool:
	if depth>MAX_TRAVERSAL_DEPTH: return _fail(result,&"MAX_DEPTH")
	result.max_depth=maxi(result.max_depth,depth)
	if item==null or item.definition==null or not item.definition.is_valid() or item.stack_count<1 or item.stack_count>item.definition.max_stack: return _fail(result,&"INVALID_ITEM")
	if result.visited.has(item.get_instance_id()): return _fail(result,&"CYCLE_OR_ALIAS")
	result.visited[item.get_instance_id()]=true
	var owner: InventoryTransactionService=item.get_owner_registry()
	if owner!=null and owner!=registry: return _fail(result,&"FOREIGN_OWNER")
	if owner!=null and (not owner.items.has(item) or owner.get_location_count(item)>1): return _fail(result,&"REGISTRY_INCONSISTENT")
	var runtime: RefCounted=item.runtime_state
	if runtime!=null:
		var identity: int=runtime.get_instance_id()
		if result.runtimes.has(identity): return _fail(result,&"DUPLICATE_RUNTIME")
		result.runtimes[identity]=item
		if owner!=null and owner.find_runtime_item(runtime)!=item: return _fail(result,&"RUNTIME_REGISTRY_INCONSISTENT")
	if item.definition.has_capability(&"weapon") and (not runtime is WeaponRuntime or runtime.weapon_data==null): return _fail(result,&"INVALID_WEAPON")
	if item.definition.has_capability(&"magazine") and not runtime is MagazineInstance: return _fail(result,&"INVALID_MAGAZINE")
	if item.definition.has_capability(&"portable_container") and (runtime==null or not runtime.has_method("get_storage_grids")): return _fail(result,&"INVALID_CONTAINER")
	result.items.append(item)
	for grid in item.get_storage_grids():
		if grid==null or grid.size.x<1 or grid.size.y<1 or result.grids.has(grid) or grid.get_owner_item()!=item: return _fail(result,&"INVALID_GRID_PARENT")
		if grid.get_transactions()!=owner: return _fail(result,&"GRID_REGISTRY_INCONSISTENT")
		if owner!=null and not owner.grids.has(grid): return _fail(result,&"GRID_REGISTRY_INCONSISTENT")
		result.grids.append(grid)
		for placement in grid.placements:
			if placement==null or placement.item==null or not grid.can_place_geometry(placement.item,placement.position,placement.item.rotated): return _fail(result,&"INVALID_PLACEMENT")
	for edge in item.get_owned_child_edges(registry):
		if edge.get("parent_item")!=item or edge.get("child_item")==null or String(edge.get("edge_role","")).is_empty(): return _fail(result,&"INVALID_EDGE")
		var child: InventoryItemInstance=edge.child_item
		if owner!=null and child.get_owner_registry()!=owner: return _fail(result,&"CHILD_REGISTRY_INCONSISTENT")
		if edge.edge_role==&"weapon_magazine":
			if not runtime is WeaponRuntime or not child.runtime_state is MagazineInstance or runtime.loaded_magazine!=child.runtime_state: return _fail(result,&"INVALID_LOADED_MAGAZINE")
			var data: MagazineData=child.runtime_state.definition
			if data==null or not runtime.weapon_data.compatible_magazine_type_ids.has(data.magazine_type_id): return _fail(result,&"INCOMPATIBLE_LOADED_MAGAZINE")
			if child.get_owner_registry()!=null:
				var location: Dictionary=child.get_owner_registry().get_location(child)
				if location.get("weapon")!=item and not (owner==null and location.kind==&"transit"): return _fail(result,&"INVALID_LOADED_PARENT")
		elif edge.get("grid")!=null:
			if not result.grids.has(edge.grid) or edge.grid.get_placement(child)!=edge.get("placement"): return _fail(result,&"INVALID_EDGE_PLACEMENT")
			if child.get_owner_registry()!=null and child.get_owner_registry().get_location(child).get("grid")!=edge.grid: return _fail(result,&"INVALID_CHILD_PARENT")
		elif child.get_owner_registry()!=null:
			var location: Dictionary=child.get_owner_registry().get_direct_parent(child)
			if location.parent_item!=item and not (owner==null and location.kind==&"transit"): return _fail(result,&"INVALID_CHILD_PARENT")
		result.edges.append(edge)
		if not _visit(child,registry,depth+1,result): return false
	return true

static func would_create_cycle(item: InventoryItemInstance, target: InventoryGrid) -> bool:
	var parent: InventoryItemInstance=target.get_owner_item()
	if parent==null: return false
	if parent==item or (item.runtime_state!=null and item.runtime_state==parent.runtime_state): return true
	var graph: Dictionary=collect_item_subtree(item)
	if not graph.valid or graph.items.has(parent) or (parent.runtime_state!=null and graph.runtimes.has(parent.runtime_state.get_instance_id())): return true
	var ancestor_count: int=0
	var seen: Array[InventoryItemInstance]=[]
	while parent!=null:
		if seen.has(parent): return true
		seen.append(parent)
		ancestor_count+=1
		var registry: InventoryTransactionService=parent.get_owner_registry()
		parent=registry.get_direct_parent(parent).parent_item if registry!=null else null
	return ancestor_count+graph.max_depth>MAX_TRAVERSAL_DEPTH

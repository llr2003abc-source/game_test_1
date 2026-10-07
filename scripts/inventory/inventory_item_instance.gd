class_name InventoryItemInstance
extends RefCounted

var definition: ItemDefinition
var stack_count: int = 1
var rotated: bool = false
var runtime_state: RefCounted:
	set(value):
		runtime_state=value
		for grid in get_storage_grids():
			if grid.owner_item==null: grid.owner_item=weakref(self)
		if value!=null and value.has_method("set_inventory_item_owner"): value.set_inventory_item_owner(self)
var _owner_registry: WeakRef
var owned_magazine_item: InventoryItemInstance

func get_owner_registry() -> InventoryTransactionService:
	return _owner_registry.get_ref() if _owner_registry!=null else null

func _init(data: ItemDefinition = null, count: int = 1, runtime: RefCounted = null) -> void:
	definition = data
	stack_count = count
	runtime_state = runtime

func get_storage_grids() -> Array[InventoryGrid]:
	var grids: Array[InventoryGrid]=[]
	if runtime_state!=null and runtime_state.has_method("get_storage_grids"): grids=runtime_state.get_storage_grids()
	return grids

func get_owned_child_edges(registry: InventoryTransactionService=null) -> Array[Dictionary]:
	var edges: Array[Dictionary]=[]
	for grid in get_storage_grids():
		for placement in grid.placements:
			edges.append({"parent_item":self,"child_item":placement.item,"edge_role":&"container","grid":grid,"placement":placement})
	if runtime_state!=null and runtime_state.has_method("get_owned_child_edges"):
		edges.append_array(runtime_state.get_owned_child_edges(self,registry if registry!=null else get_owner_registry()))
	return edges

func get_size(rotation: bool = rotated) -> Vector2i:
	return Vector2i(definition.grid_size.y, definition.grid_size.x) if rotation else definition.grid_size

func get_weight() -> float:
	return InventoryWeightCalculator.get_item_total_weight(self).weight_kg

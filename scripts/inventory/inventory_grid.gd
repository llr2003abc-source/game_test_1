class_name InventoryGrid
extends RefCounted

var size: Vector2i
var kind: StringName
var placements: Array[InventoryPlacement] = []
var _transactions: WeakRef

func _init(width: int = 1, height: int = 1, container_kind: StringName = &"generic") -> void:
	size = Vector2i(width,height)
	kind = container_kind

func set_transactions(service: InventoryTransactionService) -> void:
	_transactions = weakref(service)

func get_transactions() -> InventoryTransactionService:
	return _transactions.get_ref() if _transactions != null else null

func can_place(item: InventoryItemInstance, position: Vector2i, rotation: bool = false) -> bool:
	if item == null or item.definition == null or not item.definition.is_valid() or item.stack_count < 1 or item.stack_count > item.definition.max_stack:
		return false
	if kind in [&"rig", &"backpack"] and item.definition.category in [ItemDefinition.Category.RIG,ItemDefinition.Category.BACKPACK]:
		return false
	var extent: Vector2i = item.get_size(rotation)
	var rectangle := Rect2i(position,extent)
	if position.x < 0 or position.y < 0 or position.x + extent.x > size.x or position.y + extent.y > size.y:
		return false
	for placement in placements:
		if placement.item != item and rectangle.intersects(Rect2i(placement.position,placement.item.get_size())):
			return false
	return true

func get_placement(item: InventoryItemInstance) -> InventoryPlacement:
	for placement in placements:
		if placement.item == item: return placement
	return null

func get_item_at_cell(cell: Vector2i) -> InventoryItemInstance:
	for placement in placements:
		if Rect2i(placement.position,placement.item.get_size()).has_point(cell): return placement.item
	return null

func find_first_free_position(item: InventoryItemInstance, rotation: bool = false) -> Vector2i:
	for y in range(size.y):
		for x in range(size.x):
			if can_place(item,Vector2i(x,y),rotation): return Vector2i(x,y)
	return Vector2i(-1,-1)

func place_item(item: InventoryItemInstance, position: Vector2i) -> bool:
	var service: InventoryTransactionService = get_transactions()
	if service != null: return service.place(item,self,position,item.rotated)
	if get_placement(item) != null or not can_place(item,position,item.rotated): return false
	_commit_place(item,position,item.rotated)
	return true

func remove_item(item: InventoryItemInstance) -> bool:
	if get_placement(item) == null: return false
	var service: InventoryTransactionService = get_transactions()
	if service != null: return service.remove(item)
	return _commit_remove(item)

func move_item(item: InventoryItemInstance, position: Vector2i) -> bool:
	if get_placement(item) == null: return false
	var service: InventoryTransactionService = get_transactions()
	if service != null: return service.move(item,self,position,item.rotated)
	if get_placement(item) == null or not can_place(item,position,item.rotated): return false
	get_placement(item).position = position
	return true

func rotate_item(item: InventoryItemInstance) -> bool:
	if get_placement(item) == null: return false
	var service: InventoryTransactionService = get_transactions()
	if service != null: return service.rotate(item)
	var placement: InventoryPlacement = get_placement(item)
	if placement == null or not can_place(item,placement.position,not item.rotated): return false
	item.rotated = not item.rotated
	return true

func auto_add_item(item: InventoryItemInstance) -> bool:
	return place_item(item,find_first_free_position(item,item.rotated))

func get_total_weight() -> float:
	var total: float = 0.0
	for placement in placements: total += placement.item.get_weight()
	return total

func _commit_place(item: InventoryItemInstance, position: Vector2i, rotation: bool) -> void:
	item.rotated = rotation
	placements.append(InventoryPlacement.new(item,position))

func _commit_remove(item: InventoryItemInstance) -> bool:
	var placement: InventoryPlacement = get_placement(item)
	if placement == null: return false
	placements.erase(placement)
	return true

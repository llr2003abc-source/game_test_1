class_name InventoryTransactionService
extends RefCounted

signal changed()
static var _runtime_owner_registries: Dictionary = {}
var grids: Array[InventoryGrid] = []
var items: Array[InventoryItemInstance] = []
var runtime_registry: Dictionary = {}
var world_items: Dictionary = {}
var inventory: Node
var locked: bool = false

func register_grid(grid: InventoryGrid) -> bool:
	if not grids.has(grid):
		if not _can_adopt_grid(grid): return false
		var candidates: Array[InventoryItemInstance] = []
		for placement in grid.placements: candidates.append_array(_registration_group(placement.item))
		if not _can_register(candidates): return false
		_commit_registration(candidates)
		grids.append(grid)
		grid.set_transactions(self)
	return true

func register_item(item: InventoryItemInstance) -> bool:
	for grid in _contents_grids(item):
		if not _can_adopt_grid(grid): return false
	var candidates: Array[InventoryItemInstance] = _registration_group(item)
	if not _can_register(candidates): return false
	_commit_registration(candidates)
	return true

func _registration_group(item: InventoryItemInstance) -> Array[InventoryItemInstance]:
	var candidates: Array[InventoryItemInstance] = [item]
	if item.runtime_state is WeaponRuntime and item.runtime_state.loaded_magazine!=null:
		var loaded: InventoryItemInstance=find_runtime_item(item.runtime_state.loaded_magazine)
		if loaded!=null:
			var location: Dictionary=get_location(loaded)
			if location.kind not in [&"transit",&"unregistered"] and not (location.kind==&"weapon_magazine" and location.weapon==item): return [null]
			candidates.append(loaded)
		elif item.definition.magazine_item_definition!=null:
			candidates.append(InventoryItemInstance.new(item.definition.magazine_item_definition,1,item.runtime_state.loaded_magazine))
	for grid in _contents_grids(item):
		for placement in grid.placements: candidates.append_array(_registration_group(placement.item))
	return candidates

func _contents_grids(item: InventoryItemInstance) -> Array[InventoryGrid]:
	var contents: Array[InventoryGrid] = []
	if item == null: return contents
	if item.runtime_state is RigContainerRuntime: contents = item.runtime_state.grids
	elif item.runtime_state is BackpackContainerRuntime: contents.append(item.runtime_state.grid)
	return contents

func _can_adopt_grid(grid: InventoryGrid) -> bool:
	if grid.get_transactions() != null and grid.get_transactions() != self: return false
	if not grids.has(grid):
		for placement in grid.placements:
			if get_location(placement.item).kind not in [&"transit",&"unregistered"]: return false
	return true

func _can_register(candidates: Array[InventoryItemInstance]) -> bool:
	for identity in _runtime_owner_registries.keys():
		if _runtime_owner_registries[identity].get_ref()==null: _runtime_owner_registries.erase(identity)
	var pending: Dictionary = {}
	var seen_items: Array[InventoryItemInstance] = []
	for item in candidates:
		if item == null or item.definition == null or not item.definition.is_valid() or item.stack_count < 1 or item.stack_count > item.definition.max_stack: return false
		if item.get_owner_registry()!=null and item.get_owner_registry()!=self: return false
		if seen_items.has(item): return false
		seen_items.append(item)
		if item.runtime_state == null: continue
		var identity: int = item.runtime_state.get_instance_id()
		var runtime_owner: InventoryTransactionService=_runtime_owner_registries[identity].get_ref() if _runtime_owner_registries.has(identity) else null
		if runtime_owner!=null and runtime_owner!=self: return false
		if runtime_registry.has(identity) and runtime_registry[identity] != item: return false
		if pending.has(identity) and pending[identity] != item: return false
		pending[identity] = item
	return true

func _commit_registration(candidates: Array[InventoryItemInstance]) -> void:
	for item in candidates:
		item._owner_registry = weakref(self)
		if item.runtime_state != null:
			var identity: int=item.runtime_state.get_instance_id()
			runtime_registry[identity] = item
			_runtime_owner_registries[identity] = weakref(self)
		if not items.has(item): items.append(item)

func find_runtime_item(runtime: RefCounted) -> InventoryItemInstance:
	return runtime_registry.get(runtime.get_instance_id()) if runtime != null else null

func owns_world_item(item: InventoryItemInstance, node: Node) -> bool:
	return items.has(item) and world_items.get(item)==node and is_instance_valid(node) and get_location(item).kind==&"world"

func drop_item_to_world(item: InventoryItemInstance, parent: Node3D, world_transform: Transform3D) -> DroppedItem:
	if locked or not items.has(item) or not is_instance_valid(parent) or parent.is_queued_for_deletion(): return null
	var source: Dictionary=get_location(item)
	if source.kind not in [&"grid",&"equipment",&"transit"] or not register_item(item): return null
	var node: DroppedItem=WorldItemFactory._prepare(item,self)
	_clear_location(item,source)
	world_items[item]=node
	WorldItemFactory._attach(node,parent,world_transform)
	changed.emit()
	return node

func preview_world_pickup(world: DroppedItem) -> PickupPreviewResult:
	var count: int=world.item.stack_count if is_instance_valid(world) and world.item!=null else 0
	if locked: return PickupPreviewResult.new(0,count,&"INVENTORY_LOCKED")
	if not is_instance_valid(world) or world.is_queued_for_deletion() or not owns_world_item(world.item,world) or inventory==null: return PickupPreviewResult.new(0,count)
	var plan: Dictionary=PickupPlacementPolicy.plan_pickup(inventory,world.item)
	var accepted: int=0
	for transfer in plan.merges: accepted+=transfer.amount
	if not plan.destination.is_empty() and _valid_pickup_destination(world.item,plan.destination): accepted=count
	return PickupPreviewResult.new(accepted,count-accepted,&"NONE" if accepted==count else (&"PARTIAL_SPACE" if accepted>0 else &"NO_SPACE"))

func pickup_world_item_to_grid(world: DroppedItem, grid: InventoryGrid, cell: Vector2i, rotation: bool) -> Dictionary:
	return pickup_world_item(world,{"kind":&"grid","grid":grid,"position":cell,"rotated":rotation},true)

func pickup_world_ammo_into(world: DroppedItem, target: InventoryItemInstance) -> Dictionary:
	var failure: Dictionary={"success":false,"accepted_count":0,"remaining_count":world.item.stack_count if is_instance_valid(world) and world.item!=null else 0}
	if locked or not is_instance_valid(world) or world.is_queued_for_deletion() or not owns_world_item(world.item,world) or get_location(target).kind!=&"grid": return failure
	var source: InventoryItemInstance=world.item
	var count: int=load_ammo_into_magazine(source,target,source.stack_count) if target.definition.category==ItemDefinition.Category.MAGAZINE else merge_stacks(source,target)
	if count<=0: return failure
	if source.stack_count==0: world.retire()
	return {"success":true,"accepted_count":count,"remaining_count":source.stack_count}

func pickup_world_item(world: DroppedItem, destination: Dictionary = {}, manual: bool = false) -> Dictionary:
	var failure: Dictionary={"success":false,"accepted_count":0,"remaining_count":world.item.stack_count if is_instance_valid(world) and world.item!=null else 0}
	if locked or not is_instance_valid(world) or world.is_queued_for_deletion() or not owns_world_item(world.item,world): return failure
	var item: InventoryItemInstance=world.item
	var plan: Dictionary={"merges":[],"destination":destination}
	if destination.is_empty() and inventory!=null: plan=PickupPlacementPolicy.plan_pickup(inventory,item)
	destination=plan.destination
	if destination.is_empty() and plan.merges.is_empty(): return failure
	if not destination.is_empty() and not _valid_pickup_destination(item,destination,manual): return failure
	if not register_item(item): return failure
	var count: int=item.stack_count
	for transfer in plan.merges:
		transfer.item.stack_count+=transfer.amount
		item.stack_count-=transfer.amount
	var remaining: int=item.stack_count
	if not destination.is_empty():
		_clear_location(item,{"kind":&"world"})
		_commit_pickup_destination(item,destination)
		remaining=0
		world.retire()
	elif item.stack_count==0:
		_consume_item(item)
		world.retire()
	changed.emit()
	return {"success":true,"accepted_count":count-remaining,"remaining_count":remaining}

func _valid_pickup_destination(item: InventoryItemInstance, destination: Dictionary, manual: bool = false) -> bool:
	if destination.get("kind")==&"grid":
		var grid: InventoryGrid=destination.get("grid")
		return grids.has(grid) and (manual or grid.kind!=&"secure") and grid.can_place(item,destination.position,destination.get("rotated",item.rotated))
	if destination.get("kind")==&"equipment" and inventory!=null:
		var slot: int=destination.get("slot",-1)
		return inventory.equipment.can_equip(item,slot) and inventory.equipment.slots[slot]==null
	return false

func _commit_pickup_destination(item: InventoryItemInstance, destination: Dictionary) -> void:
	if destination.kind==&"grid": destination.grid._commit_place(item,destination.position,destination.get("rotated",item.rotated))
	else:
		var equipment: EquipmentComponent=inventory.equipment
		var had_active: bool=equipment.get_active_item()!=null
		equipment.slots[destination.slot]=item
		item.rotated=false
		if not had_active and destination.slot in [0,1,2,3]: equipment.active_weapon_slot=destination.slot as EquipmentComponent.Slot

func get_location(item: InventoryItemInstance) -> Dictionary:
	for grid in grids:
		if grid.get_placement(item) != null: return {"kind":&"grid", "grid":grid}
	if inventory != null:
		for slot in inventory.equipment.slots:
			if inventory.equipment.slots[slot] == item: return {"kind":&"equipment", "slot":slot}
	for owner_item in items:
		if owner_item.runtime_state is WeaponRuntime and owner_item.runtime_state.loaded_magazine == item.runtime_state and item.runtime_state is MagazineInstance:
			return {"kind":&"weapon_magazine", "weapon":owner_item}
	if world_items.has(item): return {"kind":&"world", "node":world_items[item]}
	return {"kind":&"transit"} if items.has(item) else {"kind":&"unregistered"}

func place(item: InventoryItemInstance, grid: InventoryGrid, position: Vector2i, rotation: bool = false) -> bool:
	if locked or get_location(item).kind not in [&"transit",&"unregistered"]: return false
	return move(item,grid,position,rotation)

func move(item: InventoryItemInstance, grid: InventoryGrid, position: Vector2i, rotation: bool = false) -> bool:
	if locked or not grids.has(grid) or not grid.can_place(item,position,rotation): return false
	var source: Dictionary = get_location(item)
	if source.kind in [&"weapon_magazine",&"world"]: return false
	if not register_item(item): return false
	_clear_location(item,source)
	grid._commit_place(item,position,rotation)
	changed.emit()
	return true

func remove(item: InventoryItemInstance) -> bool:
	var source: Dictionary = get_location(item)
	if locked or source.kind not in [&"grid",&"equipment"]: return false
	_clear_location(item,source)
	changed.emit()
	return true

func rotate(item: InventoryItemInstance) -> bool:
	var source: Dictionary = get_location(item)
	if locked or source.kind != &"grid": return false
	return move(item,source.grid,source.grid.get_placement(item).position,not item.rotated)

func equip(item: InventoryItemInstance, slot: int) -> bool:
	if locked or inventory == null or not inventory.equipment.can_equip(item,slot): return false
	var current: InventoryItemInstance = inventory.equipment.slots[slot]
	if current == item: return true
	if current != null: return false
	var source: Dictionary = get_location(item)
	if source.kind in [&"weapon_magazine",&"world"] or not register_item(item): return false
	_clear_location(item,source)
	item.rotated = false
	inventory.equipment.slots[slot] = item
	changed.emit()
	return true

func merge_stacks(source: InventoryItemInstance, target: InventoryItemInstance) -> int:
	if locked or source == target or not items.has(source) or not items.has(target): return 0
	if source.definition.category != ItemDefinition.Category.AMMO or target.definition.category != ItemDefinition.Category.AMMO or source.definition.item_id != target.definition.item_id or target.definition.max_stack <= 1: return 0
	var amount: int = mini(source.stack_count,target.definition.max_stack-target.stack_count)
	if amount <= 0: return 0
	source.stack_count -= amount
	target.stack_count += amount
	if source.stack_count == 0: _consume_item(source)
	changed.emit()
	return amount

func split_stack(source: InventoryItemInstance, amount: int, destination: InventoryGrid = null) -> InventoryItemInstance:
	if locked or not items.has(source) or source.definition.category != ItemDefinition.Category.AMMO or amount <= 0 or amount >= source.stack_count: return null
	var location: Dictionary = get_location(source)
	if destination == null:
		if location.kind != &"grid": return null
		destination = location.grid
	if not grids.has(destination): return null
	var split := InventoryItemInstance.new(source.definition,amount)
	var cell: Vector2i = destination.find_first_free_position(split)
	if cell.x < 0: return null
	source.stack_count -= amount
	register_item(split)
	destination._commit_place(split,cell,false)
	changed.emit()
	return split

func load_ammo_into_magazine(ammo: InventoryItemInstance, magazine: InventoryItemInstance, requested_amount: int) -> int:
	if locked or requested_amount <= 0 or not items.has(ammo) or not items.has(magazine): return 0
	if ammo.definition.category != ItemDefinition.Category.AMMO or magazine.definition.category != ItemDefinition.Category.MAGAZINE: return 0
	var round_data: AmmoData = ammo.definition.ammo_data
	var runtime: MagazineInstance = magazine.runtime_state as MagazineInstance
	if round_data == null or runtime == null or runtime.definition == null or not runtime.definition.compatible_ammo_type_ids.has(round_data.ammo_type_id): return 0
	var amount: int = mini(requested_amount,mini(ammo.stack_count,runtime.definition.capacity-runtime.get_round_count()))
	if amount <= 0: return 0
	for i in range(amount): runtime.push_round(round_data)
	ammo.stack_count -= amount
	if ammo.stack_count == 0: _consume_item(ammo)
	changed.emit()
	return amount

func _clear_location(item: InventoryItemInstance, location: Dictionary) -> void:
	if location.kind == &"grid": location.grid._commit_remove(item)
	elif location.kind == &"equipment": inventory.equipment.slots[location.slot] = null
	elif location.kind == &"world": world_items.erase(item)

func _consume_item(item: InventoryItemInstance) -> void:
	_clear_location(item,get_location(item))
	items.erase(item)
	item._owner_registry=null
	if item.runtime_state != null:
		var identity: int=item.runtime_state.get_instance_id()
		runtime_registry.erase(identity)
		_runtime_owner_registries.erase(identity)

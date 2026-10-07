class_name InventoryDragCandidateResolver
extends RefCounted

static func resolve_grid(context: InventoryDragContext, grid: InventoryGrid, mouse_position: Vector2, grid_origin: Vector2, cell_size: float = 48.0, snap_radius: float = 16.0, locked: bool = false) -> Dictionary:
	var ideal: Vector2 = context.get_ghost_top_left(mouse_position) - grid_origin
	var raw := Vector2i(floori(ideal.x/cell_size),floori(ideal.y/cell_size))
	var result: Dictionary = {"kind":&"placement","grid":grid,"raw_position":raw,"position":raw,"rotated":context.preview_rotation,"valid":false,"snapped":false,"snap_distance":0.0,"target_item":null}
	var pointer: Vector2 = (mouse_position-grid_origin)/cell_size
	var pointer_cell := Vector2i(floori(pointer.x),floori(pointer.y))
	var target: InventoryItemInstance = grid.get_item_at_cell(pointer_cell)
	if target!=null and target.definition.has_capability(&"portable_container"):
		return resolve_container_content(context,target,grid,locked)
	if context.item.definition.category==ItemDefinition.Category.AMMO and target!=null and target!=context.item:
		if target.definition.category in [ItemDefinition.Category.MAGAZINE,ItemDefinition.Category.AMMO]:
			result.kind = &"load" if target.definition.category==ItemDefinition.Category.MAGAZINE else &"stack"
			result.target_item = target
			result.position = grid.get_placement(target).position
			result.valid = can_load(context.item,target,locked) if result.kind==&"load" else can_stack(context.item,target,locked)
			return result
	if locked: return result
	if grid.can_place(context.item,raw,context.preview_rotation):
		result.valid = true
		return result
	var best_distance: float = INF
	# Stable row-major order; raw has already failed, at most8 further checks.
	for y in range(-1,2):
		for x in range(-1,2):
			if x==0 and y==0: continue
			var cell: Vector2i = raw + Vector2i(x,y)
			var distance: float = ideal.distance_to(Vector2(cell)*cell_size)
			if distance > snap_radius or distance >= best_distance - 0.000001: continue
			if grid.can_place(context.item,cell,context.preview_rotation):
				best_distance = distance
				result.position = cell
				result.valid = true
				result.snapped = true
				result.snap_distance = distance
	return result

static func resolve_container_content(context: InventoryDragContext, target: InventoryItemInstance, hover_grid: InventoryGrid=null, locked: bool=false) -> Dictionary:
	var result: Dictionary={"kind":&"container_content","target_item":target,"hover_grid":hover_grid,"hover_position":hover_grid.get_placement(target).position if hover_grid!=null else Vector2i(-1,-1),"grid":null,"position":Vector2i(-1,-1),"rotated":context.preview_rotation,"valid":false,"snapped":false,"snap_distance":0.0,"reason":&"NO_SPACE"}
	if target==context.item:
		result.reason=&"SELF"
		return result
	var registry:=target.get_owner_registry()
	var source:=context.item.get_owner_registry()
	if locked or (registry!=null and (registry.locked or registry.is_reserved(target))) or (source!=null and (source.locked or source.is_reserved(context.item))):
		result.reason=&"BUSY"
		return result
	var incoming: Dictionary=InventoryOwnershipGraph.collect_item_subtree(context.item)
	var contents: Dictionary=InventoryOwnershipGraph.collect_item_subtree(target)
	if not incoming.valid or not contents.valid or (registry!=null and not registry._can_register(incoming.items,source)):
		result.reason=&"INVALID_OWNERSHIP"
		return result
	for storage: InventoryGrid in target.get_storage_grids():
		if InventoryOwnershipGraph.would_create_cycle(context.item,storage):
			result.reason=&"CYCLE_OR_DEPTH"
			return result
		if storage.kind in [&"rig",&"pocket",&"secure"] and context.item.definition.has_capability(&"portable_container"):
			result.reason=&"NOT_ALLOWED"
			continue
		var cell: Vector2i=storage.find_first_free_position(context.item,context.preview_rotation)
		if cell.x<0: continue
		result.grid=storage
		result.position=cell
		result.valid=true
		result.reason=&"NONE"
		return result
	return result

static func can_load(ammo: InventoryItemInstance, target: InventoryItemInstance, locked: bool = false) -> bool:
	if locked or ammo.definition.category!=ItemDefinition.Category.AMMO or target.definition.category!=ItemDefinition.Category.MAGAZINE: return false
	var round_data: AmmoData = ammo.definition.ammo_data
	var magazine: MagazineInstance = target.runtime_state as MagazineInstance
	return ammo.stack_count>0 and round_data!=null and magazine!=null and magazine.definition!=null and not magazine.is_full() and magazine.definition.compatible_ammo_type_ids.has(round_data.ammo_type_id)

static func can_stack(ammo: InventoryItemInstance, target: InventoryItemInstance, locked: bool = false) -> bool:
	return not locked and ammo!=target and ammo.definition.category==ItemDefinition.Category.AMMO and target.definition.category==ItemDefinition.Category.AMMO and ammo.definition.item_id==target.definition.item_id and ammo.stack_count>0 and target.stack_count<target.definition.max_stack and target.definition.max_stack>1

static func resolve_equipment(context: InventoryDragContext, equipment: EquipmentComponent, slot: int, locked: bool = false) -> Dictionary:
	return {"kind":&"equipment","slot":slot,"rotated":false,"valid":not locked and equipment.can_equip(context.item,slot) and equipment.slots[slot] in [null,context.item],"snapped":false,"snap_distance":0.0}

class_name InventoryDragCandidateResolver
extends RefCounted

static func resolve_grid(context: InventoryDragContext, grid: InventoryGrid, mouse_position: Vector2, grid_origin: Vector2, cell_size: float = 48.0, snap_radius: float = 16.0, locked: bool = false) -> Dictionary:
	var ideal: Vector2 = context.get_ghost_top_left(mouse_position) - grid_origin
	var raw := Vector2i(floori(ideal.x/cell_size),floori(ideal.y/cell_size))
	var result: Dictionary = {"kind":&"placement","grid":grid,"raw_position":raw,"position":raw,"rotated":context.preview_rotation,"valid":false,"snapped":false,"snap_distance":0.0,"target_item":null}
	var pointer: Vector2 = (mouse_position-grid_origin)/cell_size
	var pointer_cell := Vector2i(floori(pointer.x),floori(pointer.y))
	var target: InventoryItemInstance = grid.get_item_at_cell(pointer_cell)
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

static func can_load(ammo: InventoryItemInstance, target: InventoryItemInstance, locked: bool = false) -> bool:
	if locked or ammo.definition.category!=ItemDefinition.Category.AMMO or target.definition.category!=ItemDefinition.Category.MAGAZINE: return false
	var round_data: AmmoData = ammo.definition.ammo_data
	var magazine: MagazineInstance = target.runtime_state as MagazineInstance
	return ammo.stack_count>0 and round_data!=null and magazine!=null and magazine.definition!=null and not magazine.is_full() and magazine.definition.compatible_ammo_type_ids.has(round_data.ammo_type_id)

static func can_stack(ammo: InventoryItemInstance, target: InventoryItemInstance, locked: bool = false) -> bool:
	return not locked and ammo!=target and ammo.definition.category==ItemDefinition.Category.AMMO and target.definition.category==ItemDefinition.Category.AMMO and ammo.definition.item_id==target.definition.item_id and ammo.stack_count>0 and target.stack_count<target.definition.max_stack and target.definition.max_stack>1

static func resolve_equipment(context: InventoryDragContext, equipment: EquipmentComponent, slot: int, locked: bool = false) -> Dictionary:
	return {"kind":&"equipment","slot":slot,"rotated":false,"valid":not locked and equipment.can_equip(context.item,slot) and equipment.slots[slot] in [null,context.item],"snapped":false,"snap_distance":0.0}

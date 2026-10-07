class_name ReloadCoordinator
extends Node

signal magazine_dropped(item: InventoryItemInstance)
@export var tactical_time_multiplier: float = 1.0
@export var drop_time_multiplier: float = 1.0
var inventory: PlayerInventoryComponent
var executor: Firearm
var context: Dictionary = {}

func configure(owner_inventory: PlayerInventoryComponent, firearm: Firearm = null) -> void:
	inventory = owner_inventory
	executor = firearm

func select_reload_magazine() -> InventoryItemInstance:
	var weapon: InventoryItemInstance = inventory.equipment.get_active_item()
	var rig: RigContainerRuntime = inventory.get_equipped_rig()
	if weapon == null or not weapon.runtime_state is WeaponRuntime or rig == null: return null
	var runtime: WeaponRuntime = weapon.runtime_state
	var best: InventoryItemInstance = null
	for grid in rig.grids:
		for placement in grid.placements:
			var item: InventoryItemInstance = placement.item
			if item.definition.category != ItemDefinition.Category.MAGAZINE or not item.runtime_state is MagazineInstance: continue
			var magazine: MagazineInstance = item.runtime_state
			if magazine.definition == null or not runtime.weapon_data.compatible_magazine_type_ids.has(magazine.definition.magazine_type_id) or magazine.is_empty(): continue
			if best == null or magazine.get_round_count() > best.runtime_state.get_round_count(): best = item
	return best

func get_available_magazine_count() -> int:
	var weapon: InventoryItemInstance = inventory.equipment.get_active_item()
	var rig: RigContainerRuntime = inventory.get_equipped_rig()
	if weapon == null or not weapon.runtime_state is WeaponRuntime or rig == null: return 0
	var count: int = 0
	for grid in rig.grids:
		for placement in grid.placements:
			var item: InventoryItemInstance = placement.item
			if item.definition.category==ItemDefinition.Category.MAGAZINE and item.runtime_state is MagazineInstance and not item.runtime_state.is_empty() and item.runtime_state.definition != null and weapon.runtime_state.weapon_data.compatible_magazine_type_ids.has(item.runtime_state.definition.magazine_type_id): count += 1
	return count

func request_reload(requested: WeaponRuntime.ReloadType = WeaponRuntime.ReloadType.TACTICAL) -> bool:
	if inventory.transactions.locked: return false
	var replacement: InventoryItemInstance = select_reload_magazine()
	if replacement == null: return false
	var weapon: InventoryItemInstance = inventory.equipment.get_active_item()
	var runtime: WeaponRuntime = weapon.runtime_state
	if not runtime.can_begin_reload(replacement.runtime_state): return false
	var old: InventoryItemInstance = inventory.find_runtime_item(runtime.loaded_magazine)
	if runtime.loaded_magazine != null and old == null: return false
	var target: InventoryGrid
	var cell := Vector2i(-1,-1)
	if requested == WeaponRuntime.ReloadType.TACTICAL and old != null:
		for grid in inventory.get_equipped_rig().grids:
			var free: Vector2i = grid.find_first_free_position(old,old.rotated)
			if free.x >= 0:
				target = grid
				cell = free
				break
	var type: WeaponRuntime.ReloadType = requested
	if old != null and requested==WeaponRuntime.ReloadType.TACTICAL and target==null: type=WeaponRuntime.ReloadType.DROP
	var source: InventoryGrid = inventory.transactions.get_location(replacement).grid
	var origin: Vector2i = source.get_placement(replacement).position
	var duration: float = ReloadTimingProvider.get_base_duration(runtime.weapon_data,replacement.runtime_state.definition,runtime.chambered_round==null) * (drop_time_multiplier if type==WeaponRuntime.ReloadType.DROP else tactical_time_multiplier)
	if executor != null and executor.injury_component != null: duration *= executor.injury_component.get_reload_multiplier()
	context = {"weapon":weapon,"runtime":runtime,"old":old,"replacement":replacement,"source":source,"origin":origin,"target":target,"cell":cell,"type":type}
	context["incoming_reservation"]=inventory.transactions.reserve_item(replacement)
	context["outgoing_reservation"]=inventory.transactions.reserve_item(old,false) if old!=null else null
	if context.incoming_reservation==null or (old!=null and context.outgoing_reservation==null):
		if context.incoming_reservation!=null: inventory.transactions.cancel_reservation(context.incoming_reservation)
		context.clear()
		return false
	inventory.transactions.locked = true
	runtime.reload_finished.connect(_complete)
	if not runtime.begin_reload(replacement.runtime_state,duration,type):
		runtime.reload_finished.disconnect(_complete)
		inventory.transactions.locked = false
		inventory.transactions.cancel_reservation(context.incoming_reservation)
		if context.outgoing_reservation!=null: inventory.transactions.cancel_reservation(context.outgoing_reservation)
		context.clear()
		return false
	inventory._on_inventory_changed()
	return true

func _complete(result: WeaponReloadResult) -> void:
	if context.is_empty() or not result.success: return
	var runtime: WeaponRuntime = context.runtime
	runtime.reload_finished.disconnect(_complete)
	var old: InventoryItemInstance = inventory.find_runtime_item(result.old_magazine)
	if old != null:
		if context.type==WeaponRuntime.ReloadType.TACTICAL:
			context.target._commit_place(old,context.cell,old.rotated)
		else:
			inventory.transactions.world_items[old] = null
			magazine_dropped.emit(old)
		inventory.transactions.finish_reservation(context.outgoing_reservation)
	inventory.transactions.finish_reservation(context.incoming_reservation)
	context.clear()
	inventory.transactions.locked = false
	inventory._on_inventory_changed()

func cancel_reload() -> bool:
	if context.is_empty(): return false
	var runtime: WeaponRuntime=context.runtime
	if not inventory.transactions.cancel_reservation(context.incoming_reservation): return false
	if context.outgoing_reservation!=null: inventory.transactions.cancel_reservation(context.outgoing_reservation)
	runtime.reload_finished.disconnect(_complete)
	runtime.cancel_reload()
	context.clear()
	inventory.transactions.locked=false
	inventory._on_inventory_changed()
	return true

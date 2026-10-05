class_name PlayerInventoryComponent
extends Node

signal inventory_changed()
var transactions := InventoryTransactionService.new()
var equipment := EquipmentComponent.new()
var pockets: Array[InventoryGrid] = []
var secure := SecureContainerComponent.new()
var firearm: Firearm
var reload_coordinator: ReloadCoordinator

func _ready() -> void:
	if get_parent().has_node("Head/Camera3D/WeaponRoot"):
		firearm = get_parent().get_node("Head/Camera3D/WeaponRoot")
		initialize_loadout()

func initialize_loadout() -> void:
	var world_executor: Firearm = firearm
	var runtime: WeaponRuntime = firearm.weapon_runtime if firearm != null else null
	# Construct the aggregate before publishing an active binding.
	firearm = null
	var rig := InventoryItemInstance.new(load("res://data/items/rig_1.tres"),1,RigContainerRuntime.new())
	var backpack := InventoryItemInstance.new(load("res://data/items/backpack_1.tres"),1,BackpackContainerRuntime.new())
	transactions.equip(rig,EquipmentComponent.Slot.RIG)
	transactions.equip(backpack,EquipmentComponent.Slot.BACKPACK)
	var weapon_definition: ItemDefinition = load("res://data/items/primary_weapon_1_item.tres")
	var magazine_definition: ItemDefinition = load("res://data/items/magazine_1_item.tres")
	if runtime == null:
		var loaded := MagazineInstance.new()
		loaded.initialize_full(magazine_definition.magazine_data)
		runtime = WeaponRuntime.new()
		runtime.initialize(weapon_definition.weapon_data,loaded)
		runtime.chamber_next_round()
	if runtime.loaded_magazine != null: transactions.register_item(InventoryItemInstance.new(magazine_definition,1,runtime.loaded_magazine))
	var weapon := InventoryItemInstance.new(weapon_definition,1,runtime)
	transactions.equip(weapon,EquipmentComponent.Slot.PRIMARY)
	for i in range(2):
		var magazine := MagazineInstance.new()
		magazine.initialize_full(magazine_definition.magazine_data)
		rig.runtime_state.grids[i].place_item(InventoryItemInstance.new(magazine_definition,1,magazine),Vector2i.ZERO)
	backpack.runtime_state.grid.place_item(InventoryItemInstance.new(load("res://data/items/weapon1_level2_ammo_item.tres"),60),Vector2i.ZERO)
	reload_coordinator = ReloadCoordinator.new()
	add_child(reload_coordinator)
	firearm = world_executor
	reload_coordinator.configure(self,firearm)
	reload_coordinator.magazine_dropped.connect(_spawn_dropped_magazine)
	if firearm != null:
		firearm.inventory_managed = true
		firearm.reload_coordinator = reload_coordinator
	_on_inventory_changed()

func _init() -> void:
	transactions.inventory = self
	equipment._inventory = self
	transactions.changed.connect(_on_inventory_changed)
	for i in range(6):
		var pocket := InventoryGrid.new(1,1,&"pocket")
		pockets.append(pocket)
		transactions.register_grid(pocket)
	transactions.register_grid(secure.grid)

func get_equipped_rig() -> RigContainerRuntime:
	var item: InventoryItemInstance = equipment.slots[EquipmentComponent.Slot.RIG]
	return item.runtime_state as RigContainerRuntime if item != null else null

func get_equipped_backpack() -> BackpackContainerRuntime:
	var item: InventoryItemInstance = equipment.slots[EquipmentComponent.Slot.BACKPACK]
	return item.runtime_state as BackpackContainerRuntime if item != null else null

func find_runtime_item(runtime: RefCounted) -> InventoryItemInstance:
	return transactions.find_runtime_item(runtime)

func get_total_weight() -> float:
	var total: float = 0.0
	for item in transactions.items:
		if transactions.get_location(item).kind != &"world": total += item.get_weight()
	return total

func _on_inventory_changed() -> void:
	for item in transactions.items:
		if item.runtime_state is RigContainerRuntime:
			for grid in item.runtime_state.grids: transactions.register_grid(grid)
		elif item.runtime_state is BackpackContainerRuntime: transactions.register_grid(item.runtime_state.grid)
	if firearm != null:
		var active: InventoryItemInstance = equipment.get_active_item()
		var runtime: WeaponRuntime = active.runtime_state as WeaponRuntime if active != null else null
		if firearm.weapon_runtime != runtime: firearm.bind_runtime(runtime)
		firearm.get_node("WeaponMesh").visible = active != null
		firearm.publish_weapon_state()
	if is_inside_tree() and get_parent().has_node("EquipmentVisuals"):
		get_parent().get_node("EquipmentVisuals/Rig").visible = get_equipped_rig() != null
		get_parent().get_node("EquipmentVisuals/Backpack").visible = get_equipped_backpack() != null
	inventory_changed.emit()

func _spawn_dropped_magazine(item: InventoryItemInstance) -> void:
	if not is_inside_tree() or get_tree().current_scene == null: return
	var dropped: DroppedItem = load("res://scenes/items/dropped_item.tscn").instantiate()
	dropped.configure(item)
	get_tree().current_scene.add_child(dropped)
	var character: Node3D = get_parent()
	dropped.global_position = character.global_position + character.global_basis.x * 0.55 + Vector3.UP * 0.12
	transactions.world_items[item] = dropped

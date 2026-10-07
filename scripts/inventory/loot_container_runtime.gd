class_name LootContainerRuntime
extends RefCounted

signal changed()
var container_id: StringName
var display_name: String
var grid_size: Vector2i
var inventory_grid: InventoryGrid
var transactions:=InventoryTransactionService.new()

func _init(identity: StringName = &"loot_crate", title: String = "Loot Crate", extent: Vector2i = Vector2i(8,6)) -> void:
	container_id=identity
	display_name=title
	grid_size=extent
	inventory_grid=InventoryGrid.new(extent.x,extent.y,&"external")
	transactions.changed.connect(_on_changed)

func _on_changed() -> void:
	changed.emit()

func get_contents_weight() -> float:
	return InventoryWeightCalculator.get_external_container_contents_weight(transactions).weight_kg

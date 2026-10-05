class_name InventoryPlacement
extends RefCounted
var item: InventoryItemInstance
var position: Vector2i
func _init(value: InventoryItemInstance, cell: Vector2i) -> void:
	item = value
	position = cell

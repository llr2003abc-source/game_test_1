class_name InventoryItemInstance
extends RefCounted

var definition: ItemDefinition
var stack_count: int = 1
var rotated: bool = false
var runtime_state: RefCounted

func _init(data: ItemDefinition = null, count: int = 1, runtime: RefCounted = null) -> void:
	definition = data
	stack_count = count
	runtime_state = runtime

func get_size(rotation: bool = rotated) -> Vector2i:
	return Vector2i(definition.grid_size.y, definition.grid_size.x) if rotation else definition.grid_size

func get_weight() -> float:
	return definition.weight * stack_count

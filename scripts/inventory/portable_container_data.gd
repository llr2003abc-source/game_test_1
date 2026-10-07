class_name PortableContainerData
extends Resource

@export var definition_id: StringName
@export var grid_sizes: Array[Vector2i] = []

func is_valid() -> bool:
	if grid_sizes.is_empty(): return false
	for extent in grid_sizes:
		if extent.x<1 or extent.y<1: return false
	return true

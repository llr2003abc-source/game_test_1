class_name BackpackContainerRuntime
extends RefCounted
var grid: InventoryGrid
var definition: PortableContainerData
# No-argument construction preserves existing pre-factory fixtures only.
func _init(data: PortableContainerData = preload("res://data/containers/backpack_1_layout.tres")) -> void:
	definition=data
	var extent: Vector2i=data.grid_sizes[0]
	grid=InventoryGrid.new(extent.x,extent.y,&"backpack")

func get_storage_grids() -> Array[InventoryGrid]:
	return [grid]

class_name RigContainerRuntime
extends RefCounted
var grids: Array[InventoryGrid] = []
var definition: PortableContainerData
# No-argument construction preserves existing pre-factory fixtures only.
func _init(data: PortableContainerData = preload("res://data/containers/rig_1_layout.tres")) -> void:
	definition=data
	for extent in data.grid_sizes: grids.append(InventoryGrid.new(extent.x,extent.y,&"rig"))

func get_storage_grids() -> Array[InventoryGrid]:
	return grids

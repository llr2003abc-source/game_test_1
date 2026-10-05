class_name RigContainerRuntime
extends RefCounted
var grids: Array[InventoryGrid] = []
func _init() -> void:
	for i in range(4): grids.append(InventoryGrid.new(1,2,&"rig"))

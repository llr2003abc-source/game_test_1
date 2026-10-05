extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	for path in ["rig_container_runtime","backpack_container_runtime","secure_container_component"]:
		check(FileAccess.file_exists("res://scripts/inventory/%s.gd"%path),"container implementation: "+path)
	if failures==0:
		var rig: Variant = load("res://scripts/inventory/rig_container_runtime.gd").new()
		var backpack: Variant = load("res://scripts/inventory/backpack_container_runtime.gd").new()
		var secure: Variant = load("res://scripts/inventory/secure_container_component.gd").new()
		check(rig.grids.size()==4,"four rig slots")
		for g in rig.grids:
			check(g.size==Vector2i(1,2),"each rig is independent 1x2")
			check(not g.can_place(item(2,2),Vector2i.ZERO),"cannot bridge rig slots")
			check(g.place_item(item(1,1),Vector2i.ZERO) and g.place_item(item(1,1),Vector2i(0,1)),"two small items fit one rig slot")
		check(rig.grids[0]!=rig.grids[1],"rig grids distinct objects")
		check(backpack.grid.size==Vector2i(5,5),"backpack continuous 5x5")
		check(secure.grid.size==Vector2i(3,3),"secure continuous 3x3")
		var bag: Variant = item(3,4)
		bag.definition.category=8
		check(not backpack.grid.can_place(bag,Vector2i.ZERO),"container nesting rejected")
		check(bag.get_size()==Vector2i(3,4),"backpack exterior independent of content")
		for i in range(6):
			var pocket: Variant = load("res://scripts/inventory/inventory_grid.gd").new(1,1,&"pocket")
			check(not pocket.can_place(item(1,2),Vector2i.ZERO) and pocket.can_place(item(1,1),Vector2i.ZERO),"individual pocket cannot bridge")
	print("CONTAINER_INVENTORY_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

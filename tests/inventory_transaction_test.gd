extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	var service: Variant = load("res://scripts/inventory/inventory_transaction_service.gd").new()
	var a: Variant = load("res://scripts/inventory/inventory_grid.gd").new(3,3)
	var b: Variant = load("res://scripts/inventory/inventory_grid.gd").new(1,1)
	service.register_grid(a)
	service.register_grid(b)
	var value: Variant = item(1,2)
	check(a.place_item(value,Vector2i.ZERO),"transaction owns initial placement")
	check(not b.place_item(value,Vector2i.ZERO),"cannot place an already-owned item twice")
	check(not service.move(value,b,Vector2i.ZERO),"invalid cross-container move rejected")
	check(a.get_placement(value)!=null and b.placements.is_empty(),"failed transfer has no partial remove")
	check(not service.move(value,a,Vector2i(3,3),true) and not value.rotated,"failed transfer retains rotation")
	check(service.move(value,a,Vector2i(1,1),true),"legal move and rotation atomic")
	check(a.placements.size()==1 and value.rotated,"same-container move never duplicates")
	service.locked = true
	check(not a.remove_item(value),"public grid remove obeys lock")
	check(not a.rotate_item(value),"public grid rotation obeys lock")
	check(not service.move(value,a,Vector2i.ZERO),"cross-container lock enforced")
	service.locked = false
	check(service.remove(value) and service.get_location(value).kind==&"transit","remove changes location once")
	check(service.place(value,a,Vector2i.ZERO,true),"transit item can be placed again")
	value.definition.weight = 2.0
	check(a.get_total_weight()==2.0,"weight is definition times quantity")
	print("INVENTORY_TRANSACTION_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

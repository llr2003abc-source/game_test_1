extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	if not FileAccess.file_exists("res://scripts/inventory/secure_container_component.gd"):
		check(false,"secure implementation exists")
	else:
		var secure: Variant = load("res://scripts/inventory/secure_container_component.gd").new()
		var a: Variant = item(1,2)
		check(secure.grid.place_item(a,Vector2i.ZERO),"secure placement")
		check(secure.grid.rotate_item(a),"secure rotation")
		check(secure.grid.move_item(a,Vector2i(1,2)),"secure movement")
		check(not secure.grid.rotate_item(a) and a.rotated,"secure invalid rotation atomic")
	print("SECURE_CONTAINER_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

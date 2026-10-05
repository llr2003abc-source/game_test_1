extends SceneTree
var assertions: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)
func item(width: int, height: int) -> Variant:
	var d: Variant = load("res://scripts/inventory/item_definition.gd").new()
	d.grid_size = Vector2i(width,height)
	return load("res://scripts/inventory/inventory_item_instance.gd").new(d)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for path in ["item_definition", "inventory_item_instance", "inventory_placement", "inventory_grid", "inventory_transaction_service"]:
		check(FileAccess.file_exists("res://scripts/inventory/%s.gd" % path), "required inventory core: " + path)
	if failures == 0:
		var g: Variant = load("res://scripts/inventory/inventory_grid.gd").new(5,5)
		var s: Variant = load("res://scripts/inventory/inventory_transaction_service.gd").new()
		s.register_grid(g)
		var a: Variant = item(2,3)
		check(g.place_item(a,Vector2i.ZERO),"place legal rectangle")
		check(g.get_item_at_cell(Vector2i(1,2))==a,"covered cell resolves exact item")
		check(not g.place_item(item(1,1),Vector2i(1,1)),"overlap rejected")
		check(not g.move_item(a,Vector2i(4,4)),"out of bounds move rejected")
		check(g.get_placement(a).position==Vector2i.ZERO,"failed move preserves placement")
		check(g.rotate_item(a),"legal rotation commits")
		check(a.rotated and g.get_item_at_cell(Vector2i(2,1))==a,"rotation changes occupied size")
		check(g.move_item(a,Vector2i(2,3)),"move rotated object")
		check(not g.rotate_item(a) and a.rotated,"rotation failure preserves rotation")
		check(g.remove_item(a) and g.get_item_at_cell(Vector2i(2,3))==null,"remove clears rectangle")
		for width in range(1,6):
			for height in range(1,6):
				check(g.can_place(item(width,height),Vector2i.ZERO),"all legal sizes %dx%d"%[width,height])
		check(not g.can_place(item(1,1),Vector2i(-1,0)),"negative boundary rejected")
	print("INVENTORY_GRID_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

extends "res://tests/inventory_grid_test.gd"

func released_runtime() -> Array[WeakRef]:
	var runtime: Variant=load("res://scripts/inventory/loot_container_runtime.gd").new()
	return [weakref(runtime),weakref(runtime.transactions)]

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/inventory/loot_container_runtime.gd"),"external loot runtime exists")
	var service:=InventoryTransactionService.new()
	check(service.has_method("register_external_container"),"external runtime atomic registration exists")
	if failures==0:
		var released:=released_runtime()
		check(released[0].get_ref()==null and released[1].get_ref()==null,"runtime/signal registry do not retain themselves after release")
		var runtime: Variant=load("res://scripts/inventory/loot_container_runtime.gd").new(&"crate_a","Loot Crate",Vector2i(8,6))
		var grid: InventoryGrid=runtime.inventory_grid
		check(runtime.grid_size==Vector2i(8,6) and grid.size==Vector2i(8,6),"runtime initializes continuous8x6")
		check(runtime.container_id==&"crate_a" and runtime.display_name=="Loot Crate","runtime stores explicit identity/name")
		var weapon: InventoryItemInstance=item(5,2)
		grid.place_item(weapon,Vector2i.ZERO)
		var ammo_definition: ItemDefinition=load("res://data/items/weapon1_level2_ammo_item.tres")
		var ammo:=InventoryItemInstance.new(ammo_definition,20)
		var other:=InventoryItemInstance.new(ammo_definition,30)
		grid.place_item(ammo,Vector2i(5,0))
		grid.place_item(other,Vector2i(6,0))
		check(runtime.transactions.register_external_container(runtime),"complete valid external runtime registers")
		var location: Dictionary=runtime.transactions.get_location(weapon)
		check(location.kind==&"container" and location.container==runtime and location.grid==grid and location.placement==grid.get_placement(weapon),"location has actual container/grid/placement")
		check(grid.move_item(weapon,Vector2i(0,3)),"same-container item move uses transaction")
		check(not grid.rotate_item(weapon) and not weapon.rotated,"illegal2x5 rotation preserves original")
		check(grid.move_item(weapon,Vector2i.ZERO) and grid.rotate_item(weapon),"valid5x2-to2x5 rotation commits")
		check(grid.get_placement(weapon).position==Vector2i.ZERO and weapon.get_size()==Vector2i(2,5),"rotation retains actual original instance/layout")
		check(runtime.transactions.merge_stacks(ammo,other)==20 and other.stack_count==50,"container internal merge uses existing max60 logic")
		check(grid.get_placement(ammo)==null and runtime.transactions.get_location(other).kind==&"container","full merge consumes source only")
		var split: InventoryItemInstance=runtime.transactions.split_stack(other,15)
		check(split!=null and split.stack_count==15 and other.stack_count==35,"container internal split counts conserved")
		check(runtime.transactions.get_location(split).container==runtime,"split gets true container owner")
		var snapshot: Array=[]
		for placement in grid.placements: snapshot.append([placement.item,placement.position,placement.item.rotated,placement.item.stack_count])
		check(runtime.transactions.register_external_container(runtime),"repeat registration is idempotent")
		var after: Array=[]
		for placement in grid.placements: after.append([placement.item,placement.position,placement.item.rotated,placement.item.stack_count])
		check(snapshot==after,"registration preserves layout/rotation/count/identity")
		check(runtime.transactions.world_items.is_empty(),"external runtime never creates WORLD representation")
	print("LOOT_CONTAINER_RUNTIME_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

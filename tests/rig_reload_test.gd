extends "res://tests/inventory_grid_test.gd"
func fixture() -> Variant:
	var inv: Variant=load("res://scripts/inventory/player_inventory_component.gd").new()
	var rig: Variant=load("res://scripts/inventory/inventory_item_instance.gd").new(load("res://data/items/rig_1.tres"),1,load("res://scripts/inventory/rig_container_runtime.gd").new())
	inv.transactions.equip(rig,4)
	var d: ItemDefinition=load("res://data/items/primary_weapon_1_item.tres")
	var mag:=MagazineInstance.new()
	mag.initialize_full(d.weapon_data.magazine_data)
	for i in range(13): mag.pop_round()
	var runtime:=WeaponRuntime.new()
	runtime.initialize(d.weapon_data,mag,d.weapon_data.magazine_data.default_ammo)
	var gun:=InventoryItemInstance.new(d,1,runtime)
	inv.transactions.register_item(InventoryItemInstance.new(load("res://data/items/magazine_1_item.tres"),1,mag))
	inv.transactions.equip(gun,0)
	return inv
func magazine(count: int, wrong: bool=false) -> Variant:
	var d: ItemDefinition=load("res://data/items/magazine_1_item.tres")
	var runtime:=MagazineInstance.new()
	var data: MagazineData=d.magazine_data.duplicate()
	if wrong: data.magazine_type_id=&"wrong_magazine"
	runtime.initialize_full(data)
	for i in range(30-count): runtime.pop_round()
	return InventoryItemInstance.new(d,1,runtime)
func _run() -> void:
	check(FileAccess.file_exists("res://scripts/weapons/reload_coordinator.gd"),"rig reload coordinator exists")
	if failures==0:
		for requested in [1,2]:
			for unavailable in [0,1,2]:
				var inv: Variant=fixture()
				var coord: Variant=load("res://scripts/weapons/reload_coordinator.gd").new()
				coord.configure(inv)
				if unavailable>0: inv.get_equipped_rig().grids[0].place_item(magazine(0 if unavailable==2 else 30,unavailable==1),Vector2i.ZERO)
				var runtime: Variant=inv.equipment.get_active_item().runtime_state
				var old: MagazineInstance=runtime.loaded_magazine
				check(not coord.request_reload(requested),"no valid replacement rejects both reload types")
				check(runtime.loaded_magazine==old and old.get_round_count()==17 and runtime.chambered_round!=null and runtime.state==0 and inv.transactions.world_items.is_empty(),"no replacement leaves entire weapon/world unchanged")
				coord.free()
				inv.free()
		for full in [false,true]:
			for requested in [1,2]:
				var inv: Variant=fixture()
				var coord: Variant=load("res://scripts/weapons/reload_coordinator.gd").new()
				coord.configure(inv)
				var rig: Variant=inv.get_equipped_rig()
				var replacement: Variant=magazine(30)
				rig.grids[0].place_item(replacement,Vector2i.ZERO)
				if full:
					for i in range(1,4): rig.grids[i].place_item(magazine(20),Vector2i.ZERO)
				var runtime: Variant=inv.equipment.get_active_item().runtime_state
				var old: Variant=inv.find_runtime_item(runtime.loaded_magazine)
				var chamber: AmmoData=runtime.chambered_round
				check(coord.request_reload(requested),"valid equipped-rig replacement accepted")
				var expected: int=2 if full or requested==2 else 1
				check(runtime.reload_type==expected,"pre-removal rig space determines tactical/drop")
				check(inv.transactions.locked and inv.transactions.get_location(replacement).kind==&"transit","replacement reserved with global inventory lock")
				check(not rig.grids[0].place_item(item(1,1),Vector2i.ZERO),"lock prevents stealing freed candidate slot")
				runtime.tick(2.0)
				check(not inv.transactions.locked and runtime.loaded_magazine==replacement.runtime_state and runtime.chambered_round==chamber,"completion preserves exact magazine/chamber refs")
				check(old.runtime_state.get_round_count()==17,"old magazine still17")
				check(inv.transactions.get_location(old).kind==(&"world" if expected==2 else &"grid"),"old item goes to rig or world exactly once")
				check(inv.transactions.get_location(replacement).kind==&"weapon_magazine","replacement owns one weapon position")
				coord.free()
				inv.free()
	print("RIG_RELOAD_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

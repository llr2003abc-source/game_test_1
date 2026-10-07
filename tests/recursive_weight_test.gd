extends "res://tests/ownership_subtree_test.gd"

class FutureChildRuntime extends RefCounted:
	var child: InventoryItemInstance
	func get_owned_child_edges(parent: InventoryItemInstance, _registry: InventoryTransactionService) -> Array[Dictionary]:
		return [{"parent_item":parent,"child_item":child,"edge_role":&"attachment:rail/optic","grid":null,"placement":null}]

func ammo(count: int=60) -> InventoryItemInstance:
	return InventoryItemFactory.create(load("res://data/items/weapon1_level2_ammo_item.tres"),count)

func mag(count: int=30) -> InventoryItemInstance:
	return InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres"),1,count)

func weight_is(value: Dictionary, expected: float) -> bool:
	return value.valid and is_equal_approx(value.weight_kg,expected)

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/inventory/inventory_weight_calculator.gd"),"shared recursive weight foundation exists")
	if failures:
		finish_weight()
		return
	var calc: Variant=load("res://scripts/inventory/inventory_weight_calculator.gd")
	check(weight_is(calc.get_item_total_weight(ammo()),0.72),"current L2 Ammo60 weighs 0.72")
	check(weight_is(calc.get_item_total_weight(mag()),0.51),"real Mag30 weighs empty0.15 plus actual thirty rounds")
	var gun:=InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres"))
	check(weight_is(calc.get_item_total_weight(gun),4.01),"Weapon CH1/MAG29 weighs 4.01 without base double count")
	var rig:=InventoryItemFactory.create(load("res://data/items/rig_1.tres"))
	rig.runtime_state.grids[0].place_item(mag(),Vector2i.ZERO)
	rig.runtime_state.grids[1].place_item(mag(),Vector2i.ZERO)
	check(weight_is(calc.get_item_total_weight(rig),2.02),"Rig plus two full mags weighs 2.02")
	var a:=bag()
	a.runtime_state.grid.place_item(ammo(),Vector2i.ZERO)
	check(weight_is(calc.get_item_total_weight(a),2.22),"Backpack plus Ammo60 weighs 2.22")
	var b:=bag()
	b.runtime_state.grid.place_item(a,Vector2i.ZERO)
	check(weight_is(calc.get_item_total_weight(b),3.72),"nested Backpack+Backpack+Ammo60 weighs 3.72")
	var c:=bag()
	var one_rig:=InventoryItemFactory.create(load("res://data/items/rig_1.tres"))
	one_rig.runtime_state.grids[0].place_item(mag(),Vector2i.ZERO)
	c.runtime_state.grid.place_item(one_rig,Vector2i.ZERO)
	check(weight_is(calc.get_item_total_weight(c),3.01),"Backpack+Rig+Mag weighs 3.01")
	var mixed:=mag(0)
	var round_a:=AmmoData.new()
	round_a.round_weight_kg=0.01
	var round_b:=AmmoData.new()
	round_b.round_weight_kg=0.025
	for round_data in [round_a,round_b,round_a]: mixed.runtime_state.push_round(round_data)
	check(weight_is(calc.get_item_total_weight(mixed),0.195),"mixed ammo weight sums actual0.01+0.025+0.01, not default")
	var runtime:=FutureChildRuntime.new()
	var adapter: InventoryItemInstance=item(1,1)
	adapter.definition.weight=0.5
	runtime.child=adapter
	var future: InventoryItemInstance=item(1,1)
	future.definition.weight=2.0
	future.runtime_state=runtime
	check(weight_is(calc.get_item_total_weight(future),2.5),"future arbitrary attachment-role edge contributes without new DFS or weight branches")
	var service:=InventoryTransactionService.new()
	check(service.register_complete_subtree(future) and service.get_direct_parent(adapter).parent_item==future,"future-role graph registers true item identity without attachment gameplay")
	var borrowed_runtime:=FutureChildRuntime.new()
	borrowed_runtime.child=adapter
	var borrowed_parent: InventoryItemInstance=item(1,1)
	borrowed_parent.runtime_state=borrowed_runtime
	check(not service.register_complete_subtree(borrowed_parent) and service.get_direct_parent(adapter).parent_item==future,"new generic parent cannot alias a registered child already owned by another parent")
	var bad:=bag()
	bad.runtime_state.grid._commit_place(bad,Vector2i.ZERO,false)
	check(not calc.get_item_total_weight(bad).valid,"cycle returns explicit invalid weight instead of silently counting")
	bad.runtime_state.grid.placements.clear()
	var duplicate: InventoryItemInstance=item(1,1)
	bad.runtime_state.grid._commit_place(duplicate,Vector2i.ZERO,false)
	bad.runtime_state.grid._commit_place(duplicate,Vector2i(1,0),false)
	check(not calc.get_item_total_weight(bad).valid,"aliased child refuses weight instead of undercount")
	bad.runtime_state.grid.placements.clear()
	var cycle_registry:=InventoryTransactionService.new()
	var cycle_a:=bag()
	var cycle_b:=bag()
	cycle_a.runtime_state.grid.place_item(cycle_b,Vector2i.ZERO)
	cycle_registry.register_complete_subtree(cycle_a)
	cycle_b.runtime_state.grid._commit_place(cycle_a,Vector2i.ZERO,false)
	check(not calc.get_registry_total_weight(cycle_registry).valid,"registry rootless cycle is invalid, never a plausible zero carried weight")
	cycle_b.runtime_state.grid.placements.clear()
	await integration(calc)
	finish_weight()

func integration(calc: Variant) -> void:
	var inv:=PlayerInventoryComponent.new()
	var gun:=InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres"))
	var rig:=InventoryItemFactory.create(load("res://data/items/rig_1.tres"))
	var a:=bag()
	rig.runtime_state.grids[0].place_item(mag(),Vector2i.ZERO)
	rig.runtime_state.grids[1].place_item(mag(),Vector2i.ZERO)
	a.runtime_state.grid.place_item(ammo(),Vector2i.ZERO)
	inv.transactions.equip(gun,0)
	inv.transactions.equip(rig,4)
	inv.transactions.equip(a,5)
	check(is_equal_approx(inv.get_total_weight(),8.25),"Player carried roots exclude registered loaded magazine and all nested child double counts")
	inv.secure.grid.place_item(ammo(10),Vector2i.ZERO)
	check(is_equal_approx(inv.get_total_weight(),8.37),"Secure contents count, no imaginary shell weight")
	var before: float=inv.get_total_weight()
	var shot: WeaponFireResult=gun.runtime_state.try_fire()
	check(shot.success and is_equal_approx(before-inv.get_total_weight(),0.012),"actual Fire consumes actual round weight immediately")
	gun.runtime_state.tick(1.0)
	var coordinator:=ReloadCoordinator.new()
	coordinator.configure(inv)
	before=inv.get_total_weight()
	check(coordinator.request_reload(),"original Rig-only tactical reload accepted")
	gun.runtime_state.tick(2.0)
	check(is_equal_approx(before,inv.get_total_weight()),"tactical reload preserves all carried weight")
	gun.runtime_state.try_fire()
	gun.runtime_state.tick(1.0)
	before=inv.get_total_weight()
	var outgoing: InventoryItemInstance=inv.find_runtime_item(gun.runtime_state.loaded_magazine)
	var outgoing_weight: float=calc.get_item_total_weight(outgoing).weight_kg
	check(coordinator.request_reload(WeaponRuntime.ReloadType.DROP),"original DROP policy accepted")
	gun.runtime_state.tick(2.0)
	check(is_equal_approx(before-inv.get_total_weight(),outgoing_weight),"DROP reload excludes actual old-mag WORLD root weight")
	var world:=Node3D.new()
	root.add_child(world)
	var dropped:=WorldItemFactory.materialize_reserved(outgoing,inv.transactions,world,Transform3D.IDENTITY)
	check(weight_is(calc.get_world_root_total_weight(outgoing),outgoing_weight),"WORLD root weight matches actual dropped mag")
	check(inv.transactions.pickup_world_item(dropped).success and is_equal_approx(before,inv.get_total_weight()),"recovering same dropped magazine restores weight")
	var crate:=LootContainerRuntime.new()
	crate.inventory_grid.place_item(ammo(10),Vector2i.ZERO)
	crate.transactions.register_external_container(crate)
	check(weight_is(calc.get_external_container_contents_weight(crate.transactions),0.12),"Crate contents weigh only actual roots, not shell")
	coordinator.free()
	inv.free()
	world.queue_free()
	await process_frame

func finish_weight() -> void:
	print("RECURSIVE_WEIGHT_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

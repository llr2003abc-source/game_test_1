extends "res://tests/inventory_grid_test.gd"

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/inventory/external_inventory_transfer.gd"),"runtime reference migration available")
	if failures==0: await exercise()
	print("CONTAINER_RUNTIME_PERSISTENCE_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

func exercise() -> void:
	for name in ["primary_weapon_1_item","rig_1","backpack_1"]:
		var owner: Variant=load("res://tests/container_test_owner.gd").new()
		var actor:=Node3D.new()
		root.add_child(owner)
		root.add_child(actor)
		var inv:=PlayerInventoryComponent.new()
		actor.add_child(inv)
		var ext: InventoryTransactionService=owner.runtime.transactions
		var grid: InventoryGrid=owner.runtime.inventory_grid
		var original:=InventoryItemFactory.create(load("res://data/items/%s.tres"%name),1,17)
		var state: RefCounted=original.runtime_state
		var child: InventoryItemInstance
		var inner: InventoryGrid
		if not state is WeaponRuntime:
			inner=state.grids[0] if state is RigContainerRuntime else state.grid
			child=InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres"),1,17)
			inner.place_item(child,Vector2i.ZERO)
		grid.place_item(original,Vector2i.ZERO)
		check(ext.register_external_container(owner.runtime),"register populated "+name)
		if state is WeaponRuntime: child=ext.find_runtime_item(state.loaded_magazine)
		var round_a:=AmmoData.new()
		var round_b:=AmmoData.new()
		round_a.flesh_damage=30
		round_b.flesh_damage=50
		child.runtime_state.rounds[0]=round_a
		child.runtime_state.rounds[1]=round_b
		var rounds: Array[AmmoData]=child.runtime_state.rounds.duplicate()
		var access:=LootContainerAccess.new(actor,owner,inv.transactions)
		var slot: int=1 if state is WeaponRuntime else (4 if state is RigContainerRuntime else 5)
		check(ExternalInventoryTransfer.transfer(access,original,inv.transactions,{"kind":&"equipment","slot":slot}),"original external item->equipment "+name)
		check(original.runtime_state==state and child.get_owner_registry()==inv.transactions and inv.find_runtime_item(child.runtime_state)==child,"root+child exact identities migrated "+name)
		check(child.runtime_state.rounds==rounds and child.runtime_state.get_round_count()==17,"all AmmoData references/order preserved "+name)
		check(child.runtime_state.rounds[0]==round_a and child.runtime_state.rounds[1]==round_b,"mixed A/B reference sequence survives external transfer "+name)
		check(not ext.items.has(original) and not ext.items.has(child),"source registration removed "+name)
		if inner!=null: check(inner.get_transactions()==inv.transactions and not ext.grids.has(inner),"portable child grid registry migrated "+name)
		else: check(state.chambered_round!=null and state.selected_fire_mode==WeaponData.FireMode.AUTO,"CH1/MAG17/AUTO remains original")
		check(ExternalInventoryTransfer.transfer(access,original,ext,{"kind":&"grid","grid":grid,"position":Vector2i(0,1)}),"whole item returns CONTAINER "+name)
		check(child.get_owner_registry()==ext and ext.find_runtime_item(child.runtime_state)==child and not inv.transactions.items.has(child),"return keeps actual child wrapper "+name)
		if inner!=null: check(inner.get_transactions()==ext and not inv.transactions.grids.has(inner),"return clears stale player grids "+name)
		access.close()
		var reopened:=LootContainerAccess.new(actor,owner,inv.transactions)
		check(reopened.is_valid() and grid.get_placement(original).position==Vector2i(0,1) and original.runtime_state==state,"close/reopen same layout/runtime "+name)
		check(ext.world_items.is_empty() and inv.transactions.world_items.is_empty(),"no WORLD at any point "+name)
		owner.free()
		actor.free()

extends "res://tests/inventory_grid_test.gd"

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/inventory/loot_container_access.gd"),"transaction access session exists")
	check(FileAccess.file_exists("res://scripts/inventory/external_inventory_transfer.gd"),"atomic external transfer exists")
	if failures==0: await exercise()
	print("CONTAINER_TRANSFER_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

func exercise() -> void:
	var owner: Variant=load("res://tests/container_test_owner.gd").new()
	var actor:=Node3D.new()
	root.add_child(owner)
	root.add_child(actor)
	var inv:=PlayerInventoryComponent.new()
	actor.add_child(inv)
	var runtime: LootContainerRuntime=owner.runtime
	var grid:=runtime.inventory_grid
	var ext:=runtime.transactions
	var ammo_def: ItemDefinition=load("res://data/items/weapon1_level2_ammo_item.tres")
	var ammo:=InventoryItemInstance.new(ammo_def,20)
	grid.place_item(ammo,Vector2i.ZERO)
	check(ext.register_external_container(runtime),"register contents before transfer")
	var access:=LootContainerAccess.new(actor,owner,inv.transactions)
	var target:=InventoryItemInstance.new(ammo_def,50)
	inv.transactions.place(target,inv.pockets[0],Vector2i.ZERO)
	check(ExternalInventoryTransfer.transfer_ammo(access,ammo,target)==10,"C20->P50 partial merge10")
	check(target.stack_count==60 and ammo.stack_count==10 and ext.get_location(ammo).container==runtime,"partial source remains original CONTAINER10")
	var reverse:=InventoryItemInstance.new(ammo_def,55)
	ext.place(reverse,grid,Vector2i(1,0))
	var player_ammo:=InventoryItemInstance.new(ammo_def,20)
	inv.transactions.place(player_ammo,inv.pockets[1],Vector2i.ZERO)
	check(ExternalInventoryTransfer.transfer_ammo(access,player_ammo,reverse)==5,"P20->C55 partial merge5")
	check(player_ammo.stack_count==15 and reverse.stack_count==60 and inv.pockets[1].get_placement(player_ammo)!=null,"reverse partial original remains PLAYER15")
	var magazine:=InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres"),1,17)
	ext.place(magazine,grid,Vector2i(2,0))
	check(ExternalInventoryTransfer.transfer_ammo(access,player_ammo,magazine)==13,"PLAYER ammo loads CONTAINER magazine")
	check(player_ammo.stack_count==2 and magazine.runtime_state.get_round_count()==30,"load conserves15=13+2")
	var player_mag:=InventoryItemFactory.create(magazine.definition,1,17)
	inv.transactions.place(player_mag,inv.secure.grid,Vector2i.ZERO)
	check(ExternalInventoryTransfer.transfer_ammo(access,ammo,player_mag)==10,"CONTAINER ammo loads PLAYER magazine")
	check(ammo.stack_count==0 and ext.get_location(ammo).kind==&"unregistered" and player_mag.runtime_state.get_round_count()==27,"full consume unregisters SOURCE not destination")
	check(not ExternalInventoryTransfer.transfer(access,magazine,inv.transactions,{"kind":&"grid","grid":inv.pockets[2],"position":Vector2i.ZERO}),"oversized magazine rejects pocket atomically")
	check(ext.get_location(magazine).container==runtime and magazine.get_owner_registry()==ext,"failure retains placement/ownership")
	check(ExternalInventoryTransfer.transfer(access,magazine,inv.transactions,{"kind":&"grid","grid":inv.secure.grid,"position":Vector2i(1,0)}),"manual Secure transfer allowed")
	check(magazine.get_owner_registry()==inv.transactions and ext.find_runtime_item(magazine.runtime_state)==null,"unique runtime migrated")
	check(ExternalInventoryTransfer.transfer(access,magazine,ext,{"kind":&"grid","grid":grid,"position":Vector2i(3,0)}),"PLAYER->CONTAINER reverse same instance")
	var lock_observed: Array=[]
	var callback: Callable=func(): lock_observed.append(ext.locked and inv.transactions.locked); lock_observed.append(not inv.transactions.move(player_ammo,inv.pockets[3],Vector2i.ZERO))
	ext.changed.connect(callback)
	check(ExternalInventoryTransfer.transfer(access,magazine,inv.transactions,{"kind":&"grid","grid":inv.secure.grid,"position":Vector2i(1,0)}),"second atomic transfer commits")
	check(lock_observed==[true,true],"both registries locked throughout callback/reentrant operation")
	ext.changed.disconnect(callback)
	check(not ext.locked and not inv.transactions.locked,"locks released after callbacks")
	actor.position.x=3.01
	check(not ExternalInventoryTransfer.transfer_ammo(access,player_ammo,reverse),"fresh distance check prevents stale commit")
	actor.position.x=0
	owner.allowed=false
	check(not ExternalInventoryTransfer.transfer_ammo(access,player_ammo,reverse),"fresh LOS/access failure prevents commit")
	owner.allowed=true
	inv.transactions.locked=true
	check(not ExternalInventoryTransfer.transfer_ammo(access,player_ammo,reverse),"reload lock forbids mutation")
	inv.transactions.locked=false
	access.close()
	check(not ExternalInventoryTransfer.transfer_ammo(access,player_ammo,reverse),"closed session unusable")
	check(ext.world_items.is_empty() and inv.transactions.world_items.is_empty(),"all transfers contain no WORLD intermediate")
	await full_rollback(actor,owner,inv)
	owner.free()
	actor.free()

func full_rollback(actor: Node3D, owner: Node3D, inv: PlayerInventoryComponent) -> void:
	var ext: InventoryTransactionService=owner.runtime.transactions
	var grid: InventoryGrid=owner.runtime.inventory_grid
	for y in range(6):
		for x in range(8):
			if grid.get_item_at_cell(Vector2i(x,y))==null: ext.place(item(1,1),grid,Vector2i(x,y))
	var access:=LootContainerAccess.new(actor,owner,inv.transactions)
	var source:=InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres"),1,17)
	inv.transactions.place(source,inv.secure.grid,Vector2i(2,0))
	var initial: Array[AmmoData]=source.runtime_state.rounds.duplicate()
	for cell in [Vector2i.ZERO,Vector2i(7,5),Vector2i(-1,0),Vector2i(8,6)]:
		check(not ExternalInventoryTransfer.transfer(access,source,ext,{"kind":&"grid","grid":grid,"position":cell}),"full crate bounds/overlap rejects "+str(cell))
		check(source.get_owner_registry()==inv.transactions and inv.secure.grid.get_placement(source).position==Vector2i(2,0) and source.runtime_state.rounds==initial,"failed transfer all original source state intact "+str(cell))
	var foreign_actor:=Node3D.new()
	root.add_child(foreign_actor)
	var wrong:=LootContainerAccess.new(foreign_actor,owner,inv.transactions)
	check(not wrong.is_valid(),"access actor must own supplied player registry")
	foreign_actor.free()
	var invalid_owner:=Node3D.new()
	root.add_child(invalid_owner)
	var invalid:=LootContainerAccess.new(actor,invalid_owner,inv.transactions)
	check(not invalid.is_valid(),"non-external owner cannot create access")
	invalid_owner.free()

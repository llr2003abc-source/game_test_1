class_name LootContainerFactory
extends RefCounted

static func create(identity: StringName, title: String, variant: int) -> LootContainerRuntime:
	var runtime:=LootContainerRuntime.new(identity,title)
	var ammo: ItemDefinition=load("res://data/items/weapon1_level2_ammo_item.tres")
	var magazine: ItemDefinition=load("res://data/items/magazine_1_item.tres")
	var grid:=runtime.inventory_grid
	if variant==0:
		grid.place_item(InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres"),1,17),Vector2i.ZERO)
		grid.place_item(InventoryItemInstance.new(ammo,40),Vector2i(5,0))
		grid.place_item(InventoryItemInstance.new(ammo,25),Vector2i(6,0))
		grid.place_item(InventoryItemFactory.create(magazine,1,30),Vector2i(5,1))
		grid.place_item(InventoryItemFactory.create(magazine,1,17),Vector2i(6,1))
	else:
		grid.place_item(InventoryItemInstance.new(ammo,55),Vector2i(1,3))
		grid.place_item(InventoryItemInstance.new(ammo,15),Vector2i(3,0))
		grid.place_item(InventoryItemFactory.create(magazine,1,12),Vector2i(0,1))
	runtime.transactions.register_external_container(runtime)
	return runtime

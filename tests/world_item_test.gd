extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	for path in ["res://scripts/items/world_item_factory.gd","res://scripts/inventory/inventory_item_factory.gd"]:
		check(FileAccess.file_exists(path),"required world factory: "+path)
	if failures==0:
		var factory: Variant=load("res://scripts/inventory/inventory_item_factory.gd")
		var world_factory: Variant=load("res://scripts/items/world_item_factory.gd")
		var inv:=PlayerInventoryComponent.new()
		var world:=Node3D.new()
		root.add_child(world)
		for definition_path in ["magazine_1_item","primary_weapon_1_item","rig_1","backpack_1","weapon1_level2_ammo_item"]:
			var definition: ItemDefinition=load("res://data/items/%s.tres"%definition_path)
			var original: InventoryItemInstance=factory.create(definition,60 if definition.category==ItemDefinition.Category.AMMO else 1,17)
			var runtime: RefCounted=original.runtime_state
			var dropped: Variant=world_factory.spawn(original,inv.transactions,world,Transform3D(Basis.IDENTITY,Vector3(1,1,0)))
			check(is_instance_valid(dropped) and dropped is Node3D and not dropped is PhysicsBody3D,"generic nonphysical world item: "+definition_path)
			check(dropped.item==original and dropped.item.runtime_state==runtime,"world keeps original item/runtime: "+definition_path)
			check(dropped.has_node("VisualRoot") and dropped.get_node("VisualRoot").get_child_count()==1,"world has definition visual")
			check(dropped.get_node("Area3D").collision_layer==16 and dropped.get_node("Area3D").collision_mask==0,"dedicated nonblocking interaction layer")
			check(not(Firearm.HITSCAN_COLLISION_MASK & 16),"weapon mask excludes loot")
			check(dropped.find_children("*","NavigationObstacle3D",true,false).is_empty(),"loot never creates navigation obstacle")
			check(inv.transactions.get_location(original).kind==&"world","factory commits WORLD ownership")
			if runtime is MagazineInstance:
				check(runtime.get_round_count()==17 and dropped.get_interaction_prompt(null).contains("17 / 30"),"world magazine reads real17rounds")
			elif runtime is WeaponRuntime:
				check(runtime.get_magazine_round_count()==17 and runtime.chambered_round!=null,"independent world weapon CH1 MAG17")
				check(dropped.get_interaction_prompt(null).contains("CH 1 / MAG 17"),"world weapon prompt reads real runtime")
			elif definition.category==ItemDefinition.Category.AMMO:
				check(dropped.get_interaction_prompt(null).contains("x60"),"ammo prompt reads true stack")
		var first: InventoryItemInstance=factory.create(load("res://data/items/magazine_1_item.tres"))
		var second: InventoryItemInstance=factory.create(first.definition)
		check(first!=second and first.runtime_state!=second.runtime_state,"factories create independent actual instances")
		check(first.runtime_state.get_round_count()==30,"default magazine is full")
		check(factory.create(first.definition,2)==null,"invalid nonstack quantity rejected")
		world.queue_free()
		await process_frame
		inv.free()
	print("WORLD_ITEM_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

extends "res://tests/inventory_grid_test.gd"

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/items/world_loot_spawn_point.gd"),"deterministic loot spawn point exists")
	check(FileAccess.file_exists("res://scenes/levels/world_loot_test_area.tscn"),"world loot test area exists")
	if failures==0: await _test_level()
	print("WORLD_LOOT_GAMEPLAY_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

func key_press(code: Key) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=true
	root.push_input(event)
	event=event.duplicate()
	event.pressed=false
	root.push_input(event)

func aim_at(player: Node3D, world_item: DroppedItem) -> void:
	player.global_position=world_item.global_position+Vector3(0,-0.16,1.2)
	player.camera.look_at(world_item.global_position,Vector3.UP)
	await physics_frame
	await physics_frame

func _test_level() -> void:
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	var player: Variant=level.get_node("Player")
	player.set_physics_process(false)
	player.firearm.set_physics_process(false)
	var inv: PlayerInventoryComponent=player.inventory
	var area: Node3D=level.get_node("WorldLootTestArea")
	check(inv.transactions.world_items.is_empty(),"isolated legacy fixture has unchanged default loadout")
	var worlds: Array[DroppedItem]=area.spawn_loot()
	check(worlds.size()==6 and inv.transactions.world_items.size()==6,"six deterministic loot objects spawned")
	check(area.spawn_loot().is_empty(),"spawn points never respawn picked or existing loot automatically")
	check(worlds[0].item.stack_count==60,"test area ammo60")
	check(worlds[1].item.runtime_state.get_round_count()==30,"test area mag30")
	check(worlds[2].item.runtime_state.get_round_count()==17,"test area mag17")
	var world_runtime: WeaponRuntime=worlds[3].item.runtime_state
	check(world_runtime.chambered_round!=null and world_runtime.get_magazine_round_count()==17 and world_runtime.selected_fire_mode==WeaponData.FireMode.AUTO,"test weapon CH1 MAG17 AUTO")
	check(world_runtime!=player.firearm.weapon_runtime and world_runtime.loaded_magazine!=player.firearm.loaded_magazine,"world weapon independent from equipped gun")
	check(worlds[4].item.runtime_state is BackpackContainerRuntime and worlds[5].item.runtime_state is RigContainerRuntime,"test area bag/rig are runtime containers")
	for node in worlds:
		check(node.get_node("Area3D").collision_layer==16 and node.get_node("Area3D").collision_mask==0,"loot uses interaction-only area")
		check(not node.is_class("PhysicsBody3D") and node.find_children("*","NavigationObstacle3D",true,false).is_empty(),"loot cannot block movement or navigation")
	var interactor: PlayerInteractor=player.get_node("PlayerInteractor")
	var original_mag: InventoryItemInstance=worlds[2].item
	# The wall hides mag17 from the south, while its north side is accessible.
	player.global_position=Vector3(-5,0,8)
	player.camera.look_at(worlds[2].global_position,Vector3.UP)
	await physics_frame
	await physics_frame
	check(interactor.update_target()==null,"actual loot test wall blocks pickup ray")
	key_press(KEY_F)
	await physics_frame
	check(inv.transactions.owns_world_item(original_mag,worlds[2]),"F through wall never transfers loot")
	player.global_position=Vector3(-5,0,4.8)
	player.camera.look_at(worlds[2].global_position,Vector3.UP)
	await physics_frame
	await physics_frame
	check(interactor.update_target()==worlds[2],"same mag17 accessible from unblocked side")
	check(player.get_node("InteractionPrompt").label.text.contains("17 / 30"),"actual label reads magazine runtime17")
	var initial_spares: int=inv.reload_coordinator.get_available_magazine_count()
	key_press(KEY_F)
	await physics_frame
	await physics_frame
	check(inv.transactions.get_location(original_mag).kind==&"grid" and original_mag.runtime_state.get_round_count()==17,"real viewport F picks original17")
	check(inv.reload_coordinator.get_available_magazine_count()==initial_spares+1,"world pickup refreshes real spare count")
	check(level.get_node("CanvasLayer/AmmoLabel").text.contains("SPARE MAGS: 3"),"ammo HUD receives spare update")
	var ammo: InventoryItemInstance=worlds[0].item
	await aim_at(player,worlds[0])
	check(interactor.update_target()==worlds[0],"actual floor loot target found")
	player.set_inventory_open(true)
	key_press(KEY_F)
	await physics_frame
	check(inv.transactions.get_location(ammo).kind==&"world" and not player.get_node("InteractionPrompt").label.visible,"inventory open blocks F and prompt")
	player.set_inventory_open(false)
	await physics_frame
	inv.transactions.locked=true
	key_press(KEY_F)
	await physics_frame
	check(inv.transactions.get_location(ammo).kind==&"world" and worlds[0].item.stack_count==60,"inventory lock keeps real world stack")
	inv.transactions.locked=false
	key_press(KEY_F)
	await physics_frame
	await physics_frame
	check(inv.transactions.get_location(ammo).kind==&"grid" and ammo.stack_count==60,"F ammo pickup keeps original stack60")
	for i in range(5): key_press(KEY_F)
	await physics_frame
	check(inv.get_equipped_backpack().grid.placements.filter(func(p): return p.item==ammo).size()==1,"viewport F spam cannot duplicate original")
	inv.transactions.equip(InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres")),1)
	var weapon: InventoryItemInstance=worlds[3].item
	var active: WeaponRuntime=player.firearm.weapon_runtime
	await aim_at(player,worlds[3])
	check(interactor.update_target()==worlds[3] and player.get_node("InteractionPrompt").label.text.contains("CH 1 / MAG 17"),"world weapon real chamber/magazine prompt")
	key_press(KEY_F)
	await physics_frame
	await physics_frame
	check(inv.transactions.get_location(weapon).kind==&"grid" and weapon.runtime_state==world_runtime,"occupied weapon slot places same world gun in bag")
	check(player.firearm.weapon_runtime==active and world_runtime.get_magazine_round_count()==17,"pickup does not replace active firearm or refill world gun")
	var origin: Vector3=worlds[1].global_position+Vector3(0,0,0.5)
	var query:=PhysicsRayQueryParameters3D.create(origin,origin+Vector3.FORWARD,Firearm.HITSCAN_COLLISION_MASK)
	query.collide_with_areas=true
	check(level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"hitscan ignores actual loot area")
	var projectile:=BallisticProjectile.new()
	query.collision_mask=projectile.collision_mask
	projectile.free()
	check(level.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"projectile collision query ignores actual loot area")
	check((player.collision_mask & 16)==0,"player collision mask ignores interaction layer")
	player.global_position=Vector3(-7,0,6.5)
	player.velocity=Vector3(0,0,-1.5)
	for i in range(40):
		await physics_frame
		player.move_and_slide()
	check(player.global_position.z<5.8,"actual CharacterBody passes through world magazine")
	check(level.has_node("Target_01") and level.has_node("Target_02") and level.has_node("Target_03") and level.has_node("DamageableTarget"),"existing combat targets preserved")
	level.queue_free()
	await process_frame

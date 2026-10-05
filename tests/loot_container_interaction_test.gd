extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	check(FileAccess.file_exists("res://scenes/containers/loot_container.tscn"),"physical searchable crate scene exists")
	var resolver:=InteractionInputResolver.new()
	check(resolver.get("hold_enabled")!=null,"interaction capability excludes crate hold-management")
	if failures==0: await exercise()
	print("LOOT_CONTAINER_INTERACTION_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

func exercise() -> void:
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	root.grab_focus()
	var player: Variant=level.get_node("Player")
	player.set_physics_process(false)
	player.firearm.set_physics_process(false)
	var crate: LootContainer=level.get_node("LootCrateA")
	var ui: InventoryUI=player.get_node("InventoryUI")
	var interactor: PlayerInteractor=player.get_node("PlayerInteractor")
	await physics_frame
	check(crate.runtime.transactions.get_external_owner()==crate.runtime and crate.runtime.transactions.items.size()==6,"crate already registered before UI including loaded mag")
	check(crate.runtime.inventory_grid.placements.size()==5 and crate.get("item")==null,"crate not pickup InventoryItem; contents not WORLD nodes")
	check(crate.get_node("PhysicsBody").collision_layer==1 and crate.get_node("InteractionArea").collision_layer==16,"separate world and interaction layers")
	for distance in [2.49,2.5,2.51]:
		player.global_position=crate.get_interaction_position()+Vector3(0,-1.65,distance)
		player.camera.global_position=crate.get_interaction_position()+Vector3(0,0,distance)
		player.camera.look_at(crate.get_interaction_position())
		await physics_frame
		check(crate.can_interact(player)==(distance<=2.5),"open center distance boundary %.2f"%distance)
		check((interactor.update_target()==crate)==(distance<=2.5),"actual interaction ray boundary %.2f"%distance)
	player.global_position=crate.global_position+Vector3(0,0,2)
	player.camera.global_position=player.global_position+Vector3.UP*1.65
	player.camera.look_at(crate.get_interaction_position())
	await physics_frame
	check(interactor.update_target()==crate,"area resolved as searchable owner")
	check(crate.get_interaction_prompt(player).contains("Search") and not crate.supports_hold_manage(),"Search capability has no Vicinity hold action")
	var resolver:=InteractionInputResolver.new()
	resolver.press(crate,false,false)
	check(resolver.tick(1.0)==null and resolver.pending,"long crate hold cannot emit manage")
	check(resolver.release()==crate,"long crate F release still searches once")
	for duration in [0.08,0.5]:
		interactor.update_target()
		var world_count: int=player.inventory.transactions.world_items.size()
		var down:=InputEventKey.new()
		down.keycode=KEY_F
		down.physical_keycode=KEY_F
		down.pressed=true
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		root.push_input(down)
		await create_timer(duration).timeout
		down.pressed=false
		root.push_input(down)
		await create_timer(0.06).timeout
		await process_frame
		await physics_frame
		check(ui.visible and ui.mode==InventoryUI.Mode.CONTAINER_LOOT,"real F searches crate %.2fs"%duration)
		check(not ui.vicinity_mode and player.inventory.transactions.world_items.size()==world_count,"crate F preserves WORLD registry and never opens Nearby")
		ui.toggle()
		await physics_frame
	await physics_frame
	crate.get_node("InteractionArea").collision_layer=0
	await physics_frame
	check(interactor.update_target()!=crate,"body cannot substitute disabled interaction area")
	crate.get_node("InteractionArea").collision_layer=16
	var wall:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(3,4,0.1)
	shape.shape=box
	wall.add_child(shape)
	level.add_child(wall)
	wall.global_position=crate.global_position+Vector3(0,1,1)
	await physics_frame
	check(not crate.can_interact(player) and not crate.can_access(player) and interactor.update_target()!=crate,"wall blocks open and continuing access")
	wall.queue_free()
	await physics_frame
	for distance in [2.99,3.0,3.01]:
		player.global_position=crate.global_position+Vector3(0,0,distance)
		player.camera.global_position=player.global_position+Vector3.UP*1.65
		check(crate.can_access(player)==(distance<=3.0),"actor access boundary %.2f"%distance)
	var query:=PhysicsRayQueryParameters3D.create(crate.global_position+Vector3(0,0.6,2),crate.global_position+Vector3(0,0.6,-2),1)
	query.exclude=[player.get_rid()]
	check(level.get_world_3d().direct_space_state.intersect_ray(query).get("collider")==crate.get_node("PhysicsBody"),"physical crate blocks hitscan/projectile WORLD ray")
	level.queue_free()
	await process_frame

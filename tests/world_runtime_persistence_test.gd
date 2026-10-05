extends "res://tests/inventory_grid_test.gd"

func inventory_fixture() -> PlayerInventoryComponent:
	var inv:=PlayerInventoryComponent.new()
	inv.transactions.equip(InventoryItemFactory.create(load("res://data/items/rig_1.tres")),4)
	inv.transactions.equip(InventoryItemFactory.create(load("res://data/items/backpack_1.tres")),5)
	inv.transactions.equip(InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres"),1,17),0)
	return inv

func _run() -> void:
	for mixed in [false,true]:
		var inv:=inventory_fixture()
		var world:=Node3D.new()
		root.add_child(world)
		var original: InventoryItemInstance=InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres"),1,17)
		var runtime: MagazineInstance=original.runtime_state
		var item_identity: int=original.get_instance_id()
		var runtime_identity: int=runtime.get_instance_id()
		var a:=AmmoData.new()
		var b:=AmmoData.new()
		var c:=AmmoData.new()
		if mixed:
			runtime.clear()
			for round_data in [a,b,a,c]: runtime.push_round(round_data)
		var initial: Array[AmmoData]=runtime.rounds.duplicate()
		var node: DroppedItem=WorldItemFactory.spawn(original,inv.transactions,world,Transform3D.IDENTITY)
		var coordinator:=ReloadCoordinator.new()
		coordinator.configure(inv)
		check(coordinator.get_available_magazine_count()==0,"world mag not counted as spare")
		check(inv.transactions.pickup_world_item(node).success,"world magazine auto pickup")
		check(inv.transactions.get_location(original).grid==inv.get_equipped_rig().grids[0],"world magazine enters first rig slot")
		check(original.get_instance_id()==item_identity and runtime.get_instance_id()==runtime_identity,"item and magazine instance IDs unchanged")
		check(runtime.rounds==initial,"pickup preserves every round reference/order")
		check(coordinator.get_available_magazine_count()==1,"rig pickup immediately updates spare count")
		check(coordinator.request_reload(),"picked-up world magazine remains compatible replacement")
		inv.equipment.get_active_item().runtime_state.tick(2.0)
		check(inv.equipment.get_active_item().runtime_state.loaded_magazine==runtime,"reload binds same recovered magazine")
		check(inv.transactions.get_location(original).kind==&"weapon_magazine","after reload magazine has one weapon ownership")
		check(runtime.rounds==initial and runtime.get_round_count()==(4 if mixed else 17),"reload retains17 or mixed A B A C intact")
		world.queue_free()
		await process_frame
		coordinator.free()
		inv.free()
	await _test_weapons()
	await _test_containers()
	await _test_drop_reload()
	print("WORLD_RUNTIME_PERSISTENCE_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

func _test_drop_reload() -> void:
	var world:=Node3D.new()
	root.add_child(world)
	current_scene=world
	var player: Variant=load("res://scenes/player/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.firearm.set_physics_process(false)
	var inv: PlayerInventoryComponent=player.inventory
	var original: InventoryItemInstance=inv.find_runtime_item(player.firearm.loaded_magazine)
	while original.runtime_state.get_round_count()>17: original.runtime_state.pop_round()
	var initial: Array[AmmoData]=original.runtime_state.rounds.duplicate()
	check(inv.reload_coordinator.request_reload(WeaponRuntime.ReloadType.DROP),"actual drop reload requested")
	player.firearm.weapon_runtime.tick(2.0)
	var location: Dictionary=inv.transactions.get_location(original)
	var node: DroppedItem=location.node
	check(node.can_interact(player),"drop reload uses generic interactable world representation")
	check(node.global_position.distance_to(player.global_position)>0.6,"drop placed outside player body")
	check(node.interact(player).success,"drop-reload magazine can be F-interacted back into inventory")
	check(original.runtime_state.rounds==initial and original.runtime_state.get_round_count()==17,"recovered drop keeps same17round runtime")
	check(inv.transactions.get_location(original).kind==&"grid","recovered drop has one rig location")
	for grid in inv.get_equipped_rig().grids:
		for placement in grid.placements.duplicate():
			if placement.item!=original: inv.transactions.remove(placement.item)
	player.firearm.weapon_runtime.try_fire()
	check(inv.reload_coordinator.request_reload(),"recovered original can reload again")
	player.firearm.weapon_runtime.tick(2.0)
	check(player.firearm.loaded_magazine==original.runtime_state and original.runtime_state.get_round_count()==17,"same recovered instance becomes loaded magazine")
	world.queue_free()
	await process_frame

func _test_weapons() -> void:
	for scenario in ["empty","occupied","full"]:
		var inv:=inventory_fixture()
		var active: InventoryItemInstance=inv.equipment.get_active_item()
		if scenario=="empty": inv.transactions.remove(active)
		else: inv.transactions.equip(InventoryItemFactory.create(active.definition),1)
		if scenario=="full": inv.get_equipped_backpack().grid.place_item(item(5,5),Vector2i.ZERO)
		var world:=Node3D.new()
		root.add_child(world)
		var original: InventoryItemInstance=InventoryItemFactory.create(active.definition,1,17)
		var runtime: WeaponRuntime=original.runtime_state
		var chamber: AmmoData=runtime.chambered_round
		var loaded: MagazineInstance=runtime.loaded_magazine
		var initial: Array[AmmoData]=loaded.rounds.duplicate()
		check(runtime!=active.runtime_state and loaded!=active.runtime_state.loaded_magazine,"world weapon independent of player weapon")
		var node: DroppedItem=WorldItemFactory.spawn(original,inv.transactions,world,Transform3D.IDENTITY)
		var wrapper: InventoryItemInstance=inv.find_runtime_item(loaded)
		check(wrapper!=null and wrapper.runtime_state==loaded,"world weapon registers actual loaded magazine wrapper")
		var result: Dictionary=inv.transactions.pickup_world_item(node)
		check(result.success==(scenario!="full"),"weapon destination availability determines atomic success")
		check(original.runtime_state==runtime and runtime.chambered_round==chamber and runtime.loaded_magazine==loaded,"pickup preserves weapon/chamber/loaded refs")
		check(loaded.rounds==initial and loaded.get_round_count()==17 and runtime.selected_fire_mode==WeaponData.FireMode.AUTO,"weapon MAG17 AUTO preserved")
		if scenario=="empty":
			check(inv.equipment.get_active_item()==original,"no active weapon auto-equips and activates original")
		elif scenario=="occupied":
			check(inv.get_equipped_backpack().grid.get_placement(original)!=null and inv.equipment.get_active_item()==active,"occupied primary stores weapon without switching")
		else:
			check(inv.transactions.owns_world_item(original,node) and not node.is_queued_for_deletion(),"no weapon space retains world node")
		world.queue_free()
		await process_frame
		inv.free()
	# Actual Firearm binding uses the recovered runtime rather than initializing another.
	var world:=Node3D.new()
	root.add_child(world)
	current_scene=world
	var player: Variant=load("res://scenes/player/player.tscn").instantiate()
	world.add_child(player)
	player.set_physics_process(false)
	player.firearm.set_physics_process(false)
	var inv: PlayerInventoryComponent=player.inventory
	inv.transactions.remove(inv.equipment.get_active_item())
	var original: InventoryItemInstance=InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres"),1,17)
	var runtime: WeaponRuntime=original.runtime_state
	var node: DroppedItem=WorldItemFactory.spawn(original,inv.transactions,world,Transform3D.IDENTITY)
	check(inv.transactions.pickup_world_item(node).success and player.firearm.weapon_runtime==runtime,"actual Firearm binds same newly equipped weapon runtime")
	check(player.firearm.loaded_magazine==runtime.loaded_magazine and player.firearm.chambered_round==runtime.chambered_round,"actual firearm publishes preserved CH1 MAG17")
	world.queue_free()
	await process_frame

func _test_containers() -> void:
	for definition_name in ["rig_1","backpack_1"]:
		for occupied in [false,true]:
			var inv:=PlayerInventoryComponent.new()
			var original: InventoryItemInstance=InventoryItemFactory.create(load("res://data/items/%s.tres"%definition_name))
			var runtime: RefCounted=original.runtime_state
			var contents: InventoryGrid=runtime.grids[0] if runtime is RigContainerRuntime else runtime.grid
			var stored: InventoryItemInstance=InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres"),1,17)
			contents.place_item(stored,Vector2i.ZERO)
			var slot: int=4 if definition_name=="rig_1" else 5
			if occupied: inv.transactions.equip(InventoryItemFactory.create(original.definition),slot)
			var world:=Node3D.new()
			root.add_child(world)
			var node: DroppedItem=WorldItemFactory.spawn(original,inv.transactions,world,Transform3D.IDENTITY)
			check(inv.transactions.items.has(stored) and inv.find_runtime_item(stored.runtime_state)==stored,"pre-populated container registers actual content wrapper")
			var result: Dictionary=inv.transactions.pickup_world_item(node)
			check(result.success==not occupied,"container only equips into empty matching slot")
			check(original.runtime_state==runtime and contents.get_placement(stored)!=null and stored.runtime_state.get_round_count()==17,"container content and runtime survive pickup/failure")
			if occupied:
				check(inv.transactions.owns_world_item(original,node) and not node.is_queued_for_deletion(),"occupied slot leaves whole container in WORLD")
			else:
				check(inv.equipment.slots[slot]==original and contents.get_transactions()==inv.transactions,"original container/grid adopted by inventory")
				if slot==4:
					inv.transactions.equip(InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres"),1,17),0)
					var coordinator:=ReloadCoordinator.new()
					coordinator.configure(inv)
					check(coordinator.request_reload(),"pre-populated picked-up rig magazine usable for reload")
					inv.equipment.get_active_item().runtime_state.tick(2.0)
					check(inv.equipment.get_active_item().runtime_state.loaded_magazine==stored.runtime_state,"container child identity survives reload")
					coordinator.free()
			world.queue_free()
			await process_frame
			inv.free()
	var inv:=PlayerInventoryComponent.new()
	var rig: InventoryItemInstance=InventoryItemFactory.create(load("res://data/items/rig_1.tres"))
	var duplicate: InventoryItemInstance=InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres"))
	for i in range(2): rig.runtime_state.grids[i].place_item(duplicate,Vector2i.ZERO)
	var world:=Node3D.new()
	root.add_child(world)
	check(WorldItemFactory.spawn(rig,inv.transactions,world,Transform3D.IDENTITY)==null,"duplicate child ownership prevents world container registration")
	check(inv.transactions.items.is_empty() and inv.transactions.world_items.is_empty() and world.get_child_count()==0,"invalid container registration is atomic")
	check(rig.get_owner_registry()==null and duplicate.get_owner_registry()==null,"failed adoption leaves original owner handles untouched")
	world.queue_free()
	await process_frame
	inv.free()

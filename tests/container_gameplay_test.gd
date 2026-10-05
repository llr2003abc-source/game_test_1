extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	var probe:=InventoryUI.new()
	check(probe.has_method("open_container"),"search opens existing inventory UI")
	probe.free()
	if failures==0: await exercise()
	print("CONTAINER_GAMEPLAY_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

func exercise() -> void:
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	root.grab_focus()
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	var inv: PlayerInventoryComponent=p.inventory
	var ui: InventoryUI=p.get_node("InventoryUI")
	var crate: LootContainer=level.get_node("LootCrateA")
	var other: LootContainer=level.get_node("LootCrateB")
	p.global_position=crate.global_position+Vector3(0,0,1.8)
	p.camera.look_at(crate.get_interaction_position())
	await physics_frame
	check(ui.open_container(crate),"gameplay open A")
	var grid:=crate.runtime.inventory_grid
	var ext:=crate.runtime.transactions
	var b_layout: Array=[]
	for place in other.runtime.inventory_grid.placements: b_layout.append([place.item,place.position,place.item.stack_count])
	var original_mag:=grid.get_item_at_cell(Vector2i(6,1))
	var rounds: Array[AmmoData]=original_mag.runtime_state.rounds.duplicate()
	var rig:=inv.get_equipped_rig()
	for i in [0,1]:
		var old: InventoryItemInstance=rig.grids[i].placements[0].item
		check(ExternalInventoryTransfer.transfer(ui.container_access,old,ext,{"kind":&"grid","grid":grid,"position":Vector2i(i,3)}),"move Rig spare to crate")
	check(inv.reload_coordinator.get_available_magazine_count()==0,"external mags never considered spare")
	check(ExternalInventoryTransfer.transfer(ui.container_access,original_mag,inv.transactions,{"kind":&"grid","grid":rig.grids[0],"position":Vector2i.ZERO}),"C MAG17->Rig original")
	check(inv.reload_coordinator.get_available_magazine_count()==1,"MAG17 candidate immediately registered")
	ui.toggle()
	check(inv.reload_coordinator.request_reload(),"normal R coordinator accepts recovered17")
	p.firearm.weapon_runtime.tick(2.0)
	check(p.firearm.loaded_magazine==original_mag.runtime_state and original_mag.runtime_state.rounds==rounds,"R retains actual17round magazine")
	check(inv.transactions.get_location(original_mag).kind==&"weapon_magazine","loaded wrapper has exactly weapon ownership")
	check(ui.open_container(crate),"reopen A after reload")
	var gun:=grid.get_item_at_cell(Vector2i.ZERO)
	var state: WeaponRuntime=gun.runtime_state
	var loaded_wrapper:=ext.find_runtime_item(state.loaded_magazine)
	var active: WeaponRuntime=p.firearm.weapon_runtime
	check(ExternalInventoryTransfer.transfer(ui.container_access,gun,inv.transactions,{"kind":&"equipment","slot":1}),"crate gun->Slot2 original")
	check(p.firearm.weapon_runtime==active and state.get_magazine_round_count()==17,"Slot2 transfer does not switch/reset")
	ui.toggle()
	check(inv.equipment.select_weapon_slot(1),"slot2 selection allowed")
	check(p.firearm.weapon_runtime==state,"Firearm binds transferred runtime")
	check(state.try_fire()!=null and state.get_magazine_round_count()==16,"Slot2 fire cycles actual CH1/MAG17")
	check(ui.open_container(crate),"reopen to store active gun")
	check(ExternalInventoryTransfer.transfer(ui.container_access,gun,ext,{"kind":&"grid","grid":grid,"position":Vector2i.ZERO}),"active gun->crate")
	check(p.firearm.weapon_runtime==null and not p.firearm.get_node("WeaponMesh").visible,"active gun unequips/unbinds without cloning")
	check(ext.find_runtime_item(state.loaded_magazine)==loaded_wrapper and ext.get_location(loaded_wrapper).kind==&"weapon_magazine","loaded wrapper identity moves with gun")
	check(ExternalInventoryTransfer.transfer(ui.container_access,gun,inv.transactions,{"kind":&"equipment","slot":1}),"return to empty current slot")
	check(p.firearm.weapon_runtime==state and state.get_magazine_round_count()==16,"return activates original with spent ammo intact")
	var b_after: Array=[]
	for place in other.runtime.inventory_grid.placements: b_after.append([place.item,place.position,place.item.stack_count])
	check(b_layout==b_after and other.runtime.transactions!=ext,"A/B independent layouts/counts/registries")
	var portable:=inv.equipment.slots[4] as InventoryItemInstance
	var contents: InventoryGrid=portable.runtime_state.grids.filter(func(g): return not g.placements.is_empty())[0]
	var content_item: InventoryItemInstance=contents.placements[0].item
	check(ExternalInventoryTransfer.transfer(ui.container_access,portable,ext,{"kind":&"grid","grid":grid,"position":Vector2i(3,3)}),"populated Rig equipment->crate whole contents")
	check(inv.get_equipped_rig()==null and contents.get_transactions()==ext and content_item.get_owner_registry()==ext,"Rig contents no longer player-owned/reload candidates")
	check(inv.reload_coordinator.get_available_magazine_count()==0,"no equipped Rig gives0spares")
	check(ExternalInventoryTransfer.transfer(ui.container_access,portable,inv.transactions,{"kind":&"equipment","slot":4}),"populated crate Rig->empty equipment")
	check(inv.get_equipped_rig()==portable.runtime_state and contents.get_placement(content_item)!=null,"Rig equipped preserves children")
	check(inv.reload_coordinator.get_available_magazine_count()==1,"restored Rig child eligible immediately")
	check(ext.world_items.is_empty() and inv.transactions.world_items.is_empty(),"all gameplay transactions zero WORLD nodes")
	await blocked_input(p,ui,crate)
	level.queue_free()
	await process_frame

func blocked_input(p: Node3D, ui: InventoryUI, crate: LootContainer) -> void:
	p.set_physics_process(true)
	p.firearm.set_physics_process(true)
	var state: WeaponRuntime=p.firearm.weapon_runtime
	var count: int=state.get_magazine_round_count()
	var basis: Basis=p.global_basis
	var head_rotation: Vector3=p.head.rotation
	var slot: int=p.inventory.equipment.active_weapon_slot
	for action in ["fire","aim","weapon_primary","reload","interact","move_forward"]: Input.action_press(action)
	var motion:=InputEventMouseMotion.new()
	motion.screen_relative=Vector2(80,50)
	root.push_input(motion)
	await create_timer(0.25).timeout
	check(state.get_magazine_round_count()==count,"container UI suppresses true gameplay Fire ticks")
	check(not p.firearm.is_aiming and p.camera.fov>74,"container UI suppresses ADS")
	check(p.global_basis==basis and p.head.rotation==head_rotation,"container UI blocks mouse look")
	check(p.inventory.equipment.active_weapon_slot==slot,"container UI blocks weapon slot input")
	check(not p.inventory.transactions.locked and state.state!=WeaponRuntime.State.RELOADING,"container UI gameplay reload input disabled")
	check(ui.visible and ui.current_open_container==crate,"F cannot open another inventory while container mode active")
	check(Vector2(p.velocity.x,p.velocity.z).is_zero_approx(),"existing inventory WASD blocking preserved")
	check(not p.get_tree().paused,"UI does not pause SceneTree")
	for action in ["fire","aim","weapon_primary","reload","interact","move_forward"]: Input.action_release(action)
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)

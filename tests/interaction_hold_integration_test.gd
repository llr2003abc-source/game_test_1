extends "res://tests/inventory_grid_test.gd"

var p: Variant
var interactor: PlayerInteractor
var ui: InventoryUI
var inv: PlayerInventoryComponent
var world: Node3D
var managed: Array[int]=[0]
var picked: Array[int]=[0]

func key(pressed: bool, echo: bool = false) -> InputEventKey:
	var event:=InputEventKey.new()
	event.keycode=KEY_F
	event.physical_keycode=KEY_F
	event.pressed=pressed
	event.echo=echo
	return event

func make_target() -> DroppedItem:
	var node:=WorldItemFactory.spawn(InventoryItemFactory.create(load("res://data/items/weapon1_level2_ammo_item.tres"),1),inv.transactions,world,Transform3D(Basis.IDENTITY,p.camera.global_position+Vector3.FORWARD*2))
	await physics_frame
	await physics_frame
	interactor.update_target()
	return node

func _run() -> void:
	world=Node3D.new()
	root.add_child(world)
	current_scene=world
	p=load("res://scenes/player/player.tscn").instantiate()
	world.add_child(p)
	root.grab_focus()
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	inv=p.inventory
	ui=p.get_node("InventoryUI")
	interactor=p.get_node("PlayerInteractor")
	interactor.set_physics_process(false)
	interactor.manage_requested.connect(func(_target): managed[0]+=1)
	interactor.interaction_performed.connect(func(_result): picked[0]+=1)
	for duration in [0.0,0.34,0.35,0.5]:
		var node: DroppedItem=await make_target()
		var original: InventoryItemInstance=node.item
		var before_manage: int=managed[0]
		var before_pick: int=picked[0]
		interactor._unhandled_input(key(true))
		interactor._physics_process(duration)
		interactor._input(key(false))
		interactor._unhandled_input(key(false))
		interactor._physics_process(0.0)
		check(picked[0]-before_pick==int(duration<0.35),"actual interactor short exactly once duration "+str(duration))
		check(managed[0]-before_manage==int(duration>=0.35),"actual interactor hold threshold duration "+str(duration))
		check((inv.transactions.get_location(original).kind==&"world")==bool(duration>=0.35),"hold versus tap ownership "+str(duration))
		interactor._physics_process(0.5)
		check(managed[0]-before_manage==int(duration>=0.35),"hold cannot reopen repeatedly")
		if ui.visible: ui.toggle()
		if is_instance_valid(node): node.queue_free()
		await physics_frame
	for reason in ["target_change","range","deleted","ownership","other_ui","mouse_visible","reload_lock","escape"]:
		var node: DroppedItem=await make_target()
		var before_manage: int=managed[0]
		var before_pick: int=picked[0]
		interactor._unhandled_input(key(true))
		interactor._physics_process(0.1)
		check(p.get_node("InteractionPrompt").label.text.contains("HOLD F"),"hold progress before "+reason)
		var second: DroppedItem
		match reason:
			"target_change": second=await make_target(); second.position+=Vector3.BACK*0.5
			"range": node.position+=Vector3.FORWARD*3
			"deleted": node.queue_free()
			"ownership": inv.transactions.pickup_world_item(node)
			"other_ui": ui.toggle()
			"mouse_visible": Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
			"reload_lock": inv.transactions.locked=true
			"escape":
				var escape:=InputEventKey.new()
				escape.keycode=KEY_ESCAPE
				escape.pressed=true
				interactor._input(escape)
		await physics_frame
		await physics_frame
		interactor._physics_process(0.4)
		interactor._input(key(false))
		interactor._physics_process(0.0)
		check(managed[0]==before_manage and picked[0]==before_pick,"actual cancel never holds/taps after "+reason)
		check(not interactor.input_resolver.pending,"pending cleared after "+reason)
		inv.transactions.locked=false
		if ui.visible: ui.toggle()
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
		if is_instance_valid(node): node.queue_free()
		if is_instance_valid(second): second.queue_free()
		await physics_frame
	var node: DroppedItem=await make_target()
	var before_manage: int=managed[0]
	var before_pick: int=picked[0]
	interactor._unhandled_input(key(true,true))
	interactor._physics_process(0.5)
	interactor._input(key(false))
	interactor._physics_process(0.0)
	check(managed[0]==before_manage and picked[0]==before_pick,"actual key echo alone cannot start interaction")
	inv.transactions.locked=true
	ui.open_vicinity(node)
	check(not ui.visible,"locked inventory cannot open editable vicinity")
	check(node.get_interaction_prompt(p).contains("当前无法整理"),"lock prompt actual state")
	world.queue_free()
	await process_frame
	print("INTERACTION_HOLD_INTEGRATION_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

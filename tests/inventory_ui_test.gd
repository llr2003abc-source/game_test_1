extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	check(FileAccess.file_exists("res://scenes/ui/inventory_ui.tscn"),"inventory UI scene exists")
	if failures==0:
		var level: Node=load("res://scenes/levels/test_level.tscn").instantiate()
		root.add_child(level)
		current_scene=level
		await process_frame
		var player: Variant=level.get_node("Player")
		var ui: Variant=player.get_node("InventoryUI")
		ui.toggle()
		check(ui.visible and player.inventory_open and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Tab-style open releases mouse")
		check(not paused,"inventory never pauses tree")
		await process_frame
		var first_grid: Variant=ui.views[0]
		var native_item: Variant=first_grid.grid.placements[0].item
		first_grid.force_drag(ui.begin_drag(native_item),ui.create_preview(native_item))
		check(root.gui_is_dragging(),"native viewport drag started")
		var rotate_key:=InputEventKey.new()
		rotate_key.keycode=KEY_R
		rotate_key.physical_keycode=KEY_R
		rotate_key.pressed=true
		Input.parse_input_event(rotate_key)
		await process_frame
		check(ui.drag_data.rotated and not native_item.rotated,"native R rotates preview only")
		ui.toggle()
		check(not root.gui_is_dragging() and ui.drag_data.is_empty(),"Tab close cancels actual native drag")
		ui.toggle()
		await process_frame
		check(ui.equipment_views.size()==6 and ui.views.size()==12,"six equipment views and4rig+6pocket+backpack+secure grids")
		var inv: Variant=player.inventory
		var ammo: Variant=inv.get_equipped_backpack().grid.placements[0].item
		var mag: Variant=inv.get_equipped_rig().grids[0].placements[0].item
		for i in range(13): mag.runtime_state.pop_round()
		var target_position: Vector2=ui.views[0].get_global_rect().get_center()
		ui.views[10].force_drag(ui.begin_drag(ammo),ui.create_preview(ammo))
		Input.warp_mouse(target_position)
		var motion:=InputEventMouseMotion.new()
		motion.position=target_position
		motion.global_position=target_position
		root.push_input(motion)
		await process_frame
		var release:=InputEventMouseButton.new()
		release.button_index=MOUSE_BUTTON_LEFT
		release.position=target_position
		release.global_position=target_position
		root.push_input(release)
		check(ammo.stack_count==47 and mag.runtime_state.get_round_count()==30,"native viewport ammo drop executes transaction")
		for i in range(13): mag.runtime_state.pop_round()
		ammo.stack_count=60
		var data: Dictionary=ui.begin_drag(ammo)
		check(ui.drop_on_grid(data,inv.get_equipped_rig().grids[0],Vector2i.ZERO),"UI ammo drop invokes loading transaction")
		check(ammo.stack_count==47 and mag.runtime_state.get_round_count()==30,"UI reflects actual47/30 quantities")
		check(ui.describe_item(ammo).split("\n")[1]=="x47","ammo quantity has visible separate line in1x1 cell")
		var weapon: Variant=inv.equipment.get_active_item()
		data=ui.begin_drag(weapon)
		ui.rotate_drag()
		check(data.rotated and not weapon.rotated,"drag rotation is preview only")
		check(not ui.drop_on_grid(data,inv.pockets[0],Vector2i.ZERO) and inv.equipment.get_active_item()==weapon,"invalid UI drop leaves original equipment")
		ui.finish_drag()
		data=ui.begin_drag(weapon)
		check(ui.drop_on_grid(data,inv.get_equipped_backpack().grid,Vector2i(0,1)),"UI weapon to backpack")
		check(player.firearm.weapon_runtime==null,"UI unequip disables weapon")
		check(ui.drop_on_equipment(data,0) and player.firearm.weapon_runtime==weapon.runtime_state,"UI re-equip uses original runtime")
		player.reload_input_resolver.press()
		ui.toggle()
		ui.toggle()
		check(not player.reload_input_resolver.pending,"opening cancels pending R")
		var before_count: int=player.firearm.weapon_runtime.get_magazine_round_count()
		Input.action_press("fire")
		Input.action_press("aim")
		Input.action_press("reload")
		player._physics_process(0.1)
		check(not player.firearm.is_aiming and not player.firearm._trigger_held and not player.reload_input_resolver.pending,"UI blocks fire ADS reload")
		check(player.firearm.weapon_runtime.get_magazine_round_count()==before_count,"UI interaction consumes no ammo")
		for action in ["fire","aim","reload"]: Input.action_release(action)
		inv.transactions.locked=true
		check(not ui.drop_on_grid(ui.begin_drag(ammo),inv.pockets[0],Vector2i.ZERO),"UI obeys gameplay reload lock")
		inv.transactions.locked=false
		ui.toggle()
		check(not ui.visible and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"close captures mouse")
		level.queue_free()
		await process_frame
	print("INVENTORY_UI_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

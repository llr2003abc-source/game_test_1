extends "res://tests/inventory_grid_test.gd"
func _run() -> void:
	check(FileAccess.file_exists("res://scenes/items/dropped_item.tscn"),"minimal dropped scene exists")
	if failures==0:
		var level: Node=load("res://scenes/levels/test_level.tscn").instantiate()
		root.add_child(level)
		current_scene=level
		var inv: Variant=level.get_node("Player/PlayerInventory")
		var f: Variant=inv.firearm
		f.set_physics_process(false)
		var original: Variant=inv.find_runtime_item(f.loaded_magazine)
		var a:=AmmoData.new()
		var b:=AmmoData.new()
		var c:=AmmoData.new()
		original.runtime_state.clear()
		for round_data in [a,b,a,c]: original.runtime_state.push_round(round_data)
		check(inv.reload_coordinator.request_reload(WeaponRuntime.ReloadType.DROP),"real drop reload begins")
		f.weapon_runtime.tick(2.0)
		var location: Dictionary=inv.transactions.get_location(original)
		check(location.kind==&"world" and is_instance_valid(location.node),"completion creates one world item")
		if location.node!=null:
			var dropped: Variant=location.node
			check(dropped.item==original and dropped.item.runtime_state==original.runtime_state,"world retains original wrapper/runtime")
			check(dropped.item.runtime_state.rounds==[a,b,a,c],"mixed A B A C order unchanged")
			check(dropped.get_node("Area3D").collision_layer==16 and dropped.get_node("Area3D").collision_mask==0,"interaction-only area mask")
			check(not (Firearm.HITSCAN_COLLISION_MASK & dropped.get_node("Area3D").collision_layer),"hitscan cannot collide with drop")
			check(not inv.transactions.move(original,inv.get_equipped_backpack().grid,Vector2i(1,0)),"world transfer rejected until pickup implemented")
			check(inv.transactions.get_location(original).kind==&"world" and dropped.item==original,"rejected pickup leaves one original world owner")
		check(inv.transactions.world_items.size()==1,"one drop per completed reload")
		f.weapon_runtime.finish_reload()
		check(inv.transactions.world_items.size()==1,"duplicate finish cannot duplicate drop")
		level.queue_free()
		await process_frame
	print("DROPPED_MAGAZINE_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

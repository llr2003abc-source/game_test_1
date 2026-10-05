extends "res://tests/inventory_grid_test.gd"

func _run() -> void:
	check(FileAccess.file_exists("res://scripts/inventory/vicinity_loot_query.gd"),"nearby query exists")
	check(FileAccess.file_exists("res://scripts/ui/vicinity_loot_layout.gd"),"nearby virtual layout exists")
	if failures==0:
		var world:=Node3D.new()
		root.add_child(world)
		var p: Variant=load("res://scenes/player/player.tscn").instantiate()
		world.add_child(p)
		p.set_physics_process(false)
		p.firearm.set_physics_process(false)
		var inv: PlayerInventoryComponent=p.inventory
		var source:=InventoryItemFactory.create(load("res://data/items/magazine_1_item.tres"),1,17)
		var node:=WorldItemFactory.spawn(source,inv.transactions,world,Transform3D.IDENTITY)
		var query: Script=load("res://scripts/inventory/vicinity_loot_query.gd")
		for distance in [2.9,3.0,3.01]:
			node.global_position=Vector3(0,0,-distance)
			await physics_frame
			await physics_frame
			check(query.find_visible(p,inv.transactions,3.0).has(node)==(distance<=3.0),"vicinity inclusive3m: "+str(distance))
		var wall:=StaticBody3D.new()
		var collision:=CollisionShape3D.new()
		var shape:=BoxShape3D.new()
		shape.size=Vector3(2,3,0.2)
		collision.shape=shape
		wall.add_child(collision)
		world.add_child(wall)
		wall.position=Vector3(0,1,-1)
		node.position=Vector3(0,0,-2)
		await physics_frame
		await physics_frame
		check(query.find_visible(p,inv.transactions,3.0).is_empty(),"nearby excludes world loot behind wall")
		wall.queue_free()
		await physics_frame
		await physics_frame
		var nodes: Array[DroppedItem]=[node]
		for path in ["primary_weapon_1_item","weapon1_level2_ammo_item","backpack_1"]:
			var original:=InventoryItemFactory.create(load("res://data/items/%s.tres"%path))
			nodes.append(WorldItemFactory.spawn(original,inv.transactions,world,Transform3D.IDENTITY))
		var grid_count: int=inv.transactions.grids.size()
		var layout: Variant=load("res://scripts/ui/vicinity_loot_layout.gd").new()
		layout.rebuild(nodes,8)
		check(layout.placements.size()==4 and layout.width==8,"virtual first-fit covers every world item")
		for placement in layout.placements:
			check(inv.transactions.get_location(placement.item).kind==&"world","virtual grid never changes WORLD owner")
			check(placement.extent==placement.item.get_size() and placement.position.x+placement.extent.x<=layout.width,"real footprint fits virtual width")
			for other in layout.placements:
				if other==placement: continue
				check(not Rect2i(placement.position,placement.extent).intersects(Rect2i(other.position,other.extent)),"virtual placements never overlap")
		check(inv.transactions.grids.size()==grid_count,"no virtual grid registration")
		check(source.runtime_state.get_round_count()==17,"layout leaves runtime17 intact")
		nodes[1].item.rotated=true
		for i in range(24): nodes.append(WorldItemFactory.spawn(InventoryItemFactory.create(load("res://data/items/primary_weapon_1_item.tres")),inv.transactions,world,Transform3D.IDENTITY))
		layout.rebuild(nodes,8)
		check(layout.placements[1].extent==Vector2i(2,5),"virtual layout uses actual weapon rotation")
		check(layout.rows>6 and layout.placements.size()==28,"large vicinity list extends rows for vertical scrolling")
		var before: Array=layout.placements.duplicate(true)
		layout.rebuild(nodes,8)
		check(layout.placements==before,"stable first-fit layout deterministic")
		check(layout.get_at_cell(layout.placements[-1].position).item==nodes[-1].item,"virtual cell lookup reaches last scrolling item")
		check(inv.transactions.grids.size()==grid_count and nodes.all(func(n): return inv.transactions.owns_world_item(n.item,n)),"large virtual list still adds no owner/grids")
		world.queue_free()
		await process_frame
	print("VICINITY_LOOT_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

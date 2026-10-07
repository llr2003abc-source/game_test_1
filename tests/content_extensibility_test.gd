extends "res://tests/inventory_grid_test.gd"

class ImpactReceiver extends Area3D:
	var hits: Array[DamageInfo] = []
	func receive_hit(info: DamageInfo) -> void:
		hits.append(info)

func _run() -> void:
	for path in ["res://scripts/inventory/portable_container_data.gd","res://scripts/weapons/attachment_slot_definition.gd","res://scripts/weapons/attachment_data.gd","res://scripts/weapons/computed_weapon_stats.gd","res://scripts/weapons/weapon_stat_resolver.gd"]:
		check(FileAccess.file_exists(path),"content foundation available: "+path)
	if failures>0:
		finish()
		return
	var layout_type: Variant=load("res://scripts/inventory/portable_container_data.gd")
	var rig_layout: Variant=layout_type.new()
	rig_layout.definition_id=&"temporary_rig_layout"
	rig_layout.grid_sizes.assign([Vector2i(1,2),Vector2i(2,2),Vector2i(1,1)])
	var rig_def:=ItemDefinition.new()
	rig_def.item_id=&"temporary_rig"
	rig_def.category=ItemDefinition.Category.RIG
	rig_def.container_data=rig_layout
	var rig_a:=InventoryItemFactory.create(rig_def)
	var rig_b:=InventoryItemFactory.create(rig_def)
	check(rig_a!=null and rig_b!=null,"non-demo Rig definitions construct through shared factory")
	check(rig_a.runtime_state.grids.size()==3,"heterogeneous Rig creates three independent compartments")
	for i in range(3):
		check(rig_a.runtime_state.grids[i].size==[Vector2i(1,2),Vector2i(2,2),Vector2i(1,1)][i],"Rig geometry comes from each definition entry")
		check(rig_a.runtime_state.grids[i]!=rig_b.runtime_state.grids[i],"shared layout never shares runtime grids")
	var bag_layout: Variant=layout_type.new()
	bag_layout.definition_id=&"temporary_large_bag"
	bag_layout.grid_sizes.assign([Vector2i(7,6)])
	var bag_def:=ItemDefinition.new()
	bag_def.item_id=&"temporary_bag"
	bag_def.category=ItemDefinition.Category.BACKPACK
	bag_def.grid_size=Vector2i(5,6)
	bag_def.container_data=bag_layout
	var bag:=InventoryItemFactory.create(bag_def)
	check(bag.get_size()==Vector2i(5,6) and bag.runtime_state.grid.size==Vector2i(7,6),"external footprint and internal geometry remain independent")
	var inv:=PlayerInventoryComponent.new()
	check(inv.transactions.equip(rig_a,4) and inv.transactions.equip(bag,5),"new portable definitions work with existing equipment")
	check(inv.transactions.grids.has(rig_a.runtime_state.grids[1]) and inv.transactions.grids.has(bag.runtime_state.grid),"existing initial registration adopts new layout grids")
	var small_item: InventoryItemInstance=item(2,2)
	check(rig_a.runtime_state.grids[1].place_item(small_item,Vector2i.ZERO),"heterogeneous Rig accepts actual 2x2 geometry")
	check(rig_b.runtime_state.grids[1].placements.is_empty(),"another instance retains independent empty contents")
	for sizes in [[],[Vector2i.ZERO],[Vector2i(1,-1)]]:
		var invalid: Variant=rig_layout.duplicate()
		invalid.grid_sizes.assign(sizes)
		var bad_def: ItemDefinition=rig_def.duplicate()
		bad_def.container_data=invalid
		check(InventoryItemFactory.create(bad_def)==null,"invalid portable layout rejected without runtime publication")
	var bad_bag: ItemDefinition=bag_def.duplicate()
	bad_bag.container_data=rig_layout
	check(InventoryItemFactory.create(bad_bag)==null,"single-grid Backpack rejects multi-grid definition")
	var missing: ItemDefinition=rig_def.duplicate()
	missing.container_data=null
	check(InventoryItemFactory.create(missing)==null,"missing portable definition never silently uses demo geometry")
	check(rig_def.has_capability(&"portable_container") and not rig_def.has_capability(&"weapon"),"capability comes from category rather than content identity")
	inv.free()
	await weapon_smoke()
	finish()

func weapon_smoke() -> void:
	var ammo_a:=AmmoData.new()
	ammo_a.definition_id=&"temp_round_a"
	ammo_a.ammo_type_id=&"temp_caliber"
	ammo_a.flesh_damage=30.0
	ammo_a.armor_damage=30.0
	ammo_a.bullet_level=1
	ammo_a.round_weight_kg=0.01
	var ammo_b:=AmmoData.new()
	ammo_b.definition_id=&"temp_round_b"
	ammo_b.ammo_type_id=&"temp_caliber"
	ammo_b.flesh_damage=50.0
	ammo_b.armor_damage=70.0
	ammo_b.bullet_level=4
	ammo_b.round_weight_kg=0.015
	var mag_data:=MagazineData.new()
	mag_data.definition_id=&"temp_mag_6"
	mag_data.magazine_type_id=&"temp_mag_interface"
	mag_data.compatible_ammo_type_ids=[&"temp_caliber"]
	mag_data.capacity=6
	mag_data.empty_weight_kg=0.18
	mag_data.default_ammo=ammo_a
	var mag_def:=ItemDefinition.new()
	mag_def.item_id=&"temp_mag_item"
	mag_def.category=ItemDefinition.Category.MAGAZINE
	mag_def.grid_size=Vector2i(2,2)
	mag_def.magazine_data=mag_data
	var big_def: ItemDefinition=mag_def.duplicate()
	big_def.item_id=&"different_content_mag"
	big_def.grid_size=Vector2i(2,3)
	big_def.magazine_data=mag_data.duplicate()
	big_def.magazine_data.definition_id=&"temp_mag_9"
	big_def.magazine_data.capacity=9
	big_def.magazine_data.empty_weight_kg=0.25
	var weapon_data_b:=WeaponData.new()
	weapon_data_b.definition_id=&"temp_weapon_b"
	weapon_data_b.weapon_name="Not Weapon1"
	weapon_data_b.compatible_magazine_type_ids=[&"temp_mag_interface"]
	weapon_data_b.magazine_data=mag_data
	weapon_data_b.rounds_per_minute=200.0
	weapon_data_b.bare_weight_kg=3.5
	weapon_data_b.base_ergonomics=42.0
	weapon_data_b.hip_spread_degrees=0.0
	weapon_data_b.ads_spread_degrees=0.0
	var weapon_def:=ItemDefinition.new()
	weapon_def.item_id=&"totally_new_content"
	weapon_def.display_name="Temporary Test Weapon B"
	weapon_def.category=ItemDefinition.Category.PRIMARY_WEAPON
	weapon_def.weapon_data=weapon_data_b
	weapon_def.magazine_item_definition=mag_def
	weapon_def.grid_size=Vector2i(4,2)
	var first:=InventoryItemFactory.create(weapon_def)
	var second:=InventoryItemFactory.create(weapon_def)
	check(first!=null and first.runtime_state is WeaponRuntime,"new Weapon uses existing factory and runtime")
	check(first.runtime_state!=second.runtime_state and first.runtime_state.loaded_magazine!=second.runtime_state.loaded_magazine,"shared weapon definitions produce independent runtime and magazine identities")
	check(first.runtime_state.get_magazine_round_count()==5 and first.runtime_state.chambered_round==ammo_a,"new magazine capacity respects 5+1 initial conservation")
	check(weapon_def.has_capability(&"weapon") and mag_def.has_capability(&"magazine"),"new content exposes generic capabilities")
	var mag_small:=InventoryItemFactory.create(mag_def)
	var mag_big:=InventoryItemFactory.create(big_def)
	check(mag_small.runtime_state.get_round_count()==6 and mag_big.runtime_state.get_round_count()==9,"different capacities require no new Gameplay code")
	check(mag_small.get_size()==Vector2i(2,2) and mag_big.get_size()==Vector2i(2,3),"magazine external footprint remains definition-driven")
	var geometry:=InventoryGrid.new(2,3)
	check(geometry.can_place(mag_big,Vector2i.ZERO,false) and not geometry.can_place(mag_big,Vector2i(1,0),false),"actual can_place applies new magazine geometry")
	var level: Node3D=load("res://scenes/levels/test_level.tscn").instantiate()
	root.add_child(level)
	current_scene=level
	var p: Variant=level.get_node("Player")
	p.set_physics_process(false)
	p.firearm.set_physics_process(false)
	var weapon_a: WeaponRuntime=p.inventory.equipment.get_active_item().runtime_state
	var weapon_a_before: Array=[weapon_a.weapon_data,weapon_a.loaded_magazine,weapon_a.chambered_round,weapon_a.get_magazine_round_count(),weapon_a.fire_cooldown_remaining,weapon_a.selected_fire_mode]
	check(weapon_a.weapon_data!=weapon_data_b and weapon_a.weapon_data.rounds_per_minute!=weapon_data_b.rounds_per_minute,"different Weapon definitions retain independent base RPM on same executor")
	check(p.inventory.transactions.equip(first,1) and p.inventory.equipment.select_weapon_slot(1),"new Weapon binds existing shared Firearm execution path")
	var coord: ReloadCoordinator=p.inventory.reload_coordinator
	var test_rig_data: Variant=load("res://scripts/inventory/portable_container_data.gd").new()
	test_rig_data.grid_sizes.assign([Vector2i(2,3),Vector2i(2,3),Vector2i(2,3)])
	var test_rig_def: ItemDefinition=load("res://data/items/rig_1.tres").duplicate()
	test_rig_def.container_data=test_rig_data
	p.inventory.transactions.remove(p.inventory.equipment.slots[4])
	p.inventory.transactions.equip(InventoryItemFactory.create(test_rig_def),4)
	check(p.inventory.get_equipped_rig().grids[0].place_item(mag_big,Vector2i.ZERO),"new Rig supports larger compatible magazines")
	check(coord.select_reload_magazine()==mag_big,"Reload selects new magazine by shared interface, not name or capacity")
	var incompatible:=InventoryItemFactory.create(big_def)
	incompatible.runtime_state.definition=incompatible.runtime_state.definition.duplicate()
	incompatible.runtime_state.definition.magazine_type_id=&"wrong_interface"
	p.inventory.get_equipped_rig().grids[1].place_item(incompatible,Vector2i.ZERO)
	check(coord.get_available_magazine_count()==1,"wrong interface excluded even with same item Definition")
	var rt: WeaponRuntime=first.runtime_state
	rt.loaded_magazine.clear()
	rt.loaded_magazine.push_round(ammo_b)
	rt.loaded_magazine.push_round(ammo_a)
	var receiver:=ImpactReceiver.new()
	receiver.collision_layer=4
	receiver.collision_mask=0
	var collision:=CollisionShape3D.new()
	var sphere:=SphereShape3D.new()
	sphere.radius=0.8
	collision.shape=sphere
	receiver.add_child(collision)
	level.add_child(receiver)
	receiver.global_position=p.camera.global_position-p.camera.global_basis.z*3.0
	await physics_frame
	check(p.firearm._fire_shot(),"new Weapon actually fires through shared Hitscan")
	check(rt.chambered_round==ammo_b and rt.get_magazine_round_count()==1,"cycle takes real mixed next round")
	check(not p.firearm._fire_shot(),"new 200 RPM uses existing cooldown enforcement")
	check(is_equal_approx(rt.fire_cooldown_remaining,0.3),"new 200 RPM produces 0.3 second interval")
	rt.tick(0.3)
	check(p.firearm._fire_shot(),"second mixed round fires after its RPM interval")
	check(receiver.hits.size()==2,"real raycasts reach generic receiver twice")
	if receiver.hits.size()==2:
		check(receiver.hits[0].ammo_data==ammo_a and receiver.hits[1].ammo_data==ammo_b,"DamageInfo keeps actual fired Ammo identity")
		check(receiver.hits[0].base_flesh_damage==30.0 and receiver.hits[1].base_flesh_damage==50.0,"same Weapon has different actual per-round flesh damage")
		check(receiver.hits[0].bullet_level==1 and receiver.hits[1].bullet_level==4,"penetration level follows actual rounds")
		check(ArmorCalculator.calculate_hit(receiver.hits[0].ammo_data).base_armor_damage==30.0 and ArmorCalculator.calculate_hit(receiver.hits[1].ammo_data).base_armor_damage==70.0,"Armor source is actual round, independent of Weapon")
	check(second.runtime_state.get_magazine_round_count()==5 and second.runtime_state.fire_cooldown_remaining==0.0,"second Weapon runtime is untouched by firing first")
	check(weapon_a_before==[weapon_a.weapon_data,weapon_a.loaded_magazine,weapon_a.chambered_round,weapon_a.get_magazine_round_count(),weapon_a.fire_cooldown_remaining,weapon_a.selected_fire_mode],"firing Weapon B leaves stored Weapon A definition, magazine, chamber, cooldown and mode untouched")
	var outgoing: InventoryItemInstance=p.inventory.find_runtime_item(rt.loaded_magazine)
	var preserved_round: AmmoData=rt.chambered_round
	check(coord.request_reload(),"different 2x3 magazine begins actual generic tactical reload")
	rt.tick(2.0)
	check(not p.inventory.transactions.locked and rt.loaded_magazine==mag_big.runtime_state,"larger magazine reload completes with same runtime identity and lock release")
	check(rt.chambered_round==preserved_round and rt.get_magazine_round_count()==9,"larger magazine tactical reload preserves chamber plus all nine magazine rounds")
	check(p.inventory.transactions.get_location(mag_big).kind==&"weapon_magazine" and p.inventory.transactions.get_location(outgoing).kind==&"grid" and outgoing.runtime_state.get_round_count()==0,"reload ownership moves actual incoming item and retains outgoing depleted magazine")
	var slot_type: Variant=load("res://scripts/weapons/attachment_slot_definition.gd")
	var attachment_type: Variant=load("res://scripts/weapons/attachment_data.gd")
	var rail: Variant=slot_type.new()
	rail.slot_id=&"receiver_mount"
	rail.slot_interface=&"base_mount"
	var optic: Variant=slot_type.new()
	optic.slot_id=&"optic"
	optic.slot_interface=&"picatinny"
	var adapter: Variant=attachment_type.new()
	adapter.definition_id=&"temporary_adapter"
	adapter.compatible_slot_interfaces.assign([&"base_mount"])
	adapter.provided_slots.assign([optic])
	weapon_data_b.base_attachment_slots.assign([rail])
	var resolver: Variant=load("res://scripts/weapons/weapon_stat_resolver.gd")
	var stats: Variant=resolver.resolve(rt)
	check(stats.rounds_per_minute==200.0 and stats.ergonomics==42.0 and stats.bare_weight_kg==3.5,"computed base context reads new Weapon stats without balancing Gameplay")
	check(stats.loaded_magazine_definition==big_def.magazine_data and stats.base_attachment_slots[0]==rail,"loaded magazine and base attachment slots coexist in computed context")
	check(adapter.provided_slots[0].slot_interface==&"picatinny" and rt.loaded_magazine.definition==big_def.magazine_data,"adapter can provide nested slot without replacing loaded magazine definition")
	stats.rounds_per_minute=99.0
	stats.base_attachment_slots.clear()
	check(weapon_data_b.rounds_per_minute==200.0 and weapon_data_b.base_attachment_slots.size()==1,"mutating computed snapshot never mutates shared definition arrays")
	var world_item:=WorldItemFactory.spawn(second,p.inventory.transactions,level,Transform3D(Basis.IDENTITY,Vector3(8,0.1,0)))
	check(world_item!=null and world_item.item==second and world_item.item.runtime_state==second.runtime_state,"new Weapon world factory preserves identity without content branches")
	check(world_item.get_node("VisualRoot").get_child_count()==1,"new Weapon uses generic world visual fallback")
	level.queue_free()
	await process_frame

func finish() -> void:
	print("CONTENT_EXTENSIBILITY_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

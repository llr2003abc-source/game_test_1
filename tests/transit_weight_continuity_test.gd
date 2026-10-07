extends "res://tests/recursive_weight_test.gd"

func _run() -> void:
	for injured in [false,true]:
		var inv:=PlayerInventoryComponent.new()
		inv.initialize_loadout()
		var executor:=Firearm.new()
		var injury:=BodyInjuryComponent.new()
		injury.arms_injured=injured
		executor.injury_component=injury
		inv.reload_coordinator.executor=executor
		var runtime: WeaponRuntime=inv.equipment.get_active_item().runtime_state
		runtime.try_fire()
		runtime.tick(1.0)
		var before: float=inv.get_total_weight()
		var old:=inv.find_runtime_item(runtime.loaded_magazine)
		var original_rounds: Array[AmmoData]=old.runtime_state.rounds.duplicate()
		check(inv.reload_coordinator.request_reload(),"R begins injury=%s"%injured)
		var duration: float=2.7 if injured else 2.0
		check(is_equal_approx(runtime.reload_remaining,duration),"existing TimingProvider and Arms x1.35 preserved")
		for fraction in [0.1,0.2,0.3]:
			runtime.tick(duration*fraction)
			check(is_equal_approx(before,inv.get_total_weight()) and inv.transactions.locked,"R midpoint continuous ownership injury=%s"%injured)
		runtime.tick(duration*0.4)
		check(is_equal_approx(before,inv.get_total_weight()) and old.runtime_state.rounds==original_rounds,"R complete retains exact outgoing rounds")
		check(inv.transactions.reservations.is_empty(),"successful reload releases both leases")
		runtime.try_fire()
		runtime.tick(1.0)
		before=inv.get_total_weight()
		inv.reload_coordinator.tactical_time_multiplier=-1.0
		check(not inv.reload_coordinator.request_reload(),"invalid timing fails after reserve preflight")
		check(inv.transactions.reservations.is_empty() and not inv.transactions.locked and is_equal_approx(inv.get_total_weight(),before),"failed begin restores leases locations and weight")
		inv.reload_coordinator.tactical_time_multiplier=1.0
		runtime.chambered_round=null
		runtime.loaded_magazine.clear()
		runtime.state=WeaponRuntime.State.EMPTY
		before=inv.get_total_weight()
		check(inv.reload_coordinator.request_reload(),"empty reload starts")
		check(is_equal_approx(inv.get_total_weight(),before),"empty reload mid weight stable")
		runtime.tick(duration)
		check(is_equal_approx(inv.get_total_weight(),before) and runtime.chambered_round!=null,"empty chambering moves actual round without weight change")
		executor.free()
		injury.free()
		inv.free()
	var actor:=Node3D.new()
	var owner: Variant=load("res://tests/container_test_owner.gd").new()
	root.add_child(actor)
	root.add_child(owner)
	var inv:=PlayerInventoryComponent.new()
	actor.add_child(inv)
	var crate: InventoryTransactionService=owner.runtime.transactions
	crate.register_external_container(owner.runtime)
	var access:=LootContainerAccess.new(actor,owner,inv.transactions)
	var source:=ammo(10)
	inv.pockets[0].place_item(source,Vector2i.ZERO)
	var before: float=inv.get_total_weight()
	var lease:=inv.transactions.reserve_item(source)
	check(source.get_owner_registry()==inv.transactions and is_equal_approx(inv.get_total_weight(),before),"cross registry prepared state still source owned")
	var observed: Array=[]
	inv.transactions.changed.connect(func(): observed.append([source.get_owner_registry()==crate,inv.get_total_weight(),InventoryWeightCalculator.get_registry_total_weight(crate).weight_kg]))
	check(not ExternalInventoryTransfer.transfer(access,source,crate,{"kind":&"grid","grid":owner.runtime.inventory_grid,"position":Vector2i(100,100)}),"cross registry failed preflight no mutation")
	check(source.get_owner_registry()==inv.transactions and inv.transactions.is_reserved(source) and observed.is_empty(),"cross registry failure retains original lease and weight")
	check(ExternalInventoryTransfer.transfer(access,source,crate,{"kind":&"grid","grid":owner.runtime.inventory_grid,"position":Vector2i.ZERO}),"reserved root transfers atomically to crate")
	check(lease.phase==InventoryReservation.Phase.COMMITTED and not inv.transactions.is_reserved(source),"cross registry consumes reservation exactly once")
	check(observed.size()==1 and observed[0][0] and is_equal_approx(observed[0][1],0.0) and is_equal_approx(observed[0][2],before),"notifications see final owner and equal opposite weight deltas")
	check(crate.get_location_count(source)==1 and not inv.transactions.items.has(source),"cross registry one actual identity and one logical parent")
	var mixed:=mag(0)
	var a:=AmmoData.new()
	a.round_weight_kg=0.01
	var b:=AmmoData.new()
	b.round_weight_kg=0.025
	mixed.runtime_state.push_round(a)
	mixed.runtime_state.push_round(b)
	crate.place(mixed,owner.runtime.inventory_grid,Vector2i(1,0))
	var crate_before: float=InventoryWeightCalculator.get_registry_total_weight(crate).weight_kg
	var mixed_lease:=crate.reserve_item(mixed)
	check(weight_is(InventoryWeightCalculator.get_registry_total_weight(crate),crate_before),"reserved mixed magazine uses actual round masses")
	check(crate.cancel_reservation(mixed_lease) and mixed.runtime_state.rounds==[a,b],"cancel retains mixed ammo references")
	owner.free()
	actor.free()
	print("TRANSIT_WEIGHT_CONTINUITY_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

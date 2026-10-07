extends "res://tests/recursive_weight_test.gd"

class ObservedTransactions extends InventoryTransactionService:
	var watching: bool=false
	var expected: float
	var snapshots: Array=[]
	func reserve_item(member: InventoryItemInstance, detach: bool=true) -> InventoryReservation:
		var result:=super.reserve_item(member,detach)
		if watching: snapshots.append(InventoryWeightCalculator.get_registry_total_weight(self))
		return result
	func _commit_registration(group: Array[InventoryItemInstance]) -> void:
		super._commit_registration(group)
		if watching: snapshots.append(InventoryWeightCalculator.get_registry_total_weight(self))

func _run() -> void:
	for external in [false,true]:
		var service:=ObservedTransactions.new()
		var grid:=InventoryGrid.new(4,3,&"external" if external else &"backpack")
		service.register_grid(grid)
		var source:=ammo(53)
		grid.place_item(source,Vector2i.ZERO)
		var original: float=InventoryWeightCalculator.get_registry_total_weight(service).weight_kg
		service.expected=original
		service.watching=true
		var notifications: Array=[]
		var callback: Callable=func(): notifications.append([service.locked,InventoryWeightCalculator.get_registry_total_weight(service)])
		service.changed.connect(callback)
		var split:=service.split_stack(source,20)
		check(split!=null and source.stack_count==33 and split.stack_count==20,"split actual counts conserved generic registry=%s"%external)
		for snapshot in service.snapshots: check(weight_is(snapshot,original),"reserved/registered phase conserves all weight")
		check(notifications.size()==1 and notifications[0][0] and weight_is(notifications[0][1],original),"atomic notification locked with final conserved weight")
		check(service.reservations.is_empty() and not service.locked,"split clears both leases and lock")
		check(service.get_location_count(source)==1 and service.get_location_count(split)==1,"split roots each have exactly one physical parent")
		var different:=InventoryGrid.new(3,3)
		service.register_grid(different)
		var before: Array=[source.stack_count,service.items.size(),InventoryWeightCalculator.get_registry_total_weight(service)]
		check(service.split_stack(source,2,different)==null,"split cannot redirect into another location context")
		check(before==[source.stack_count,service.items.size(),InventoryWeightCalculator.get_registry_total_weight(service)],"different destination refusal has zero mutation")
		for amount in [-1,0,33,40]:
			check(service.split_stack(source,amount)==null and source.stack_count==33,"invalid amount revalidation %d"%amount)
		service.watching=false
		for y in range(grid.size.y):
			for x in range(grid.size.x):
				if grid.get_item_at_cell(Vector2i(x,y))==null: grid.place_item(item(1,1),Vector2i(x,y))
		before=[source.stack_count,service.items.size(),InventoryWeightCalculator.get_registry_total_weight(service)]
		check(service.split_stack(source,2)==null,"full grid rejects before reserving")
		check(before==[source.stack_count,service.items.size(),InventoryWeightCalculator.get_registry_total_weight(service)] and service.reservations.is_empty(),"full grid keeps counts graph and leases intact")
		service.changed.disconnect(callback)
	print("SPLIT_RESERVATION_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

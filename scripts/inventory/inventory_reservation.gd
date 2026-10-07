class_name InventoryReservation
extends RefCounted

enum Phase { RESERVED, COMMITTING, COMMITTED, CANCELLED }
var item: InventoryItemInstance
var origin: Dictionary
var rotation: bool
var phase: Phase = Phase.RESERVED
var _registry: WeakRef

func _init(member: InventoryItemInstance, location: Dictionary, registry: InventoryTransactionService) -> void:
	item=member
	origin=location.duplicate()
	rotation=member.rotated
	if location.get("grid")!=null and not origin.has("position"): origin["position"]=location.grid.get_placement(member).position
	_registry=weakref(registry)

func get_registry() -> InventoryTransactionService:
	return _registry.get_ref()

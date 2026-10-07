class_name LootContainerAccess
extends RefCounted

var runtime: LootContainerRuntime
var player_registry: InventoryTransactionService
var _actor: WeakRef
var _target: WeakRef
var _closed: bool = false

func _init(actor: Node3D, target: Node3D, registry: InventoryTransactionService) -> void:
	_actor=weakref(actor)
	_target=weakref(target)
	player_registry=registry
	runtime=target.get_external_inventory() if target.has_method("get_external_inventory") else null

func close() -> void:
	_closed=true

func is_valid() -> bool:
	return can_view() and not player_registry.locked and not runtime.transactions.locked

func can_view() -> bool:
	var actor: Node3D=_actor.get_ref()
	var target: Node3D=_target.get_ref()
	return not _closed and is_instance_valid(actor) and not actor.is_queued_for_deletion() and is_instance_valid(target) and not target.is_queued_for_deletion() and runtime!=null and target.get_external_inventory()==runtime and runtime.transactions.get_external_owner()==runtime and is_instance_valid(player_registry.inventory) and player_registry.inventory.get_parent()==actor and target.can_access(actor)

func permits(source: InventoryTransactionService, destination: InventoryTransactionService) -> bool:
	return is_valid() and source in [player_registry,runtime.transactions] and destination in [player_registry,runtime.transactions]

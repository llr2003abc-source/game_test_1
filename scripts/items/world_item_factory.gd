class_name WorldItemFactory
extends RefCounted

static func spawn(item: InventoryItemInstance, registry: InventoryTransactionService, parent: Node3D, world_transform: Transform3D) -> DroppedItem:
	if item==null or registry.locked or not is_instance_valid(parent) or parent.is_queued_for_deletion() or registry.world_items.has(item): return null
	if registry.get_location(item).kind not in [&"transit",&"unregistered"] or not registry.register_complete_subtree(item): return null
	var node: DroppedItem=_prepare(item,registry)
	registry.world_items[item]=node
	_attach(node,parent,world_transform)
	registry.changed.emit()
	return node

static func materialize_reserved(item: InventoryItemInstance, registry: InventoryTransactionService, parent: Node3D, world_transform: Transform3D) -> DroppedItem:
	# Reload has already reserved WORLD while its inventory lock is still held.
	if not registry.items.has(item) or not registry.world_items.has(item) or registry.world_items[item]!=null: return null
	var node: DroppedItem=_prepare(item,registry)
	registry.world_items[item]=node
	_attach(node,parent,world_transform)
	return node

static func grounded_drop_transform(character: Node3D, lateral_offset: float = 0.0) -> Transform3D:
	var ahead: Vector3=character.global_position-character.global_basis.z*0.8+character.global_basis.x*lateral_offset
	var query:=PhysicsRayQueryParameters3D.create(ahead+Vector3.UP,ahead-Vector3.UP*4,1)
	var hit: Dictionary=character.get_world_3d().direct_space_state.intersect_ray(query)
	var ground: Vector3=hit.position if not hit.is_empty() else ahead
	return Transform3D(Basis.IDENTITY,ground+Vector3.UP*0.12)

static func _prepare(item: InventoryItemInstance, registry: InventoryTransactionService) -> DroppedItem:
	var node: DroppedItem=load("res://scenes/items/dropped_item.tscn").instantiate()
	node.configure(item,registry)
	return node

static func _attach(node: DroppedItem, parent: Node3D, world_transform: Transform3D) -> void:
	parent.add_child(node)
	if parent.is_inside_tree(): node.global_transform=world_transform
	else: node.transform=world_transform

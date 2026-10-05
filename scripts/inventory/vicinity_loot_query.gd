class_name VicinityLootQuery
extends RefCounted

static func find_visible(actor: CharacterBody3D, registry: InventoryTransactionService, radius: float) -> Array[DroppedItem]:
	var result: Array[DroppedItem]=[]
	var camera: Camera3D=actor.get_node("Head/Camera3D")
	for item in registry.world_items:
		var node: DroppedItem=registry.world_items[item]
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node.can_interact(actor): continue
		if actor.global_position.distance_to(node.global_position)>radius+0.000001: continue
		var query:=PhysicsRayQueryParameters3D.create(camera.global_position,node.global_position,1|8,[actor.get_rid()])
		if actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): result.append(node)
	return result

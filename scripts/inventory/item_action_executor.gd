class_name ItemActionExecutor
extends RefCounted

var screen: InventoryUI

func _init(owner_screen: InventoryUI) -> void:
	screen=owner_screen

func execute(action_id: StringName, item: InventoryItemInstance, payload: Dictionary={}) -> Variant:
	if payload.has("signature") and screen.action_signature(item)!=payload.signature: return null
	var allowed: bool=false
	for descriptor in ItemActionResolver.resolve(item,screen):
		if descriptor.id==action_id and descriptor.enabled: allowed=true
	if not allowed: return null
	screen.close_item_context()
	match action_id:
		ItemActionDescriptor.INSPECT: return ItemInspection.describe(item)
		ItemActionDescriptor.OPEN_CONTAINER: return screen.open_portable_container(item,payload.get("parent_window"))
		ItemActionDescriptor.SPLIT: return item.get_owner_registry().split_stack(item,int(payload.get("amount",0)))
		ItemActionDescriptor.DROP:
			var transform:=WorldItemFactory.grounded_drop_transform(screen.player)
			var query:=PhysicsRayQueryParameters3D.create(screen.player.global_position+Vector3.UP*0.35,transform.origin+Vector3.UP*0.35,1|8,[screen.player.get_rid()])
			if not screen.player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return null
			return item.get_owner_registry().drop_item_to_world(item,screen.get_tree().current_scene,transform)
	return null

class_name ItemActionResolver
extends RefCounted

static func resolve(item: InventoryItemInstance, screen: InventoryUI) -> Array[ItemActionDescriptor]:
	var actions: Array[ItemActionDescriptor]=[]
	if not screen.can_access_item(item) or screen.is_item_busy(item): return actions
	actions.append(ItemActionDescriptor.new(ItemActionDescriptor.INSPECT,"Inspect"))
	var signature: Array=screen.item_location_signature(item)
	var root: InventoryItemInstance=signature.back()[0]
	var player_owned: bool=item.get_owner_registry()==screen.inventory.transactions and screen.inventory.transactions.get_location(root).kind!=&"world"
	if player_owned: actions.append(ItemActionDescriptor.new(ItemActionDescriptor.DROP,"Drop"))
	if item.definition.has_capability(&"portable_container"):
		actions.append(ItemActionDescriptor.new(ItemActionDescriptor.OPEN_CONTAINER,"Open Container"))
	if item.definition.has_capability(&"ammo_stack"):
		var split:=ItemActionDescriptor.new(ItemActionDescriptor.SPLIT,"Split")
		split.enabled=item.stack_count>1 and item.get_owner_registry().get_location(item).kind in [&"grid",&"container"]
		if not split.enabled: split.disabled_reason="Requires at least two rounds in a storage grid"
		actions.append(split)
	return actions

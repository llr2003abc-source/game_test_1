extends Node3D

func _ready() -> void:
	# Custom SceneTree test fixtures opt into this debug area explicitly.
	if get_tree().get_script()==null: spawn_loot.call_deferred()

func spawn_loot() -> Array[DroppedItem]:
	var inventory: PlayerInventoryComponent=get_parent().get_node("Player/PlayerInventory")
	var spawned: Array[DroppedItem]=[]
	for child in get_children():
		if child is WorldLootSpawnPoint:
			var world_item: DroppedItem=child.spawn_loot(inventory.transactions)
			if world_item!=null: spawned.append(world_item)
	return spawned

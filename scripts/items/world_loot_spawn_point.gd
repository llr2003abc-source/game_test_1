class_name WorldLootSpawnPoint
extends Marker3D

@export var item_definition: ItemDefinition
@export var stack_count: int = 1
@export var initial_magazine_rounds: int = -1
@export var show_debug_label: bool = true
var _spawned: bool = false

func spawn_loot(registry: InventoryTransactionService) -> DroppedItem:
	if _spawned: return null
	var original:=InventoryItemFactory.create(item_definition,stack_count,initial_magazine_rounds)
	if original==null: return null
	var world_item:=WorldItemFactory.spawn(original,registry,get_parent(),global_transform)
	if world_item!=null:
		_spawned=true
		world_item.show_debug_label=show_debug_label
		world_item.get_node("DebugLabel3D").visible=show_debug_label
	return world_item

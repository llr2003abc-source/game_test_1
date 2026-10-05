class_name DroppedItem
extends Node3D

var item: InventoryItemInstance

func configure(original: InventoryItemInstance) -> void:
	item = original
	if item.definition.visual_scene != null:
		add_child(item.definition.visual_scene.instantiate())

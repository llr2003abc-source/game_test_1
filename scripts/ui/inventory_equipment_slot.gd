class_name InventoryEquipmentSlot
extends Button
var slot: int
var screen: InventoryUI

func _get_drag_data(_at_position: Vector2) -> Variant:
	var item: InventoryItemInstance = screen.inventory.equipment.slots[slot]
	if item == null or screen.inventory.transactions.locked: return null
	var data: Dictionary = screen.begin_drag(item)
	set_drag_preview(screen.create_preview(item))
	return data

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("item") or screen.inventory.transactions.locked: return false
	return screen.inventory.equipment.can_equip(data.item,slot) and screen.inventory.equipment.slots[slot] in [null,data.item]

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	screen.drop_on_equipment(data,slot)

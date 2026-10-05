class_name InventoryEquipmentSlot
extends Button
var slot: int
var screen: InventoryUI

func _get_drag_data(at_position: Vector2) -> Variant:
	var item: InventoryItemInstance = screen.inventory.equipment.slots[slot]
	if item == null or screen.transactions_locked(): return null
	var grab: Vector2 = (at_position/size)*Vector2(item.get_size())*screen.cell_size
	var data: Dictionary = screen.begin_drag(item,grab)
	if data.is_empty(): return null
	set_drag_preview(screen.create_preview(item))
	return data

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("item") or screen.inventory.transactions.locked: return false
	return screen.update_drag_candidate(get_global_transform()*at_position,data).get("valid",false)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	screen.commit_drag_candidate(data)

func _notification(what: int) -> void:
	if what==NOTIFICATION_DRAG_END and screen!=null: screen.finish_drag()

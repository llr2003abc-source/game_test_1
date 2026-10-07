class_name VicinityLootPanel
extends Control

var screen: InventoryUI
var layout:=VicinityLootLayout.new()
var highlighted_item: InventoryItemInstance
var _pressed_item: InventoryItemInstance
var _press_position: Vector2
var _pressed_cell: Vector2i

func set_items(nodes: Array[DroppedItem], highlighted: InventoryItemInstance) -> void:
	layout.rebuild(nodes,8)
	highlighted_item=highlighted
	custom_minimum_size=Vector2(layout.width,layout.rows)*screen.cell_size
	queue_redraw()

func _draw() -> void:
	var cell: float=screen.cell_size
	for y in range(layout.rows):
		for x in range(layout.width):
			var rect:=Rect2(Vector2(x,y)*cell,Vector2.ONE*cell)
			draw_rect(rect,Color(0.08,0.11,0.14))
			draw_rect(rect,Color(0.3,0.36,0.4),false)
	for placement in layout.placements:
		var rect:=Rect2(Vector2(placement.position)*cell,Vector2(placement.extent)*cell)
		var alpha: float=0.4 if screen.drag_context!=null and screen.drag_context.item==placement.item else 1.0
		draw_rect(rect.grow(-2),Color(0.22,0.32,0.36,alpha))
		if placement.item==highlighted_item: draw_rect(rect.grow(-2),Color(1,0.8,0.2),false,2)
		var lines: PackedStringArray=screen.describe_item(placement.item).split("\n")
		for i in range(lines.size()): draw_string(get_theme_default_font(),rect.position+Vector2(4,13+i*13),lines[i],HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-8,10,Color(1,1,1,alpha))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT:
		var placement: Dictionary=layout.get_at_cell(Vector2i(event.position/screen.cell_size))
		screen.show_item_context(placement.get("item"),get_global_transform()*event.position)
		accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		var placement: Dictionary=layout.get_at_cell(Vector2i(event.position/screen.cell_size))
		_pressed_item=placement.get("item")
		_press_position=event.position
		_pressed_cell=placement.get("position",Vector2i(-1,-1))
		screen.selected_item=_pressed_item
		screen.show_selection()
		if event.double_click and _pressed_item!=null: screen.open_portable_container(_pressed_item)

func _get_drag_data(at_position: Vector2) -> Variant:
	var placement: Dictionary=layout.get_at_cell(Vector2i(_press_position/screen.cell_size)) if _pressed_item!=null else layout.get_at_cell(Vector2i(at_position/screen.cell_size))
	if _pressed_item!=null and (placement.get("item")!=_pressed_item or placement.get("position")!=_pressed_cell): return null
	if placement.is_empty() or screen.inventory.transactions.locked or not screen.is_vicinity_item(placement.item): return null
	var point: Vector2=_press_position if _pressed_item!=null else at_position
	var data: Dictionary=screen.begin_drag(placement.item,point-Vector2(placement.position)*screen.cell_size)
	_pressed_item=null
	set_drag_preview(screen.create_preview(placement.item))
	return data

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and screen.update_drag_candidate(get_global_transform()*at_position,data).get("valid",false)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	screen.commit_drag_candidate(data)

func _notification(what: int) -> void:
	if what==NOTIFICATION_DRAG_END and screen!=null: screen.finish_drag()

class_name InventoryGridView
extends Control
var grid: InventoryGrid
var screen: InventoryUI
var _pressed_item: InventoryItemInstance
var _press_position: Vector2

func configure(container: InventoryGrid, inventory_screen: InventoryUI) -> void:
	grid = container
	screen = inventory_screen
	custom_minimum_size = Vector2(grid.size) * screen.cell_size
	clip_contents = true

func _draw() -> void:
	if grid == null: return
	var cell: float = screen.cell_size
	for y in range(grid.size.y):
		for x in range(grid.size.x):
			var rectangle := Rect2(Vector2(x,y)*cell,Vector2.ONE*cell)
			draw_rect(rectangle,Color(0.08,0.11,0.14))
			draw_rect(rectangle,Color(0.3,0.36,0.4),false,1.0)
	for placement in grid.placements:
		var rectangle := Rect2(Vector2(placement.position)*cell,Vector2(placement.item.get_size())*cell)
		var alpha: float = 0.4 if screen.drag_context!=null and screen.drag_context.item==placement.item else 1.0
		draw_rect(rectangle.grow(-2),Color(0.22,0.32,0.36,alpha))
		var lines: PackedStringArray = screen.describe_item(placement.item).split("\n")
		for i in range(lines.size()):
			draw_string(get_theme_default_font(),rectangle.position+Vector2(4,13+i*13),lines[i],HORIZONTAL_ALIGNMENT_LEFT,rectangle.size.x-8,10,Color(1,1,1,alpha))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		screen.selected_item = grid.get_item_at_cell(Vector2i(event.position/screen.cell_size))
		_pressed_item = screen.selected_item
		_press_position = event.position
		screen.show_selection()

func _get_tooltip(at_position: Vector2) -> String:
	var item: InventoryItemInstance = grid.get_item_at_cell(Vector2i(at_position/screen.cell_size))
	return screen.describe_item(item) if item != null else ""

func _get_drag_data(at_position: Vector2) -> Variant:
	var item: InventoryItemInstance = _pressed_item if _pressed_item!=null and grid.get_placement(_pressed_item)!=null else grid.get_item_at_cell(Vector2i(at_position/screen.cell_size))
	if item == null or screen.inventory.transactions.locked: return null
	var position: Vector2 = _press_position if item==_pressed_item else at_position
	var grab: Vector2 = position-Vector2(grid.get_placement(item).position)*screen.cell_size
	var data: Dictionary = screen.begin_drag(item,grab)
	_pressed_item = null
	set_drag_preview(screen.create_preview(item))
	return data

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("item") and screen.update_drag_candidate(get_global_transform()*at_position,data).get("valid",false)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	screen.commit_drag_candidate(data)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and screen != null: screen.finish_drag()

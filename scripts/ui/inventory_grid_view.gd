class_name InventoryGridView
extends Control
var grid: InventoryGrid
var screen: InventoryUI

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
		draw_rect(rectangle.grow(-2),Color(0.22,0.32,0.36))
		var lines: PackedStringArray = screen.describe_item(placement.item).split("\n")
		for i in range(lines.size()):
			draw_string(get_theme_default_font(),rectangle.position+Vector2(4,13+i*13),lines[i],HORIZONTAL_ALIGNMENT_LEFT,rectangle.size.x-8,10,Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		screen.selected_item = grid.get_item_at_cell(Vector2i(event.position/screen.cell_size))
		screen.show_selection()

func _get_tooltip(at_position: Vector2) -> String:
	var item: InventoryItemInstance = grid.get_item_at_cell(Vector2i(at_position/screen.cell_size))
	return screen.describe_item(item) if item != null else ""

func _get_drag_data(at_position: Vector2) -> Variant:
	var item: InventoryItemInstance = grid.get_item_at_cell(Vector2i(at_position/screen.cell_size))
	if item == null or screen.inventory.transactions.locked: return null
	var data: Dictionary = screen.begin_drag(item)
	set_drag_preview(screen.create_preview(item))
	return data

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("item") and screen.can_drop_on_grid(data,grid,Vector2i(at_position/screen.cell_size))

func _drop_data(at_position: Vector2, data: Variant) -> void:
	screen.drop_on_grid(data,grid,Vector2i(at_position/screen.cell_size))

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and screen != null: screen.finish_drag()

class_name PortableContainerWindow
extends PanelContainer

var item: InventoryItemInstance
var parent_window: PortableContainerWindow
var manager: PortableWindowManager
var views: Array[InventoryGridView]=[]
var location_signature: Array
var weight_label: Label
var _moving_title: bool=false

func configure(member: InventoryItemInstance, owner_manager: PortableWindowManager, ancestor: PortableContainerWindow) -> void:
	item=member
	manager=owner_manager
	parent_window=ancestor
	location_signature=manager.screen.item_location_signature(item)
	var style:=StyleBoxFlat.new()
	style.bg_color=Color(0.12,0.16,0.19)
	style.border_color=Color(0.55,0.65,0.7)
	style.set_border_width_all(2)
	style.content_margin_left=10
	style.content_margin_right=10
	style.content_margin_top=8
	style.content_margin_bottom=10
	add_theme_stylebox_override("panel",style)
	var column:=VBoxContainer.new()
	add_child(column)
	var title:=HBoxContainer.new()
	title.custom_minimum_size.y=34
	title.mouse_filter=Control.MOUSE_FILTER_STOP
	title.gui_input.connect(_title_input)
	column.add_child(title)
	var caption:=Label.new()
	caption.text=item.definition.display_name
	caption.mouse_filter=Control.MOUSE_FILTER_IGNORE
	caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title.add_child(caption)
	var close:=Button.new()
	close.text="×"
	close.pressed.connect(func(): manager.close_window(self))
	title.add_child(close)
	weight_label=Label.new()
	column.add_child(weight_label)
	var scrolling:=ScrollContainer.new()
	column.add_child(scrolling)
	var grids_row:=HBoxContainer.new()
	scrolling.add_child(grids_row)
	var storage_width: float=0.0
	var storage_height: float=0.0
	for grid in item.get_storage_grids():
		storage_width+=grid.size.x*manager.screen.cell_size+4
		storage_height=maxf(storage_height,grid.size.y*manager.screen.cell_size)
		var view:=InventoryGridView.new()
		view.configure(grid,manager.screen)
		view.portable_window=self
		grids_row.add_child(view)
		views.append(view)
	var viewport_size: Vector2=manager.screen.get_viewport().get_visible_rect().size
	scrolling.custom_minimum_size=Vector2(minf(storage_width,minf(640,viewport_size.x-60)),minf(storage_height,minf(400,viewport_size.y-140)))
	refresh_contents()

func refresh_contents() -> void:
	var weight: Dictionary=InventoryWeightCalculator.get_item_total_weight(item)
	weight_label.text="TOTAL %.2f kg"%weight.weight_kg if weight.valid else "WEIGHT INVALID"
	for view in views: view.queue_redraw()

func move_title(delta: Vector2) -> void:
	position+=delta
	clamp_position()

func clamp_position() -> void:
	if not is_inside_tree(): return
	var viewport_size: Vector2=get_viewport().get_visible_rect().size
	position=Vector2(clampf(position.x,0,maxf(0,viewport_size.x-size.x)),clampf(position.y,0,maxf(0,viewport_size.y-size.y)))

func _title_input(event: InputEvent) -> void:
	if manager.screen.drag_context!=null:
		_moving_title=false
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		_moving_title=event.pressed
		if event.pressed: manager.bring_to_front(self)
	elif event is InputEventMouseMotion and _moving_title:
		move_title(event.relative)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed: manager.bring_to_front(self)

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and manager.screen.update_drag_candidate(get_global_transform()*at_position,data).get("valid",false)

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	manager.screen.commit_drag_candidate(data)

func _notification(what: int) -> void:
	if what==NOTIFICATION_RESIZED: clamp_position()
	if what==NOTIFICATION_DRAG_END and manager!=null: manager.screen.finish_drag()

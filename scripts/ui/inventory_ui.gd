class_name InventoryUI
extends CanvasLayer

@export var cell_size: float = 48.0
var player: Node
var inventory: PlayerInventoryComponent
var views: Array[InventoryGridView] = []
var equipment_views: Dictionary = {}
var selected_item: InventoryItemInstance
var drag_data: Dictionary = {}
var drag_preview: Control
var panel: PanelContainer
var content: VBoxContainer
var status: Label
var split_amount: SpinBox
var _toggle_handled: bool = false

func _ready() -> void:
	player = get_parent()
	inventory = player.get_node("PlayerInventory")
	layer = 20
	visible = false
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.08,0.09,0.11,1.0)
	panel.add_theme_stylebox_override("panel",background)
	add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["margin_left","margin_right","margin_top","margin_bottom"]: margin.add_theme_constant_override(edge,16)
	panel.add_child(margin)
	content = VBoxContainer.new()
	margin.add_child(content)
	inventory.inventory_changed.connect(_on_changed)
	player.firearm.weapon_state_changed.connect(_on_weapon_changed)

func toggle() -> void:
	visible = not visible
	player.set_inventory_open(visible)
	if get_viewport().gui_is_dragging(): get_viewport().gui_cancel_drag()
	finish_drag()
	if visible: refresh()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		_toggle_handled = true
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("reload"):
		if not drag_data.is_empty(): rotate_drag()
		elif selected_item != null:
			if not inventory.transactions.rotate(selected_item): status.text="Rotation unavailable"
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("inventory_toggle") and not _toggle_handled: toggle()
	_toggle_handled = false

func _on_changed() -> void:
	if visible: refresh()

func _on_weapon_changed(_mag: int, _chamber: bool, _spares: int, _state: int) -> void:
	if visible: refresh()

func label(text: String) -> Label:
	var result := Label.new()
	result.text = text
	return result

func refresh() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	views.clear()
	equipment_views.clear()
	var header := HBoxContainer.new()
	header.add_child(label("PLAYER INVENTORY  |  %.2f kg"%inventory.get_total_weight()))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close := Button.new()
	close.text = "Close [Tab]"
	close.pressed.connect(toggle)
	header.add_child(close)
	content.add_child(header)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation",32)
	content.add_child(layout)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 220
	layout.add_child(left)
	left.add_child(label("EQUIPMENT"))
	for slot in range(6):
		left.add_child(label(["PRIMARY","SECONDARY","PISTOL","KNIFE","RIG","BACKPACK"][slot]))
		var button := InventoryEquipmentSlot.new()
		button.slot = slot
		button.screen = self
		button.custom_minimum_size = Vector2(220,48)
		var item: InventoryItemInstance = inventory.equipment.slots[slot]
		button.text = "Empty" if item==null else describe_item(item)
		button.pressed.connect(func() -> void: selected_item=inventory.equipment.slots[slot]; show_selection())
		left.add_child(button)
		equipment_views[slot] = button
	var right := VBoxContainer.new()
	layout.add_child(right)
	right.add_child(label("RIG — independent slots"))
	var rig_row := HBoxContainer.new()
	right.add_child(rig_row)
	var rig: RigContainerRuntime = inventory.get_equipped_rig()
	if rig != null:
		for grid in rig.grids: add_grid(rig_row,grid)
	else: rig_row.add_child(label("No equipped rig"))
	right.add_child(label("POCKETS"))
	var pocket_row := HBoxContainer.new()
	right.add_child(pocket_row)
	for grid in inventory.pockets: add_grid(pocket_row,grid)
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation",32)
	right.add_child(lower)
	var bag_column := VBoxContainer.new()
	lower.add_child(bag_column)
	bag_column.add_child(label("BACKPACK"))
	var bag: BackpackContainerRuntime = inventory.get_equipped_backpack()
	if bag != null: add_grid(bag_column,bag.grid)
	else: bag_column.add_child(label("No equipped backpack"))
	var secure_column := VBoxContainer.new()
	lower.add_child(secure_column)
	var secure_space := Control.new()
	secure_space.custom_minimum_size.y = cell_size*2
	secure_column.add_child(secure_space)
	secure_column.add_child(label("SECURE CONTAINER"))
	add_grid(secure_column,inventory.secure.grid)
	var actions := HBoxContainer.new()
	content.add_child(actions)
	actions.add_child(label("Drag items • R rotate • Split ammo:"))
	split_amount = SpinBox.new()
	split_amount.min_value = 1
	split_amount.max_value = 59
	split_amount.value = 20
	actions.add_child(split_amount)
	var split := Button.new()
	split.text = "Split selected"
	split.pressed.connect(_split_selected)
	actions.add_child(split)
	status = label("Reload locks inventory changes" if inventory.transactions.locked else "Ready")
	content.add_child(status)

func add_grid(parent: Node, grid: InventoryGrid) -> void:
	var view := InventoryGridView.new()
	view.configure(grid,self)
	parent.add_child(view)
	views.append(view)

func describe_item(item: InventoryItemInstance) -> String:
	var text: String = item.definition.display_name
	if item.runtime_state is MagazineInstance: text += "\n%d/%d"%[item.runtime_state.get_round_count(),item.runtime_state.definition.capacity]
	elif item.runtime_state is WeaponRuntime: text += "\nMAG %d + CH %d"%[item.runtime_state.get_magazine_round_count(),int(item.runtime_state.chambered_round!=null)]
	elif item.definition.category==ItemDefinition.Category.AMMO: text += "\nx%d"%item.stack_count
	return text+"\n%dx%d"%[item.get_size().x,item.get_size().y]

func show_selection() -> void:
	if status != null: status.text = describe_item(selected_item).replace("\n"," | ") if selected_item!=null else "Ready"

func begin_drag(item: InventoryItemInstance) -> Dictionary:
	drag_data = {"item":item,"rotated":item.rotated}
	selected_item = item
	return drag_data

func create_preview(item: InventoryItemInstance) -> Control:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(item.get_size())*cell_size
	preview.add_child(label(describe_item(item)))
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview = preview
	return preview

func rotate_drag() -> void:
	if drag_data.is_empty(): return
	drag_data.rotated = not drag_data.rotated
	if is_instance_valid(drag_preview):
		drag_preview.custom_minimum_size = Vector2(drag_data.item.get_size(drag_data.rotated))*cell_size
		drag_preview.size = drag_preview.custom_minimum_size

func finish_drag() -> void:
	drag_data = {}
	drag_preview = null

func can_drop_on_grid(data: Dictionary, grid: InventoryGrid, cell: Vector2i) -> bool:
	if inventory.transactions.locked or not data.has("item"): return false
	var target: InventoryItemInstance = grid.get_item_at_cell(cell)
	if target!=null and target!=data.item and data.item.definition.category==ItemDefinition.Category.AMMO:
		return target.definition.category in [ItemDefinition.Category.AMMO,ItemDefinition.Category.MAGAZINE]
	return grid.can_place(data.item,cell,data.rotated)

func drop_on_grid(data: Dictionary, grid: InventoryGrid, cell: Vector2i) -> bool:
	if not data.has("item") or inventory.transactions.locked: return false
	var item: InventoryItemInstance = data.item
	var target: InventoryItemInstance = grid.get_item_at_cell(cell)
	var ok: bool
	if target!=null and target!=item and item.definition.category==ItemDefinition.Category.AMMO:
		ok = inventory.transactions.load_ammo_into_magazine(item,target,item.stack_count)>0 if target.definition.category==ItemDefinition.Category.MAGAZINE else inventory.transactions.merge_stacks(item,target)>0
	else: ok = inventory.transactions.move(item,grid,cell,data.rotated)
	if not ok and status != null: status.text="Invalid placement, compatibility, or inventory locked"
	return ok

func drop_on_equipment(data: Dictionary, slot: int) -> bool:
	return data.has("item") and inventory.transactions.equip(data.item,slot)

func _split_selected() -> void:
	if selected_item==null or inventory.transactions.split_stack(selected_item,int(split_amount.value))==null: status.text="Split unavailable: check ammo, quantity and space"

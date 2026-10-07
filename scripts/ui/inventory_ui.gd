class_name InventoryUI
extends CanvasLayer

class DragSurface extends PanelContainer:
	var screen: InventoryUI
	func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and screen.update_drag_candidate(get_global_transform()*at_position,data).get("valid",false)
	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		screen.commit_drag_candidate(data)
	func _notification(what: int) -> void:
		if what==NOTIFICATION_DRAG_END and screen!=null: screen.finish_drag()

@export var cell_size: float = 48.0
@export_range(12.0,18.0,0.5) var snap_radius_pixels: float = 16.0
@export var vicinity_radius: float = 3.0
enum Mode { PLAYER, VICINITY, CONTAINER_LOOT }
var mode: Mode = Mode.PLAYER
var vicinity_mode: bool:
	get: return mode==Mode.VICINITY
var current_open_container: Node3D
var container_access: LootContainerAccess
var _equipment_layout: Array=[]
var _header_label: Label
var _grid_signatures: Dictionary={}
var nearby_panel: VicinityLootPanel
var nearby_scroll: ScrollContainer
var highlighted_item: InventoryItemInstance
var _nearby_signature: Array=[]
var _vicinity_elapsed: float = 0.0
var _vicinity_position: Vector3
var player: Node
var inventory: PlayerInventoryComponent
var views: Array[InventoryGridView] = []
var equipment_views: Dictionary = {}
var selected_item: InventoryItemInstance
var drag_data: Dictionary = {}
var drag_preview: InventoryDragGhost
var drag_context: InventoryDragContext
var placement_preview: InventoryPlacementPreview
var panel: PanelContainer
var content: VBoxContainer
var status: Label
var split_amount: SpinBox
var _toggle_handled: bool = false
var _pending_refresh: bool = false
var _committing_drag: bool = false
var _drag_pointer: Vector2
var _has_drag_pointer: bool = false

func _ready() -> void:
	player = get_parent()
	inventory = player.get_node("PlayerInventory")
	layer = 20
	visible = false
	var drag_surface := DragSurface.new()
	drag_surface.screen = self
	panel = drag_surface
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
	placement_preview = InventoryPlacementPreview.new()
	add_child(placement_preview)
	placement_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player.get_node("PlayerInteractor").manage_requested.connect(open_vicinity)

func toggle() -> void:
	close_container()
	visible = not visible
	mode=Mode.PLAYER
	player.set_inventory_open(visible)
	if get_viewport().gui_is_dragging(): get_viewport().gui_cancel_drag()
	finish_drag()
	if visible: refresh()

func open_vicinity(target: Node) -> void:
	if inventory.transactions.locked or not target is DroppedItem or not target.can_interact(player): return
	close_container()
	mode=Mode.VICINITY
	highlighted_item=target.item
	visible=true
	player.set_inventory_open(true)
	if get_viewport().gui_is_dragging(): get_viewport().gui_cancel_drag()
	finish_drag()
	refresh()

func open_container(target: Node3D) -> bool:
	if not is_instance_valid(target) or not target.can_interact(player): return false
	close_container()
	current_open_container=target
	container_access=LootContainerAccess.new(player,target,inventory.transactions)
	if not container_access.is_valid():
		close_container()
		return false
	container_access.runtime.changed.connect(_on_changed)
	mode=Mode.CONTAINER_LOOT
	visible=true
	player.set_inventory_open(true)
	if get_viewport().gui_is_dragging(): get_viewport().gui_cancel_drag()
	finish_drag()
	refresh()
	return true

func close_container() -> void:
	if container_access!=null:
		if container_access.runtime.changed.is_connected(_on_changed): container_access.runtime.changed.disconnect(_on_changed)
		container_access.close()
	container_access=null
	current_open_container=null
	selected_item=null

func _exit_tree() -> void:
	visible=false
	close_container()
	if is_instance_valid(inventory) and inventory.inventory_changed.is_connected(_on_changed): inventory.inventory_changed.disconnect(_on_changed)
	var executor: Firearm=player.get("firearm") if is_instance_valid(player) else null
	if executor!=null and executor.weapon_state_changed.is_connected(_on_weapon_changed): executor.weapon_state_changed.disconnect(_on_weapon_changed)

func transactions_locked() -> bool:
	return inventory.transactions.locked or (mode==Mode.CONTAINER_LOOT and (container_access==null or not container_access.is_valid()))

func is_vicinity_item(item: InventoryItemInstance) -> bool:
	if not visible or not vicinity_mode or inventory.transactions.locked: return false
	var node: DroppedItem=inventory.transactions.world_items.get(item)
	return is_instance_valid(node) and VicinityLootQuery.find_visible(player,inventory.transactions,vicinity_radius).has(node)

func _refresh_nearby(force: bool = false) -> void:
	if not visible or not vicinity_mode or not is_instance_valid(nearby_panel): return
	var nodes:=VicinityLootQuery.find_visible(player,inventory.transactions,vicinity_radius)
	var signature: Array=[]
	for node in nodes: signature.append([node.item.get_instance_id(),node.item.stack_count,node.item.rotated,describe_item(node.item)])
	if not force and signature==_nearby_signature: return
	if drag_context!=null and not _committing_drag:
		if get_viewport().gui_is_dragging(): get_viewport().gui_cancel_drag()
		finish_drag()
	_nearby_signature=signature
	nearby_panel.set_items(nodes,highlighted_item)

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
			if transactions_locked() or selected_item.get_owner_registry()==null or not selected_item.get_owner_registry().rotate(selected_item): status.text="Rotation unavailable"
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("inventory_toggle") and not _toggle_handled: toggle()
	_toggle_handled = false
	if visible and mode==Mode.CONTAINER_LOOT and (container_access==null or not container_access.is_valid()):
		toggle()
		return
	if drag_context!=null and get_viewport().gui_is_dragging():
		var pointer: Vector2 = panel.get_global_mouse_position()
		if not _has_drag_pointer or pointer!=_drag_pointer: update_drag_candidate(pointer,drag_data)
	if visible and vicinity_mode:
		_vicinity_elapsed+=delta
		if _vicinity_elapsed>=0.2 or player.global_position.distance_to(_vicinity_position)>=0.2:
			_vicinity_elapsed=0.0
			_vicinity_position=player.global_position
			_refresh_nearby()

func _on_changed() -> void:
	if not visible or not is_inside_tree(): return
	if drag_context!=null and _committing_drag:
		_pending_refresh = true
		return
	if drag_context!=null:
		if get_viewport().gui_is_dragging(): get_viewport().gui_cancel_drag()
		finish_drag()
	var layout: Array=[inventory.equipment.slots[4],inventory.equipment.slots[5]]
	if mode!=Mode.CONTAINER_LOOT or layout!=_equipment_layout:
		refresh()
	else:
		_pending_refresh=false
		_header_label.text="PLAYER INVENTORY  |  %.2f kg"%inventory.get_total_weight()
		for slot in equipment_views:
			var item: InventoryItemInstance=inventory.equipment.slots[slot]
			equipment_views[slot].text="Empty" if item==null else describe_item(item)
		for view in views:
			var signature:=_grid_signature(view.grid)
			if _grid_signatures.get(view.grid)!=signature:
				_grid_signatures[view.grid]=signature
				view.queue_redraw()

func _on_weapon_changed(_mag: int, _chamber: bool, _spares: int, _state: int) -> void:
	_on_changed()

func label(text: String) -> Label:
	var result := Label.new()
	result.text = text
	return result

func refresh() -> void:
	_pending_refresh = false
	_equipment_layout=[inventory.equipment.slots[4],inventory.equipment.slots[5]]
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	views.clear()
	_grid_signatures.clear()
	equipment_views.clear()
	nearby_panel=null
	nearby_scroll=null
	var header := HBoxContainer.new()
	_header_label=label("PLAYER INVENTORY  |  %.2f kg"%inventory.get_total_weight())
	header.add_child(_header_label)
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
		left.add_child(label(["WEAPON SLOT 1","WEAPON SLOT 2","PISTOL","KNIFE","RIG","BACKPACK"][slot]))
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
	if vicinity_mode:
		var nearby_column:=VBoxContainer.new()
		layout.add_child(nearby_column)
		nearby_column.add_child(label("NEARBY — drag here to drop"))
		nearby_scroll=ScrollContainer.new()
		nearby_scroll.custom_minimum_size=Vector2(cell_size*8+16,400)
		nearby_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
		nearby_column.add_child(nearby_scroll)
		nearby_panel=VicinityLootPanel.new()
		nearby_panel.screen=self
		nearby_scroll.add_child(nearby_panel)
		_refresh_nearby(true)
	elif mode==Mode.CONTAINER_LOOT and container_access!=null:
		var container_column:=VBoxContainer.new()
		layout.add_child(container_column)
		container_column.add_child(label("%s — %d × %d"%[container_access.runtime.display_name,container_access.runtime.grid_size.x,container_access.runtime.grid_size.y]))
		add_grid(container_column,container_access.runtime.inventory_grid)
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
	_grid_signatures[grid]=_grid_signature(grid)

func _grid_signature(grid: InventoryGrid) -> Array:
	var result: Array=[]
	for placement in grid.placements: result.append([placement.item,placement.position,placement.item.rotated,describe_item(placement.item)])
	return result

func describe_item(item: InventoryItemInstance, preview_rotated: Variant = null) -> String:
	var text: String = item.definition.display_name
	if item.runtime_state is MagazineInstance: text += "\n%d/%d"%[item.runtime_state.get_round_count(),item.runtime_state.definition.capacity]
	elif item.runtime_state is WeaponRuntime: text += "\nMAG %d + CH %d"%[item.runtime_state.get_magazine_round_count(),int(item.runtime_state.chambered_round!=null)]
	elif item.definition.category==ItemDefinition.Category.AMMO: text += "\nx%d"%item.stack_count
	var extent: Vector2i = item.get_size() if preview_rotated==null else item.get_size(preview_rotated)
	return text+"\n%dx%d"%[extent.x,extent.y]

func show_selection() -> void:
	if status != null: status.text = describe_item(selected_item).replace("\n"," | ") if selected_item!=null else "Ready"

func begin_drag(item: InventoryItemInstance, grab_offset: Vector2 = Vector2.ZERO) -> Dictionary:
	finish_drag()
	if transactions_locked() or item.get_owner_registry()==null: return {}
	var source: Dictionary = item.get_owner_registry().get_location(item)
	var grid: InventoryGrid = source.get("grid")
	var cell: Vector2i = grid.get_placement(item).position if grid!=null else Vector2i(-1,-1)
	drag_context = InventoryDragContext.new(item,cell_size,grab_offset,grid,cell,source.get("slot",-1))
	drag_data = {"item":item,"rotated":item.rotated,"context":drag_context}
	if source.kind==&"world": drag_data.world=weakref(source.node)
	selected_item = item
	_redraw_source()
	return drag_data

func create_preview(item: InventoryItemInstance) -> Control:
	var preview := InventoryDragGhost.new(drag_context,describe_item(item,drag_context.preview_rotation),cell_size)
	drag_preview = preview
	return preview

func rotate_drag() -> void:
	if drag_context==null: return
	drag_context.rotate_preview()
	drag_data.rotated = drag_context.preview_rotation
	if is_instance_valid(drag_preview):
		drag_preview.caption = describe_item(drag_context.item,drag_context.preview_rotation)
		drag_preview.queue_redraw()
	if _has_drag_pointer: update_drag_candidate(_drag_pointer,drag_data)

func finish_drag() -> void:
	if is_instance_valid(drag_preview) and drag_preview.get_parent()==null: drag_preview.free()
	drag_data = {}
	drag_preview = null
	drag_context = null
	_has_drag_pointer = false
	if is_instance_valid(placement_preview): placement_preview.visible = false
	_redraw_source()
	if _pending_refresh and visible: _on_changed()

func _redraw_source() -> void:
	for view in views: view.queue_redraw()
	if is_instance_valid(nearby_panel): nearby_panel.queue_redraw()
	for slot in equipment_views:
		var dragging: bool = drag_context!=null and inventory.equipment.slots[slot]==drag_context.item
		equipment_views[slot].modulate.a = 0.4 if dragging else 1.0

func update_drag_candidate(mouse_position: Vector2, data: Dictionary = {}) -> Dictionary:
	if drag_context==null or (not data.is_empty() and data.get("item")!=drag_context.item): return {"kind":&"none","valid":false}
	_drag_pointer = mouse_position
	_has_drag_pointer = true
	var candidate: Dictionary = {"kind":&"none","valid":false}
	# Only control rectangles are scanned. Placement searches remain local3x3.
	for view in views:
		if view.get_global_rect().has_point(mouse_position):
			candidate = _resolve_grid_view(view,mouse_position)
			break
	if candidate.kind==&"none":
		for slot in equipment_views:
			if equipment_views[slot].get_global_rect().has_point(mouse_position):
				candidate = InventoryDragCandidateResolver.resolve_equipment(drag_context,inventory.equipment,slot,transactions_locked())
				candidate.preview_rect = equipment_views[slot].get_global_rect()
				candidate.footprint_size = Vector2i.ONE
				break
	if candidate.kind==&"none":
		if vicinity_mode and is_instance_valid(nearby_scroll) and nearby_scroll.get_global_rect().has_point(mouse_position):
			candidate={"kind":&"world_drop","valid":not inventory.transactions.locked and not drag_data.has("world"),"snapped":false}
	if candidate.kind==&"none":
		var ideal: Vector2 = drag_context.get_ghost_top_left(mouse_position)
		var best_distance: float = INF
		for view in views:
			if not view.get_global_rect().grow(snap_radius_pixels).has_point(ideal): continue
			var near: Dictionary = _resolve_grid_view(view,mouse_position)
			if candidate.kind==&"none": candidate = near
			if near.valid and near.snap_distance<best_distance:
				candidate = near
				best_distance = near.snap_distance
	drag_context.set_candidate(candidate)
	placement_preview.show_candidate(candidate,cell_size)
	if candidate.kind!=&"none" and status!=null:
		status.text = ("VALID " if candidate.valid else "INVALID ")+String(candidate.kind).to_upper()
		if candidate.get("snapped",false): status.text += " | SNAP %.1f px"%candidate.snap_distance
	return candidate

func _resolve_grid_view(view: InventoryGridView, mouse_position: Vector2) -> Dictionary:
	var origin: Vector2 = view.get_global_rect().position
	var candidate: Dictionary = InventoryDragCandidateResolver.resolve_grid(drag_context,view.grid,mouse_position,origin,cell_size,snap_radius_pixels,transactions_locked())
	var footprint: Vector2i = candidate.target_item.get_size() if candidate.target_item!=null else drag_context.get_preview_size()
	candidate.footprint_size = footprint
	candidate.preview_rect = Rect2(origin+Vector2(candidate.position)*cell_size,Vector2(footprint)*cell_size)
	candidate.grid_rect = view.get_global_rect()
	return candidate

func commit_drag_candidate(data: Dictionary) -> bool:
	if drag_context==null or data.get("item")!=drag_context.item or not drag_context.candidate.get("valid",false): return false
	if transactions_locked() or not _source_unchanged(): return false
	if data.has("world") and not is_vicinity_item(data.item): return false
	var candidate: Dictionary = drag_context.candidate
	if candidate.kind in [&"load",&"stack"]:
		if candidate.grid.get_item_at_cell(candidate.position)!=candidate.target_item: return false
	_committing_drag = true
	var ok: bool
	if candidate.kind==&"world_drop":
		var drop_transform:=WorldItemFactory.grounded_drop_transform(player,(inventory.transactions.world_items.size()%3-1)*0.15)
		var query:=PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP*0.35,drop_transform.origin+Vector3.UP*0.35,1|8,[player.get_rid()])
		if player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			ok=inventory.transactions.drop_item_to_world(data.item,get_tree().current_scene,drop_transform)!=null
		else: status.text="Drop blocked by world geometry"
	elif candidate.kind==&"equipment": ok = drop_on_equipment(data,candidate.slot)
	elif candidate.kind in [&"load",&"stack"]: ok = drop_on_grid(data,candidate.grid,candidate.position)
	elif data.has("world"): ok=inventory.transactions.pickup_world_item_to_grid(data.world.get_ref(),candidate.grid,candidate.position,candidate.rotated).success
	# Commit the displayed cell/rotation; never resolve a second mouse position.
	else: ok = _move_to_grid(drag_context.item,candidate.grid,candidate.position,candidate.rotated)
	_committing_drag = false
	return ok

func _source_unchanged() -> bool:
	var registry:=drag_context.item.get_owner_registry()
	if registry==null or drag_context.item.rotated!=drag_context.source_rotation: return false
	var location:=registry.get_location(drag_context.item)
	if drag_context.source_container!=null:
		var placement:=drag_context.source_container.get_placement(drag_context.item)
		return location.get("grid")==drag_context.source_container and placement!=null and placement.position==drag_context.source_placement
	if drag_context.source_equipment_slot>=0: return location.kind==&"equipment" and location.slot==drag_context.source_equipment_slot
	return location.kind==&"world" and drag_data.has("world") and location.node==drag_data.world.get_ref()

func _move_to_grid(item: InventoryItemInstance, grid: InventoryGrid, cell: Vector2i, preview_rotated: bool) -> bool:
	if mode==Mode.CONTAINER_LOOT:
		return ExternalInventoryTransfer.transfer(container_access,item,grid.get_transactions(),{"kind":&"grid","grid":grid,"position":cell,"rotated":preview_rotated})
	return inventory.transactions.move(item,grid,cell,preview_rotated)

func can_drop_on_grid(data: Dictionary, grid: InventoryGrid, cell: Vector2i) -> bool:
	if transactions_locked() or not data.has("item"): return false
	var target: InventoryItemInstance = grid.get_item_at_cell(cell)
	if target!=null and target!=data.item and data.item.definition.category==ItemDefinition.Category.AMMO:
		return InventoryDragCandidateResolver.can_load(data.item,target) if target.definition.category==ItemDefinition.Category.MAGAZINE else InventoryDragCandidateResolver.can_stack(data.item,target)
	return grid.can_place(data.item,cell,data.rotated)

func drop_on_grid(data: Dictionary, grid: InventoryGrid, cell: Vector2i) -> bool:
	if not data.has("item") or transactions_locked(): return false
	var item: InventoryItemInstance = data.item
	var target: InventoryItemInstance = grid.get_item_at_cell(cell)
	var ok: bool
	if data.has("world"):
		if not is_vicinity_item(item): return false
		ok=inventory.transactions.pickup_world_ammo_into(data.world.get_ref(),target).success if target!=null else inventory.transactions.pickup_world_item_to_grid(data.world.get_ref(),grid,cell,data.rotated).success
	elif target!=null and target!=item and item.definition.category==ItemDefinition.Category.AMMO:
		if mode==Mode.CONTAINER_LOOT: ok=ExternalInventoryTransfer.transfer_ammo(container_access,item,target)>0
		else: ok = inventory.transactions.load_ammo_into_magazine(item,target,item.stack_count)>0 if target.definition.category==ItemDefinition.Category.MAGAZINE else inventory.transactions.merge_stacks(item,target)>0
	else: ok = _move_to_grid(item,grid,cell,data.rotated)
	if not ok and status != null: status.text="Invalid placement, compatibility, or inventory locked"
	return ok

func drop_on_equipment(data: Dictionary, slot: int) -> bool:
	if not data.has("item") or transactions_locked(): return false
	if data.has("world"):
		return is_vicinity_item(data.item) and inventory.transactions.pickup_world_item(data.world.get_ref(),{"kind":&"equipment","slot":slot},true).success
	if data.item.get_owner_registry()==inventory.transactions: return inventory.transactions.equip(data.item,slot)
	if mode==Mode.CONTAINER_LOOT: return data.has("item") and ExternalInventoryTransfer.transfer(container_access,data.item,inventory.transactions,{"kind":&"equipment","slot":slot})
	return data.has("item") and inventory.transactions.equip(data.item,slot)

func _split_selected() -> void:
	if selected_item==null or transactions_locked() or selected_item.get_owner_registry()==null or selected_item.get_owner_registry().split_stack(selected_item,int(split_amount.value))==null: status.text="Split unavailable: check ammo, quantity and space"

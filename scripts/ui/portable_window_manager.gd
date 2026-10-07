class_name PortableWindowManager
extends RefCounted

var screen: InventoryUI
var surface: Control
var windows: Dictionary={}
var before_close: Callable

func _init(owner_screen: InventoryUI) -> void:
	screen=owner_screen
	surface=Control.new()
	surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(surface)

func open_container(item: InventoryItemInstance, ancestor: PortableContainerWindow=null) -> PortableContainerWindow:
	if item==null or not item.definition.has_capability(&"portable_container") or not screen.can_access_item(item) or screen.is_item_busy(item): return null
	validate_windows()
	if windows.has(item):
		bring_to_front(windows[item])
		return windows[item]
	if ancestor!=null and (not windows.has(ancestor.item) or windows[ancestor.item]!=ancestor): return null
	var window:=PortableContainerWindow.new()
	window.configure(item,self,ancestor)
	window.position=Vector2(48,48)+Vector2(280,40)*windows.size()
	surface.add_child(window)
	window.clamp_position()
	windows[item]=window
	return window

func bring_to_front(window: PortableContainerWindow) -> void:
	if window.get_parent()==surface: surface.move_child(window,surface.get_child_count()-1)

func close_window(window: PortableContainerWindow) -> void:
	if not is_instance_valid(window) or not windows.has(window.item): return
	for child: PortableContainerWindow in windows.values().duplicate():
		if child.parent_window==window: close_window(child)
	windows.erase(window.item)
	if window.get_parent()==surface: surface.remove_child(window)
	screen.on_portable_window_closing(window.item)
	if before_close.is_valid(): before_close.call(window.item)
	window.queue_free()

func close_all() -> void:
	for window: PortableContainerWindow in windows.values().duplicate(): close_window(window)

func validate_windows() -> void:
	for window: PortableContainerWindow in windows.values().duplicate():
		if not windows.has(window.item): continue
		if not screen.can_access_item(window.item) or screen.item_location_signature(window.item)!=window.location_signature:
			close_window(window)
		else: window.refresh_contents()
		if windows.has(window.item): window.clamp_position()

func window_at(pointer: Vector2) -> PortableContainerWindow:
	var controls: Array=surface.get_children()
	controls.reverse()
	for control in controls:
		if control is PortableContainerWindow and control.get_global_rect().has_point(pointer): return control
	return null

func get_views(pointer: Variant=null) -> Array[InventoryGridView]:
	var result: Array[InventoryGridView]=[]
	var controls: Array=surface.get_children()
	controls.reverse()
	for control in controls:
		if not control is PortableContainerWindow: continue
		var window: PortableContainerWindow=control
		if pointer!=null and window.get_global_rect().has_point(pointer): return window.views.duplicate()
		result.append_array(window.views)
	if pointer!=null: result.append_array(screen.views)
	return result

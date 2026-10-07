class_name ItemContextMenu
extends PopupMenu

var screen: InventoryUI
var _item_ref: WeakRef
var _window_ref: WeakRef
var _signature: Array=[]
var _descriptors: Array[ItemActionDescriptor]=[]

func configure(owner_screen: InventoryUI) -> void:
	screen=owner_screen
	id_pressed.connect(_execute)

func open_for(item: InventoryItemInstance, pointer: Vector2, parent_window: PortableContainerWindow=null) -> void:
	close_menu()
	_descriptors=ItemActionResolver.resolve(item,screen)
	if _descriptors.is_empty(): return
	_item_ref=weakref(item)
	_window_ref=weakref(parent_window) if parent_window!=null else null
	_signature=screen.action_signature(item)
	for index in range(_descriptors.size()):
		var descriptor:=_descriptors[index]
		add_item(descriptor.label,index)
		set_item_disabled(index,not descriptor.enabled)
		set_item_tooltip(index,descriptor.disabled_reason)
	position=Vector2i(pointer)
	size=Vector2i.ZERO
	popup()

func close_menu() -> void:
	hide()
	clear()
	_item_ref=null
	_window_ref=null
	_signature.clear()
	_descriptors.clear()

func validate_context() -> void:
	if not visible: return
	var item: InventoryItemInstance=_item_ref.get_ref() if _item_ref!=null else null
	if not screen.can_access_item(item) or screen.is_item_busy(item) or screen.action_signature(item)!=_signature: close_menu()

func _execute(index: int) -> void:
	var item: InventoryItemInstance=_item_ref.get_ref() if _item_ref!=null else null
	var window: PortableContainerWindow=_window_ref.get_ref() if _window_ref!=null else null
	var signature: Array=_signature.duplicate(true)
	var action_id: StringName=_descriptors[index].id if index>=0 and index<_descriptors.size() else &""
	close_menu()
	if screen.action_signature(item)!=signature: return
	if action_id==ItemActionDescriptor.SPLIT:
		screen.open_split_dialog(item)
	else:
		var result: Variant=screen.action_executor.execute(action_id,item,{"signature":signature,"parent_window":window})
		if action_id==ItemActionDescriptor.INSPECT and result is Dictionary: screen.show_inspection(result)

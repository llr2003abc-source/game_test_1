class_name AmmoSplitDialog
extends PanelContainer

var screen: InventoryUI
var slider: HSlider
var amount: SpinBox
var _item_ref: WeakRef
var _signature: Array
var _syncing: bool=false

func configure(item: InventoryItemInstance, owner_screen: InventoryUI) -> void:
	screen=owner_screen
	_item_ref=weakref(item)
	_signature=screen.action_signature(item)
	var column:=VBoxContainer.new()
	add_child(column)
	var caption:=Label.new()
	caption.text="Split %s (%d rounds)"%[item.definition.display_name,item.stack_count]
	column.add_child(caption)
	slider=HSlider.new()
	slider.min_value=1
	slider.max_value=item.stack_count-1
	slider.step=1
	slider.custom_minimum_size=Vector2(300,30)
	column.add_child(slider)
	amount=SpinBox.new()
	amount.min_value=1
	amount.max_value=item.stack_count-1
	column.add_child(amount)
	slider.value_changed.connect(func(value: float): _sync(value,true))
	amount.value_changed.connect(func(value: float): _sync(value,false))
	slider.value=1
	amount.value=1
	var row:=HBoxContainer.new()
	column.add_child(row)
	var confirm:=Button.new()
	confirm.text="Confirm"
	confirm.pressed.connect(confirm_split)
	row.add_child(confirm)
	var cancel:=Button.new()
	cancel.text="Cancel"
	cancel.pressed.connect(close_dialog)
	row.add_child(cancel)
	position=Vector2(360,280)

func _sync(value: float, from_slider: bool) -> void:
	if _syncing: return
	_syncing=true
	if from_slider: amount.value=value
	else: slider.value=value
	_syncing=false

func is_context_valid() -> bool:
	var item: InventoryItemInstance=_item_ref.get_ref()
	return screen.can_access_item(item) and not screen.is_item_busy(item) and screen.action_signature(item)==_signature

func confirm_split() -> bool:
	if not is_context_valid():
		close_dialog()
		return false
	var item: InventoryItemInstance=_item_ref.get_ref()
	var result: Variant=screen.action_executor.execute(ItemActionDescriptor.SPLIT,item,{"amount":int(amount.value),"signature":_signature})
	if result==null and screen.status!=null: screen.status.text="Split unavailable: source changed or no space"
	close_dialog()
	return result!=null

func close_dialog() -> void:
	hide()
	if screen.split_dialog==self: screen.split_dialog=null
	queue_free()

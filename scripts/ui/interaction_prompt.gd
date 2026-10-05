class_name InteractionPrompt
extends CanvasLayer

var label: Label
func _ready() -> void:
	layer=10
	label=Label.new()
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",18)
	add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.offset_left=-180
	label.offset_right=180
	label.offset_top=40
	label.offset_bottom=120
	get_parent().get_node("PlayerInteractor").prompt_changed.connect(_on_prompt_changed)
	_on_prompt_changed("")

func _on_prompt_changed(text: String) -> void:
	label.text=text
	label.visible=not text.is_empty()

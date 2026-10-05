class_name InventoryDragGhost
extends Control

var context: InventoryDragContext
var caption: String
var cell_size: float

func _init(drag: InventoryDragContext, text: String, pixel_cell_size: float) -> void:
	context = drag
	caption = text
	cell_size = pixel_cell_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func get_body_rect() -> Rect2:
	return Rect2(-context.grab_offset_pixels,Vector2(context.get_preview_size())*cell_size)

func _draw() -> void:
	var rectangle: Rect2 = get_body_rect()
	draw_rect(rectangle,Color(0.16,0.28,0.36,0.72))
	draw_rect(rectangle,Color(0.7,0.85,0.95,0.9),false,2.0)
	var font: Font = get_theme_default_font()
	var lines: PackedStringArray = caption.split("\n")
	var header := Rect2(rectangle.position-Vector2(0,20),Vector2(maxf(rectangle.size.x,font.get_string_size(lines[0],HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+8),20))
	draw_rect(header,Color(0.08,0.12,0.16,0.85))
	draw_string(font,header.position+Vector2(4,14),lines[0],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
	for i in range(1,lines.size()):
		draw_string(font,rectangle.position+Vector2(4,14*i),lines[i],HORIZONTAL_ALIGNMENT_LEFT,rectangle.size.x-8,11,Color.WHITE)

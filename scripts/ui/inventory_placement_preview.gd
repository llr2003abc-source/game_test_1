class_name InventoryPlacementPreview
extends Control

var preview_rect: Rect2
var footprint_size := Vector2i.ONE
var is_valid: bool = false
var kind: StringName
var cell_size: float = 48.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func show_candidate(candidate: Dictionary, pixel_cell_size: float) -> void:
	visible = candidate.get("kind",&"none") != &"none"
	if not visible: return
	preview_rect = candidate.preview_rect
	footprint_size = candidate.footprint_size
	is_valid = candidate.valid
	kind = candidate.kind
	cell_size = pixel_cell_size
	queue_redraw()

func _draw() -> void:
	var color := Color(0.25,0.9,0.45,0.3) if is_valid else Color(1.0,0.25,0.2,0.3)
	var border: Color = Color(color,0.95)
	if kind==&"equipment":
		draw_rect(preview_rect,color)
		draw_rect(preview_rect,border,false,2.0)
	else:
		for y in range(footprint_size.y):
			for x in range(footprint_size.x):
				var rectangle := Rect2(preview_rect.position+Vector2(x,y)*cell_size,Vector2.ONE*cell_size)
				draw_rect(rectangle,color)
				draw_rect(rectangle,border,false,2.0)
	var text: String = "VALID" if is_valid else "INVALID"
	if kind==&"load": text = "LOAD" if is_valid else "INVALID LOAD"
	elif kind==&"stack": text = "MERGE" if is_valid else "INVALID MERGE"
	draw_string(get_theme_default_font(),preview_rect.position-Vector2(0,5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,11,border)

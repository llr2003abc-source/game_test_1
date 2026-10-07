class_name InventoryPlacementPreview
extends Control

var preview_rect: Rect2
var footprint_size := Vector2i.ONE
var is_valid: bool = false
var kind: StringName
var cell_size: float = 48.0
var reason: StringName
var clip_rect: Rect2
var occlusion_rects: Array[Rect2]=[]

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func show_candidate(candidate: Dictionary, pixel_cell_size: float) -> void:
	visible = candidate.get("kind",&"none") not in [&"none",&"world_drop"]
	if not visible: return
	preview_rect = candidate.preview_rect
	footprint_size = candidate.footprint_size
	is_valid = candidate.valid
	kind = candidate.kind
	reason=candidate.get("reason",&"")
	cell_size = pixel_cell_size
	clip_rect=candidate.get("grid_rect",preview_rect)
	occlusion_rects.clear()
	for rectangle: Rect2 in candidate.get("occlusion_rects",[]): occlusion_rects.append(rectangle)
	if kind==&"placement" and not is_valid and not candidate.get("render_invalid",false): visible=false
	if candidate.has("actual_grid_rect"):
		if not candidate.actual_grid_rect.encloses(preview_rect) or not clip_rect.intersects(preview_rect): visible=false
	elif candidate.has("grid_rect") and not candidate.grid_rect.encloses(preview_rect): visible=false
	queue_redraw()

func get_render_regions() -> Array[Rect2]:
	var regions: Array[Rect2]=[preview_rect.intersection(clip_rect)]
	for occluder: Rect2 in occlusion_rects:
		var next: Array[Rect2]=[]
		for region: Rect2 in regions:
			var cut: Rect2=region.intersection(occluder)
			if not cut.has_area():
				next.append(region)
				continue
			for remaining: Rect2 in [Rect2(region.position,Vector2(region.size.x,cut.position.y-region.position.y)),Rect2(Vector2(region.position.x,cut.end.y),Vector2(region.size.x,region.end.y-cut.end.y)),Rect2(Vector2(region.position.x,cut.position.y),Vector2(cut.position.x-region.position.x,cut.size.y)),Rect2(Vector2(cut.end.x,cut.position.y),Vector2(region.end.x-cut.end.x,cut.size.y))]:
				if remaining.has_area(): next.append(remaining)
		regions=next
	return regions

func _draw() -> void:
	var color := Color(0.25,0.9,0.45,0.3) if is_valid else Color(1.0,0.25,0.2,0.3)
	var border: Color = Color(color,0.95)
	var regions: Array[Rect2]=get_render_regions()
	if kind in [&"equipment",&"container_content"]:
		for region: Rect2 in regions:
			draw_rect(region,color)
			draw_rect(region,border,false,2.0)
	else:
		for y in range(footprint_size.y):
			for x in range(footprint_size.x):
				var rectangle := Rect2(preview_rect.position+Vector2(x,y)*cell_size,Vector2.ONE*cell_size)
				for region: Rect2 in regions:
					if not rectangle.intersects(region): continue
					draw_rect(rectangle.intersection(region),color)
					draw_rect(rectangle.intersection(region),border,false,2.0)
	var text: String = "VALID" if is_valid else "INVALID"
	if kind==&"load": text = "LOAD" if is_valid else "INVALID LOAD"
	elif kind==&"stack": text = "MERGE" if is_valid else "INVALID MERGE"
	elif kind==&"container_content": text="STORE INSIDE" if is_valid else String(reason).replace("_"," ")
	var text_position: Vector2=preview_rect.position+Vector2(3,13)
	for region: Rect2 in regions:
		if region.has_point(text_position):
			draw_string(get_theme_default_font(),text_position,text,HORIZONTAL_ALIGNMENT_LEFT,region.end.x-text_position.x,11,border)
			break

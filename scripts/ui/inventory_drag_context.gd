class_name InventoryDragContext
extends RefCounted

var item: InventoryItemInstance
var source_container: InventoryGrid
var source_placement: Vector2i
var source_equipment_slot: int
var source_rotation: bool
var preview_rotation: bool
var grab_offset_pixels: Vector2
var normalized_grab_position: Vector2
var pixel_cell_size: float
var current_target_container: InventoryGrid
var raw_candidate_position := Vector2i(-1,-1)
var resolved_candidate_position := Vector2i(-1,-1)
var is_valid: bool = false
var is_snapped: bool = false
var snap_distance: float = 0.0
var candidate: Dictionary = {}

func _init(original: InventoryItemInstance, cell_size: float = 48.0, grab: Vector2 = Vector2.ZERO, source: InventoryGrid = null, placement: Vector2i = Vector2i(-1,-1), equipment_slot: int = -1) -> void:
	item = original
	pixel_cell_size = cell_size
	source_container = source
	source_placement = placement
	source_equipment_slot = equipment_slot
	source_rotation = item.rotated
	preview_rotation = source_rotation
	grab_offset_pixels = grab
	normalized_grab_position = grab / (Vector2(get_preview_size()) * pixel_cell_size)

func get_preview_size() -> Vector2i:
	return item.get_size(preview_rotation)

func get_ghost_top_left(mouse_position: Vector2) -> Vector2:
	return mouse_position - grab_offset_pixels

func rotate_preview() -> void:
	preview_rotation = not preview_rotation
	grab_offset_pixels = normalized_grab_position * Vector2(get_preview_size()) * pixel_cell_size

func set_candidate(result: Dictionary) -> void:
	candidate = result
	current_target_container = result.get("grid")
	raw_candidate_position = result.get("raw_position",Vector2i(-1,-1))
	resolved_candidate_position = result.get("position",Vector2i(-1,-1))
	is_valid = result.get("valid",false)
	is_snapped = result.get("snapped",false)
	snap_distance = result.get("snap_distance",0.0)

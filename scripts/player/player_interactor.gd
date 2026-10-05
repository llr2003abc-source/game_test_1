class_name PlayerInteractor
extends Node

signal prompt_changed(text: String)
signal interaction_performed(result: Variant)
const INTERACTION_MASK: int = 1 | 8 | 16
@export var interaction_range: float = 2.5
var current_target: Node
var _interaction_requested: bool = false
var _prompt_text: String = ""
@onready var actor: Node = get_parent()
@onready var camera: Camera3D = actor.get_node("Head/Camera3D")

func _ready() -> void:
	process_physics_priority=2

func _unhandled_input(event: InputEvent) -> void:
	if actor.get("inventory_open")!=true and event.is_action_pressed("interact"):
		_interaction_requested=true
		get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	update_target()
	if _interaction_requested:
		_interaction_requested=false
		try_interact()

func update_target() -> Node:
	var target: Node
	if actor.get("inventory_open")!=true:
		var origin: Vector3=camera.global_position
		var query:=PhysicsRayQueryParameters3D.create(origin,origin-camera.global_basis.z*interaction_range,INTERACTION_MASK)
		query.collide_with_areas=true
		query.exclude=[actor.get_rid()]
		var hit: Dictionary=camera.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var candidate: Node=hit.collider
			while candidate!=null and not candidate.has_method("interact"): candidate=candidate.get_parent()
			if candidate!=null and candidate.has_method("can_interact") and candidate.has_method("get_interaction_prompt") and not candidate.is_queued_for_deletion():
				var point: Vector3=candidate.get_interaction_position() if candidate.has_method("get_interaction_position") else hit.position
				if origin.distance_to(point)<=interaction_range and candidate.can_interact(actor): target=candidate
	else: _interaction_requested=false
	current_target=target
	_publish_prompt()
	return target

func try_interact() -> bool:
	if actor.get("inventory_open")==true or not is_instance_valid(current_target) or current_target.is_queued_for_deletion() or not current_target.can_interact(actor): return false
	var result: Variant=current_target.interact(actor)
	interaction_performed.emit(result)
	update_target()
	return result.get("success",false) if result is Dictionary else bool(result)

func _publish_prompt() -> void:
	var text: String=current_target.get_interaction_prompt(actor) if is_instance_valid(current_target) else ""
	if text!=_prompt_text:
		_prompt_text=text
		prompt_changed.emit(text)

class_name PlayerInteractor
extends Node

signal prompt_changed(text: String)
signal interaction_performed(result: Variant)
signal manage_requested(target: Node)
const INTERACTION_MASK: int = 1 | 8 | 16
@export var interaction_range: float = 2.5
@export var hold_manage_threshold: float = 0.35
var current_target: Node
var input_resolver:=InteractionInputResolver.new()
var _short_target: WeakRef
var _prompt_text: String = ""
@onready var actor: Node = get_parent()
@onready var camera: Camera3D = actor.get_node("Head/Camera3D")

func _ready() -> void:
	process_physics_priority=2
	input_resolver.hold_threshold=hold_manage_threshold

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: cancel_interaction()
	if event.is_action_released("interact"):
		var target: Node=input_resolver.release()
		if target!=null and _interaction_allowed(): _short_target=weakref(target)

func _interaction_allowed() -> bool:
	var inventory: PlayerInventoryComponent=actor.get_node_or_null("PlayerInventory")
	return actor.get("inventory_open")!=true and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and (inventory==null or not inventory.transactions.locked)

func cancel_interaction() -> void:
	input_resolver.cancel()
	_short_target=null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_released("interact"):
		var target: Node=input_resolver.release()
		if target!=null and _interaction_allowed(): _short_target=weakref(target)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact",true) and _interaction_allowed():
		input_resolver.press(current_target,event.echo if event is InputEventKey else false)
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	update_target()
	if not _interaction_allowed(): cancel_interaction()
	var managed: Node=input_resolver.tick(delta)
	if managed!=null and managed==current_target: manage_requested.emit(managed)
	if _short_target!=null:
		var target: Node=_short_target.get_ref()
		_short_target=null
		if target!=null and target==current_target and _interaction_allowed(): try_interact()
	_publish_prompt()

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
	if target!=current_target: cancel_interaction()
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
	if input_resolver.pending: text+="\nHOLD F... %d%%"%mini(100,int(input_resolver.elapsed/hold_manage_threshold*100))
	if text!=_prompt_text:
		_prompt_text=text
		prompt_changed.emit(text)

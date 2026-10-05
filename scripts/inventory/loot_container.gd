class_name LootContainer
extends Node3D

@export var container_id: StringName = &"loot_crate_a"
@export var display_name: String = "Loot Crate A"
@export var contents_variant: int = 0
@export var access_range: float = 3.0
var runtime: LootContainerRuntime

func _ready() -> void:
	if runtime==null: runtime=LootContainerFactory.create(container_id,display_name,contents_variant)
	else: runtime.transactions.register_external_container(runtime)
	$DebugLabel3D.text=display_name

func get_external_inventory() -> LootContainerRuntime:
	return runtime

func supports_hold_manage() -> bool:
	return false

func is_interaction_collider(collider: Node) -> bool:
	return collider==$InteractionArea

func get_interaction_position() -> Vector3:
	return $InteractionArea.global_position

func _has_line_of_sight(actor: Node3D) -> bool:
	var camera: Camera3D=actor.get_node_or_null("Head/Camera3D")
	if camera==null: return false
	var excluded: Array[RID]=[]
	if actor is CollisionObject3D: excluded.append(actor.get_rid())
	var query:=PhysicsRayQueryParameters3D.create(camera.global_position,get_interaction_position(),1|8,excluded)
	var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or is_ancestor_of(hit.collider)

func can_access(actor: Node3D) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and runtime!=null and is_instance_valid(actor) and actor.is_inside_tree() and actor.global_position.distance_to(global_position)<=access_range+0.000001 and _has_line_of_sight(actor)

func can_interact(actor: Node3D) -> bool:
	var camera: Camera3D=actor.get_node_or_null("Head/Camera3D")
	var interactor: PlayerInteractor=actor.get_node_or_null("PlayerInteractor")
	var inventory: PlayerInventoryComponent=actor.get_node_or_null("PlayerInventory")
	return can_access(actor) and camera!=null and interactor!=null and inventory!=null and not inventory.transactions.locked and not runtime.transactions.locked and camera.global_position.distance_to(get_interaction_position())<=interactor.interaction_range+0.000001

func get_interaction_prompt(_actor: Node) -> String:
	return "[F] Search "+display_name

func interact(actor: Node3D) -> Dictionary:
	var ui: InventoryUI=actor.get_node_or_null("InventoryUI")
	return {"success":can_interact(actor) and ui!=null and ui.open_container(self)}

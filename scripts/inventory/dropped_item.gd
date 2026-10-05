class_name DroppedItem
extends Node3D

var item: InventoryItemInstance
var _registry: WeakRef
@export var show_debug_label: bool = false

func configure(original: InventoryItemInstance, registry: InventoryTransactionService = null) -> void:
	item = original
	_registry = weakref(registry) if registry!=null else null
	if item.definition.visual_scene != null:
		$VisualRoot.add_child(item.definition.visual_scene.instantiate())
	else:
		var visual:=MeshInstance3D.new()
		var mesh:=BoxMesh.new()
		mesh.size=Vector3(0.18,0.12,0.18)
		visual.mesh=mesh
		$VisualRoot.add_child(visual)

func _ready() -> void:
	var bounds:=AABB()
	for child in $VisualRoot.get_children():
		if child is MeshInstance3D: bounds=bounds.merge(child.transform*child.get_aabb())
	var shape:=BoxShape3D.new()
	shape.size=bounds.size.max(Vector3(0.16,0.16,0.16))+Vector3.ONE*0.08
	$Area3D/CollisionShape3D.shape=shape
	$Area3D/CollisionShape3D.position=bounds.get_center()
	$DebugLabel3D.visible=show_debug_label

func _process(_delta: float) -> void:
	if show_debug_label and item!=null: $DebugLabel3D.text=get_display_info()

func get_display_info() -> String:
	var text: String=item.definition.display_name
	if item.runtime_state is MagazineInstance: text+="\n%d / %d"%[item.runtime_state.get_round_count(),item.runtime_state.definition.capacity]
	elif item.runtime_state is WeaponRuntime: text+="\nCH %d / MAG %d"%[int(item.runtime_state.chambered_round!=null),item.runtime_state.get_magazine_round_count()]
	elif item.definition.category==ItemDefinition.Category.AMMO: text+=" x%d"%item.stack_count
	return text

func get_interaction_prompt(actor: Node) -> String:
	var prefix: String=""
	var inventory: PlayerInventoryComponent=actor.get_node_or_null("PlayerInventory") if is_instance_valid(actor) else null
	if inventory!=null:
		var result:=inventory.transactions.preview_world_pickup(self)
		if result.reason==&"NO_SPACE": prefix="（背包已满）\n"
		elif result.reason==&"PARTIAL_SPACE": prefix="（空间不足：可拾取 %d / %d）\n"%[result.accepted_count,item.stack_count]
		elif result.reason==&"INVENTORY_LOCKED": prefix="（当前无法整理）\n"
	return prefix+"[F] 拾取 "+get_display_info()+"\n[长按 F] 管理附近物品"

func get_interaction_position() -> Vector3:
	return global_position

func can_interact(_actor: Node) -> bool:
	var registry: InventoryTransactionService=_registry.get_ref() if _registry!=null else null
	return not is_queued_for_deletion() and item!=null and item.stack_count>0 and registry!=null and registry.owns_world_item(item,self)

func interact(actor: Node) -> Dictionary:
	var inventory: PlayerInventoryComponent=actor.get_node_or_null("PlayerInventory")
	if inventory==null: return {"success":false,"accepted_count":0,"remaining_count":item.stack_count}
	return inventory.transactions.pickup_world_item(self)

func retire() -> void:
	$Area3D.collision_layer=0
	queue_free()

func _exit_tree() -> void:
	var registry: InventoryTransactionService=_registry.get_ref() if _registry!=null else null
	if registry!=null and registry.world_items.get(item)==self: registry.world_items.erase(item)

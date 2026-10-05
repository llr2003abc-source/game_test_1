extends Node3D

var runtime:=LootContainerRuntime.new()
var allowed: bool=true
func get_external_inventory() -> LootContainerRuntime:
	return runtime
func can_access(actor: Node3D) -> bool:
	return allowed and global_position.distance_to(actor.global_position)<=3.0

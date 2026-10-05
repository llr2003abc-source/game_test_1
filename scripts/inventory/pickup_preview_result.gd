class_name PickupPreviewResult
extends RefCounted

var can_accept_all: bool
var accepted_count: int
var remaining_count: int
var reason: StringName

func _init(accepted: int = 0, remaining: int = 0, why: StringName = &"INVALID_TARGET") -> void:
	accepted_count=accepted
	remaining_count=remaining
	reason=why
	can_accept_all=accepted>0 and remaining==0

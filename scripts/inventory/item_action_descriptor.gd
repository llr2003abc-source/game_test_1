class_name ItemActionDescriptor
extends RefCounted

const INSPECT: StringName=&"inspect"
const DROP: StringName=&"drop"
const SPLIT: StringName=&"split"
const OPEN_CONTAINER: StringName=&"open_container"
const UNLOAD: StringName=&"unload"
const RELOAD_WITH: StringName=&"reload_with"
var id: StringName
var label: String
var enabled: bool=true
var disabled_reason: String=""
var payload: Dictionary={}

func _init(action_id: StringName, caption: String) -> void:
	id=action_id
	label=caption

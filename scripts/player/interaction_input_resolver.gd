class_name InteractionInputResolver
extends RefCounted

var hold_threshold: float = 0.35
var elapsed: float = 0.0
var pending: bool = false
var hold_enabled: bool = true
var _held: bool = false
var _target: WeakRef

func press(target: Node, echo: bool = false, allow_hold: bool = true) -> void:
	if echo or _held or not is_instance_valid(target): return
	_held=true
	pending=true
	hold_enabled=allow_hold
	elapsed=0.0
	_target=weakref(target)

func tick(delta: float) -> Node:
	if not pending or not hold_enabled: return null
	elapsed+=delta
	if elapsed+0.000000001<hold_threshold: return null
	pending=false
	return _target.get_ref()

func release() -> Node:
	var target: Node=_target.get_ref() if pending and _target!=null else null
	pending=false
	_held=false
	_target=null
	return target

func cancel() -> void:
	pending=false
	_target=null

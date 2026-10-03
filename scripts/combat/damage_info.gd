class_name DamageInfo
extends RefCounted

var damage: float = 0.0
var hit_position: Vector3 = Vector3.ZERO
var hit_normal: Vector3 = Vector3.ZERO
var hit_direction: Vector3 = Vector3.ZERO
var hit_zone: StringName = &""
var source: Node
var weapon: Node
var ammo_data: AmmoData

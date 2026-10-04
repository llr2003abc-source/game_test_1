class_name DamageInfo
extends RefCounted

var base_flesh_damage: float = 0.0
# Damage delivered to Health after armor and the Hurtbox body multiplier.
var final_flesh_damage: float = 0.0
var bullet_level: int = 1
var armor_hit_result: ArmorHitResult
var hit_position: Vector3 = Vector3.ZERO
var hit_normal: Vector3 = Vector3.ZERO
var hit_direction: Vector3 = Vector3.ZERO
var hit_zone: StringName = &""
var source: Node
var weapon: Node
var ammo_data: AmmoData

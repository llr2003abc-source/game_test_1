class_name ArmorHitResult
extends RefCounted

var armor_hit: bool = false
var armor_broken_before: bool = false
var armor_broken_after: bool = false
var bullet_level: int = 0
var armor_level: int = 0
var base_armor_damage: float = 0.0
var armor_damage_multiplier: float = 0.0
var final_armor_damage: float = 0.0
var base_flesh_damage: float = 0.0
var flesh_damage_multiplier: float = 1.0
# Before the Hurtbox body multiplier; DamageInfo stores the final Health input.
var final_flesh_damage: float = 0.0
var durability_before: float = 0.0
var durability_after: float = 0.0

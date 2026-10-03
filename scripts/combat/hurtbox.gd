class_name Hurtbox
extends Area3D

@export var damage_multiplier: float = 1.0
@export var hit_zone: StringName = &"torso"
@export var health_component: HealthComponent

func receive_hit(damage_info: DamageInfo) -> void:
	damage_info.hit_zone = hit_zone
	var final_damage: float = damage_info.damage * damage_multiplier
	health_component.apply_damage(final_damage, damage_info)

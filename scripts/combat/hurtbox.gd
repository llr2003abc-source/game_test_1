class_name Hurtbox
extends Area3D

@export var damage_multiplier: float = 1.0
@export var hit_zone: StringName = &"torso"
@export var health_component: HealthComponent
@export var armor_component: ArmorComponent

func receive_hit(damage_info: DamageInfo) -> void:
	if health_component.is_dead():
		return
	damage_info.hit_zone = hit_zone
	var flesh_damage: float = damage_info.base_flesh_damage
	if armor_component != null and damage_info.ammo_data != null:
		damage_info.armor_hit_result = armor_component.resolve_hit(damage_info.ammo_data, hit_zone)
		flesh_damage = damage_info.armor_hit_result.final_flesh_damage
	damage_info.final_flesh_damage = flesh_damage * damage_multiplier
	health_component.apply_damage(damage_info.final_flesh_damage, damage_info)

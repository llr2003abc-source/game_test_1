class_name AmmoData
extends Resource

@export var ammo_name: String = "Ammo"
@export var definition_id: StringName
@export var ammo_type_id: StringName
@export var round_weight_kg: float = 0.0
@export_range(1, 5) var bullet_level: int = 1
@export var flesh_damage: float = 30.0
@export var armor_damage: float = 30.0
@export var muzzle_velocity: float = 800.0
@export var gravity_scale: float = 1.0
@export var max_flight_time: float = 5.0

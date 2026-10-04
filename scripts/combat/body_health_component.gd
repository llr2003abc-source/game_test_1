class_name BodyHealthComponent
extends Node

signal zone_health_changed(zone: StringName, current_health: float, max_health: float)
signal zone_destroyed(zone: StringName, damage_info: DamageInfo)

const ZONES: Array[StringName] = [&"head", &"torso", &"arms", &"legs"]

@export var health_component: HealthComponent
@export var head_max_health: float = 35.0
@export var torso_max_health: float = 85.0
@export var arms_max_health: float = 60.0
@export var legs_max_health: float = 70.0

var current_zone_health: Dictionary[StringName, float] = {}

func _ready() -> void:
	reset_body_health()

func get_zone_max_health(zone: StringName) -> float:
	match zone:
		&"head": return head_max_health
		&"torso": return torso_max_health
		&"arms": return arms_max_health
		&"legs": return legs_max_health
	return 0.0

func get_zone_health(zone: StringName) -> float:
	return current_zone_health.get(zone, 0.0)

func apply_zone_damage(zone: StringName, amount: float, damage_info: DamageInfo = null) -> void:
	if amount <= 0.0 or not current_zone_health.has(zone) or health_component.is_dead():
		return
	var previous_health: float = current_zone_health[zone]
	current_zone_health[zone] = maxf(0.0, previous_health - amount)
	zone_health_changed.emit(zone, current_zone_health[zone], get_zone_max_health(zone))
	# Forward the full damage, including overkill or hits on an already-zero zone.
	health_component.apply_damage(amount, damage_info)
	if previous_health > 0.0 and current_zone_health[zone] == 0.0:
		zone_destroyed.emit(zone, damage_info)

func reset_body_health() -> void:
	for zone in ZONES:
		current_zone_health[zone] = maxf(0.0, get_zone_max_health(zone))
		zone_health_changed.emit(zone, current_zone_health[zone], get_zone_max_health(zone))

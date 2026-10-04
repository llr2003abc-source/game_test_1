class_name BodyInjuryComponent
extends Node

signal injury_started(zone: StringName)
signal injuries_reset()

@export var body_health: BodyHealthComponent
@export var head_recoil_multiplier: float = 1.35
@export var head_spread_multiplier: float = 1.5
@export var torso_movement_multiplier: float = 0.8
@export var arms_recoil_multiplier: float = 1.5
@export var arms_reload_multiplier: float = 1.35
@export var legs_jump_multiplier: float = 0.5

var head_injured: bool = false
var torso_injured: bool = false
var arms_injured: bool = false
var legs_injured: bool = false

func _ready() -> void:
	body_health.zone_destroyed.connect(_on_zone_destroyed)
	for zone in BodyHealthComponent.ZONES:
		if body_health.get_zone_health(zone) == 0.0:
			_on_zone_destroyed(zone, null)

func _on_zone_destroyed(zone: StringName, _damage_info: DamageInfo) -> void:
	if is_zone_injured(zone):
		return
	match zone:
		&"head": head_injured = true
		&"torso": torso_injured = true
		&"arms": arms_injured = true
		&"legs": legs_injured = true
		_: return
	injury_started.emit(zone)

func is_zone_injured(zone: StringName) -> bool:
	match zone:
		&"head": return head_injured
		&"torso": return torso_injured
		&"arms": return arms_injured
		&"legs": return legs_injured
	return false

func get_movement_multiplier() -> float:
	return torso_movement_multiplier if torso_injured else 1.0

func get_recoil_multiplier() -> float:
	return (head_recoil_multiplier if head_injured else 1.0) * (arms_recoil_multiplier if arms_injured else 1.0)

func get_spread_multiplier() -> float:
	return head_spread_multiplier if head_injured else 1.0

func get_reload_multiplier() -> float:
	return arms_reload_multiplier if arms_injured else 1.0

func get_jump_multiplier() -> float:
	return legs_jump_multiplier if legs_injured else 1.0

func reset_injuries() -> void:
	head_injured = false
	torso_injured = false
	arms_injured = false
	legs_injured = false
	injuries_reset.emit()

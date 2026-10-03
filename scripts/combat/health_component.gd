class_name HealthComponent
extends Node

signal health_changed(current_health: float, max_health: float)
signal damaged(amount: float, damage_info: DamageInfo)
signal died(damage_info: DamageInfo)

@export var max_health: float = 100.0

var current_health: float = 0.0
var _dead: bool = false

func _ready() -> void:
	reset_health()

func apply_damage(amount: float, damage_info: DamageInfo = null) -> void:
	if amount <= 0.0 or _dead:
		return
	var previous_health: float = current_health
	current_health = maxf(0.0, current_health - amount)
	_dead = current_health == 0.0
	health_changed.emit(current_health, max_health)
	damaged.emit(previous_health - current_health, damage_info)
	if _dead:
		died.emit(damage_info)

func is_dead() -> bool:
	return _dead

func reset_health() -> void:
	current_health = max_health
	_dead = false
	health_changed.emit(current_health, max_health)

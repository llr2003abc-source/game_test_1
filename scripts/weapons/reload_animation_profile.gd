class_name ReloadAnimationProfile
extends Resource

# Empty families are wildcards; exact family matches take precedence.
@export var definition_id: StringName
@export var weapon_animation_family: StringName
@export var magazine_animation_family: StringName
@export var tactical_animation: Animation
@export var empty_animation: Animation
@export_range(0.1,20.0,0.1) var fallback_tactical_duration: float = 2.0
@export_range(0.1,20.0,0.1) var fallback_empty_duration: float = 2.0

class_name WeaponData
extends Resource

@export var weapon_name: String = "Firearm"
@export_range(1, 300, 1) var magazine_size: int = 30
@export_range(1.0, 3000.0, 1.0) var rounds_per_minute: float = 600.0
@export_range(0.1, 10.0, 0.1) var reload_time: float = 2.0
@export_range(1.0, 2000.0, 1.0) var max_range: float = 1000.0
@export var ammo_data: AmmoData

@export_range(0.0, 20.0, 0.05) var hip_spread_degrees: float = 1.5
@export_range(0.0, 20.0, 0.05) var ads_spread_degrees: float = 0.25
@export_range(0.0, 10.0, 0.05) var recoil_pitch: float = 0.8
@export_range(0.0, 10.0, 0.05) var recoil_yaw: float = 0.25

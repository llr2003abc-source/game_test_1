class_name WeaponData
extends Resource

enum FireMode { SEMI, AUTO }
enum FireModel { HITSCAN, PROJECTILE }

@export var weapon_name: String = "Firearm"
@export var definition_id: StringName
@export var weapon_category: StringName
@export var compatible_magazine_type_ids: Array[StringName] = []
@export var animation_family: StringName
@export var supported_fire_modes: Array[FireMode] = [FireMode.SEMI,FireMode.AUTO]
@export var bare_weight_kg: float = 0.0
@export var base_ergonomics: float = 50.0
@export var base_attachment_slots: Array[AttachmentSlotDefinition] = []
@export var reload_profiles: Array[ReloadAnimationProfile] = []
@export var magazine_data: MagazineData
@export var fire_mode: FireMode = FireMode.AUTO
@export var fire_model: FireModel = FireModel.HITSCAN
@export_range(0.0, 2000.0) var gunshot_hearing_radius: float = 200.0
@export_range(1.0, 3000.0, 1.0) var rounds_per_minute: float = 600.0
@export_range(0.1, 10.0, 0.1) var reload_time: float = 2.0
@export_range(1.0, 2000.0, 1.0) var max_range: float = 1000.0

@export_range(0.0, 20.0, 0.05) var hip_spread_degrees: float = 1.5
@export_range(0.0, 20.0, 0.05) var ads_spread_degrees: float = 0.25
@export_range(0.0, 10.0, 0.05) var recoil_pitch: float = 0.8
@export_range(0.0, 10.0, 0.05) var recoil_yaw: float = 0.25

class_name WeaponStatResolver
extends RefCounted

# Base snapshot only. Attachment stat application is a separate gameplay phase.
static func resolve(runtime: WeaponRuntime) -> ComputedWeaponStats:
	var stats:=ComputedWeaponStats.new()
	var data: WeaponData=runtime.weapon_data
	stats.rounds_per_minute=data.rounds_per_minute
	stats.max_range=data.max_range
	stats.hip_spread_degrees=data.hip_spread_degrees
	stats.ads_spread_degrees=data.ads_spread_degrees
	stats.recoil_pitch=data.recoil_pitch
	stats.recoil_yaw=data.recoil_yaw
	stats.ergonomics=data.base_ergonomics
	stats.bare_weight_kg=data.bare_weight_kg
	stats.loaded_magazine_definition=runtime.loaded_magazine.definition if runtime.loaded_magazine!=null else null
	stats.base_attachment_slots=data.base_attachment_slots.duplicate()
	return stats

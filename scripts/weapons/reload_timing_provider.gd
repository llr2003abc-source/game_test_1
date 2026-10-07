class_name ReloadTimingProvider
extends RefCounted

static func get_base_duration(data: WeaponData, magazine: MagazineData, empty: bool) -> float:
	var selected: ReloadAnimationProfile
	var best_score: int=-1
	var magazine_family: StringName=magazine.animation_family if magazine!=null else &""
	for profile in data.reload_profiles:
		if profile==null: continue
		if not profile.weapon_animation_family.is_empty() and profile.weapon_animation_family!=data.animation_family: continue
		if not profile.magazine_animation_family.is_empty() and profile.magazine_animation_family!=magazine_family: continue
		var score: int=int(not profile.weapon_animation_family.is_empty())+int(not profile.magazine_animation_family.is_empty())
		if score>best_score:
			selected=profile
			best_score=score
	if selected==null: return data.reload_time
	var animation: Animation=selected.empty_animation if empty else selected.tactical_animation
	return animation.length if animation!=null else (selected.fallback_empty_duration if empty else selected.fallback_tactical_duration)

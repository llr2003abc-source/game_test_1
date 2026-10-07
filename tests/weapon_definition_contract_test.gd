extends "res://tests/rig_reload_test.gd"

func _run() -> void:
	for path in ["res://scripts/weapons/reload_animation_profile.gd","res://scripts/weapons/reload_timing_provider.gd"]:
		check(FileAccess.file_exists(path),"animation-ready timing foundation available: "+path)
	if failures>0:
		finish()
		return
	var provider: Variant=load("res://scripts/weapons/reload_timing_provider.gd")
	var profile_type: Variant=load("res://scripts/weapons/reload_animation_profile.gd")
	var data:=WeaponData.new()
	data.reload_time=2.0
	data.animation_family=&"weapon_family_b"
	var mag:=MagazineData.new()
	mag.animation_family=&"mag_family_b"
	check(provider.get_base_duration(data,mag,false)==2.0 and provider.get_base_duration(data,mag,true)==2.0,"no profile retains configured legacy tactical and empty fallback")
	var wildcard: Variant=profile_type.new()
	wildcard.fallback_tactical_duration=1.8
	wildcard.fallback_empty_duration=2.6
	var exact: Variant=profile_type.new()
	exact.weapon_animation_family=&"weapon_family_b"
	exact.magazine_animation_family=&"mag_family_b"
	exact.fallback_tactical_duration=2.0
	exact.fallback_empty_duration=3.0
	data.reload_profiles=[wildcard,exact]
	check(provider.get_base_duration(data,mag,false)==2.0 and provider.get_base_duration(data,mag,true)==3.0,"exact families override wildcard and keep Tactical/Empty distinct")
	var animation:=Animation.new()
	animation.length=4.0
	exact.empty_animation=animation
	check(provider.get_base_duration(data,mag,true)==4.0 and provider.get_base_duration(data,mag,false)==2.0,"matching actual Animation length overrides only matching action fallback")
	var alien:=MagazineData.new()
	alien.animation_family=&"other_mag_family"
	check(provider.get_base_duration(data,alien,true)==2.6,"wrong magazine family uses matching wildcard, never unrelated animation")
	data.reload_profiles=[exact]
	check(provider.get_base_duration(data,alien,false)==2.0,"unmatched profiles retain legacy configured fallback")
	data.reload_profiles=[exact,wildcard]
	check(provider.get_base_duration(data,mag,true)==4.0,"selection does not depend on wildcard before or after exact")
	check(provider.get_base_duration(data,null,false)==1.8,"missing magazine selects only wildcard family")
	var runtime:=WeaponRuntime.new()
	var real_mag:=MagazineInstance.new()
	real_mag.definition=mag
	runtime.initialize(data,real_mag,AmmoData.new())
	check(provider.get_base_duration(runtime.weapon_data,runtime.loaded_magazine.definition,false)==2.0,"stored weapon timing does not require Firearm binding")
	var before: Array=[data.reload_time,animation.length,exact.fallback_empty_duration,mag.animation_family]
	var injury:=BodyInjuryComponent.new()
	injury.arms_injured=true
	check(is_equal_approx(provider.get_base_duration(data,mag,true)*injury.get_reload_multiplier(),5.4),"Arms injury scales Animation duration without changing its length")
	check(before==[data.reload_time,animation.length,exact.fallback_empty_duration,mag.animation_family],"duration resolution and injury never mutate shared resources")
	injury.free()
	var armor_ids: Array[StringName]=[]
	for path in ["res://data/armor/test_level_1_armor.tres","res://data/armor/test_level_3_armor.tres","res://data/armor/test_level_6_armor.tres"]:
		var armor: ArmorData=load(path)
		var stable_id: Variant=armor.get("definition_id")
		check(stable_id!=null and not String(stable_id).is_empty(),"Armor has stable ID independent of display name: "+path)
		if stable_id!=null: armor_ids.append(stable_id)
	check(armor_ids.size()==3 and armor_ids[0]!=armor_ids[1] and armor_ids[1]!=armor_ids[2] and armor_ids[0]!=armor_ids[2],"authored Armor IDs are unique")
	for path in ["res://data/weapons/test_rifle.tres","res://data/magazines/test_30rd_magazine.tres","res://data/ammo/test_round.tres","res://data/ammo/weapon1_level2_round.tres"]:
		var definition: Resource=load(path)
		check(not definition.definition_id.is_empty(),"stable definition ID configured: "+path)
	var rifle: WeaponData=load("res://data/weapons/test_rifle.tres")
	check(provider.get_base_duration(rifle,rifle.magazine_data,false)==2.0 and provider.get_base_duration(rifle,rifle.magazine_data,true)==2.0,"current Rifle Tactical/Empty retains original 2.0 balance")
	await coordinator_timing(provider,profile_type)
	finish()

func coordinator_timing(provider: Variant, profile_type: Variant) -> void:
	for empty in [false,true]:
		var inv: Variant=fixture()
		var weapon: InventoryItemInstance=inv.equipment.get_active_item()
		var rt: WeaponRuntime=weapon.runtime_state
		rt.weapon_data=rt.weapon_data.duplicate()
		rt.weapon_data.animation_family=&"test_weapon"
		var replacement: Variant=magazine(30)
		replacement.runtime_state.definition=replacement.runtime_state.definition.duplicate()
		replacement.runtime_state.definition.animation_family=&"incoming"
		rt.loaded_magazine.definition=rt.loaded_magazine.definition.duplicate()
		rt.loaded_magazine.definition.animation_family=&"outgoing"
		var profile: Variant=profile_type.new()
		profile.weapon_animation_family=&"test_weapon"
		profile.magazine_animation_family=&"incoming"
		profile.fallback_tactical_duration=1.4
		profile.fallback_empty_duration=2.4
		rt.weapon_data.reload_profiles=[profile]
		if empty:
			rt.chambered_round=null
			rt.loaded_magazine.clear()
		inv.get_equipped_rig().grids[0].place_item(replacement,Vector2i.ZERO)
		var coord:=ReloadCoordinator.new()
		coord.configure(inv)
		check(coord.request_reload(WeaponRuntime.ReloadType.DROP),"DROP policy accepts incoming magazine for either chamber state")
		check(is_equal_approx(rt.reload_remaining,2.4 if empty else 1.4),"actual coordinator timing uses chamber and incoming family, independent of DROP disposition")
		check(is_equal_approx(provider.get_base_duration(rt.weapon_data,replacement.runtime_state.definition,empty),2.4 if empty else 1.4),"stored and bound timing sources agree")
		rt.tick(2.4)
		check(not inv.transactions.locked and rt.loaded_magazine==replacement.runtime_state and rt.chambered_round!=null,"original reload conservation and completion remain intact")
		coord.free()
		inv.free()

func finish() -> void:
	print("WEAPON_DEFINITION_CONTRACT_RESULT assertions=%d failures=%d"%[assertions,failures])
	quit(1 if failures else 0)

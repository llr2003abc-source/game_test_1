class_name ItemInspection
extends RefCounted

static func describe(item: InventoryItemInstance) -> Dictionary:
	var total: Dictionary=InventoryWeightCalculator.get_item_total_weight(item)
	var base: float=item.definition.weight*item.stack_count
	var details: Dictionary={"name":item.definition.display_name,"definition_id":item.definition.item_id,"category":ItemDefinition.Category.keys()[item.definition.category],"external_size":item.get_size(),"count":item.stack_count,"capabilities":[],"total_weight_kg":total.weight_kg}
	for capability in [&"weapon",&"magazine",&"ammo_stack",&"portable_container"]:
		if item.definition.has_capability(capability): details.capabilities.append(capability)
	var runtime: RefCounted=item.runtime_state
	if runtime is WeaponRuntime:
		base=runtime.weapon_data.bare_weight_kg
		var chamber_weight: float=runtime.chambered_round.round_weight_kg if runtime.chambered_round!=null else 0.0
		var loaded: InventoryItemInstance=item.owned_magazine_item if runtime.loaded_magazine!=null else null
		details.merge({"chamber_loaded":runtime.chambered_round!=null,"magazine_rounds":runtime.get_magazine_round_count(),"fire_mode":WeaponData.FireMode.keys()[runtime.selected_fire_mode],"compatible_magazine_interfaces":runtime.weapon_data.compatible_magazine_type_ids,"bare_weight_kg":base,"loaded_magazine_weight_kg":loaded.get_weight() if loaded!=null else 0.0,"chamber_weight_kg":chamber_weight,"base_ergonomics":runtime.weapon_data.base_ergonomics})
	elif runtime is MagazineInstance:
		base=runtime.definition.empty_weight_kg
		var composition: Dictionary={}
		for round_data in runtime.rounds:
			var key: String=String(round_data.definition_id) if not String(round_data.definition_id).is_empty() else round_data.ammo_name
			composition[key]=composition.get(key,0)+1
		details.merge({"round_count":runtime.get_round_count(),"capacity":runtime.definition.capacity,"magazine_interface":runtime.definition.magazine_type_id,"compatible_ammo_interfaces":runtime.definition.compatible_ammo_type_ids,"composition":composition,"empty_weight_kg":base,"rounds_weight_kg":total.weight_kg-base})
	elif item.definition.has_capability(&"ammo_stack"):
		base=item.definition.ammo_data.round_weight_kg*item.stack_count
	if item.definition.has_capability(&"portable_container"):
		details["storage_sizes"]=[]
		for grid in item.get_storage_grids(): details.storage_sizes.append(grid.size)
	details["base_weight_kg"]=base
	details["contents_weight_kg"]=total.weight_kg-base
	return details

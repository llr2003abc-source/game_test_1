class_name InventoryItemFactory
extends RefCounted

static func create(definition: ItemDefinition, count: int = 1, magazine_rounds: int = -1) -> InventoryItemInstance:
	if definition==null or not definition.is_valid() or count<1 or count>definition.max_stack: return null
	var runtime: RefCounted
	match definition.category:
		ItemDefinition.Category.MAGAZINE:
			if definition.magazine_data==null: return null
			runtime = MagazineInstance.new()
			runtime.initialize_full(definition.magazine_data)
		ItemDefinition.Category.PRIMARY_WEAPON,ItemDefinition.Category.SECONDARY_WEAPON,ItemDefinition.Category.PISTOL:
			if definition.weapon_data==null or definition.magazine_item_definition==null: return null
			var initial_magazine := MagazineInstance.new()
			initial_magazine.initialize_full(definition.magazine_item_definition.magazine_data)
			runtime = WeaponRuntime.new()
			runtime.initialize(definition.weapon_data,initial_magazine)
			runtime.chamber_next_round()
		ItemDefinition.Category.RIG: runtime = RigContainerRuntime.new()
		ItemDefinition.Category.BACKPACK: runtime = BackpackContainerRuntime.new()
	var magazine: MagazineInstance=runtime as MagazineInstance
	if runtime is WeaponRuntime: magazine=runtime.loaded_magazine
	if magazine!=null and magazine_rounds>=0:
		if magazine_rounds>magazine.get_round_count(): return null
		while magazine.get_round_count()>magazine_rounds: magazine.pop_round()
	return InventoryItemInstance.new(definition,count,runtime)

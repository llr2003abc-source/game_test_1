class_name EquipmentComponent
extends RefCounted
enum Slot { PRIMARY, SECONDARY, PISTOL, KNIFE, RIG, BACKPACK }
var slots: Dictionary = {Slot.PRIMARY:null,Slot.SECONDARY:null,Slot.PISTOL:null,Slot.KNIFE:null,Slot.RIG:null,Slot.BACKPACK:null}
var active_weapon_slot: Slot = Slot.PRIMARY
var _inventory: Node

func can_equip(item: InventoryItemInstance, slot: int) -> bool:
	if item == null or item.definition == null or not slots.has(slot): return false
	var category: int = item.definition.category
	if slot in [Slot.PRIMARY,Slot.SECONDARY]:
		if category not in [ItemDefinition.Category.PRIMARY_WEAPON,ItemDefinition.Category.SECONDARY_WEAPON] or not item.runtime_state is WeaponRuntime: return false
		if not item.definition.allowed_equipment_slots.is_empty(): return item.definition.allowed_equipment_slots.has(slot)
		return true
	if category != {Slot.PISTOL:ItemDefinition.Category.PISTOL,Slot.KNIFE:ItemDefinition.Category.MELEE,Slot.RIG:ItemDefinition.Category.RIG,Slot.BACKPACK:ItemDefinition.Category.BACKPACK}[slot]: return false
	match slot:
		Slot.PISTOL: return item.runtime_state is WeaponRuntime
		Slot.RIG: return item.runtime_state is RigContainerRuntime
		Slot.BACKPACK: return item.runtime_state is BackpackContainerRuntime
	return true

func equip(item: InventoryItemInstance, slot: int) -> bool:
	return _inventory.transactions.equip(item,slot)

func get_active_item() -> InventoryItemInstance:
	return slots[active_weapon_slot]

func select_weapon_slot(slot: int) -> bool:
	if _inventory.transactions.locked or slot not in [Slot.PRIMARY,Slot.SECONDARY,Slot.PISTOL,Slot.KNIFE] or slots[slot]==null: return false
	active_weapon_slot = slot as Slot
	_inventory._on_inventory_changed()
	return true

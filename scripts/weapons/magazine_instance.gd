class_name MagazineInstance
extends RefCounted

var definition: MagazineData
# Index 0 is the next round presented to the chamber.
var rounds: Array[AmmoData] = []

func initialize_full(magazine_definition: MagazineData) -> void:
	definition = magazine_definition
	rounds.clear()
	for i in range(definition.capacity):
		rounds.append(definition.default_ammo)

func get_round_count() -> int:
	return rounds.size()

func is_empty() -> bool:
	return rounds.is_empty()

func is_full() -> bool:
	return definition != null and rounds.size() >= definition.capacity

func peek_round() -> AmmoData:
	return null if rounds.is_empty() else rounds[0]

func pop_round() -> AmmoData:
	return null if rounds.is_empty() else rounds.pop_front()

func push_round(ammo: AmmoData) -> bool:
	if ammo == null or definition == null or is_full():
		return false
	rounds.append(ammo)
	return true

func clear() -> void:
	rounds.clear()

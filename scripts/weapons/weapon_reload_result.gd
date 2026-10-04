class_name WeaponReloadResult
extends RefCounted

var success: bool
var old_magazine: MagazineInstance
var new_magazine: MagazineInstance
var chambered_round: AmmoData
var reload_type: int

func _init(completed: bool = false, previous: MagazineInstance = null, replacement: MagazineInstance = null, chamber: AmmoData = null, type: int = 0) -> void:
	success = completed
	old_magazine = previous
	new_magazine = replacement
	chambered_round = chamber
	reload_type = type

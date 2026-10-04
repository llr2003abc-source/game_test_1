class_name WeaponFireResult
extends RefCounted

enum FailureReason { NONE, EMPTY, COOLDOWN, RELOADING, DISABLED }

var success: bool
var fired_round: AmmoData
var failure_reason: FailureReason

func _init(round_data: AmmoData = null, reason: FailureReason = FailureReason.NONE) -> void:
	success = round_data != null
	fired_round = round_data
	failure_reason = reason

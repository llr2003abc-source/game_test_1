class_name AcousticEvent
extends RefCounted

const FOOTSTEP_SNEAK: StringName = &"footstep_sneak"
const FOOTSTEP_WALK: StringName = &"footstep_walk"
const FOOTSTEP_SPRINT: StringName = &"footstep_sprint"
const FOOTSTEP_ADS: StringName = &"footstep_ads"
const FOOTSTEP_INJURED: StringName = &"footstep_injured"
const FOOTSTEP_LAND: StringName = &"footstep_land"
const GUNSHOT: StringName = &"gunshot"

var position: Vector3
var radius: float
var category: StringName
var source: Node
var timestamp: float

static func is_event_audible(listener_position: Vector3, event: AcousticEvent) -> bool:
	return listener_position.distance_squared_to(event.position) <= event.radius * event.radius

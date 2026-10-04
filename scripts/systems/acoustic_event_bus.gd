class_name AcousticEventBus
extends Node

signal sound_emitted(event: AcousticEvent)

func emit_sound(position: Vector3, radius: float, category: StringName, source: Node) -> void:
	var event := AcousticEvent.new()
	event.position = position
	event.radius = radius
	event.category = category
	event.source = source
	event.timestamp = Time.get_ticks_msec() / 1000.0
	sound_emitted.emit(event)

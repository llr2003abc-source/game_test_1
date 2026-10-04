extends Node

var events: Array[AcousticEvent] = []

func _ready() -> void:
	get_node("/root/GameplayAcoustics").sound_emitted.connect(_on_sound_emitted)

func _on_sound_emitted(event: AcousticEvent) -> void:
	events.append(event)

func clear_events() -> void:
	events.clear()

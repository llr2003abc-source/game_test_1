class_name AttachmentData
extends Resource

@export var definition_id: StringName
@export var display_name: String
@export var compatible_slot_interfaces: Array[StringName] = []
@export var weight_kg: float = 0.0
@export var provided_slots: Array[AttachmentSlotDefinition] = []

extends MeshInstance3D

func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	queue_free()

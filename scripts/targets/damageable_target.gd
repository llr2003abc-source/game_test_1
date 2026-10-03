extends Node3D

@onready var health: HealthComponent = $HealthComponent
@onready var mesh: Node3D = $Mesh
@onready var health_label: Label3D = $DebugHealthLabel
@onready var reset_timer: Timer = $ResetTimer

func _ready() -> void:
	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	reset_timer.timeout.connect(reset_target)
	_on_health_changed(health.current_health, health.max_health)

func _on_health_changed(current_health: float, max_health: float) -> void:
	mesh.visible = not health.is_dead()
	health_label.text = "DEAD" if health.is_dead() else "%.0f / %.0f" % [current_health, max_health]

func _on_damaged(amount: float, damage_info: DamageInfo) -> void:
	var hit_zone: StringName = damage_info.hit_zone if damage_info != null else &"unknown"
	print("Damage %s: %.0f HP lost; %.0f / %.0f" % [hit_zone, amount, health.current_health, health.max_health])

func _on_died(_damage_info: DamageInfo) -> void:
	reset_timer.start()

func reset_target() -> void:
	reset_timer.stop()
	health.reset_health()

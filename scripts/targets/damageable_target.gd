extends Node3D

@onready var health: HealthComponent = $HealthComponent
@onready var armor: ArmorComponent = $ArmorComponent
@onready var body_health: BodyHealthComponent = $BodyHealthComponent
@onready var injuries: BodyInjuryComponent = $BodyInjuryComponent
@onready var mesh: Node3D = $Mesh
@onready var health_label: Label3D = $DebugHealthLabel
@onready var reset_timer: Timer = $ResetTimer

func _ready() -> void:
	health.health_changed.connect(_on_health_changed)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	armor.armor_changed.connect(_update_debug_label)
	body_health.zone_health_changed.connect(_on_zone_health_changed)
	injuries.injury_started.connect(_on_injury_started)
	injuries.injuries_reset.connect(_update_debug_label)
	reset_timer.timeout.connect(reset_target)
	_on_health_changed(health.current_health, health.max_health)

func _on_health_changed(_current_health: float, _max_health: float) -> void:
	_update_debug_label()

func _on_zone_health_changed(_zone: StringName, _current_health: float, _max_health: float) -> void:
	_update_debug_label()

func _on_injury_started(_zone: StringName) -> void:
	_update_debug_label()

func _update_debug_label() -> void:
	mesh.visible = not health.is_dead()
	var health_text: String = "DEAD" if health.is_dead() else "HP: %.0f / %.0f" % [health.current_health, health.max_health]
	var armor_text: String = "ARMOR: NONE"
	if armor.equipped_armor != null:
		var equipped: ArmorInstance = armor.equipped_armor
		armor_text = "ARMOR: L%d " % equipped.definition.armor_level
		armor_text += "BROKEN" if equipped.is_broken() else "%.0f / %.0f" % [equipped.current_durability, equipped.definition.max_durability]
	var lines: PackedStringArray = [health_text]
	for zone in BodyHealthComponent.ZONES:
		var zone_text: String = "INJURED" if injuries.is_zone_injured(zone) else "%.0f / %.0f" % [body_health.get_zone_health(zone), body_health.get_zone_max_health(zone)]
		lines.append("%s: %s" % [zone.to_upper(), zone_text])
	lines.append(armor_text)
	health_label.text = "\n".join(lines)

func _on_damaged(amount: float, damage_info: DamageInfo) -> void:
	var hit_zone: StringName = damage_info.hit_zone if damage_info != null else &"unknown"
	print("Damage %s: %.0f HP lost; %.0f / %.0f" % [hit_zone, amount, health.current_health, health.max_health])

func _on_died(_damage_info: DamageInfo) -> void:
	reset_timer.start()

func reset_target() -> void:
	reset_timer.stop()
	health.reset_health()
	body_health.reset_body_health()
	injuries.reset_injuries()
	armor.reset_armor()

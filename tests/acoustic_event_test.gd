extends SceneTree

var failures: int = 0
var assertions: int = 0

func check(condition: bool, message: String) -> void:
	assertions += 1
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for path in ["res://scripts/systems/acoustic_event.gd", "res://scripts/systems/acoustic_event_bus.gd", "res://scripts/tests/debug_acoustic_listener.gd"]:
		check(FileAccess.file_exists(path), "required acoustic boundary: " + path)
	if failures > 0:
		finish()
		return
	var bus: Variant = root.get_node_or_null("GameplayAcoustics")
	check(bus != null, "GameplayAcoustics autoload is available to publishers")
	if bus == null:
		finish()
		return
	var event_type: Variant = load("res://scripts/systems/acoustic_event.gd")
	var listener: Variant = load("res://scripts/tests/debug_acoustic_listener.gd").new()
	root.add_child(listener)
	var source := Node3D.new()
	root.add_child(source)
	var categories: Array[StringName] = [&"footstep_sneak", &"footstep_walk", &"footstep_sprint", &"footstep_ads", &"footstep_injured", &"footstep_land", &"gunshot"]
	for category in categories:
		var before: int = listener.events.size()
		bus.emit_sound(Vector3(4, 2, 7), 15.0, category, source)
		check(listener.events.size() == before + 1, "one real bus notification: " + category)
		var event: Variant = listener.events.back()
		check(event.position == Vector3(4, 2, 7) and event.radius == 15.0 and event.category == category and event.source == source and event.timestamp >= 0.0, "listener records complete event and source: " + category)
	for radius in [5.0, 15.0, 20.0, 30.0, 200.0]:
		bus.emit_sound(Vector3(4, 2, 7), radius, &"gunshot", source)
		var event: Variant = listener.events.back()
		check(event_type.is_event_audible(Vector3(4 + radius - 0.1, 2, 7), event), "inside %.1fm boundary" % radius)
		check(event_type.is_event_audible(Vector3(4 + radius, 2, 7), event), "inclusive %.1fm boundary" % radius)
		check(not event_type.is_event_audible(Vector3(4 + radius + 0.1, 2, 7), event), "outside %.1fm boundary" % radius)
		check(not event_type.is_event_audible(Vector3(4, 2 + radius + 0.1, 7), event), "3D distance includes vertical separation %.1fm" % radius)
	var first: Variant = listener.events[0]
	var last: Variant = listener.events.back()
	check(first != last and first.category == &"footstep_sneak" and first.radius == 15.0 and last.timestamp >= first.timestamp, "events remain independent with monotonic timestamps")
	listener.clear_events()
	check(listener.events.is_empty(), "debug listener can clear observations without affecting the bus")
	bus.emit_sound(Vector3.ZERO, 5.0, &"footstep_sneak", source)
	check(listener.events.size() == 1, "bus keeps publishing after listener clears observations")
	listener.free()
	source.free()
	finish()

func finish() -> void:
	print("ACOUSTIC_EVENT_RESULT assertions=%d failures=%d" % [assertions, failures])
	quit(1 if failures > 0 else 0)

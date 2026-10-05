class_name ReloadInputResolver
extends Node

signal reload_requested(type: WeaponRuntime.ReloadType)
@export var reload_double_tap_window: float = 0.22
var pending: bool = false
var elapsed: float = 0.0
var enabled: bool = true

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled: cancel()

func cancel() -> void:
	pending = false
	elapsed = 0.0

func press(echo: bool = false) -> void:
	if not enabled or echo: return
	if pending:
		cancel()
		reload_requested.emit(WeaponRuntime.ReloadType.DROP)
	else:
		pending = true
		elapsed = 0.0

func tick(delta: float) -> void:
	if not pending or not enabled or not is_finite(delta) or delta < 0.0: return
	elapsed += delta
	if elapsed + 0.000000001 >= reload_double_tap_window:
		cancel()
		reload_requested.emit(WeaponRuntime.ReloadType.TACTICAL)

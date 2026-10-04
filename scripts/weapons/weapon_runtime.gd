class_name WeaponRuntime
extends RefCounted

signal state_changed()
signal reload_finished(result: WeaponReloadResult)

enum State { READY, RELOADING, EMPTY }
enum ReloadType { NONE, TACTICAL, DROP }
const TIME_EPSILON: float = 0.000000001

var weapon_data: WeaponData
var chambered_round: AmmoData
var loaded_magazine: MagazineInstance
var selected_fire_mode: WeaponData.FireMode = WeaponData.FireMode.AUTO
var state: State = State.EMPTY
var fire_cooldown_remaining: float = 0.0
var reload_remaining: float = 0.0
var reload_type: ReloadType = ReloadType.NONE
var _reload_magazine: MagazineInstance
# Overshoot available only for requests in the current continuous-fire tick.
var _fire_time_credit: float = 0.0

func initialize(data: WeaponData, magazine: MagazineInstance = null, chamber: AmmoData = null) -> void:
	weapon_data = data
	loaded_magazine = magazine
	chambered_round = chamber
	selected_fire_mode = data.fire_mode if data != null else WeaponData.FireMode.AUTO
	state = State.READY if chamber != null else State.EMPTY
	fire_cooldown_remaining = 0.0
	reload_remaining = 0.0
	reload_type = ReloadType.NONE
	_reload_magazine = null
	_fire_time_credit = 0.0
	state_changed.emit()

func get_magazine_round_count() -> int:
	return loaded_magazine.get_round_count() if loaded_magazine != null else 0

func chamber_next_round() -> bool:
	if state == State.RELOADING or chambered_round != null:
		return false
	if loaded_magazine == null or loaded_magazine.is_empty():
		state = State.EMPTY
		state_changed.emit()
		return false
	chambered_round = loaded_magazine.pop_round()
	state = State.READY
	state_changed.emit()
	return true

func tick(delta: float, allow_catch_up: bool = false) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	_fire_time_credit = 0.0
	if state != State.RELOADING and allow_catch_up and selected_fire_mode == WeaponData.FireMode.AUTO:
		_fire_time_credit = maxf(0.0, delta - fire_cooldown_remaining)
	fire_cooldown_remaining = maxf(0.0, fire_cooldown_remaining - delta)
	if fire_cooldown_remaining <= TIME_EPSILON:
		fire_cooldown_remaining = 0.0
	if state == State.RELOADING:
		reload_remaining = maxf(0.0, reload_remaining - delta)
		if reload_remaining <= TIME_EPSILON:
			reload_remaining = 0.0
			finish_reload()

func try_fire() -> WeaponFireResult:
	if state == State.RELOADING:
		return WeaponFireResult.new(null, WeaponFireResult.FailureReason.RELOADING)
	if chambered_round == null:
		return WeaponFireResult.new(null, WeaponFireResult.FailureReason.EMPTY)
	if weapon_data == null or not is_finite(weapon_data.rounds_per_minute) or weapon_data.rounds_per_minute <= 0.0:
		return WeaponFireResult.new(null, WeaponFireResult.FailureReason.DISABLED)
	var interval: float = 60.0 / weapon_data.rounds_per_minute
	if not is_finite(interval):
		return WeaponFireResult.new(null, WeaponFireResult.FailureReason.DISABLED)
	if fire_cooldown_remaining > TIME_EPSILON:
		return WeaponFireResult.new(null, WeaponFireResult.FailureReason.COOLDOWN)
	var fired_round: AmmoData = chambered_round
	chambered_round = null
	fire_cooldown_remaining = maxf(0.0, interval - _fire_time_credit)
	_fire_time_credit = maxf(0.0, _fire_time_credit - interval)
	chamber_next_round()
	return WeaponFireResult.new(fired_round)

func can_begin_reload(replacement: MagazineInstance) -> bool:
	if weapon_data == null or state == State.RELOADING or replacement == null or replacement == loaded_magazine or replacement.is_empty():
		return false
	return not (chambered_round != null and loaded_magazine != null and loaded_magazine.is_full())

func begin_reload(replacement: MagazineInstance, duration: float, type: ReloadType = ReloadType.TACTICAL) -> bool:
	if not can_begin_reload(replacement) or not is_finite(duration) or duration < 0.0:
		return false
	_reload_magazine = replacement
	reload_remaining = duration
	reload_type = type
	state = State.RELOADING
	_fire_time_credit = 0.0
	state_changed.emit()
	return true

func finish_reload() -> WeaponReloadResult:
	if state != State.RELOADING or reload_remaining > TIME_EPSILON:
		return WeaponReloadResult.new()
	var previous: MagazineInstance = loaded_magazine
	loaded_magazine = _reload_magazine
	_reload_magazine = null
	var completed_type: ReloadType = reload_type
	reload_type = ReloadType.NONE
	reload_remaining = 0.0
	state = State.READY if chambered_round != null else State.EMPTY
	if chambered_round == null and loaded_magazine != null and not loaded_magazine.is_empty():
		chambered_round = loaded_magazine.pop_round()
		state = State.READY
	var result := WeaponReloadResult.new(true, previous, loaded_magazine, chambered_round, completed_type)
	reload_finished.emit(result)
	state_changed.emit()
	return result

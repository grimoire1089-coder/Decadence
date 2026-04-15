extends Node

signal time_changed(day: int, hour: int, minute: int)
signal new_day(day: int)
signal period_changed(period: int)
signal time_pause_changed(paused: bool)

enum TimePeriod {
	DAY,
	NIGHT
}

@export var real_seconds_per_game_minute: float = 1.0

var day: int = 1
var hour: int = 8
var minute: int = 0

var tick_timer: Timer
var _last_period: int = -1
var _pause_sources: Dictionary = {}


func _ready() -> void:
	add_to_group("time_manager")

	tick_timer = Timer.new()
	tick_timer.wait_time = real_seconds_per_game_minute
	tick_timer.one_shot = false
	tick_timer.autostart = false
	add_child(tick_timer)

	tick_timer.timeout.connect(_on_tick)
	tick_timer.start()
	tick_timer.paused = false

	_update_period(true)
	_emit_time_changed()


func _on_tick() -> void:
	add_minutes(1)


func add_minutes(value: int) -> void:
	minute += value

	while minute >= 60:
		minute -= 60
		hour += 1

	while hour >= 24:
		hour -= 24
		day += 1
		new_day.emit(day)

	_update_period()
	_emit_time_changed()


func set_time(target_day: int, target_hour: int, target_minute: int) -> void:
	day = max(1, target_day)
	hour = clamp(target_hour, 0, 23)
	minute = clamp(target_minute, 0, 59)

	_update_period()
	_emit_time_changed()


func request_pause(source: String = "unknown") -> void:
	if source.is_empty():
		source = "unknown"

	var was_paused := is_time_paused()
	_pause_sources[source] = true
	_apply_pause_state(was_paused)


func release_pause(source: String = "unknown") -> void:
	if source.is_empty():
		source = "unknown"

	var was_paused := is_time_paused()
	_pause_sources.erase(source)
	_apply_pause_state(was_paused)


func pause_time(source: String = "manual") -> void:
	request_pause(source)


func resume_time(source: String = "manual") -> void:
	release_pause(source)


func is_time_paused() -> bool:
	return not _pause_sources.is_empty()


func get_pause_sources() -> PackedStringArray:
	var sources := PackedStringArray()
	for key in _pause_sources.keys():
		sources.append(str(key))
	return sources


func get_time_text() -> String:
	return "Day %d  %02d:%02d" % [day, hour, minute]


func get_time_period() -> int:
	if hour >= 18 or hour < 6:
		return TimePeriod.NIGHT
	return TimePeriod.DAY


func is_night() -> bool:
	return get_time_period() == TimePeriod.NIGHT


func _update_period(force: bool = false) -> void:
	var new_period := get_time_period()
	if force or new_period != _last_period:
		_last_period = new_period
		period_changed.emit(new_period)


func _emit_time_changed() -> void:
	time_changed.emit(day, hour, minute)


func _apply_pause_state(was_paused: bool) -> void:
	var now_paused := is_time_paused()

	if tick_timer != null:
		tick_timer.paused = now_paused

	_set_customer_timers_paused(now_paused)

	if now_paused == was_paused:
		return

	time_pause_changed.emit(now_paused)

	if now_paused:
		var reason_text := _build_pause_reason_text()
		_log_system("ゲーム内時間を停止しました%s" % reason_text)
	else:
		_log_system("ゲーム内時間が再開しました")


func _build_pause_reason_text() -> String:
	var sources := get_pause_sources()
	if sources.is_empty():
		return ""
	return "（%s）" % " / ".join(sources)


func _set_customer_timers_paused(paused_value: bool) -> void:
	var targets: Array[Node] = get_tree().get_nodes_in_group("customer_timer_targets")
	for target in targets:
		if target == null:
			continue

		if target is Timer:
			(target as Timer).paused = paused_value
			continue

		if target.has_method("set_paused_by_ui"):
			target.call("set_paused_by_ui", paused_value)
			continue

		if paused_value and target.has_method("pause_customer_timer"):
			target.call("pause_customer_timer")
			continue

		if (not paused_value) and target.has_method("resume_customer_timer"):
			target.call("resume_customer_timer")


func _get_message_log() -> Node:
	return get_node_or_null("/root/MessageLog")


func _log_system(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node == null:
		return

	if log_node.has_method("add_system"):
		log_node.call("add_system", text)
	elif log_node.has_method("add_message"):
		log_node.call("add_message", text, "SYSTEM")

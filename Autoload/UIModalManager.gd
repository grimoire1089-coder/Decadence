extends Node
class_name UIModalManager

signal ui_lock_changed(active: bool)
signal player_input_lock_changed(locked: bool)

const TIME_PAUSE_PREFIX: String = "UI:"
const MANAGER_GROUP: StringName = &"ui_modal_manager"
const TIME_MANAGER_GROUP: StringName = &"time_manager"
const TIME_MANAGER_SCRIPT_NAME: String = "TimeManager.gd"

var _locks: Dictionary = {}


func _ready() -> void:
	add_to_group(MANAGER_GROUP)


func acquire_lock(source: String, lock_player_input: bool = true, pause_time: bool = true) -> void:
	source = source.strip_edges()
	if source.is_empty():
		source = "unknown_ui"

	var player_locked_before: bool = is_player_input_blocked()
	var entry: Dictionary = _locks.get(source, {
		"count": 0,
		"lock_player_input": false,
		"pause_time": false
	})

	entry["count"] = int(entry.get("count", 0)) + 1
	entry["lock_player_input"] = bool(entry.get("lock_player_input", false)) or lock_player_input
	entry["pause_time"] = bool(entry.get("pause_time", false)) or pause_time
	_locks[source] = entry

	if pause_time:
		_request_time_pause(source)

	_emit_lock_state(player_locked_before)


func release_lock(source: String) -> void:
	source = source.strip_edges()
	if source.is_empty():
		source = "unknown_ui"

	var player_locked_before: bool = is_player_input_blocked()

	if _locks.has(source):
		var entry: Dictionary = _locks[source]
		var count: int = int(entry.get("count", 1)) - 1

		if count > 0:
			entry["count"] = count
			_locks[source] = entry
		else:
			_locks.erase(source)

	_release_time_pause(source)
	_emit_lock_state(player_locked_before)


func clear_all_locks() -> void:
	var player_locked_before: bool = is_player_input_blocked()
	var sources: Array = _locks.keys()

	for source_value in sources:
		_release_time_pause(str(source_value))

	_locks.clear()
	_emit_lock_state(player_locked_before)


func is_any_ui_locked() -> bool:
	return not _locks.is_empty()


func is_player_input_blocked() -> bool:
	for entry_value in _locks.values():
		var entry: Dictionary = entry_value as Dictionary
		if bool(entry.get("lock_player_input", false)):
			return true
	return false


func is_source_active(source: String) -> bool:
	return _locks.has(source)


func get_active_sources() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for source_value in _locks.keys():
		result.append(str(source_value))
	return result


func _find_time_manager() -> Node:
	var by_path: Node = get_node_or_null("/root/TimeManager")
	if by_path != null:
		return by_path

	var by_group: Node = get_tree().get_first_node_in_group("time_manager")
	if by_group != null:
		return by_group

	for child in get_tree().root.get_children():
		var script_value: Variant = child.get_script()
		if script_value is Script:
			var script_ref: Script = script_value as Script
			if script_ref != null and script_ref.resource_path.get_file() == TIME_MANAGER_SCRIPT_NAME:
				return child

	return null


func _request_time_pause(source: String) -> void:
	var time_manager: Node = _find_time_manager()
	if time_manager == null:
		return

	var pause_source: String = TIME_PAUSE_PREFIX + source

	if time_manager.has_method("request_pause"):
		time_manager.call("request_pause", pause_source)
	elif time_manager.has_method("pause_time"):
		time_manager.call("pause_time", pause_source)


func _release_time_pause(source: String) -> void:
	var time_manager: Node = _find_time_manager()
	if time_manager == null:
		return

	var pause_source: String = TIME_PAUSE_PREFIX + source

	if time_manager.has_method("release_pause"):
		time_manager.call("release_pause", pause_source)
	elif time_manager.has_method("resume_time"):
		time_manager.call("resume_time", pause_source)


func _emit_lock_state(player_locked_before: bool) -> void:
	var player_locked_now: bool = is_player_input_blocked()
	ui_lock_changed.emit(is_any_ui_locked())

	if player_locked_before != player_locked_now:
		player_input_lock_changed.emit(player_locked_now)

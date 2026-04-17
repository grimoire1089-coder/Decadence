extends Label

var _time_manager: Node = null


func _ready() -> void:
	_time_manager = get_node_or_null("/root/TimeManager")
	if _time_manager == null:
		text = "TimeManager not found"
		return

	if _time_manager.has_signal("time_changed") and not _time_manager.time_changed.is_connected(_on_time_changed):
		_time_manager.time_changed.connect(_on_time_changed)

	if _time_manager.has_signal("time_pause_changed") and not _time_manager.time_pause_changed.is_connected(_on_time_pause_changed):
		_time_manager.time_pause_changed.connect(_on_time_pause_changed)

	_update_text()


func _on_time_changed(_day: int, _hour: int, _minute: int) -> void:
	_update_text()


func _on_time_pause_changed(_paused: bool) -> void:
	_update_text()


func _process(_delta: float) -> void:
	# デバッグ表示。時間UIが止まって見えるときに状態を確認しやすくする。
	_update_text()


func _update_text() -> void:
	if _time_manager == null:
		text = "TimeManager not found"
		return

	var base_text: String = ""
	if _time_manager.has_method("get_time_text"):
		base_text = String(_time_manager.call("get_time_text"))
	else:
		base_text = "Time"

	var running: bool = bool(_time_manager.get("is_running")) if _has_prop(_time_manager, "is_running") else false
	var paused: bool = false
	if _time_manager.has_method("is_time_paused"):
		paused = bool(_time_manager.call("is_time_paused"))

	var pause_sources_text: String = ""
	if _time_manager.has_method("get_pause_sources"):
		var sources_variant: Variant = _time_manager.call("get_pause_sources")
		pause_sources_text = str(sources_variant)

	text = "%s\nrun=%s paused=%s %s" % [base_text, str(running), str(paused), pause_sources_text]


func _has_prop(target: Object, prop_name: String) -> bool:
	for p in target.get_property_list():
		if String(p.get("name", "")) == prop_name:
			return true
	return false

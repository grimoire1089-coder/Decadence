extends PanelContainer

@export var panel_title: String = "BGM音量"
@export var fallback_percent: int = 70

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var slider: HSlider = $MarginContainer/VBoxContainer/HBoxContainer/VolumeSlider
@onready var value_label: Label = $MarginContainer/VBoxContainer/HBoxContainer/ValueLabel
@onready var reset_button: Button = $MarginContainer/VBoxContainer/ResetButton

var _refreshing: bool = false


func _ready() -> void:
	title_label.text = panel_title
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0

	slider.value_changed.connect(_on_slider_value_changed)
	reset_button.pressed.connect(_on_reset_button_pressed)
	_connect_manager_signal()
	_refresh_from_manager()


func _exit_tree() -> void:
	var manager: Node = _get_manager()
	if manager == null:
		return

	var callable := Callable(self, "_on_manager_bgm_volume_changed")
	if manager.has_signal("bgm_volume_changed") and manager.is_connected("bgm_volume_changed", callable):
		manager.disconnect("bgm_volume_changed", callable)


func _connect_manager_signal() -> void:
	var manager: Node = _get_manager()
	if manager == null:
		return

	var callable := Callable(self, "_on_manager_bgm_volume_changed")
	if manager.has_signal("bgm_volume_changed") and not manager.is_connected("bgm_volume_changed", callable):
		manager.connect("bgm_volume_changed", callable)


func _get_manager() -> Node:
	return get_node_or_null("/root/BgmSettingsManager")


func _refresh_from_manager() -> void:
	_refreshing = true

	var percent: int = fallback_percent
	var manager: Node = _get_manager()
	if manager != null and manager.has_method("get_bgm_percent"):
		percent = int(manager.call("get_bgm_percent"))

	slider.value = percent
	value_label.text = "%d%%" % percent

	_refreshing = false


func _on_slider_value_changed(value: float) -> void:
	var percent: int = int(round(value))
	value_label.text = "%d%%" % percent

	if _refreshing:
		return

	var manager: Node = _get_manager()
	if manager != null and manager.has_method("set_bgm_percent"):
		manager.call("set_bgm_percent", percent)


func _on_reset_button_pressed() -> void:
	var manager: Node = _get_manager()
	if manager != null and manager.has_method("reset_to_default"):
		manager.call("reset_to_default")
		return

	slider.value = fallback_percent
	_on_slider_value_changed(fallback_percent)


func _on_manager_bgm_volume_changed(_ratio: float, percent: int) -> void:
	_refreshing = true
	slider.value = percent
	value_label.text = "%d%%" % percent
	_refreshing = false

extends CanvasLayer

@export var stats_manager_path: NodePath = NodePath("/root/PlayerStatsManager")
@export var panel_offset: Vector2 = Vector2(16, 16)
@export var panel_min_size: Vector2 = Vector2(260, 0)
@export var auto_hide_when_missing_manager: bool = false

@onready var _margin: MarginContainer = $MarginContainer
@onready var _panel: PanelContainer = $MarginContainer/PanelContainer
@onready var _hp_value_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/HPBox/Header/ValueLabel
@onready var _mp_value_label: Label = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MPBox/Header/ValueLabel
@onready var _hp_bar: ProgressBar = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/HPBox/HPBar
@onready var _mp_bar: ProgressBar = $MarginContainer/PanelContainer/MarginContainer/VBoxContainer/MPBox/MPBar

var _stats_manager: Node = null


func _ready() -> void:
	_layer_setup()
	_apply_default_styles()
	_resolve_stats_manager()
	_connect_stats_signals()
	_refresh_all()


func _exit_tree() -> void:
	_disconnect_stats_signals()


func _layer_setup() -> void:
	_margin.offset_left = panel_offset.x
	_margin.offset_top = panel_offset.y
	_panel.custom_minimum_size = panel_min_size


func _resolve_stats_manager() -> void:
	_stats_manager = get_node_or_null(stats_manager_path)
	visible = (not auto_hide_when_missing_manager) or _stats_manager != null


func _connect_stats_signals() -> void:
	if _stats_manager == null:
		return

	var hp_callback := Callable(self, "_on_hp_changed")
	var mp_callback := Callable(self, "_on_mp_changed")

	if _stats_manager.has_signal("hp_changed") and not _stats_manager.is_connected("hp_changed", hp_callback):
		_stats_manager.connect("hp_changed", hp_callback)
	if _stats_manager.has_signal("mp_changed") and not _stats_manager.is_connected("mp_changed", mp_callback):
		_stats_manager.connect("mp_changed", mp_callback)


func _disconnect_stats_signals() -> void:
	if _stats_manager == null:
		return

	var hp_callback := Callable(self, "_on_hp_changed")
	var mp_callback := Callable(self, "_on_mp_changed")

	if _stats_manager.has_signal("hp_changed") and _stats_manager.is_connected("hp_changed", hp_callback):
		_stats_manager.disconnect("hp_changed", hp_callback)
	if _stats_manager.has_signal("mp_changed") and _stats_manager.is_connected("mp_changed", mp_callback):
		_stats_manager.disconnect("mp_changed", mp_callback)


func _refresh_all() -> void:
	if _stats_manager == null:
		_update_bar(_hp_bar, _hp_value_label, 0, 100, "HP")
		_update_bar(_mp_bar, _mp_value_label, 0, 100, "MP")
		return

	if _stats_manager.has_method("get_hp") and _stats_manager.has_method("get_max_hp"):
		_on_hp_changed(int(_stats_manager.call("get_hp")), int(_stats_manager.call("get_max_hp")))
	else:
		_update_bar(_hp_bar, _hp_value_label, 0, 100, "HP")

	if _stats_manager.has_method("get_mp") and _stats_manager.has_method("get_max_mp"):
		_on_mp_changed(int(_stats_manager.call("get_mp")), int(_stats_manager.call("get_max_mp")))
	else:
		_update_bar(_mp_bar, _mp_value_label, 0, 100, "MP")


func _on_hp_changed(current_hp: int, max_hp: int) -> void:
	_update_bar(_hp_bar, _hp_value_label, current_hp, max_hp, "HP")


func _on_mp_changed(current_mp: int, max_mp: int) -> void:
	_update_bar(_mp_bar, _mp_value_label, current_mp, max_mp, "MP")


func _update_bar(bar: ProgressBar, value_label: Label, current_value: int, max_value: int, prefix: String) -> void:
	var safe_max: int = max(max_value, 1)
	var safe_value: int = clamp(current_value, 0, safe_max)

	bar.min_value = 0
	bar.max_value = safe_max
	bar.value = safe_value
	bar.tooltip_text = "%s %d / %d" % [prefix, safe_value, safe_max]
	value_label.text = "%d / %d" % [safe_value, safe_max]


func _apply_default_styles() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.11, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.95, 0.85, 0.35, 0.95)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.corner_radius_bottom_left = 8
	_panel.add_theme_stylebox_override("panel", panel_style)

	_apply_bar_style(_hp_bar, Color(0.88, 0.23, 0.23, 1.0))
	_apply_bar_style(_mp_bar, Color(0.25, 0.52, 0.95, 1.0))


func _apply_bar_style(bar: ProgressBar, fill_color: Color) -> void:
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.12, 0.14, 0.18, 0.95)
	background_style.corner_radius_top_left = 6
	background_style.corner_radius_top_right = 6
	background_style.corner_radius_bottom_right = 6
	background_style.corner_radius_bottom_left = 6

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_right = 6
	fill_style.corner_radius_bottom_left = 6

	bar.add_theme_stylebox_override("background", background_style)
	bar.add_theme_stylebox_override("fill", fill_style)
	bar.add_theme_constant_override("outline_size", 0)

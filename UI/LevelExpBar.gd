extends Control

@export var stats_source_path: NodePath
@export var current_exp_getter: StringName = &"get_level_exp"
@export var required_exp_getter: StringName = &"get_exp_to_next_level"
@export var auto_poll: bool = true
@export var poll_interval: float = 0.15

@onready var panel: Panel = $Panel
@onready var exp_bar: ProgressBar = $Panel/MarginContainer/ExpBar
@onready var exp_value_label: Label = $Panel/MarginContainer/ExpBar/CenterContainer/ExpValueLabel

var _stats_source: Node = null
var _poll_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_source = get_node_or_null(stats_source_path)
	_apply_theme()
	_refresh_from_source()


func _process(delta: float) -> void:
	if not auto_poll:
		return

	_poll_time += delta
	if _poll_time < poll_interval:
		return

	_poll_time = 0.0
	_refresh_from_source()


func refresh() -> void:
	_refresh_from_source()


func set_progress_values(current_exp: int, required_exp: int) -> void:
	required_exp = max(required_exp, 1)
	current_exp = clamp(current_exp, 0, required_exp)

	exp_bar.max_value = required_exp
	exp_bar.value = current_exp
	exp_value_label.text = "%d / %d" % [current_exp, required_exp]


func _refresh_from_source() -> void:
	if _stats_source == null and stats_source_path != NodePath():
		_stats_source = get_node_or_null(stats_source_path)

	if _stats_source == null:
		return

	if not _stats_source.has_method(current_exp_getter):
		return
	if not _stats_source.has_method(required_exp_getter):
		return

	var current_exp: int = int(_stats_source.call(current_exp_getter))
	var required_exp: int = int(_stats_source.call(required_exp_getter))

	set_progress_values(current_exp, required_exp)


func _apply_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.09, 0.14, 0.95)
	panel_style.border_color = Color(0.15, 0.65, 1.0, 0.80)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 20
	panel_style.corner_radius_top_right = 20
	panel_style.corner_radius_bottom_right = 20
	panel_style.corner_radius_bottom_left = 20
	panel.add_theme_stylebox_override("panel", panel_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.12, 0.08, 0.95)
	bg_style.corner_radius_top_left = 999
	bg_style.corner_radius_top_right = 999
	bg_style.corner_radius_bottom_right = 999
	bg_style.corner_radius_bottom_left = 999
	exp_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.45, 1.00, 0.45, 1.00)
	fill_style.corner_radius_top_left = 999
	fill_style.corner_radius_top_right = 999
	fill_style.corner_radius_bottom_right = 999
	fill_style.corner_radius_bottom_left = 999
	exp_bar.add_theme_stylebox_override("fill", fill_style)

	exp_value_label.add_theme_color_override("font_color", Color(0.92, 1.0, 0.92, 1.0))
	exp_value_label.add_theme_font_size_override("font_size", 14)
	exp_value_label.add_theme_constant_override("outline_size", 2)
	exp_value_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))

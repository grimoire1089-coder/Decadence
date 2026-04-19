extends Control
class_name TargetInfoUI

@export_node_path("Node") var targeting_controller_path: NodePath
@export_node_path("Node2D") var player_path: NodePath
@export var auto_find_targeting_controller: bool = true
@export var auto_find_player: bool = true
@export var auto_poll: bool = true
@export var poll_interval: float = 0.12
@export var hide_when_no_target: bool = true
@export var show_hp_text: bool = true
@export var show_distance_text: bool = true
@export var pixels_per_meter: float = 16.0
@export_range(0, 3, 1) var distance_decimals: int = 1
@export var distance_prefix: String = "距離"
@export var friendly_subtitle: String = "ALLY TARGET"
@export var hostile_subtitle: String = "ENEMY TARGET"
@export var neutral_subtitle: String = "TARGET"
@export var no_hp_subtitle: String = "INTERACT TARGET"

@onready var panel: Panel = $Panel
@onready var margin_box: MarginContainer = $Panel/MarginContainer
@onready var root_box: VBoxContainer = $Panel/MarginContainer/RootBox
@onready var name_label: Label = $Panel/MarginContainer/RootBox/NameLabel
@onready var subtitle_label: Label = $Panel/MarginContainer/RootBox/SubtitleLabel
@onready var distance_label: Label = $Panel/MarginContainer/RootBox/DistanceLabel
@onready var hp_box: VBoxContainer = $Panel/MarginContainer/RootBox/HpBox
@onready var hp_bar: ProgressBar = $Panel/MarginContainer/RootBox/HpBox/HpBar
@onready var hp_value_label: Label = $Panel/MarginContainer/RootBox/HpBox/HpBar/HpValueLabel

var _targeting_controller: Node = null
var _player: Node2D = null
var _current_target: Node = null
var _poll_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_theme()
	_resolve_targeting_controller()
	_resolve_player()
	_connect_targeting_controller()
	_refresh_from_targeting_controller(true)


func _process(delta: float) -> void:
	if not auto_poll:
		return

	_poll_time += delta
	if _poll_time < max(poll_interval, 0.01):
		return

	_poll_time = 0.0
	_refresh_from_targeting_controller(false)


func refresh() -> void:
	_refresh_from_targeting_controller(true)


func _resolve_targeting_controller() -> void:
	if not targeting_controller_path.is_empty():
		var by_path: Node = get_node_or_null(targeting_controller_path)
		if by_path != null:
			_targeting_controller = by_path
			return

	if not auto_find_targeting_controller:
		return

	var by_group: Node = get_tree().get_first_node_in_group("player_targeting_controller")
	if by_group != null:
		_targeting_controller = by_group
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		var found: Node = current_scene.find_child("TargetingController", true, false)
		if found != null:
			_targeting_controller = found


func _resolve_player() -> void:
	if not player_path.is_empty():
		var by_path: Node = get_node_or_null(player_path)
		if by_path is Node2D:
			_player = by_path as Node2D
			return

	if not auto_find_player:
		return

	var by_group: Node = get_tree().get_first_node_in_group("player")
	if by_group is Node2D:
		_player = by_group as Node2D
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		var found: Node = current_scene.find_child("CharacterBody2D", true, false)
		if found is Node2D:
			_player = found as Node2D


func _connect_targeting_controller() -> void:
	if _targeting_controller == null:
		return
	if not _targeting_controller.has_signal("target_changed"):
		return

	var callback := Callable(self, "_on_target_changed")
	if not _targeting_controller.is_connected("target_changed", callback):
		_targeting_controller.connect("target_changed", callback)


func _refresh_from_targeting_controller(force: bool) -> void:
	if _targeting_controller == null or not is_instance_valid(_targeting_controller):
		_resolve_targeting_controller()
		_connect_targeting_controller()

	if _player == null or not is_instance_valid(_player):
		_resolve_player()

	var next_target: Node = null
	if _targeting_controller != null and _targeting_controller.has_method("get_current_target"):
		var value: Variant = _targeting_controller.call("get_current_target")
		if value is Node:
			next_target = value as Node

	if not force and next_target == _current_target and _current_target != null and is_instance_valid(_current_target):
		_refresh_target_values_only()
		return

	_set_current_target(next_target)


func _set_current_target(target: Node) -> void:
	if target == _current_target:
		_refresh_full_ui()
		return

	if _current_target != null and is_instance_valid(_current_target):
		_disconnect_target_signals(_current_target)

	_current_target = target

	if _current_target != null and is_instance_valid(_current_target):
		_connect_target_signals(_current_target)

	_refresh_full_ui()


func _connect_target_signals(target: Node) -> void:
	if target == null:
		return

	if target.has_signal("hp_changed"):
		var hp_callback := Callable(self, "_on_target_hp_changed")
		if not target.is_connected("hp_changed", hp_callback):
			target.connect("hp_changed", hp_callback)

	if target.has_signal("defeated"):
		var defeated_callback := Callable(self, "_on_target_defeated")
		if not target.is_connected("defeated", defeated_callback):
			target.connect("defeated", defeated_callback)

	var tree_exited_callback := Callable(self, "_on_target_tree_exited").bind(target)
	if not target.tree_exited.is_connected(tree_exited_callback):
		target.tree_exited.connect(tree_exited_callback, CONNECT_ONE_SHOT)


func _disconnect_target_signals(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return

	if target.has_signal("hp_changed"):
		var hp_callback := Callable(self, "_on_target_hp_changed")
		if target.is_connected("hp_changed", hp_callback):
			target.disconnect("hp_changed", hp_callback)

	if target.has_signal("defeated"):
		var defeated_callback := Callable(self, "_on_target_defeated")
		if target.is_connected("defeated", defeated_callback):
			target.disconnect("defeated", defeated_callback)

	var tree_exited_callback := Callable(self, "_on_target_tree_exited").bind(target)
	if target.tree_exited.is_connected(tree_exited_callback):
		target.tree_exited.disconnect(tree_exited_callback)


func _refresh_full_ui() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		name_label.text = ""
		subtitle_label.text = ""
		distance_label.text = ""
		distance_label.visible = false
		hp_box.visible = false
		if hide_when_no_target:
			hide()
		return

	show()
	name_label.text = _get_target_display_name(_current_target)
	var has_hp: bool = _target_has_hp(_current_target)
	hp_box.visible = has_hp
	subtitle_label.text = _get_target_subtitle(_current_target, has_hp)
	_refresh_target_values_only()


func _refresh_target_values_only() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		if hide_when_no_target:
			hide()
		return

	show()
	_refresh_distance_text()

	if not _target_has_hp(_current_target):
		hp_box.visible = false
		return

	hp_box.visible = true
	var current_hp: int = _read_target_current_hp(_current_target)
	var max_hp: int = max(_read_target_max_hp(_current_target), 1)
	current_hp = clampi(current_hp, 0, max_hp)
	_hp_set_values(current_hp, max_hp)


func _refresh_distance_text() -> void:
	if not show_distance_text:
		distance_label.visible = false
		return

	if _player == null or not is_instance_valid(_player):
		_resolve_player()

	if _player == null or _current_target == null:
		distance_label.visible = false
		return

	if not (_current_target is Node2D):
		distance_label.visible = false
		return

	var target_node: Node2D = _current_target as Node2D
	var pixel_distance: float = _player.global_position.distance_to(target_node.global_position)
	var meter_distance: float = pixel_distance
	if pixels_per_meter > 0.0:
		meter_distance = pixel_distance / pixels_per_meter

	distance_label.text = "%s %sm" % [distance_prefix, String.num(meter_distance, distance_decimals)]
	distance_label.visible = true


func _hp_set_values(current_hp: int, max_hp: int) -> void:
	hp_bar.max_value = float(max_hp)
	hp_bar.value = float(current_hp)
	if show_hp_text:
		hp_value_label.text = "%d / %d" % [current_hp, max_hp]
		hp_value_label.visible = true
	else:
		hp_value_label.visible = false


func _get_target_display_name(target: Node) -> String:
	if target.has_method("get_target_display_name"):
		return String(target.call("get_target_display_name"))
	if target.has_method("get_dialog_display_name"):
		return String(target.call("get_dialog_display_name"))
	if "enemy_name" in target:
		return String(target.get("enemy_name"))
	if "npc_name" in target:
		return String(target.get("npc_name"))
	return String(target.name)


func _get_target_subtitle(target: Node, has_hp: bool) -> String:
	if not has_hp:
		return no_hp_subtitle
	if target.is_in_group("hostile_target"):
		return hostile_subtitle
	if target.is_in_group("friendly_target"):
		return friendly_subtitle
	return neutral_subtitle


func _target_has_hp(target: Node) -> bool:
	return target != null and target.has_method("get_hp") and target.has_method("get_max_hp")


func _read_target_current_hp(target: Node) -> int:
	if target == null or not target.has_method("get_hp"):
		return 0
	return int(target.call("get_hp"))


func _read_target_max_hp(target: Node) -> int:
	if target == null or not target.has_method("get_max_hp"):
		return 0
	return int(target.call("get_max_hp"))


func _apply_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.07, 0.11, 0.94)
	panel_style.border_color = Color(0.30, 0.78, 1.0, 0.90)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 18
	panel_style.corner_radius_top_right = 18
	panel_style.corner_radius_bottom_left = 18
	panel_style.corner_radius_bottom_right = 18
	panel.add_theme_stylebox_override("panel", panel_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.10, 0.14, 0.19, 0.96)
	bg_style.corner_radius_top_left = 999
	bg_style.corner_radius_top_right = 999
	bg_style.corner_radius_bottom_left = 999
	bg_style.corner_radius_bottom_right = 999
	hp_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.95, 0.32, 0.32, 1.0)
	fill_style.corner_radius_top_left = 999
	fill_style.corner_radius_top_right = 999
	fill_style.corner_radius_bottom_left = 999
	fill_style.corner_radius_bottom_right = 999
	hp_bar.add_theme_stylebox_override("fill", fill_style)

	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	name_label.add_theme_constant_override("outline_size", 2)
	name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))

	subtitle_label.add_theme_font_size_override("font_size", 11)
	subtitle_label.add_theme_color_override("font_color", Color(0.58, 0.86, 1.0, 0.95))
	subtitle_label.add_theme_constant_override("outline_size", 1)
	subtitle_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.58))

	distance_label.add_theme_font_size_override("font_size", 13)
	distance_label.add_theme_color_override("font_color", Color(0.88, 0.95, 1.0, 0.98))
	distance_label.add_theme_constant_override("outline_size", 1)
	distance_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.58))

	hp_value_label.add_theme_font_size_override("font_size", 14)
	hp_value_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.98, 1.0))
	hp_value_label.add_theme_constant_override("outline_size", 2)
	hp_value_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))


func _on_target_changed(target: Node) -> void:
	_set_current_target(target)


func _on_target_hp_changed(_current_hp: int, _max_hp: int) -> void:
	_refresh_target_values_only()


func _on_target_defeated(_enemy: Variant = null) -> void:
	_set_current_target(null)


func _on_target_tree_exited(target: Node) -> void:
	if target == _current_target:
		_set_current_target(null)

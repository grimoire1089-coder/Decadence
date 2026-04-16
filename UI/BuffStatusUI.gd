extends CanvasLayer
class_name BuffStatusUI

@export_node_path("Node") var target_path: NodePath
@export var panel_offset: Vector2 = Vector2(16, 16)
@export var icon_size: Vector2 = Vector2(72, 72)
@export_range(1, 12, 1) var columns: int = 6
@export var slot_spacing: int = 8
@export var time_label_min_width: float = 42.0
@export var hide_when_empty: bool = true
@export var update_interval: float = 0.1

@onready var _margin: MarginContainer = $TopRightMargin
@onready var _panel: PanelContainer = $TopRightMargin/Panel
@onready var _grid: GridContainer = $TopRightMargin/Panel/Margin/VBox/BuffGrid
@onready var _title: Label = $TopRightMargin/Panel/Margin/VBox.get_node_or_null("Title") as Label

var _target: Node = null
var _slot_views: Dictionary = {}
var _refresh_accumulator: float = 0.0


func _ready() -> void:
	_configure_layout()
	_resolve_target()
	_refresh_views()
	set_process(true)


func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator < update_interval:
		return
	_refresh_accumulator = 0.0

	if _target == null or not is_instance_valid(_target):
		_resolve_target()

	_refresh_views()


func _configure_layout() -> void:
	if _margin == null:
		return

	_margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_container_rect(max(_slot_views.size(), 1))

	if _panel != null:
		_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _grid != null:
		_grid.columns = columns
		_grid.add_theme_constant_override("h_separation", slot_spacing)
		_grid.add_theme_constant_override("v_separation", slot_spacing)

	if _title != null:
		_title.visible = false


func _resolve_target() -> void:
	_target = null

	if not target_path.is_empty():
		var by_path: Node = get_node_or_null(target_path)
		if by_path != null:
			_target = by_path
			return

	var player_node: Node = get_tree().get_first_node_in_group("player")
	if player_node != null:
		_target = player_node


func _refresh_views() -> void:
	var effects: Array = _collect_visible_effects()
	var keys_in_use: Dictionary = {}

	for effect in effects:
		var key: String = _get_effect_key(effect)
		keys_in_use[key] = true
		var slot: Control = _slot_views.get(key, null)
		if slot == null:
			slot = _create_slot_view(key)
			_slot_views[key] = slot
			_grid.add_child(slot)
		_update_slot_view(slot, effect)

	for key in _slot_views.keys():
		if keys_in_use.has(key):
			continue
		var old_slot: Control = _slot_views[key]
		if old_slot != null and is_instance_valid(old_slot):
			old_slot.queue_free()
		_slot_views.erase(key)

	_update_container_rect(max(_slot_views.size(), 1))

	if hide_when_empty and _panel != null:
		_panel.visible = not _slot_views.is_empty()


func _collect_visible_effects() -> Array:
	var results: Array = []
	if _target == null or not is_instance_valid(_target):
		return results

	for child in _target.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if not child.has_method("is_buff_visible"):
			continue
		if not bool(child.call("is_buff_visible")):
			continue
		results.append(child)

	results.sort_custom(func(a, b):
		var a_time := 0.0
		var b_time := 0.0
		if a.has_method("get_remaining_seconds"):
			a_time = float(a.call("get_remaining_seconds"))
		if b.has_method("get_remaining_seconds"):
			b_time = float(b.call("get_remaining_seconds"))
		return a_time > b_time
	)

	return results


func _get_effect_key(effect: Node) -> String:
	if effect.has_method("get_effect_instance_key"):
		return String(effect.call("get_effect_instance_key"))
	return str(effect.get_instance_id())


func _create_slot_view(key: String) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Buff_%s" % key.replace(":", "_")
	panel.custom_minimum_size = _get_slot_size()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_slot_stylebox())

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var root := VBoxContainer.new()
	root.name = "VBox"
	root.add_theme_constant_override("separation", 2)
	margin.add_child(root)

	var icon_holder := CenterContainer.new()
	icon_holder.name = "IconHolder"
	icon_holder.custom_minimum_size = icon_size
	root.add_child(icon_holder)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(icon)

	var fallback := Label.new()
	fallback.name = "FallbackLabel"
	fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fallback.size_flags_vertical = Control.SIZE_EXPAND_FILL
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_holder.add_child(fallback)

	var time_label := Label.new()
	time_label.name = "TimeLabel"
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.custom_minimum_size = Vector2(max(time_label_min_width, icon_size.x), 0)
	root.add_child(time_label)

	return panel


func _update_slot_view(slot: Control, effect: Node) -> void:
	var icon: TextureRect = slot.get_node_or_null("Margin/VBox/IconHolder/Icon") as TextureRect
	var fallback: Label = slot.get_node_or_null("Margin/VBox/IconHolder/FallbackLabel") as Label
	var time_label: Label = slot.get_node_or_null("Margin/VBox/TimeLabel") as Label

	var display_name: String = ""
	if effect.has_method("get_effect_display_name"):
		display_name = String(effect.call("get_effect_display_name"))

	var icon_texture: Texture2D = null
	if effect.has_method("get_effect_icon"):
		icon_texture = effect.call("get_effect_icon") as Texture2D

	if icon != null:
		icon.custom_minimum_size = icon_size
		icon.texture = icon_texture
		icon.visible = icon_texture != null

	if fallback != null:
		fallback.text = _make_fallback_text(display_name)
		fallback.visible = icon_texture == null

	var remaining_seconds: float = 0.0
	if effect.has_method("get_remaining_seconds"):
		remaining_seconds = float(effect.call("get_remaining_seconds"))
	if time_label != null:
		time_label.text = _format_remaining_time(remaining_seconds)

	var tooltip_lines: PackedStringArray = []
	tooltip_lines.append(display_name)
	tooltip_lines.append("残り %s" % _format_remaining_time(remaining_seconds))
	if effect.has_method("get_effect_total_duration_seconds"):
		tooltip_lines.append("効果時間 %.1f秒" % float(effect.call("get_effect_total_duration_seconds")))
	slot.tooltip_text = "\n".join(tooltip_lines)


func _make_fallback_text(display_name: String) -> String:
	var stripped := display_name.strip_edges()
	if stripped.is_empty():
		return "BUFF"
	if stripped.length() <= 3:
		return stripped
	return stripped.substr(0, 3)


func _format_remaining_time(seconds: float) -> String:
	var clamped := maxf(seconds, 0.0)
	if clamped >= 10.0:
		return "%d秒" % int(ceil(clamped))
	return "%.1f秒" % clamped


func _get_slot_size() -> Vector2:
	return Vector2(icon_size.x + 8.0, icon_size.y + 30.0)


func _make_slot_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.11, 0.92)
	style.border_color = Color(0.20, 0.63, 1.0, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	style.shadow_size = 2
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _update_container_rect(slot_count: int) -> void:
	if _margin == null:
		return

	var safe_columns: int = max(columns, 1)
	var visible_slots: int = max(slot_count, 1)
	var used_columns: int = mini(visible_slots, safe_columns)
	var used_rows: int = maxi(int(ceil(float(visible_slots) / float(safe_columns))), 1)
	var slot_size := _get_slot_size()
	var panel_padding_x := 16.0
	var panel_padding_y := 16.0
	var panel_width := used_columns * slot_size.x
	var panel_height := used_rows * slot_size.y

	if used_columns > 1:
		panel_width += float((used_columns - 1) * slot_spacing)
	if used_rows > 1:
		panel_height += float((used_rows - 1) * slot_spacing)

	panel_width += panel_padding_x
	panel_height += panel_padding_y

	_margin.offset_left = panel_offset.x
	_margin.offset_right = panel_offset.x + panel_width
	_margin.offset_top = panel_offset.y
	_margin.offset_bottom = panel_offset.y + panel_height

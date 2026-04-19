extends CanvasLayer

signal active_slot_changed(slot_index: int)
signal skill_slot_pressed(slot_index: int)
signal slot_skill_assigned(slot_index: int, skill_id: String)
signal slot_cleared(slot_index: int)
signal auto_attack_toggled(enabled: bool)

const DEFAULT_KEY_LABELS: PackedStringArray = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]

@export_range(1, 10, 1) var slot_count: int = 10
@export var bottom_offset: int = 24
@export var slot_size: Vector2 = Vector2(72, 72)
@export var slot_spacing: int = 8
@export var consume_number_key_input: bool = true
@export var allow_mouse_select: bool = true
@export var show_empty_tooltip: bool = false

@export_group("Auto Attack")
@export var show_auto_attack_button: bool = true
@export var auto_attack_button_size: Vector2 = Vector2(72, 72)
@export var tab_toggles_auto_attack: bool = true
@export var auto_attack_label_text: String = "AT"

@onready var _bottom_margin: MarginContainer = $BottomMargin
@onready var _slot_row: HBoxContainer = $BottomMargin/CenterContainer/SlotRow

var active_slot_index: int = 0
var _slots: Array = []
var _slot_views: Array = []

var _auto_attack_enabled: bool = false
var _auto_attack_view: Dictionary = {}
var _auto_attack_icon: Texture2D = null


func _ready() -> void:
	add_to_group("skill_hotbar_ui")
	_configure_layout()
	_ensure_slot_data_size()
	_rebuild_slots()
	select_slot(active_slot_index, false)
	_refresh_auto_attack_view()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if tab_toggles_auto_attack and event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.pressed and not key_event.echo and _is_auto_attack_toggle_key(key_event):
			toggle_auto_attack()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		var slot_index: int = _event_to_slot_index(event)
		if slot_index < 0 or slot_index >= slot_count:
			return

		select_slot(slot_index)
		emit_signal("skill_slot_pressed", slot_index)

		if consume_number_key_input:
			get_viewport().set_input_as_handled()


func select_slot(slot_index: int, emit_changed: bool = true) -> void:
	if slot_count <= 0:
		active_slot_index = 0
		return

	var clamped_index: int = clampi(slot_index, 0, slot_count - 1)
	var changed: bool = active_slot_index != clamped_index
	active_slot_index = clamped_index
	_refresh_slot_visuals()

	if emit_changed and changed:
		emit_signal("active_slot_changed", active_slot_index)


func get_active_slot_index() -> int:
	return active_slot_index


func get_active_slot_number() -> int:
	return active_slot_index + 1


func set_slot_skill(slot_index: int, skill_id: String, display_name: String = "", icon: Texture2D = null) -> void:
	_ensure_slot_data_size()
	if not _is_valid_slot_index(slot_index):
		return

	_slots[slot_index]["skill_id"] = skill_id
	_slots[slot_index]["display_name"] = display_name
	_slots[slot_index]["icon"] = icon
	_slots[slot_index]["resource"] = null
	_slots[slot_index]["resource_path"] = ""
	_slots[slot_index]["cooldown_ratio"] = 0.0
	_slots[slot_index]["cooldown_text"] = ""
	_refresh_slot(slot_index)
	slot_skill_assigned.emit(slot_index, skill_id)


func set_slot_skill_resource(slot_index: int, skill: Resource) -> void:
	_ensure_slot_data_size()
	if not _is_valid_slot_index(slot_index):
		return
	if skill == null:
		clear_slot(slot_index)
		return

	var skill_id: String = ""
	var display_name: String = ""
	var icon: Texture2D = null

	if skill.has_method("get"):
		skill_id = String(skill.get("skill_id"))
		display_name = String(skill.get("display_name"))
		var icon_value: Variant = skill.get("icon")
		if icon_value is Texture2D:
			icon = icon_value as Texture2D

	_slots[slot_index]["skill_id"] = skill_id
	_slots[slot_index]["display_name"] = display_name
	_slots[slot_index]["icon"] = icon
	_slots[slot_index]["resource"] = skill
	_slots[slot_index]["resource_path"] = String(skill.resource_path)
	_slots[slot_index]["cooldown_ratio"] = 0.0
	_slots[slot_index]["cooldown_text"] = ""
	_refresh_slot(slot_index)
	slot_skill_assigned.emit(slot_index, skill_id)


func clear_slot(slot_index: int) -> void:
	_ensure_slot_data_size()
	if not _is_valid_slot_index(slot_index):
		return

	_slots[slot_index] = _make_empty_slot_data(slot_index)
	_refresh_slot(slot_index)
	slot_cleared.emit(slot_index)


func set_slot_cooldown(slot_index: int, ratio: float, label_text: String = "") -> void:
	_ensure_slot_data_size()
	if not _is_valid_slot_index(slot_index):
		return

	_slots[slot_index]["cooldown_ratio"] = clampf(ratio, 0.0, 1.0)
	_slots[slot_index]["cooldown_text"] = label_text
	_refresh_slot(slot_index)


func get_slot_skill_id(slot_index: int) -> String:
	_ensure_slot_data_size()
	if not _is_valid_slot_index(slot_index):
		return ""
	return String(_slots[slot_index].get("skill_id", ""))


func get_slot_skill_display_name(slot_index: int) -> String:
	_ensure_slot_data_size()
	if not _is_valid_slot_index(slot_index):
		return ""
	return String(_slots[slot_index].get("display_name", ""))


func get_slot_skill_resource(slot_index: int) -> Resource:
	_ensure_slot_data_size()
	if not _is_valid_slot_index(slot_index):
		return null
	var value: Variant = _slots[slot_index].get("resource", null)
	if value is Resource:
		return value as Resource
	return null


func get_slot_skill_resource_path(slot_index: int) -> String:
	_ensure_slot_data_size()
	if not _is_valid_slot_index(slot_index):
		return ""
	return String(_slots[slot_index].get("resource_path", ""))


func is_auto_attack_enabled() -> bool:
	return _auto_attack_enabled


func set_auto_attack_enabled(enabled: bool, emit_signal_flag: bool = true) -> void:
	var changed: bool = _auto_attack_enabled != enabled
	_auto_attack_enabled = enabled
	_refresh_auto_attack_view()

	if changed and emit_signal_flag:
		auto_attack_toggled.emit(_auto_attack_enabled)


func toggle_auto_attack() -> void:
	set_auto_attack_enabled(not _auto_attack_enabled)


func set_auto_attack_icon(icon: Texture2D) -> void:
	_auto_attack_icon = icon
	_refresh_auto_attack_view()


func _configure_layout() -> void:
	_bottom_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bottom_margin.add_theme_constant_override("margin_bottom", bottom_offset)
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_row.add_theme_constant_override("separation", slot_spacing)


func _ensure_slot_data_size() -> void:
	slot_count = clampi(slot_count, 1, 10)

	while _slots.size() < slot_count:
		_slots.append(_make_empty_slot_data(_slots.size()))

	while _slots.size() > slot_count:
		_slots.remove_at(_slots.size() - 1)

	if active_slot_index >= slot_count:
		active_slot_index = slot_count - 1


func _make_empty_slot_data(slot_index: int) -> Dictionary:
	return {
		"skill_id": "",
		"display_name": "",
		"icon": null,
		"resource": null,
		"resource_path": "",
		"cooldown_ratio": 0.0,
		"cooldown_text": "",
		"key_label": _get_key_label(slot_index)
	}


func _get_key_label(slot_index: int) -> String:
	if slot_index >= 0 and slot_index < DEFAULT_KEY_LABELS.size():
		return DEFAULT_KEY_LABELS[slot_index]
	return str(slot_index + 1)


func _rebuild_slots() -> void:
	for child in _slot_row.get_children():
		child.queue_free()

	_slot_views.clear()
	_auto_attack_view = {}

	if show_auto_attack_button:
		_build_auto_attack_button()

	for i in range(slot_count):
		var panel: PanelContainer = PanelContainer.new()
		panel.name = "Slot%02d" % (i + 1)
		panel.custom_minimum_size = slot_size
		panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.clip_contents = true

		var root: Control = Control.new()
		root.name = "Root"
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.offset_left = 0.0
		root.offset_top = 0.0
		root.offset_right = 0.0
		root.offset_bottom = 0.0
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(root)

		var icon_holder: Control = Control.new()
		icon_holder.name = "IconHolder"
		icon_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_holder.offset_left = 5.0
		icon_holder.offset_top = 5.0
		icon_holder.offset_right = -5.0
		icon_holder.offset_bottom = -5.0
		icon_holder.clip_contents = true
		icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(icon_holder)

		var icon: TextureRect = TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_holder.add_child(icon)

		var cooldown_cover: ColorRect = ColorRect.new()
		cooldown_cover.name = "CooldownCover"
		cooldown_cover.color = Color(0.04, 0.05, 0.06, 0.55)
		cooldown_cover.visible = false
		cooldown_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_holder.add_child(cooldown_cover)

		var key_label: Label = Label.new()
		key_label.name = "KeyLabel"
		key_label.text = _get_key_label(i)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_label.position = Vector2(6.0, 3.0)
		key_label.size = Vector2(max(slot_size.x - 12.0, 20.0), 18.0)
		key_label.z_index = 5
		root.add_child(key_label)

		var cooldown_label: Label = Label.new()
		cooldown_label.name = "CooldownLabel"
		cooldown_label.text = ""
		cooldown_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		cooldown_label.offset_left = 0.0
		cooldown_label.offset_top = 0.0
		cooldown_label.offset_right = 0.0
		cooldown_label.offset_bottom = 0.0
		cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown_label.z_index = 10
		root.add_child(cooldown_label)

		var name_label: Label = Label.new()
		name_label.name = "NameLabel"
		name_label.text = ""
		name_label.visible = false
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(name_label)

		if allow_mouse_select:
			panel.gui_input.connect(_on_slot_gui_input.bind(i))
		panel.resized.connect(_on_slot_resized.bind(i))

		_slot_row.add_child(panel)
		_slot_views.append({
			"panel": panel,
			"root": root,
			"icon_holder": icon_holder,
			"key_label": key_label,
			"cooldown_label": cooldown_label,
			"icon": icon,
			"cooldown_cover": cooldown_cover,
			"name_label": name_label
		})

	_refresh_slot_visuals()
	for i in range(slot_count):
		_refresh_slot(i)
	_refresh_auto_attack_view()


func _build_auto_attack_button() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "AutoAttackButton"
	panel.custom_minimum_size = auto_attack_button_size
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.clip_contents = true
	panel.gui_input.connect(_on_auto_attack_gui_input)
	_slot_row.add_child(panel)

	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(root)

	var icon_holder: Control = Control.new()
	icon_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_holder.offset_left = 5.0
	icon_holder.offset_top = 5.0
	icon_holder.offset_right = -5.0
	icon_holder.offset_bottom = -5.0
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(icon_holder)

	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_holder.add_child(icon)

	var key_label: Label = Label.new()
	key_label.name = "KeyLabel"
	key_label.text = "Tab"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_label.position = Vector2(6.0, 3.0)
	key_label.size = Vector2(max(auto_attack_button_size.x - 12.0, 20.0), 18.0)
	key_label.z_index = 5
	root.add_child(key_label)

	var center_label: Label = Label.new()
	center_label.name = "CenterLabel"
	center_label.text = auto_attack_label_text
	center_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_label.z_index = 5
	root.add_child(center_label)

	var state_label: Label = Label.new()
	state_label.name = "StateLabel"
	state_label.text = "OFF"
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_label.position = Vector2(0.0, auto_attack_button_size.y - 22.0)
	state_label.size = Vector2(auto_attack_button_size.x, 18.0)
	state_label.z_index = 5
	root.add_child(state_label)

	_auto_attack_view = {
		"panel": panel,
		"icon": icon,
		"center_label": center_label,
		"state_label": state_label,
		"key_label": key_label
	}


func _refresh_slot_visuals() -> void:
	for i in range(_slot_views.size()):
		var panel: PanelContainer = _slot_views[i]["panel"] as PanelContainer
		var active: bool = i == active_slot_index
		_apply_slot_panel_style(panel, active)


func _refresh_slot(slot_index: int) -> void:
	if not _is_valid_slot_index(slot_index):
		return
	if slot_index >= _slot_views.size():
		return

	var data: Dictionary = _slots[slot_index]
	var view: Dictionary = _slot_views[slot_index]
	var icon: TextureRect = view["icon"] as TextureRect
	var name_label: Label = view["name_label"] as Label
	var key_label: Label = view["key_label"] as Label
	var cooldown_label: Label = view["cooldown_label"] as Label
	var cooldown_cover: ColorRect = view["cooldown_cover"] as ColorRect
	var icon_holder: Control = view["icon_holder"] as Control
	var panel: PanelContainer = view["panel"] as PanelContainer

	key_label.text = String(data.get("key_label", _get_key_label(slot_index)))
	icon.texture = data.get("icon", null) as Texture2D

	var display_name: String = String(data.get("display_name", ""))
	name_label.text = display_name
	name_label.visible = false

	var skill_id: String = String(data.get("skill_id", ""))
	panel.tooltip_text = display_name if not display_name.is_empty() else ("空きスロット" if show_empty_tooltip else "")
	if not skill_id.is_empty() and display_name.is_empty():
		panel.tooltip_text = skill_id

	var cooldown_ratio: float = clampf(float(data.get("cooldown_ratio", 0.0)), 0.0, 1.0)
	var cooldown_text: String = String(data.get("cooldown_text", ""))
	cooldown_label.text = cooldown_text
	cooldown_label.visible = not cooldown_text.is_empty()
	cooldown_cover.visible = cooldown_ratio > 0.001
	if cooldown_ratio > 0.001:
		var holder_height: float = max(icon_holder.size.y, icon_holder.custom_minimum_size.y)
		var cover_height: float = holder_height * cooldown_ratio
		cooldown_cover.offset_left = 0.0
		cooldown_cover.offset_right = 0.0
		cooldown_cover.offset_bottom = 0.0
		cooldown_cover.offset_top = max(holder_height - cover_height, 0.0)
	else:
		cooldown_cover.offset_top = 0.0
		cooldown_cover.offset_bottom = 0.0
		cooldown_cover.offset_left = 0.0
		cooldown_cover.offset_right = 0.0

	_apply_slot_panel_style(panel, slot_index == active_slot_index)


func _refresh_auto_attack_view() -> void:
	if _auto_attack_view.is_empty():
		return

	var panel: PanelContainer = _auto_attack_view.get("panel", null) as PanelContainer
	var icon: TextureRect = _auto_attack_view.get("icon", null) as TextureRect
	var center_label: Label = _auto_attack_view.get("center_label", null) as Label
	var state_label: Label = _auto_attack_view.get("state_label", null) as Label
	if panel == null:
		return

	if icon != null:
		icon.texture = _auto_attack_icon
		icon.visible = _auto_attack_icon != null
	if center_label != null:
		center_label.visible = _auto_attack_icon == null
		center_label.text = auto_attack_label_text
	if state_label != null:
		state_label.text = "ON" if _auto_attack_enabled else "OFF"

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.16, 0.18, 0.95) if _auto_attack_enabled else Color(0.07, 0.09, 0.12, 0.88)
	style.border_color = Color(0.22, 0.95, 0.82, 1.0) if _auto_attack_enabled else Color(0.42, 0.46, 0.54, 0.9)
	style.border_width_left = 3 if _auto_attack_enabled else 2
	style.border_width_top = 3 if _auto_attack_enabled else 2
	style.border_width_right = 3 if _auto_attack_enabled else 2
	style.border_width_bottom = 3 if _auto_attack_enabled else 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = "オート通常攻撃 %s" % ("ON" if _auto_attack_enabled else "OFF")


func _apply_slot_panel_style(panel: PanelContainer, active: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.88) if not active else Color(0.12, 0.15, 0.20, 0.96)
	style.border_color = Color(0.42, 0.46, 0.54, 0.9) if not active else Color(1.0, 0.84, 0.25, 1.0)
	style.border_width_left = 2 if not active else 3
	style.border_width_top = 2 if not active else 3
	style.border_width_right = 2 if not active else 3
	style.border_width_bottom = 2 if not active else 3
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	panel.add_theme_stylebox_override("panel", style)


func _event_to_slot_index(event: InputEventKey) -> int:
	var candidates: Array[int] = []
	if event.physical_keycode != KEY_NONE:
		candidates.append(event.physical_keycode)
	if event.keycode != KEY_NONE and event.keycode != event.physical_keycode:
		candidates.append(event.keycode)

	for code in candidates:
		match code:
			KEY_1, KEY_KP_1:
				return 0
			KEY_2, KEY_KP_2:
				return 1
			KEY_3, KEY_KP_3:
				return 2
			KEY_4, KEY_KP_4:
				return 3
			KEY_5, KEY_KP_5:
				return 4
			KEY_6, KEY_KP_6:
				return 5
			KEY_7, KEY_KP_7:
				return 6
			KEY_8, KEY_KP_8:
				return 7
			KEY_9, KEY_KP_9:
				return 8
			KEY_0, KEY_KP_0:
				return 9

	return -1


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if not allow_mouse_select:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_slot(slot_index)
		emit_signal("skill_slot_pressed", slot_index)
		get_viewport().set_input_as_handled()


func _on_auto_attack_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle_auto_attack()
		get_viewport().set_input_as_handled()


func _on_slot_resized(slot_index: int) -> void:
	_refresh_slot(slot_index)


func _is_valid_slot_index(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slot_count and slot_index < _slots.size()


func _is_auto_attack_toggle_key(event: InputEventKey) -> bool:
	if event.keycode == KEY_TAB or event.physical_keycode == KEY_TAB:
		return true
	return false

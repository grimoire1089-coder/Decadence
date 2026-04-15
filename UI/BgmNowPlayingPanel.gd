extends CanvasLayer

class_name BgmNowPlayingPanel

@export var panel_size: Vector2 = Vector2(360, 108)
@export var margin_right: float = 20.0
@export var margin_bottom: float = 190.0
@export var slide_duration: float = 0.28
@export var visible_duration: float = 2.8
@export var hidden_offset_x: float = 40.0

var panel: PanelContainer = null
var header_label: Label = null
var track_label: Label = null
var detail_label: Label = null
var hide_timer: Timer = null

var _shown_position: Vector2 = Vector2.ZERO
var _hidden_position: Vector2 = Vector2.ZERO
var _active_tween: Tween = null
var _is_visible_panel: bool = false
var _viewport_connected: bool = false
var _hide_timer_connected: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	_ensure_ui_refs()
	_apply_panel_style()
	_update_positions(true)
	_connect_runtime_signals()


func show_track(track_name: String, detail_text: String = "BGMが切り替わりました") -> void:
	if track_name.strip_edges().is_empty():
		return

	_ensure_ui_refs()
	_connect_runtime_signals()

	if header_label == null or track_label == null or detail_label == null or panel == null:
		push_warning("BgmNowPlayingPanel: 必要なUIノードが見つかりません")
		return

	header_label.text = "♪ Now Playing"
	track_label.text = track_name
	detail_label.text = detail_text

	_update_positions(_not_showing())
	_show_panel()


func _connect_runtime_signals() -> void:
	if hide_timer != null:
		hide_timer.one_shot = true
		var timeout_callable: Callable = Callable(self, "_on_hide_timer_timeout")
		if not hide_timer.timeout.is_connected(timeout_callable):
			hide_timer.timeout.connect(timeout_callable)
		_hide_timer_connected = true

	var viewport := get_viewport()
	if viewport != null:
		var size_changed_callable: Callable = Callable(self, "_on_viewport_size_changed")
		if not viewport.size_changed.is_connected(size_changed_callable):
			viewport.size_changed.connect(size_changed_callable)
		_viewport_connected = true


func _ensure_ui_refs() -> void:
	if panel == null:
		panel = get_node_or_null("Panel") as PanelContainer
	if panel == null:
		panel = PanelContainer.new()
		panel.name = "Panel"
		add_child(panel)

	var margin_container := get_node_or_null("Panel/MarginContainer") as MarginContainer
	if margin_container == null:
		margin_container = MarginContainer.new()
		margin_container.name = "MarginContainer"
		panel.add_child(margin_container)
		margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := get_node_or_null("Panel/MarginContainer/VBoxContainer") as VBoxContainer
	if vbox == null:
		vbox = VBoxContainer.new()
		vbox.name = "VBoxContainer"
		margin_container.add_child(vbox)
		vbox.theme_override_constants.separation = 4

	if header_label == null:
		header_label = get_node_or_null("Panel/MarginContainer/VBoxContainer/HeaderLabel") as Label
	if header_label == null:
		header_label = Label.new()
		header_label.name = "HeaderLabel"
		header_label.text = "♪ Now Playing"
		vbox.add_child(header_label)

	if track_label == null:
		track_label = get_node_or_null("Panel/MarginContainer/VBoxContainer/TrackLabel") as Label
	if track_label == null:
		track_label = Label.new()
		track_label.name = "TrackLabel"
		track_label.text = "Track Name"
		track_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(track_label)

	if detail_label == null:
		detail_label = get_node_or_null("Panel/MarginContainer/VBoxContainer/DetailLabel") as Label
	if detail_label == null:
		detail_label = Label.new()
		detail_label.name = "DetailLabel"
		detail_label.text = "BGMが切り替わりました"
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(detail_label)

	if hide_timer == null:
		hide_timer = get_node_or_null("HideTimer") as Timer
	if hide_timer == null:
		hide_timer = Timer.new()
		hide_timer.name = "HideTimer"
		hide_timer.one_shot = true
		add_child(hide_timer)


func _show_panel() -> void:
	if panel == null or hide_timer == null:
		return

	hide_timer.stop()
	_kill_tween()

	if _not_showing():
		panel.position = _hidden_position
		panel.modulate = Color(1.0, 1.0, 1.0, 0.0)

	panel.show()
	_active_tween = create_tween()
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_ease(Tween.EASE_OUT)
	_active_tween.parallel().tween_property(panel, "position", _shown_position, slide_duration)
	_active_tween.parallel().tween_property(panel, "modulate:a", 1.0, slide_duration)
	_active_tween.finished.connect(_on_show_finished, CONNECT_ONE_SHOT)
	_is_visible_panel = true


func _on_show_finished() -> void:
	if hide_timer != null:
		hide_timer.start(visible_duration)


func _on_hide_timer_timeout() -> void:
	_hide_panel()


func _hide_panel() -> void:
	if panel == null:
		return

	_kill_tween()

	_active_tween = create_tween()
	_active_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_ease(Tween.EASE_IN)
	_active_tween.parallel().tween_property(panel, "position", _hidden_position, slide_duration)
	_active_tween.parallel().tween_property(panel, "modulate:a", 0.0, slide_duration)
	_active_tween.finished.connect(_on_hide_finished, CONNECT_ONE_SHOT)


func _on_hide_finished() -> void:
	if panel != null:
		panel.hide()
	_is_visible_panel = false


func _on_viewport_size_changed() -> void:
	_update_positions(_not_showing())


func _update_positions(force_hide_position: bool = false) -> void:
	if panel == null:
		return

	panel.custom_minimum_size = panel_size
	panel.size = panel_size

	var viewport := get_viewport()
	if viewport == null:
		return

	var viewport_rect: Rect2 = viewport.get_visible_rect()
	_shown_position = Vector2(
		viewport_rect.size.x - panel_size.x - margin_right,
		viewport_rect.size.y - panel_size.y - margin_bottom
	)
	_hidden_position = _shown_position + Vector2(panel_size.x + hidden_offset_x, 0.0)

	if force_hide_position:
		panel.position = _hidden_position
		panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
		panel.hide()
	elif _is_visible_panel:
		panel.position = _shown_position
	else:
		panel.position = _hidden_position


func _apply_panel_style() -> void:
	if panel == null:
		return

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.043, 0.063, 0.094, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.298, 0.749, 1.0, 0.72)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 8
	style.content_margin_left = 18.0
	style.content_margin_top = 14.0
	style.content_margin_right = 18.0
	style.content_margin_bottom = 14.0
	panel.add_theme_stylebox_override("panel", style)

	if header_label != null:
		header_label.add_theme_color_override("font_color", Color("7fd7ff"))
		header_label.add_theme_font_size_override("font_size", 16)
	if track_label != null:
		track_label.add_theme_color_override("font_color", Color("f4fbff"))
		track_label.add_theme_font_size_override("font_size", 22)
	if detail_label != null:
		detail_label.add_theme_color_override("font_color", Color("b9d8ea"))
		detail_label.add_theme_font_size_override("font_size", 14)


func _kill_tween() -> void:
	if _active_tween != null and is_instance_valid(_active_tween):
		_active_tween.kill()
	_active_tween = null


func _not_showing() -> bool:
	return panel == null or (not _is_visible_panel) or (not panel.visible)

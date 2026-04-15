extends CanvasLayer

const SLIDE_DURATION := 0.2
const BUTTON_MARGIN := 4.0
const RESTORE_BUTTON_MARGIN := 4.0
const HIDE_PANEL_MARGIN := 12.0

@onready var _panel: PanelContainer = $PanelContainer
@onready var _log_text: RichTextLabel = $PanelContainer/MarginContainer/VBoxContainer/LogText
@onready var _clear_button: Button = $PanelContainer/MarginContainer/VBoxContainer/Header/ClearButton
@onready var _hide_button: Button = $HideButton
@onready var _restore_button: Button = $RestoreButton

var _is_hidden := false
var _shown_panel_position := Vector2.ZERO
var _slide_tween: Tween

func _ready() -> void:
	MessageLog.log_changed.connect(_on_log_changed)
	_clear_button.pressed.connect(_on_clear_button_pressed)
	_hide_button.pressed.connect(_on_hide_button_pressed)
	_restore_button.pressed.connect(_on_restore_button_pressed)
	get_viewport().size_changed.connect(_on_viewport_resized)

	_log_text.bbcode_enabled = true
	_log_text.scroll_active = true
	_log_text.scroll_following = true
	_log_text.selection_enabled = true

	_refresh_log()
	call_deferred("_initialize_slide_ui")

func _initialize_slide_ui() -> void:
	_shown_panel_position = _panel.position
	_update_hidden_layout(false)
	_update_button_visibility()

func _on_log_changed() -> void:
	_refresh_log()

func _refresh_log() -> void:
	var lines: PackedStringArray = []
	var messages: Array[Dictionary] = MessageLog.get_messages()

	for entry in messages:
		var time_text: String = MessageLog.escape_bbcode(str(entry.get("time", "")))
		var category: String = MessageLog.escape_bbcode(str(entry.get("category", "INFO")))
		var message_text: String = MessageLog.escape_bbcode(str(entry.get("text", "")))
		var color: String = MessageLog.get_category_color(str(entry.get("category", "INFO")))

		var line := "[color=#808080][%s][/color] [color=%s][%s][/color] %s" % [
			time_text,
			color,
			category,
			message_text
		]
		lines.append(line)

	_log_text.text = "\n".join(lines)
	call_deferred("_scroll_to_bottom")

func _scroll_to_bottom() -> void:
	var last_line: int = max(_log_text.get_line_count() - 1, 0)
	_log_text.scroll_to_line(last_line)

func _on_clear_button_pressed() -> void:
	MessageLog.clear_messages()

func _on_hide_button_pressed() -> void:
	_set_hidden_state(true)

func _on_restore_button_pressed() -> void:
	_set_hidden_state(false)

func _set_hidden_state(hidden: bool) -> void:
	if _is_hidden == hidden:
		return

	_is_hidden = hidden
	_update_hidden_layout(true)

func _update_hidden_layout(animated: bool) -> void:
	var target_position := _shown_panel_position
	if _is_hidden:
		target_position.x = -_get_panel_size().x - HIDE_PANEL_MARGIN

	if is_instance_valid(_slide_tween):
		_slide_tween.kill()

	if animated:
		_slide_tween = create_tween()
		_slide_tween.set_trans(Tween.TRANS_CUBIC)
		_slide_tween.set_ease(Tween.EASE_OUT)
		_slide_tween.tween_property(_panel, "position", target_position, SLIDE_DURATION)
		_slide_tween.finished.connect(_sync_button_positions)
	else:
		_panel.position = target_position

	_sync_button_positions()
	_update_button_visibility()

func _get_panel_size() -> Vector2:
	var panel_size: Vector2 = _panel.size
	if panel_size == Vector2.ZERO:
		panel_size = _panel.get_combined_minimum_size()
	return panel_size

func _get_button_size(button: Button) -> Vector2:
	var button_size: Vector2 = button.size
	if button_size == Vector2.ZERO:
		button_size = button.get_combined_minimum_size()
	return button_size

func _sync_button_positions() -> void:
	var panel_size := _get_panel_size()
	var hide_button_size := _get_button_size(_hide_button)
	var restore_button_size := _get_button_size(_restore_button)
	var panel_center_y: float = _shown_panel_position.y + (panel_size.y * 0.5)

	_hide_button.position = Vector2(
		_shown_panel_position.x + panel_size.x - BUTTON_MARGIN,
		panel_center_y - (hide_button_size.y * 0.5)
	)

	_restore_button.position = Vector2(
		RESTORE_BUTTON_MARGIN,
		panel_center_y - (restore_button_size.y * 0.5)
	)

func _update_button_visibility() -> void:
	_hide_button.visible = not _is_hidden and visible
	_restore_button.visible = _is_hidden and visible

func _on_viewport_resized() -> void:
	call_deferred("_refresh_slide_layout")

func _refresh_slide_layout() -> void:
	if _is_hidden:
		_panel.position.x = -_get_panel_size().x - HIDE_PANEL_MARGIN
		_panel.position.y = _shown_panel_position.y
	else:
		_panel.position = _shown_panel_position
	_sync_button_positions()
	_update_button_visibility()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_message_log"):
		visible = not visible
		_update_button_visibility()

extends Control
class_name PauseMenuUI

const UI_LOCK_SOURCE: String = "ポーズメニューUI"
const TIME_MANAGER_SCRIPT_NAME: String = "TimeManager.gd"
const BGM_SETTINGS_MANAGER_SCRIPT_NAME: String = "BgmSettingsManager.gd"

var _suppress_bgm_slider_callback: bool = false
var _suppress_voice_slider_callback: bool = false

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: Panel = $CenterContainer/Panel
@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var description_label: Label = $CenterContainer/Panel/VBoxContainer/DescriptionLabel
@onready var bgm_slider: HSlider = $CenterContainer/Panel/VBoxContainer/AudioSection/AudioVBox/BgmRow/BgmSlider
@onready var bgm_percent_label: Label = $CenterContainer/Panel/VBoxContainer/AudioSection/AudioVBox/BgmRow/BgmPercentLabel
@onready var voice_slider: HSlider = $CenterContainer/Panel/VBoxContainer/AudioSection/AudioVBox/VoiceRow/VoiceSlider
@onready var voice_percent_label: Label = $CenterContainer/Panel/VBoxContainer/AudioSection/AudioVBox/VoiceRow/VoicePercentLabel
@onready var audio_status_label: Label = $CenterContainer/Panel/VBoxContainer/AudioSection/AudioVBox/AudioStatusLabel
@onready var resume_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonRow/ResumeButton
@onready var quit_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonRow/QuitButton
@onready var close_hint_label: Label = $CenterContainer/Panel/VBoxContainer/CloseHintLabel
@onready var bgm_reset_button: Button = $CenterContainer/Panel/VBoxContainer/AudioSection/AudioVBox/AudioButtonsRow/BgmResetButton
@onready var voice_reset_button: Button = $CenterContainer/Panel/VBoxContainer/AudioSection/AudioVBox/AudioButtonsRow/VoiceResetButton
@onready var quit_confirm_dialog: ConfirmationDialog = $QuitConfirmDialog


func _ready() -> void:
	visible = false
	add_to_group("pause_menu_ui")
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	if backdrop != null:
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP

	if title_label != null:
		title_label.text = "メニュー"
	if description_label != null:
		description_label.text = "ESCで閉じる / ゲームに戻る / BGM音量とボイス音量の調整"
	if close_hint_label != null:
		close_hint_label.text = "作業UIが開いていない時に ESC でこのメニューを開ける"

	_setup_slider(bgm_slider, _on_bgm_slider_value_changed)
	_setup_slider(voice_slider, _on_voice_slider_value_changed)

	if bgm_reset_button != null and not bgm_reset_button.pressed.is_connected(_on_bgm_reset_pressed):
		bgm_reset_button.pressed.connect(_on_bgm_reset_pressed)
	if voice_reset_button != null and not voice_reset_button.pressed.is_connected(_on_voice_reset_pressed):
		voice_reset_button.pressed.connect(_on_voice_reset_pressed)
	if resume_button != null and not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
	if quit_button != null and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)
	if quit_confirm_dialog != null and not quit_confirm_dialog.confirmed.is_connected(_on_quit_confirmed):
		quit_confirm_dialog.confirmed.connect(_on_quit_confirmed)

	_refresh_audio_controls()


func _setup_slider(slider: HSlider, changed_callable: Callable) -> void:
	if slider == null:
		return
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	if not slider.value_changed.is_connected(changed_callable):
		slider.value_changed.connect(changed_callable)


func _exit_tree() -> void:
	if visible:
		_release_time_pause()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		if quit_confirm_dialog != null and quit_confirm_dialog.visible:
			quit_confirm_dialog.hide()
			get_viewport().set_input_as_handled()
			return

		close_menu()
		get_viewport().set_input_as_handled()


func open_menu() -> void:
	if visible:
		_refresh_audio_controls()
		if resume_button != null:
			resume_button.grab_focus()
		return

	visible = true
	move_to_front()
	_acquire_time_pause()
	_refresh_audio_controls()

	if resume_button != null:
		resume_button.grab_focus()


func close_menu() -> void:
	if not visible:
		return

	if quit_confirm_dialog != null:
		quit_confirm_dialog.hide()

	_release_time_pause()
	visible = false


func toggle_menu(force_open: Variant = null) -> void:
	if typeof(force_open) == TYPE_BOOL:
		if bool(force_open):
			open_menu()
		else:
			close_menu()
		return

	if visible:
		close_menu()
	else:
		open_menu()


func show_menu() -> void:
	open_menu()


func open() -> void:
	open_menu()


func hide_menu() -> void:
	close_menu()


func _on_resume_pressed() -> void:
	close_menu()


func _on_quit_pressed() -> void:
	if quit_confirm_dialog != null:
		quit_confirm_dialog.popup_centered()


func _on_quit_confirmed() -> void:
	get_tree().quit()


func _on_bgm_reset_pressed() -> void:
	var manager: Node = _find_bgm_settings_manager()
	if manager == null:
		_refresh_audio_controls()
		return

	if manager.has_method("reset_to_default"):
		manager.call("reset_to_default")
	_refresh_audio_controls()


func _on_voice_reset_pressed() -> void:
	var manager: Node = _find_bgm_settings_manager()
	if manager == null:
		_refresh_audio_controls()
		return

	if manager.has_method("reset_voice_to_default"):
		manager.call("reset_voice_to_default")
	_refresh_audio_controls()


func _on_bgm_slider_value_changed(value: float) -> void:
	if _suppress_bgm_slider_callback:
		return

	var percent: int = clampi(int(round(value)), 0, 100)
	_update_bgm_percent_label(percent)

	var manager: Node = _find_bgm_settings_manager()
	if manager == null:
		_update_audio_status_label("音量設定マネージャーが見つからない")
		return

	if manager.has_method("set_bgm_percent"):
		manager.call("set_bgm_percent", percent)
	elif manager.has_method("set_bgm_ratio"):
		manager.call("set_bgm_ratio", float(percent) / 100.0)

	_update_audio_status_label("BGM音量を %d%% に設定 / ボイス音量 %s" % [percent, _get_percent_text(voice_slider, voice_percent_label)])


func _on_voice_slider_value_changed(value: float) -> void:
	if _suppress_voice_slider_callback:
		return

	var percent: int = clampi(int(round(value)), 0, 100)
	_update_voice_percent_label(percent)

	var manager: Node = _find_bgm_settings_manager()
	if manager == null:
		_update_audio_status_label("音量設定マネージャーが見つからない")
		return

	if manager.has_method("set_voice_percent"):
		manager.call("set_voice_percent", percent)
	elif manager.has_method("set_voice_ratio"):
		manager.call("set_voice_ratio", float(percent) / 100.0)

	_update_audio_status_label("ボイス音量を %d%% に設定 / BGM音量 %s" % [percent, _get_percent_text(bgm_slider, bgm_percent_label)])


func _refresh_audio_controls() -> void:
	var manager: Node = _find_bgm_settings_manager()
	var has_manager: bool = manager != null

	_apply_slider_enabled_state(bgm_slider, has_manager)
	_apply_slider_enabled_state(voice_slider, has_manager)
	if bgm_reset_button != null:
		bgm_reset_button.disabled = not has_manager
	if voice_reset_button != null:
		voice_reset_button.disabled = not has_manager

	if not has_manager:
		_update_bgm_percent_label(0)
		_update_voice_percent_label(0)
		_update_audio_status_label("音量設定マネージャーが未接続")
		return

	var bgm_percent: int = 0
	if manager.has_method("get_bgm_percent"):
		bgm_percent = int(manager.call("get_bgm_percent"))
	elif manager.has_method("get_bgm_ratio"):
		bgm_percent = int(round(float(manager.call("get_bgm_ratio")) * 100.0))

	var voice_percent: int = 100
	if manager.has_method("get_voice_percent"):
		voice_percent = int(manager.call("get_voice_percent"))
	elif manager.has_method("get_voice_ratio"):
		voice_percent = int(round(float(manager.call("get_voice_ratio")) * 100.0))

	bgm_percent = clampi(bgm_percent, 0, 100)
	voice_percent = clampi(voice_percent, 0, 100)

	if bgm_slider != null:
		_suppress_bgm_slider_callback = true
		bgm_slider.value = bgm_percent
		_suppress_bgm_slider_callback = false
	if voice_slider != null:
		_suppress_voice_slider_callback = true
		voice_slider.value = voice_percent
		_suppress_voice_slider_callback = false

	_update_bgm_percent_label(bgm_percent)
	_update_voice_percent_label(voice_percent)
	_update_audio_status_label("現在のBGM音量: %d%% / ボイス音量: %d%%" % [bgm_percent, voice_percent])


func _apply_slider_enabled_state(slider: HSlider, enabled: bool) -> void:
	if slider == null:
		return
	slider.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	slider.modulate = Color(1.0, 1.0, 1.0, 1.0) if enabled else Color(0.7, 0.7, 0.7, 0.85)


func _update_bgm_percent_label(percent: int) -> void:
	if bgm_percent_label != null:
		bgm_percent_label.text = "%d%%" % clampi(percent, 0, 100)


func _update_voice_percent_label(percent: int) -> void:
	if voice_percent_label != null:
		voice_percent_label.text = "%d%%" % clampi(percent, 0, 100)


func _update_audio_status_label(text: String) -> void:
	if audio_status_label != null:
		audio_status_label.text = text


func _get_percent_text(slider: HSlider, label: Label) -> String:
	if label != null and not label.text.is_empty():
		return label.text
	if slider != null:
		return "%d%%" % clampi(int(round(slider.value)), 0, 100)
	return "0%"


func _find_bgm_settings_manager() -> Node:
	var by_path: Node = get_node_or_null("/root/BgmSettingsManager")
	if by_path != null:
		return by_path

	for child in get_tree().root.get_children():
		var script_value: Variant = child.get_script()
		if script_value is Script:
			var script_ref: Script = script_value as Script
			if script_ref != null and script_ref.resource_path.get_file() == BGM_SETTINGS_MANAGER_SCRIPT_NAME:
				return child

	return null


func _find_time_manager() -> Node:
	var by_path: Node = get_node_or_null("/root/TimeManager")
	if by_path != null:
		return by_path

	for child in get_tree().root.get_children():
		var script_value: Variant = child.get_script()
		if script_value is Script:
			var script_ref: Script = script_value as Script
			if script_ref != null and script_ref.resource_path.get_file() == TIME_MANAGER_SCRIPT_NAME:
				return child

	return null


func _acquire_time_pause() -> void:
	var time_manager: Node = _find_time_manager()
	if time_manager == null:
		return

	var pause_source: String = "UI:" + UI_LOCK_SOURCE
	if time_manager.has_method("request_pause"):
		time_manager.call("request_pause", pause_source)
	elif time_manager.has_method("pause_time"):
		time_manager.call("pause_time", pause_source)


func _release_time_pause() -> void:
	var time_manager: Node = _find_time_manager()
	if time_manager == null:
		return

	var pause_source: String = "UI:" + UI_LOCK_SOURCE
	if time_manager.has_method("release_pause"):
		time_manager.call("release_pause", pause_source)
	elif time_manager.has_method("resume_time"):
		time_manager.call("resume_time", pause_source)

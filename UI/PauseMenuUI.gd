extends Control
class_name PauseMenuUI

const UI_LOCK_SOURCE: String = "ポーズメニューUI"
const TIME_MANAGER_SCRIPT_NAME: String = "TimeManager.gd"
const BGM_SETTINGS_MANAGER_SCRIPT_NAME: String = "BgmSettingsManager.gd"

var _suppress_bgm_slider_callback: bool = false
var _suppress_sound_slider_callback: bool = false
var _suppress_ambient_slider_callback: bool = false
var _suppress_voice_slider_callback: bool = false
var _suppress_camera_preset_callback: bool = false

@onready var backdrop: ColorRect = $Backdrop
@onready var panel: Panel = $CenterContainer/Panel
@onready var title_label: Label = $CenterContainer/Panel/VBoxContainer/TitleLabel
@onready var description_label: Label = $CenterContainer/Panel/VBoxContainer/DescriptionLabel
@onready var settings_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonRow/SettingsButton
@onready var resume_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonRow/ResumeButton
@onready var quit_button: Button = $CenterContainer/Panel/VBoxContainer/ButtonRow/QuitButton
@onready var settings_section: PanelContainer = $CenterContainer/Panel/VBoxContainer/SettingsSection
@onready var settings_close_button: Button = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsHeaderRow/SettingsCloseButton
@onready var settings_tabs: TabContainer = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs
@onready var bgm_slider: HSlider = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Audio/AudioVBox/BgmRow/BgmSlider
@onready var bgm_percent_label: Label = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Audio/AudioVBox/BgmRow/BgmPercentLabel
@onready var sound_slider: HSlider = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Audio/AudioVBox/SoundRow/SoundSlider
@onready var sound_percent_label: Label = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Audio/AudioVBox/SoundRow/SoundPercentLabel
@onready var ambient_slider: HSlider = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Audio/AudioVBox/AmbientRow/AmbientSlider
@onready var ambient_percent_label: Label = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Audio/AudioVBox/AmbientRow/AmbientPercentLabel
@onready var voice_slider: HSlider = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Audio/AudioVBox/VoiceRow/VoiceSlider
@onready var voice_percent_label: Label = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Audio/AudioVBox/VoiceRow/VoicePercentLabel
@onready var audio_status_label: Label = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Audio/AudioVBox/AudioStatusLabel
@onready var bgm_reset_button: Button = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Audio/AudioVBox/AudioButtonsRow/BgmResetButton
@onready var sound_reset_button: Button = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Audio/AudioVBox/AudioButtonsRow/SoundResetButton
@onready var ambient_reset_button: Button = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Audio/AudioVBox/AudioButtonsRow2/AmbientResetButton
@onready var voice_reset_button: Button = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Audio/AudioVBox/AudioButtonsRow2/VoiceResetButton
@onready var camera_preset_option: OptionButton = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Graphics/GraphicsVBox/CameraPresetRow/CameraPresetOption
@onready var camera_hint_label: Label = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Graphics/GraphicsVBox/GraphicsHintLabel
@onready var graphics_status_label: Label = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Graphics/GraphicsVBox/GraphicsStatusLabel
@onready var camera_reset_button: Button = $CenterContainer/Panel/VBoxContainer/SettingsSection/SettingsVBox/SettingsTabs/Graphics/GraphicsVBox/CameraResetButton
@onready var close_hint_label: Label = $CenterContainer/Panel/VBoxContainer/CloseHintLabel
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
		description_label.text = "ESCで閉じる / ゲームに戻る / 設定を開く"
	if close_hint_label != null:
		close_hint_label.text = "作業UIが開いていない時に ESC でこのメニューを開ける"
	if settings_section != null:
		settings_section.visible = false
	if settings_tabs != null:
		if settings_tabs.get_tab_count() >= 1:
			settings_tabs.set_tab_title(0, "オーディオ")
		if settings_tabs.get_tab_count() >= 2:
			settings_tabs.set_tab_title(1, "グラフィック")

	_setup_slider(bgm_slider, _on_bgm_slider_value_changed)
	_setup_slider(sound_slider, _on_sound_slider_value_changed)
	_setup_slider(ambient_slider, _on_ambient_slider_value_changed)
	_setup_slider(voice_slider, _on_voice_slider_value_changed)
	_setup_camera_preset_option()

	if settings_button != null and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if settings_close_button != null and not settings_close_button.pressed.is_connected(_on_settings_close_pressed):
		settings_close_button.pressed.connect(_on_settings_close_pressed)
	if bgm_reset_button != null and not bgm_reset_button.pressed.is_connected(_on_bgm_reset_pressed):
		bgm_reset_button.pressed.connect(_on_bgm_reset_pressed)
	if sound_reset_button != null and not sound_reset_button.pressed.is_connected(_on_sound_reset_pressed):
		sound_reset_button.pressed.connect(_on_sound_reset_pressed)
	if ambient_reset_button != null and not ambient_reset_button.pressed.is_connected(_on_ambient_reset_pressed):
		ambient_reset_button.pressed.connect(_on_ambient_reset_pressed)
	if voice_reset_button != null and not voice_reset_button.pressed.is_connected(_on_voice_reset_pressed):
		voice_reset_button.pressed.connect(_on_voice_reset_pressed)
	if camera_reset_button != null and not camera_reset_button.pressed.is_connected(_on_camera_reset_pressed):
		camera_reset_button.pressed.connect(_on_camera_reset_pressed)
	if resume_button != null and not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
	if quit_button != null and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)
	if quit_confirm_dialog != null and not quit_confirm_dialog.confirmed.is_connected(_on_quit_confirmed):
		quit_confirm_dialog.confirmed.connect(_on_quit_confirmed)

	_refresh_audio_controls()
	_refresh_graphics_controls()


func _setup_slider(slider: HSlider, changed_callable: Callable) -> void:
	if slider == null:
		return
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	if not slider.value_changed.is_connected(changed_callable):
		slider.value_changed.connect(changed_callable)


func _setup_camera_preset_option() -> void:
	if camera_preset_option == null:
		return
	if not camera_preset_option.item_selected.is_connected(_on_camera_preset_selected):
		camera_preset_option.item_selected.connect(_on_camera_preset_selected)


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

		if settings_section != null and settings_section.visible:
			_hide_settings_section()
			get_viewport().set_input_as_handled()
			return

		close_menu()
		get_viewport().set_input_as_handled()


func open_menu() -> void:
	if visible:
		_refresh_audio_controls()
		_refresh_graphics_controls()
		if resume_button != null:
			resume_button.grab_focus()
		return

	visible = true
	move_to_front()
	_acquire_time_pause()
	_hide_settings_section()
	_refresh_audio_controls()
	_refresh_graphics_controls()

	if resume_button != null:
		resume_button.grab_focus()


func close_menu() -> void:
	if not visible:
		return

	if quit_confirm_dialog != null:
		quit_confirm_dialog.hide()

	_hide_settings_section()
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


func _on_settings_pressed() -> void:
	_show_settings_section(0)


func _on_settings_close_pressed() -> void:
	_hide_settings_section()
	if settings_button != null:
		settings_button.grab_focus()


func _show_settings_section(tab_index: int = 0) -> void:
	if settings_section != null:
		settings_section.visible = true
	if settings_tabs != null:
		settings_tabs.current_tab = clampi(tab_index, 0, max(settings_tabs.get_tab_count() - 1, 0))
	_refresh_audio_controls()
	_refresh_graphics_controls()
	call_deferred("_grab_settings_focus")


func _grab_settings_focus() -> void:
	if settings_tabs != null and settings_tabs.current_tab == 1:
		if camera_preset_option != null and not camera_preset_option.disabled and camera_preset_option.is_visible_in_tree():
			camera_preset_option.grab_focus()
			return
		if camera_reset_button != null and not camera_reset_button.disabled and camera_reset_button.is_visible_in_tree():
			camera_reset_button.grab_focus()
			return
	else:
		if bgm_slider != null and bgm_slider.is_visible_in_tree():
			bgm_slider.grab_focus()
			return
		if sound_slider != null and sound_slider.is_visible_in_tree():
			sound_slider.grab_focus()
			return
		if ambient_slider != null and ambient_slider.is_visible_in_tree():
			ambient_slider.grab_focus()
			return
		if voice_slider != null and voice_slider.is_visible_in_tree():
			voice_slider.grab_focus()
			return

	if settings_close_button != null and settings_close_button.is_visible_in_tree():
		settings_close_button.grab_focus()


func _hide_settings_section() -> void:
	if settings_section != null:
		settings_section.visible = false


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


func _on_sound_reset_pressed() -> void:
	var manager: Node = _find_bgm_settings_manager()
	if manager == null:
		_refresh_audio_controls()
		return

	if manager.has_method("reset_sound_to_default"):
		manager.call("reset_sound_to_default")
	_refresh_audio_controls()


func _on_ambient_reset_pressed() -> void:
	var manager: Node = _find_bgm_settings_manager()
	if manager == null:
		_refresh_audio_controls()
		return

	if manager.has_method("reset_ambient_to_default"):
		manager.call("reset_ambient_to_default")
	_refresh_audio_controls()


func _on_voice_reset_pressed() -> void:
	var manager: Node = _find_bgm_settings_manager()
	if manager == null:
		_refresh_audio_controls()
		return

	if manager.has_method("reset_voice_to_default"):
		manager.call("reset_voice_to_default")
	_refresh_audio_controls()


func _on_camera_reset_pressed() -> void:
	var manager: Node = _find_bgm_settings_manager()
	if manager == null:
		_refresh_graphics_controls()
		return

	if manager.has_method("reset_camera_to_default"):
		manager.call("reset_camera_to_default")
	_refresh_graphics_controls()


func _on_bgm_slider_value_changed(value: float) -> void:
	if _suppress_bgm_slider_callback:
		return

	var percent: int = clampi(int(round(value)), 0, 100)
	_update_bgm_percent_label(percent)

	var manager: Node = _find_bgm_settings_manager()
	if manager == null:
		_update_audio_status_label("設定マネージャーが見つからない")
		return

	if manager.has_method("set_bgm_percent"):
		manager.call("set_bgm_percent", percent)
	elif manager.has_method("set_bgm_ratio"):
		manager.call("set_bgm_ratio", float(percent) / 100.0)

	_update_audio_status_label(_build_audio_status_text(manager))


func _on_sound_slider_value_changed(value: float) -> void:
	if _suppress_sound_slider_callback:
		return

	var percent: int = clampi(int(round(value)), 0, 100)
	_update_sound_percent_label(percent)

	var manager: Node = _find_bgm_settings_manager()
	if manager == null:
		_update_audio_status_label("設定マネージャーが見つからない")
		return

	if manager.has_method("set_sound_percent"):
		manager.call("set_sound_percent", percent)
	elif manager.has_method("set_sound_ratio"):
		manager.call("set_sound_ratio", float(percent) / 100.0)

	_update_audio_status_label(_build_audio_status_text(manager))


func _on_ambient_slider_value_changed(value: float) -> void:
	if _suppress_ambient_slider_callback:
		return

	var percent: int = clampi(int(round(value)), 0, 100)
	_update_ambient_percent_label(percent)

	var manager: Node = _find_bgm_settings_manager()
	if manager == null:
		_update_audio_status_label("設定マネージャーが見つからない")
		return

	if manager.has_method("set_ambient_percent"):
		manager.call("set_ambient_percent", percent)
	elif manager.has_method("set_ambient_ratio"):
		manager.call("set_ambient_ratio", float(percent) / 100.0)

	_update_audio_status_label(_build_audio_status_text(manager))


func _on_voice_slider_value_changed(value: float) -> void:
	if _suppress_voice_slider_callback:
		return

	var percent: int = clampi(int(round(value)), 0, 100)
	_update_voice_percent_label(percent)

	var manager: Node = _find_bgm_settings_manager()
	if manager == null:
		_update_audio_status_label("設定マネージャーが見つからない")
		return

	if manager.has_method("set_voice_percent"):
		manager.call("set_voice_percent", percent)
	elif manager.has_method("set_voice_ratio"):
		manager.call("set_voice_ratio", float(percent) / 100.0)

	_update_audio_status_label(_build_audio_status_text(manager))


func _on_camera_preset_selected(index: int) -> void:
	if _suppress_camera_preset_callback:
		return
	if camera_preset_option == null:
		return
	if index < 0 or index >= camera_preset_option.item_count:
		return

	var preset_id: String = str(camera_preset_option.get_item_metadata(index))
	var manager: Node = _find_bgm_settings_manager()
	if manager == null:
		_update_graphics_status_label("設定マネージャーが見つからない")
		return

	if manager.has_method("set_camera_preset"):
		manager.call("set_camera_preset", preset_id)
	_refresh_graphics_controls()


func _refresh_audio_controls() -> void:
	var manager: Node = _find_bgm_settings_manager()
	var has_manager: bool = manager != null

	_apply_slider_enabled_state(bgm_slider, has_manager)
	_apply_slider_enabled_state(sound_slider, has_manager)
	_apply_slider_enabled_state(ambient_slider, has_manager)
	_apply_slider_enabled_state(voice_slider, has_manager)
	if bgm_reset_button != null:
		bgm_reset_button.disabled = not has_manager
	if sound_reset_button != null:
		sound_reset_button.disabled = not has_manager
	if ambient_reset_button != null:
		ambient_reset_button.disabled = not has_manager
	if voice_reset_button != null:
		voice_reset_button.disabled = not has_manager

	if not has_manager:
		_update_bgm_percent_label(0)
		_update_sound_percent_label(0)
		_update_ambient_percent_label(0)
		_update_voice_percent_label(0)
		_update_audio_status_label("音量設定マネージャーが未接続")
		return

	var bgm_percent: int = _get_manager_percent(manager, "get_bgm_percent", "get_bgm_ratio", 0)
	var sound_percent: int = _get_manager_percent(manager, "get_sound_percent", "get_sound_ratio", 100)
	var ambient_percent: int = _get_manager_percent(manager, "get_ambient_percent", "get_ambient_ratio", 100)
	var voice_percent: int = _get_manager_percent(manager, "get_voice_percent", "get_voice_ratio", 100)

	_set_slider_value_without_callback(bgm_slider, bgm_percent, "bgm")
	_set_slider_value_without_callback(sound_slider, sound_percent, "sound")
	_set_slider_value_without_callback(ambient_slider, ambient_percent, "ambient")
	_set_slider_value_without_callback(voice_slider, voice_percent, "voice")

	_update_bgm_percent_label(bgm_percent)
	_update_sound_percent_label(sound_percent)
	_update_ambient_percent_label(ambient_percent)
	_update_voice_percent_label(voice_percent)
	_update_audio_status_label(_build_audio_status_text(manager))


func _refresh_graphics_controls() -> void:
	var manager: Node = _find_bgm_settings_manager()
	var has_manager: bool = manager != null

	if camera_preset_option != null:
		camera_preset_option.disabled = not has_manager
	if camera_reset_button != null:
		camera_reset_button.disabled = not has_manager

	_reload_camera_preset_options(manager)

	if not has_manager:
		if camera_hint_label != null:
			camera_hint_label.text = "100% = 現在のプレイヤー付属カメラ"
		_update_graphics_status_label("グラフィック設定マネージャーが未接続")
		return

	var current_preset: String = _default_camera_preset_text()
	if manager.has_method("get_camera_preset"):
		current_preset = str(manager.call("get_camera_preset"))
	var current_label: String = "100%（現在）"
	if manager.has_method("get_camera_preset_label"):
		current_label = str(manager.call("get_camera_preset_label"))

	var selected_index: int = _find_camera_preset_option_index(current_preset)
	if camera_preset_option != null and selected_index >= 0:
		_suppress_camera_preset_callback = true
		camera_preset_option.select(selected_index)
		_suppress_camera_preset_callback = false

	var zoom_text: String = ""
	if manager.has_method("get_camera_zoom"):
		var zoom_variant: Variant = manager.call("get_camera_zoom")
		if zoom_variant is Vector2:
			var zoom_value: Vector2 = zoom_variant
			zoom_text = " / 現在 zoom: %.2f, %.2f" % [zoom_value.x, zoom_value.y]

	if camera_hint_label != null:
		camera_hint_label.text = "100%% = 現在のプレイヤー付属カメラ。引き設定は表示範囲だけ広げる%s" % zoom_text
	_update_graphics_status_label("現在のカメラ設定: %s" % current_label)


func _default_camera_preset_text() -> String:
	return "100"


func _reload_camera_preset_options(manager: Node) -> void:
	if camera_preset_option == null:
		return

	camera_preset_option.clear()

	var options: Array = []
	if manager != null and manager.has_method("get_camera_preset_options"):
		options = manager.call("get_camera_preset_options")
	else:
		options = [
			{"id": "100", "label": "100%（現在）"},
			{"id": "125", "label": "125%（少し引き）"},
			{"id": "150", "label": "150%（かなり引き）"}
		]

	for entry in options:
		if not (entry is Dictionary):
			continue
		var entry_dict: Dictionary = entry
		var preset_id: String = str(entry_dict.get("id", ""))
		var preset_label: String = str(entry_dict.get("label", preset_id))
		if preset_id.is_empty():
			continue
		camera_preset_option.add_item(preset_label)
		var item_index: int = camera_preset_option.item_count - 1
		camera_preset_option.set_item_metadata(item_index, preset_id)


func _find_camera_preset_option_index(preset_id: String) -> int:
	if camera_preset_option == null:
		return -1

	for i in range(camera_preset_option.item_count):
		if str(camera_preset_option.get_item_metadata(i)) == preset_id:
			return i
	return -1


func _apply_slider_enabled_state(slider: HSlider, enabled: bool) -> void:
	if slider == null:
		return
	slider.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	slider.modulate = Color(1.0, 1.0, 1.0, 1.0) if enabled else Color(0.7, 0.7, 0.7, 0.85)


func _update_bgm_percent_label(percent: int) -> void:
	if bgm_percent_label != null:
		bgm_percent_label.text = "%d%%" % clampi(percent, 0, 100)


func _update_sound_percent_label(percent: int) -> void:
	if sound_percent_label != null:
		sound_percent_label.text = "%d%%" % clampi(percent, 0, 100)


func _update_ambient_percent_label(percent: int) -> void:
	if ambient_percent_label != null:
		ambient_percent_label.text = "%d%%" % clampi(percent, 0, 100)


func _update_voice_percent_label(percent: int) -> void:
	if voice_percent_label != null:
		voice_percent_label.text = "%d%%" % clampi(percent, 0, 100)


func _update_audio_status_label(text: String) -> void:
	if audio_status_label != null:
		audio_status_label.text = text


func _update_graphics_status_label(text: String) -> void:
	if graphics_status_label != null:
		graphics_status_label.text = text


func _get_percent_text(slider: HSlider, label: Label) -> String:
	if label != null and not label.text.is_empty():
		return label.text
	if slider != null:
		return "%d%%" % clampi(int(round(slider.value)), 0, 100)
	return "0%"


func _build_audio_status_text(manager: Node = null) -> String:
	if manager == null:
		manager = _find_bgm_settings_manager()
	if manager == null:
		return "音量設定マネージャーが未接続"

	var bgm_percent: int = _get_manager_percent(manager, "get_bgm_percent", "get_bgm_ratio", 0)
	var sound_percent: int = _get_manager_percent(manager, "get_sound_percent", "get_sound_ratio", 100)
	var ambient_percent: int = _get_manager_percent(manager, "get_ambient_percent", "get_ambient_ratio", 100)
	var voice_percent: int = _get_manager_percent(manager, "get_voice_percent", "get_voice_ratio", 100)
	return "BGM: %d%% / 効果音: %d%% / 環境音: %d%% / ボイス: %d%%" % [bgm_percent, sound_percent, ambient_percent, voice_percent]


func _get_manager_percent(manager: Node, percent_method: String, ratio_method: String, fallback_percent: int) -> int:
	if manager == null:
		return clampi(fallback_percent, 0, 100)
	if manager.has_method(percent_method):
		return clampi(int(manager.call(percent_method)), 0, 100)
	if manager.has_method(ratio_method):
		return clampi(int(round(float(manager.call(ratio_method)) * 100.0)), 0, 100)
	return clampi(fallback_percent, 0, 100)


func _set_slider_value_without_callback(slider: HSlider, percent: int, channel: String) -> void:
	if slider == null:
		return

	match channel:
		"bgm":
			_suppress_bgm_slider_callback = true
			slider.value = percent
			_suppress_bgm_slider_callback = false
		"sound":
			_suppress_sound_slider_callback = true
			slider.value = percent
			_suppress_sound_slider_callback = false
		"ambient":
			_suppress_ambient_slider_callback = true
			slider.value = percent
			_suppress_ambient_slider_callback = false
		"voice":
			_suppress_voice_slider_callback = true
			slider.value = percent
			_suppress_voice_slider_callback = false


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

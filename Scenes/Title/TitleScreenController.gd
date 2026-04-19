extends Control
class_name TitleScreenController

const BOOT_SCENE_PATH: String = "res://Scenes/System/Boot.tscn"
const DEFAULT_SLOT_NAME: String = "slot_01"
const DEFAULT_NEW_GAME_SCENE_PATH: String = "res://Main.tscn"
const BGM_SETTINGS_MANAGER_SCRIPT_NAME: String = "BgmSettingsManager.gd"

@export var slot_name: String = DEFAULT_SLOT_NAME
@export_file("*.tscn") var boot_scene_path: String = BOOT_SCENE_PATH
@export_file("*.tscn") var new_game_scene_path: String = DEFAULT_NEW_GAME_SCENE_PATH
@export_file("*.ogg", "*.wav", "*.mp3") var title_bgm_path: String = "res://BGM/Title.ogg"

var _suppress_bgm_slider_callback: bool = false
var _suppress_voice_slider_callback: bool = false
var _title_bgm_stream: AudioStream = null

@onready var continue_button: Button = $CenterContainer/Panel/VBoxContainer/MenuButtons/ContinueButton
@onready var new_game_button: Button = $CenterContainer/Panel/VBoxContainer/MenuButtons/NewGameButton
@onready var settings_button: Button = $CenterContainer/Panel/VBoxContainer/MenuButtons/SettingsButton
@onready var quit_button: Button = $CenterContainer/Panel/VBoxContainer/MenuButtons/QuitButton
@onready var save_info_label: Label = $CenterContainer/Panel/VBoxContainer/SaveInfoLabel
@onready var title_bgm_player: AudioStreamPlayer = $TitleBgmPlayer
@onready var settings_panel: PanelContainer = $CenterContainer/Panel/VBoxContainer/SettingsPanel
@onready var bgm_slider: HSlider = $CenterContainer/Panel/VBoxContainer/SettingsPanel/AudioVBox/BgmRow/BgmSlider
@onready var bgm_percent_label: Label = $CenterContainer/Panel/VBoxContainer/SettingsPanel/AudioVBox/BgmRow/BgmPercentLabel
@onready var voice_slider: HSlider = $CenterContainer/Panel/VBoxContainer/SettingsPanel/AudioVBox/VoiceRow/VoiceSlider
@onready var voice_percent_label: Label = $CenterContainer/Panel/VBoxContainer/SettingsPanel/AudioVBox/VoiceRow/VoicePercentLabel
@onready var bgm_reset_button: Button = $CenterContainer/Panel/VBoxContainer/SettingsPanel/AudioVBox/AudioButtonsRow/BgmResetButton
@onready var voice_reset_button: Button = $CenterContainer/Panel/VBoxContainer/SettingsPanel/AudioVBox/AudioButtonsRow/VoiceResetButton
@onready var audio_status_label: Label = $CenterContainer/Panel/VBoxContainer/SettingsPanel/AudioVBox/AudioStatusLabel
@onready var new_game_confirm_dialog: ConfirmationDialog = $NewGameConfirmDialog


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_buttons()
	_setup_slider(bgm_slider, _on_bgm_slider_value_changed)
	_setup_slider(voice_slider, _on_voice_slider_value_changed)
	_refresh_continue_button()
	_refresh_audio_controls()
	_set_settings_open(false)
	_play_title_bgm()

	if continue_button != null and not continue_button.disabled:
		continue_button.grab_focus()
	elif new_game_button != null:
		new_game_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if new_game_confirm_dialog != null and new_game_confirm_dialog.visible:
			new_game_confirm_dialog.hide()
			get_viewport().set_input_as_handled()
			return

		if settings_panel != null and settings_panel.visible:
			_set_settings_open(false)
			get_viewport().set_input_as_handled()


func _setup_buttons() -> void:
	if continue_button != null and not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if new_game_button != null and not new_game_button.pressed.is_connected(_on_new_game_pressed):
		new_game_button.pressed.connect(_on_new_game_pressed)
	if settings_button != null and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button != null and not quit_button.pressed.is_connected(_on_quit_pressed):
		quit_button.pressed.connect(_on_quit_pressed)
	if new_game_confirm_dialog != null and not new_game_confirm_dialog.confirmed.is_connected(_on_new_game_confirmed):
		new_game_confirm_dialog.confirmed.connect(_on_new_game_confirmed)
	if bgm_reset_button != null and not bgm_reset_button.pressed.is_connected(_on_bgm_reset_pressed):
		bgm_reset_button.pressed.connect(_on_bgm_reset_pressed)
	if voice_reset_button != null and not voice_reset_button.pressed.is_connected(_on_voice_reset_pressed):
		voice_reset_button.pressed.connect(_on_voice_reset_pressed)


func _setup_slider(slider: HSlider, changed_callable: Callable) -> void:
	if slider == null:
		return
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	if not slider.value_changed.is_connected(changed_callable):
		slider.value_changed.connect(changed_callable)


func _refresh_continue_button() -> void:
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	var has_save: bool = false
	if save_manager != null and save_manager.has_method("has_save"):
		has_save = bool(save_manager.call("has_save", slot_name))

	if continue_button != null:
		continue_button.disabled = not has_save

	if save_info_label != null:
		save_info_label.text = "続きから遊べます" if has_save else "セーブデータがないので はじめから のみ選べる"


func _set_settings_open(open: bool) -> void:
	if settings_panel == null:
		return
	settings_panel.visible = open
	if open:
		_refresh_audio_controls()
		if bgm_slider != null:
			bgm_slider.grab_focus()
	else:
		if settings_button != null:
			settings_button.grab_focus()


func _play_title_bgm() -> void:
	if title_bgm_player == null:
		return

	if title_bgm_path.strip_edges().is_empty():
		return

	_title_bgm_stream = load(title_bgm_path) as AudioStream
	if _title_bgm_stream == null:
		push_warning("TitleScreenController: タイトルBGMを読み込めません: %s" % title_bgm_path)
		return

	title_bgm_player.stream = _title_bgm_stream
	if not title_bgm_player.playing:
		title_bgm_player.play()


func _on_continue_pressed() -> void:
	_start_boot("continue")


func _on_new_game_pressed() -> void:
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	var has_save: bool = false
	if save_manager != null and save_manager.has_method("has_save"):
		has_save = bool(save_manager.call("has_save", slot_name))

	if has_save and new_game_confirm_dialog != null:
		new_game_confirm_dialog.popup_centered()
		return

	_start_boot("new_game")


func _on_new_game_confirmed() -> void:
	_start_boot("new_game")


func _on_settings_pressed() -> void:
	_set_settings_open(settings_panel == null or not settings_panel.visible)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _start_boot(mode: String) -> void:
	var packed: PackedScene = load(boot_scene_path) as PackedScene
	if packed == null:
		push_error("TitleScreenController: Boot scene を読み込めません: %s" % boot_scene_path)
		return

	var boot_root: Node = packed.instantiate()
	if boot_root == null:
		push_error("TitleScreenController: Boot scene の生成に失敗")
		return

	if boot_root.has_method("configure_startup"):
		boot_root.call("configure_startup", mode, slot_name, new_game_scene_path)
	else:
		boot_root.set("boot_mode", mode)
		boot_root.set("slot_name", slot_name)
		boot_root.set("new_game_scene_path", new_game_scene_path)

	if title_bgm_player != null:
		title_bgm_player.stop()

	var tree: SceneTree = get_tree()
	var previous_scene: Node = tree.current_scene
	tree.root.add_child(boot_root)
	tree.current_scene = boot_root
	if is_instance_valid(previous_scene):
		previous_scene.queue_free()


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
	slider.editable = enabled
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

	for child_obj in get_tree().root.get_children():
		var child: Node = child_obj as Node
		if child == null:
			continue
		var script_value: Variant = child.get_script()
		if script_value is Script:
			var script_ref: Script = script_value as Script
			if script_ref != null and script_ref.resource_path.get_file() == BGM_SETTINGS_MANAGER_SCRIPT_NAME:
				return child

	return null

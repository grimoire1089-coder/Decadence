extends Node

signal bgm_volume_changed(ratio: float, percent: int)
signal voice_volume_changed(ratio: float, percent: int)

const SETTINGS_PATH := "user://audio_settings.cfg"
const SECTION_AUDIO := "audio"
const KEY_BGM_RATIO := "bgm_ratio"
const KEY_VOICE_RATIO := "voice_ratio"
const DEFAULT_BGM_RATIO := 0.70
const DEFAULT_VOICE_RATIO := 1.00
const MIN_LINEAR := 0.0001
const MUTE_DB := -80.0

@export var bgm_bus_name: StringName = &"BGM"
@export var voice_bus_name: StringName = &"Voice"

var _bgm_ratio: float = DEFAULT_BGM_RATIO
var _voice_ratio: float = DEFAULT_VOICE_RATIO


func _ready() -> void:
	load_settings()
	apply_bgm_volume()
	apply_voice_volume()


func set_bgm_ratio(value: float) -> void:
	var new_value: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(_bgm_ratio, new_value):
		return

	_bgm_ratio = new_value
	apply_bgm_volume()
	save_settings()


func get_bgm_ratio() -> float:
	return _bgm_ratio


func set_bgm_percent(value: int) -> void:
	set_bgm_ratio(float(clampi(value, 0, 100)) / 100.0)


func get_bgm_percent() -> int:
	return int(round(_bgm_ratio * 100.0))


func reset_to_default() -> void:
	set_bgm_ratio(DEFAULT_BGM_RATIO)


func set_voice_ratio(value: float) -> void:
	var new_value: float = clampf(value, 0.0, 1.0)
	if is_equal_approx(_voice_ratio, new_value):
		return

	_voice_ratio = new_value
	apply_voice_volume()
	save_settings()


func get_voice_ratio() -> float:
	return _voice_ratio


func set_voice_percent(value: int) -> void:
	set_voice_ratio(float(clampi(value, 0, 100)) / 100.0)


func get_voice_percent() -> int:
	return int(round(_voice_ratio * 100.0))


func reset_voice_to_default() -> void:
	set_voice_ratio(DEFAULT_VOICE_RATIO)


func reset_all_to_default() -> void:
	_bgm_ratio = DEFAULT_BGM_RATIO
	_voice_ratio = DEFAULT_VOICE_RATIO
	apply_bgm_volume()
	apply_voice_volume()
	save_settings()


func get_voice_bus_name() -> StringName:
	return voice_bus_name


func get_bgm_bus_name() -> StringName:
	return bgm_bus_name


func apply_bgm_volume() -> void:
	_apply_bus_volume(bgm_bus_name, _bgm_ratio, "BGM")
	bgm_volume_changed.emit(_bgm_ratio, get_bgm_percent())


func apply_voice_volume() -> void:
	_apply_bus_volume(voice_bus_name, _voice_ratio, "Voice")
	voice_volume_changed.emit(_voice_ratio, get_voice_percent())


func _apply_bus_volume(bus_name: StringName, ratio: float, label: String) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		push_warning("%s audio bus が見つからない: %s" % [label, String(bus_name)])
		return

	AudioServer.set_bus_volume_db(bus_index, _ratio_to_db(ratio))


func _ratio_to_db(ratio: float) -> float:
	if ratio <= 0.0:
		return MUTE_DB
	return linear_to_db(maxf(ratio, MIN_LINEAR))


func save_settings() -> void:
	var config := ConfigFile.new()
	var load_result: int = config.load(SETTINGS_PATH)
	if load_result != OK and load_result != ERR_FILE_NOT_FOUND:
		push_warning("既存設定の読み込みに失敗: %s" % SETTINGS_PATH)

	config.set_value(SECTION_AUDIO, KEY_BGM_RATIO, _bgm_ratio)
	config.set_value(SECTION_AUDIO, KEY_VOICE_RATIO, _voice_ratio)

	var save_result: int = config.save(SETTINGS_PATH)
	if save_result != OK:
		push_error("音量設定の保存に失敗: %s" % SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	var load_result: int = config.load(SETTINGS_PATH)
	if load_result != OK:
		_bgm_ratio = DEFAULT_BGM_RATIO
		_voice_ratio = DEFAULT_VOICE_RATIO
		return

	var raw_bgm: Variant = config.get_value(SECTION_AUDIO, KEY_BGM_RATIO, DEFAULT_BGM_RATIO)
	var raw_voice: Variant = config.get_value(SECTION_AUDIO, KEY_VOICE_RATIO, DEFAULT_VOICE_RATIO)
	_bgm_ratio = clampf(float(raw_bgm), 0.0, 1.0)
	_voice_ratio = clampf(float(raw_voice), 0.0, 1.0)

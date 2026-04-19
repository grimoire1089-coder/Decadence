extends Node

signal bgm_volume_changed(ratio: float, percent: int)
signal voice_volume_changed(ratio: float, percent: int)
signal camera_zoom_changed(preset_id: String, zoom: Vector2, label: String)

const SETTINGS_PATH := "user://audio_settings.cfg"
const SECTION_AUDIO := "audio"
const SECTION_GRAPHICS := "graphics"
const KEY_BGM_RATIO := "bgm_ratio"
const KEY_VOICE_RATIO := "voice_ratio"
const KEY_CAMERA_PRESET := "camera_preset"
const DEFAULT_BGM_RATIO := 0.70
const DEFAULT_VOICE_RATIO := 1.00
const DEFAULT_CAMERA_PRESET := "100"
const MIN_LINEAR := 0.0001
const MUTE_DB := -80.0

const CAMERA_PRESET_CURRENT := "100"
const CAMERA_PRESET_PULL_1 := "125"
const CAMERA_PRESET_PULL_2 := "150"
const CAMERA_ZOOM_CURRENT := Vector2(2.0, 2.0)
const CAMERA_ZOOM_PULL_1 := Vector2(1.6, 1.6)
const CAMERA_ZOOM_PULL_2 := Vector2(1.33, 1.33)

@export var bgm_bus_name: StringName = &"BGM"
@export var voice_bus_name: StringName = &"Voice"

var _bgm_ratio: float = DEFAULT_BGM_RATIO
var _voice_ratio: float = DEFAULT_VOICE_RATIO
var _camera_preset: String = DEFAULT_CAMERA_PRESET


func _ready() -> void:
	load_settings()
	apply_bgm_volume()
	apply_voice_volume()
	apply_camera_zoom()

	var tree: SceneTree = get_tree()
	if tree != null and not tree.node_added.is_connected(_on_tree_node_added):
		tree.node_added.connect(_on_tree_node_added)


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
	_camera_preset = DEFAULT_CAMERA_PRESET
	apply_bgm_volume()
	apply_voice_volume()
	apply_camera_zoom()
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


func set_camera_preset(value: String) -> void:
	var normalized: String = _normalize_camera_preset(value)
	if _camera_preset == normalized:
		apply_camera_zoom()
		return

	_camera_preset = normalized
	apply_camera_zoom()
	save_settings()


func get_camera_preset() -> String:
	return _camera_preset


func get_camera_preset_label() -> String:
	match _camera_preset:
		CAMERA_PRESET_PULL_1:
			return "125%（少し引き）"
		CAMERA_PRESET_PULL_2:
			return "150%（かなり引き）"
		_:
			return "100%（現在）"


func get_camera_zoom() -> Vector2:
	match _camera_preset:
		CAMERA_PRESET_PULL_1:
			return CAMERA_ZOOM_PULL_1
		CAMERA_PRESET_PULL_2:
			return CAMERA_ZOOM_PULL_2
		_:
			return CAMERA_ZOOM_CURRENT


func get_camera_preset_options() -> Array:
	return [
		{"id": CAMERA_PRESET_CURRENT, "label": "100%（現在）"},
		{"id": CAMERA_PRESET_PULL_1, "label": "125%（少し引き）"},
		{"id": CAMERA_PRESET_PULL_2, "label": "150%（かなり引き）"}
	]


func reset_camera_to_default() -> void:
	set_camera_preset(DEFAULT_CAMERA_PRESET)


func apply_camera_zoom() -> void:
	var zoom_value: Vector2 = get_camera_zoom()
	var camera: Camera2D = _find_player_camera()
	if camera != null:
		camera.zoom = zoom_value
	camera_zoom_changed.emit(_camera_preset, zoom_value, get_camera_preset_label())


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
	config.set_value(SECTION_GRAPHICS, KEY_CAMERA_PRESET, _camera_preset)

	var save_result: int = config.save(SETTINGS_PATH)
	if save_result != OK:
		push_error("設定の保存に失敗: %s" % SETTINGS_PATH)


func load_settings() -> void:
	var config := ConfigFile.new()
	var load_result: int = config.load(SETTINGS_PATH)
	if load_result != OK:
		_bgm_ratio = DEFAULT_BGM_RATIO
		_voice_ratio = DEFAULT_VOICE_RATIO
		_camera_preset = DEFAULT_CAMERA_PRESET
		return

	var raw_bgm: Variant = config.get_value(SECTION_AUDIO, KEY_BGM_RATIO, DEFAULT_BGM_RATIO)
	var raw_voice: Variant = config.get_value(SECTION_AUDIO, KEY_VOICE_RATIO, DEFAULT_VOICE_RATIO)
	var raw_camera_preset: Variant = config.get_value(SECTION_GRAPHICS, KEY_CAMERA_PRESET, DEFAULT_CAMERA_PRESET)
	_bgm_ratio = clampf(float(raw_bgm), 0.0, 1.0)
	_voice_ratio = clampf(float(raw_voice), 0.0, 1.0)
	_camera_preset = _normalize_camera_preset(str(raw_camera_preset))


func _normalize_camera_preset(value: String) -> String:
	match value:
		CAMERA_PRESET_CURRENT, CAMERA_PRESET_PULL_1, CAMERA_PRESET_PULL_2:
			return value
		_:
			return DEFAULT_CAMERA_PRESET


func _on_tree_node_added(node: Node) -> void:
	if node == null:
		return

	if node is Camera2D or node.name == "Player" or node.name == "CharacterBody2D":
		call_deferred("apply_camera_zoom")


func _find_player_camera() -> Camera2D:
	var scene: Node = get_tree().current_scene
	if scene != null:
		var direct: Camera2D = scene.get_node_or_null("Sortables/Player/CharacterBody2D/Camera2D") as Camera2D
		if direct != null:
			return direct

		var player_root: Node = scene.find_child("Player", true, false)
		if player_root != null:
			var nested: Camera2D = player_root.get_node_or_null("CharacterBody2D/Camera2D") as Camera2D
			if nested != null:
				return nested

	return get_node_or_null("/root/Main/Sortables/Player/CharacterBody2D/Camera2D") as Camera2D

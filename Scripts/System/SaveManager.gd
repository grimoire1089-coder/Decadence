extends Node

signal save_loaded(save_data: Dictionary)
signal save_saved(save_path: String, save_data: Dictionary)
signal save_failed(message: String)

const SAVE_VERSION: int = 1
const SAVE_DIRECTORY: String = "user://saves"
const DEFAULT_SLOT_NAME: String = "slot_01"
const SAVE_FILE_EXTENSION: String = ".json"

const SAVEABLE_AUTOLOADS: PackedStringArray = [
	"TimeManager",
	"MessageLog",
	"UiModalManager",
	"BgmSettingsManager",
	"CurrencyManager",
	"PlayerStatsManager",
	"RoleManager",
	"CombatIndicatorManager",
]

func get_save_path(slot_name: String = DEFAULT_SLOT_NAME) -> String:
	var normalized: String = slot_name.strip_edges()
	if normalized.is_empty():
		normalized = DEFAULT_SLOT_NAME
	if not normalized.ends_with(SAVE_FILE_EXTENSION):
		normalized += SAVE_FILE_EXTENSION
	return "%s/%s" % [SAVE_DIRECTORY, normalized]


func ensure_save_directory() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIRECTORY)


func new_empty_save() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"meta": {
			"slot_name": DEFAULT_SLOT_NAME,
			"saved_at_unix": 0,
			"play_time_sec": 0,
		},
		"scene": {
			"current_scene": "",
			"spawn_marker": "",
		},
		"autoloads": {},
		"world": {
			"scene_root": {},
			"persistent_nodes": {},
			"player": {},
		},
	}


func has_save(slot_name: String = DEFAULT_SLOT_NAME) -> bool:
	return FileAccess.file_exists(get_save_path(slot_name))


func load_save(slot_name: String = DEFAULT_SLOT_NAME) -> Dictionary:
	ensure_save_directory()
	var save_path: String = get_save_path(slot_name)
	if not FileAccess.file_exists(save_path):
		return new_empty_save()

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_emit_load_error("セーブファイルを開けませんでした: %s" % save_path)
		return new_empty_save()

	var raw_text: String = file.get_as_text()
	file.close()

	if raw_text.strip_edges().is_empty():
		return new_empty_save()

	var json: JSON = JSON.new()
	var parse_error: int = json.parse(raw_text)
	if parse_error != OK:
		_emit_load_error("セーブファイルの解析に失敗しました: %s (line %d)" % [json.get_error_message(), json.get_error_line()])
		return new_empty_save()

	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		_emit_load_error("セーブファイルの形式が不正です: %s" % save_path)
		return new_empty_save()

	var save_data: Dictionary = _normalize_save_data(parsed)
	emit_signal("save_loaded", save_data)
	return save_data


func load_or_create_boot_save(slot_name: String = DEFAULT_SLOT_NAME) -> Dictionary:
	if has_save(slot_name):
		return load_save(slot_name)
	var save_data: Dictionary = new_empty_save()
	save_data["meta"]["slot_name"] = slot_name
	return save_data


func save_game(current_scene: Node = null, slot_name: String = DEFAULT_SLOT_NAME) -> bool:
	ensure_save_directory()
	if current_scene == null:
		current_scene = get_tree().current_scene

	var save_data: Dictionary = new_empty_save()
	save_data["meta"]["slot_name"] = slot_name
	save_data["meta"]["saved_at_unix"] = Time.get_unix_time_from_system()
	save_data["autoloads"] = _collect_autoload_data()
	save_data["world"] = export_scene_data(current_scene)

	if is_instance_valid(current_scene):
		save_data["scene"]["current_scene"] = String(current_scene.scene_file_path)

	var save_path: String = get_save_path(slot_name)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		_emit_load_error("セーブファイルを書き込めませんでした: %s" % save_path)
		return false

	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	emit_signal("save_saved", save_path, save_data)
	return true


func get_saved_scene_path(save_data: Dictionary, fallback_scene_path: String) -> String:
	var scene_data: Dictionary = save_data.get("scene", {}) as Dictionary
	var saved_path: String = String(scene_data.get("current_scene", "")).strip_edges()
	if saved_path.is_empty():
		return fallback_scene_path
	return saved_path


func export_scene_data(scene_root: Node) -> Dictionary:
	var world_data: Dictionary = {
		"scene_root": {},
		"persistent_nodes": {},
		"player": {},
	}

	if not is_instance_valid(scene_root):
		return world_data

	if scene_root.has_method("export_save_data"):
		var exported_root: Variant = scene_root.call("export_save_data")
		if typeof(exported_root) == TYPE_DICTIONARY:
			world_data["scene_root"] = exported_root

	var player := _find_player_node(scene_root)
	if player != null and player is Node2D:
		world_data["player"] = {
			"path": String(scene_root.get_path_to(player)),
			"position": {
				"x": player.global_position.x,
				"y": player.global_position.y,
			},
		}
		if player.has_method("export_save_data"):
			var player_export: Variant = player.call("export_save_data")
			if typeof(player_export) == TYPE_DICTIONARY:
				world_data["player"]["data"] = player_export

	for node in get_tree().get_nodes_in_group("save_persistent"):
		if not _is_descendant_of(scene_root, node):
			continue
		if not node.has_method("export_save_data"):
			continue

		var persistent_id := _get_persistent_id(node)
		if persistent_id.is_empty():
			continue

		var node_export: Variant = node.call("export_save_data")
		if typeof(node_export) != TYPE_DICTIONARY:
			continue

		world_data["persistent_nodes"][persistent_id] = node_export

	return world_data


func apply_world_state(scene_root: Node, save_data: Dictionary) -> void:
	if not is_instance_valid(scene_root):
		return

	var world_data: Dictionary = save_data.get("world", {}) as Dictionary
	var root_data: Dictionary = world_data.get("scene_root", {}) as Dictionary
	if scene_root.has_method("import_save_data") and not root_data.is_empty():
		scene_root.call("import_save_data", root_data)

	var persistent_map: Dictionary = world_data.get("persistent_nodes", {}) as Dictionary
	if not persistent_map.is_empty():
		for node in get_tree().get_nodes_in_group("save_persistent"):
			if not _is_descendant_of(scene_root, node):
				continue
			if not node.has_method("import_save_data"):
				continue
			var persistent_id := _get_persistent_id(node)
			if persistent_id.is_empty():
				continue
			if persistent_map.has(persistent_id):
				node.call("import_save_data", persistent_map[persistent_id])

	_apply_player_state(scene_root, world_data.get("player", {}))

	if scene_root.has_method("after_save_data_applied"):
		scene_root.call_deferred("after_save_data_applied", save_data)


func collect_autoload_save_data() -> Dictionary:
	return _collect_autoload_data()


func apply_autoload_save_data(save_data: Dictionary) -> void:
	var autoload_data: Dictionary = save_data.get("autoloads", {}) as Dictionary
	for autoload_name in autoload_data.keys():
		var autoload: Node = get_node_or_null("/root/%s" % String(autoload_name))
		if autoload == null:
			continue
		if autoload.has_method("import_save_data"):
			autoload.call("import_save_data", autoload_data[autoload_name])


func _collect_autoload_data() -> Dictionary:
	var result: Dictionary = {}
	for autoload_name in SAVEABLE_AUTOLOADS:
		var autoload: Node = get_node_or_null("/root/%s" % autoload_name)
		if autoload == null:
			continue
		if not autoload.has_method("export_save_data"):
			continue
		var export_data: Variant = autoload.call("export_save_data")
		if typeof(export_data) != TYPE_DICTIONARY:
			continue
		result[autoload_name] = export_data
	return result


func _apply_player_state(scene_root: Node, player_data: Dictionary) -> void:
	if player_data.is_empty():
		return

	var player: Node = _find_player_node(scene_root)
	if player == null:
		var relative_path: NodePath = NodePath(String(player_data.get("path", "")))
		if not relative_path.is_empty() and scene_root.has_node(relative_path):
			player = scene_root.get_node(relative_path)

	if player == null:
		return

	if player is Node2D:
		var position_data: Dictionary = player_data.get("position", {}) as Dictionary
		if not position_data.is_empty():
			player.global_position = Vector2(
				float(position_data.get("x", player.global_position.x)),
				float(position_data.get("y", player.global_position.y))
			)

	var player_save_data: Dictionary = player_data.get("data", {}) as Dictionary
	if player.has_method("import_save_data") and not player_save_data.is_empty():
		player.call("import_save_data", player_save_data)


func _find_player_node(scene_root: Node) -> Node:
	for node in get_tree().get_nodes_in_group("player"):
		if _is_descendant_of(scene_root, node):
			return node
	return null


func _get_persistent_id(node: Node) -> String:
	if node.has_method("get_persistent_save_id"):
		return String(node.call("get_persistent_save_id")).strip_edges()
	var value: Variant = node.get("persistent_id")
	if typeof(value) == TYPE_STRING:
		return String(value).strip_edges()
	return ""


func _is_descendant_of(root: Node, candidate: Node) -> bool:
	if root == null or candidate == null:
		return false
	var current: Node = candidate
	while current != null:
		if current == root:
			return true
		current = current.get_parent()
	return false


func _normalize_save_data(raw_data: Dictionary) -> Dictionary:
	var save_data: Dictionary = new_empty_save()
	save_data.merge(raw_data, true)

	if not save_data.has("meta") or typeof(save_data["meta"]) != TYPE_DICTIONARY:
		save_data["meta"] = new_empty_save()["meta"]
	if not save_data.has("scene") or typeof(save_data["scene"]) != TYPE_DICTIONARY:
		save_data["scene"] = new_empty_save()["scene"]
	if not save_data.has("autoloads") or typeof(save_data["autoloads"]) != TYPE_DICTIONARY:
		save_data["autoloads"] = {}
	if not save_data.has("world") or typeof(save_data["world"]) != TYPE_DICTIONARY:
		save_data["world"] = new_empty_save()["world"]

	if int(save_data.get("save_version", 0)) <= 0:
		save_data["save_version"] = SAVE_VERSION

	return save_data


func _emit_load_error(message: String) -> void:
	push_warning(message)
	emit_signal("save_failed", message)

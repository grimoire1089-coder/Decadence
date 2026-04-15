extends RefCounted
class_name ItemRegistry

var items_by_id: Dictionary = {}
var items_by_path: Dictionary = {}
var conditions_by_id: Dictionary = {}
var conditions_by_path: Dictionary = {}
var conditions_by_name: Dictionary = {}
var labels_by_id: Dictionary = {}
var errors: PackedStringArray = PackedStringArray()


func clear() -> void:
	items_by_id.clear()
	items_by_path.clear()
	conditions_by_id.clear()
	conditions_by_path.clear()
	conditions_by_name.clear()
	labels_by_id.clear()
	errors = PackedStringArray()


func load_items_from_folder(folder_path: String, recursive: bool = true) -> void:
	if folder_path.is_empty():
		return
	if not DirAccess.dir_exists_absolute(folder_path):
		errors.append("アイテムフォルダが見つからない: %s" % folder_path)
		return
	_collect_items(folder_path, recursive)


func load_conditions_from_folder(folder_path: String, recursive: bool = true) -> void:
	if folder_path.is_empty():
		return
	if not DirAccess.dir_exists_absolute(folder_path):
		errors.append("条件フォルダが見つからない: %s" % folder_path)
		return
	_collect_conditions(folder_path, recursive)


func resolve_item(item_id: StringName, item_path: String = "") -> ItemData:
	if not item_path.is_empty():
		var by_path: ItemData = items_by_path.get(item_path, null) as ItemData
		if by_path != null:
			return by_path
		var loaded: ItemData = load(item_path) as ItemData
		if loaded != null:
			_register_item(loaded, item_path)
			return loaded

	if not String(item_id).is_empty():
		var key: String = String(item_id)
		var by_id: ItemData = items_by_id.get(key, null) as ItemData
		if by_id != null:
			return by_id

	return null


func resolve_condition(condition_id: StringName, condition_path: String = "") -> ItemCondition:
	if not condition_path.is_empty():
		var by_path: ItemCondition = conditions_by_path.get(condition_path, null) as ItemCondition
		if by_path != null:
			return by_path
		var loaded: ItemCondition = load(condition_path) as ItemCondition
		if loaded != null:
			_register_condition(loaded, condition_path)
			return loaded

	if not String(condition_id).is_empty():
		var key: String = String(condition_id)
		var by_id: ItemCondition = conditions_by_id.get(key, null) as ItemCondition
		if by_id != null:
			return by_id
		var by_name: ItemCondition = conditions_by_name.get(key, null) as ItemCondition
		if by_name != null:
			return by_name

	return null


func resolve_label(label_id: StringName) -> ItemTag:
	if String(label_id).is_empty():
		return null
	return labels_by_id.get(String(label_id), null) as ItemTag


func _collect_items(folder_path: String, recursive: bool) -> void:
	var dir: DirAccess = DirAccess.open(folder_path)
	if dir == null:
		errors.append("アイテムフォルダを開けない: %s" % folder_path)
		return

	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue

		var full_path: String = folder_path.path_join(entry)
		if dir.current_is_dir():
			if recursive:
				_collect_items(full_path, true)
			continue

		var lower_entry: String = entry.to_lower()
		if not lower_entry.ends_with(".tres") and not lower_entry.ends_with(".res"):
			continue

		var item_data: ItemData = load(full_path) as ItemData
		if item_data == null:
			continue
		_register_item(item_data, full_path)

	dir.list_dir_end()


func _collect_conditions(folder_path: String, recursive: bool) -> void:
	var dir: DirAccess = DirAccess.open(folder_path)
	if dir == null:
		errors.append("条件フォルダを開けない: %s" % folder_path)
		return

	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue

		var full_path: String = folder_path.path_join(entry)
		if dir.current_is_dir():
			if recursive:
				_collect_conditions(full_path, true)
			continue

		var lower_entry: String = entry.to_lower()
		if not lower_entry.ends_with(".tres") and not lower_entry.ends_with(".res"):
			continue

		var condition: ItemCondition = load(full_path) as ItemCondition
		if condition == null:
			continue
		_register_condition(condition, full_path)

	dir.list_dir_end()


func _register_item(item_data: ItemData, path_hint: String = "") -> void:
	if item_data == null:
		return

	var actual_path: String = path_hint if not path_hint.is_empty() else item_data.resource_path
	if not actual_path.is_empty():
		items_by_path[actual_path] = item_data

	if not String(item_data.id).is_empty():
		items_by_id[String(item_data.id)] = item_data
	elif not actual_path.is_empty():
		items_by_id[actual_path.get_file().get_basename()] = item_data

	for label in item_data.get_valid_labels():
		_register_label(label)


func _register_condition(condition: ItemCondition, path_hint: String = "") -> void:
	if condition == null:
		return

	var actual_path: String = path_hint if not path_hint.is_empty() else condition.resource_path
	if not actual_path.is_empty():
		conditions_by_path[actual_path] = condition
		conditions_by_name[actual_path.get_file().get_basename()] = condition

	var registry_key: String = condition.get_registry_key()
	if not registry_key.is_empty():
		conditions_by_id[registry_key] = condition
		conditions_by_name[registry_key] = condition
	elif not actual_path.is_empty():
		conditions_by_id[actual_path.get_file().get_basename()] = condition

	for label in condition.require_all_labels:
		_register_label(label)
	for label in condition.require_any_labels:
		_register_label(label)
	for label in condition.forbid_labels:
		_register_label(label)


func _register_label(label: ItemTag) -> void:
	if label == null:
		return
	if String(label.id).is_empty():
		return
	labels_by_id[String(label.id)] = label

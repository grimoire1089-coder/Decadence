@tool
extends Resource
class_name ItemCondition

@export var id: StringName = &""
@export var condition_name: String = ""
@export_multiline var memo: String = ""

@export var require_all_labels: Array[ItemTag] = []
@export var require_any_labels: Array[ItemTag] = []
@export var forbid_labels: Array[ItemTag] = []


func get_registry_key() -> String:
	if not String(id).is_empty():
		return String(id)
	if not condition_name.is_empty():
		return condition_name
	if not resource_path.is_empty():
		return resource_path.get_file().get_basename()
	return ""


func matches(item_data: ItemData) -> bool:
	if item_data == null:
		return false

	if require_all_labels.size() > 0 and not item_data.has_all_labels(require_all_labels):
		return false

	if require_any_labels.size() > 0 and not item_data.has_any_labels(require_any_labels):
		return false

	if forbid_labels.size() > 0 and item_data.has_any_labels(forbid_labels):
		return false

	return true


func get_fail_reasons(item_data: ItemData) -> PackedStringArray:
	var reasons: PackedStringArray = PackedStringArray()

	if item_data == null:
		reasons.append("アイテムデータがありません")
		return reasons

	if require_all_labels.size() > 0 and not item_data.has_all_labels(require_all_labels):
		reasons.append("必要ラベル不足: " + ", ".join(_get_label_names(require_all_labels)))

	if require_any_labels.size() > 0 and not item_data.has_any_labels(require_any_labels):
		reasons.append("いずれかのラベルが必要: " + ", ".join(_get_label_names(require_any_labels)))

	if forbid_labels.size() > 0 and item_data.has_any_labels(forbid_labels):
		reasons.append("禁止ラベルを含む: " + ", ".join(_get_label_names(forbid_labels)))

	return reasons


func get_fail_reasons_text(item_data: ItemData, separator: String = "\n") -> String:
	return separator.join(get_fail_reasons(item_data))


func get_summary_text() -> String:
	var parts: PackedStringArray = PackedStringArray()

	if require_all_labels.size() > 0:
		parts.append("全部: %s" % ", ".join(_get_label_names(require_all_labels)))
	if require_any_labels.size() > 0:
		parts.append("どれか: %s" % ", ".join(_get_label_names(require_any_labels)))
	if forbid_labels.size() > 0:
		parts.append("禁止: %s" % ", ".join(_get_label_names(forbid_labels)))

	if not condition_name.is_empty():
		return condition_name
	if parts.is_empty():
		return memo if not memo.is_empty() else "条件食材"
	return " / ".join(parts)


func _get_label_names(source: Array[ItemTag]) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}

	for label in source:
		if label == null:
			continue
		if String(label.id).is_empty():
			continue
		if seen.has(label.id):
			continue

		seen[label.id] = true
		result.append(label.get_display_name())

	return result

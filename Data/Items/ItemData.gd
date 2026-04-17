@tool
extends Resource
class_name ItemData

const FOOD_TAG_IDS: Array[StringName] = [&"food", &"食品"]
const DRINK_TAG_IDS: Array[StringName] = [&"drink", &"飲料"]

@export var id: StringName
@export var item_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export_range(1, 999999999) var max_stack: int = 999999999

# 売値
@export_range(0, 999999999) var price: int = 0

# 買値
@export_range(0, 999999999) var buy_price: int = 0

# 品質
@export_range(0, 999999999) var quality: int = 0

# ランク（0～5）
@export_range(0, 5) var rank: int = 0

@export_range(0, 999999999) var fullness_restore: int = 0
@export_range(0, 999999999) var fatigue_restore: int = 0

# 旧ビットフラグ方式との互換保持用（非表示）。
# 既存 .tres を差し替えても値が読み込めるよう、一旦残してある。
# 新規運用では使わず labels へ統一する。
@export_storage var tags: int = 0
@export_storage var traits: int = 0

# 新方式：ラベルを 1 本化
@export var labels: Array = []


func get_sell_price() -> int:
	if price < 0:
		return 0
	return price


func get_buy_price() -> int:
	if buy_price < 0:
		return 0
	return buy_price


func get_quality() -> int:
	if quality < 0:
		return 0
	return quality


func get_rank() -> int:
	if rank < 0:
		return 0
	if rank > 5:
		return 5
	return rank


func get_rank_stars() -> String:
	var clamped_rank: int = get_rank()
	var stars: String = ""

	for _i in range(clamped_rank):
		stars += "★"

	for _i in range(5 - clamped_rank):
		stars += "☆"

	return stars


func get_fullness_restore() -> int:
	if fullness_restore < 0:
		return 0
	return fullness_restore


func get_fatigue_restore() -> int:
	if fatigue_restore < 0:
		return 0
	return fatigue_restore


func get_valid_labels() -> Array:
	var result: Array = []
	var seen: Dictionary = {}

	for label_variant in labels:
		var label: ItemTag = label_variant as ItemTag
		if label == null:
			continue

		var label_id: StringName = label.id
		if String(label_id).is_empty():
			continue
		if seen.has(label_id):
			continue

		seen[label_id] = true
		result.append(label)

	return result


func has_label(label: ItemTag) -> bool:
	if label == null:
		return false
	return has_label_id(label.id)


func has_label_id(label_id: StringName) -> bool:
	if String(label_id).is_empty():
		return false

	for label_variant in labels:
		var label: ItemTag = label_variant as ItemTag
		if label == null:
			continue
		if label.id == label_id:
			return true

	return false


func has_label_in_category(label_id: StringName, category: StringName) -> bool:
	if String(label_id).is_empty():
		return false

	for label_variant in labels:
		var label: ItemTag = label_variant as ItemTag
		if label == null:
			continue
		if label.id != label_id:
			continue
		if not String(category).is_empty() and label.category != category:
			continue
		return true

	return false


func has_any_labels(check_labels: Array) -> bool:
	for label_variant in check_labels:
		var label: ItemTag = label_variant as ItemTag
		if label == null:
			continue
		if has_label_id(label.id):
			return true
	return false


func has_all_labels(check_labels: Array) -> bool:
	for label_variant in check_labels:
		var label: ItemTag = label_variant as ItemTag
		if label == null:
			continue
		if not has_label_id(label.id):
			return false
	return true


func add_label(label: ItemTag) -> void:
	if label == null:
		return
	if String(label.id).is_empty():
		return
	if has_label_id(label.id):
		return
	labels.append(label)


func remove_label(label: ItemTag) -> void:
	if label == null:
		return
	remove_label_by_id(label.id)


func remove_label_by_id(label_id: StringName) -> void:
	if String(label_id).is_empty():
		return

	for i in range(labels.size() - 1, -1, -1):
		var label: ItemTag = labels[i] as ItemTag
		if label == null:
			continue
		if label.id == label_id:
			labels.remove_at(i)


func get_label_names(category: StringName = &"") -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}

	for label_variant in labels:
		var label: ItemTag = label_variant as ItemTag
		if label == null:
			continue
		if String(label.id).is_empty():
			continue
		if not String(category).is_empty() and label.category != category:
			continue
		if seen.has(label.id):
			continue

		seen[label.id] = true
		result.append(label.get_display_name())

	return result


func get_labels_text(separator: String = " / ", category: StringName = &"") -> String:
	return separator.join(get_label_names(category))


func get_tag_names() -> PackedStringArray:
	return get_label_names(&"tag")


func get_trait_names() -> PackedStringArray:
	return get_label_names(&"trait")


func get_tags_text(separator: String = " / ") -> String:
	return get_labels_text(separator, &"tag")


func get_traits_text(separator: String = " / ") -> String:
	return get_labels_text(separator, &"trait")


func has_tag_id(tag_id: StringName) -> bool:
	return has_label_in_category(tag_id, &"tag")


func is_food() -> bool:
	for tag_id in FOOD_TAG_IDS:
		if has_tag_id(tag_id):
			return true
	return false


func is_drink() -> bool:
	for tag_id in DRINK_TAG_IDS:
		if has_tag_id(tag_id):
			return true
	return false


func can_eat() -> bool:
	return is_food() or is_drink()


func has_trait_id(trait_id: StringName) -> bool:
	return has_label_in_category(trait_id, &"trait")


func passes_filter(
	require_all_labels: Array = [],
	require_any_labels: Array = [],
	forbid_labels: Array = []
) -> bool:
	if require_all_labels.size() > 0 and not has_all_labels(require_all_labels):
		return false

	if require_any_labels.size() > 0 and not has_any_labels(require_any_labels):
		return false

	if forbid_labels.size() > 0 and has_any_labels(forbid_labels):
		return false

	return true

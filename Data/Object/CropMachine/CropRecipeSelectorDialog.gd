extends ConfirmationDialog
class_name CropRecipeSelectorDialog

signal recipe_selected(recipe_key: String)

const DIALOG_MIN_SIZE: Vector2 = Vector2(760, 540)

@onready var search_input: LineEdit = $Body/RecipeSearchInput
@onready var result_list: ItemList = $Body/BodySplit/LeftBox/RecipeResultList
@onready var detail_label: Label = $Body/BodySplit/RightBox/RecipeDetailLabel
@onready var empty_label: Label = $Body/BodySplit/LeftBox/RecipeEmptyLabel

var _selected_recipe_key: String = ""
var _entries: Array = []
var _item_count_resolver: Callable = Callable()
var _exp_resolver: Callable = Callable()


func _ready() -> void:
	exclusive = true
	dialog_hide_on_ok = true
	min_size = DIALOG_MIN_SIZE
	size = DIALOG_MIN_SIZE
	if get_ok_button() != null:
		get_ok_button().text = "選択"
	if get_cancel_button() != null:
		get_cancel_button().text = "閉じる"

	if not search_input.text_changed.is_connected(_on_search_text_changed):
		search_input.text_changed.connect(_on_search_text_changed)
	if not result_list.item_selected.is_connected(_on_result_list_item_selected):
		result_list.item_selected.connect(_on_result_list_item_selected)
	if not result_list.item_activated.is_connected(_on_result_list_item_activated):
		result_list.item_activated.connect(_on_result_list_item_activated)
	if not confirmed.is_connected(_on_confirmed):
		confirmed.connect(_on_confirmed)

	_update_detail_text()


func configure_selector(recipes: Array, selected_recipe_key: String, item_count_resolver: Callable, exp_resolver: Callable) -> void:
	_selected_recipe_key = selected_recipe_key
	_item_count_resolver = item_count_resolver
	_exp_resolver = exp_resolver
	_rebuild_entries(recipes)
	_apply_filter(search_input.text)


func open_selector() -> void:
	popup_centered_ratio(0.6)
	search_input.grab_focus()
	search_input.select_all()


func reset_selector_state() -> void:
	hide()
	_entries.clear()
	_selected_recipe_key = ""
	if search_input != null:
		search_input.text = ""
	if result_list != null:
		result_list.clear()
	_update_detail_text()


func _rebuild_entries(recipes: Array) -> void:
	_entries.clear()
	var has_known_seed_counts: bool = false
	var all_entries: Array = []

	for recipe in recipes:
		if recipe == null or not recipe.is_valid_recipe():
			continue

		var seed_name: String = _get_seed_name(recipe)
		var seed_count: int = _resolve_item_count(recipe.seed_item)
		var has_seed_count: bool = seed_count >= 0
		if has_seed_count:
			has_known_seed_counts = true

		var entry: Dictionary = {
			"recipe": recipe,
			"key": _get_recipe_key(recipe),
			"seed_name": seed_name,
			"seed_count": seed_count,
			"has_seed_count": has_seed_count,
			"list_text": _build_item_text(recipe, seed_name, seed_count, has_seed_count),
			"detail_text": _build_detail_text(recipe, seed_name, seed_count, has_seed_count),
			"search_text": (recipe.get_display_name() + " " + seed_name).to_lower()
		}
		all_entries.append(entry)

	if has_known_seed_counts:
		for entry in all_entries:
			if bool(entry.get("has_seed_count", false)) and int(entry.get("seed_count", 0)) <= 0:
				continue
			_entries.append(entry)
	else:
		_entries = all_entries


func _get_seed_name(recipe: CropRecipe) -> String:
	if recipe == null or recipe.seed_item == null:
		return "種"
	if not recipe.seed_item.item_name.is_empty():
		return recipe.seed_item.item_name
	return str(recipe.seed_item.id)


func _build_item_text(recipe: CropRecipe, seed_name: String, seed_count: int, has_seed_count: bool) -> String:
	var seed_count_text: String = "所持数不明"
	if has_seed_count:
		seed_count_text = "所持 %d" % seed_count
	return "%s  [%s / %s / %d分 / 収穫%d]" % [recipe.get_display_name(), seed_name, seed_count_text, recipe.grow_minutes, recipe.harvest_amount]


func _build_detail_text(recipe: CropRecipe, seed_name: String, seed_count: int, has_seed_count: bool) -> String:
	var lines: PackedStringArray = []
	lines.append("作物: %s" % recipe.get_display_name())
	lines.append("種: %s" % seed_name)
	if has_seed_count:
		lines.append("所持している種: %d 個" % seed_count)
	else:
		lines.append("所持している種: 取得できない")
	lines.append("成長時間: %d 分" % recipe.grow_minutes)
	lines.append("収穫量: %d 個" % recipe.harvest_amount)
	lines.append("獲得EXP: %d" % _resolve_recipe_exp(recipe))
	return "\n".join(lines)


func _apply_filter(filter_text: String) -> void:
	result_list.clear()
	var normalized_filter: String = filter_text.strip_edges().to_lower()
	var filtered_entries: Array = []

	for entry in _entries:
		var search_text: String = str(entry.get("search_text", "")).to_lower()
		if not normalized_filter.is_empty() and not search_text.contains(normalized_filter):
			continue
		filtered_entries.append(entry)

	for entry in filtered_entries:
		var item_index: int = result_list.item_count
		result_list.add_item(str(entry.get("list_text", "")))
		result_list.set_item_metadata(item_index, entry.get("key", ""))

	empty_label.visible = filtered_entries.is_empty()
	result_list.visible = not filtered_entries.is_empty()

	var select_index: int = -1
	for i in range(result_list.item_count):
		if str(result_list.get_item_metadata(i)) == _selected_recipe_key:
			select_index = i
			break

	if select_index < 0 and result_list.item_count > 0:
		select_index = 0

	if select_index >= 0:
		result_list.select(select_index)

	_update_detail_text()
	if get_ok_button() != null:
		get_ok_button().disabled = result_list.item_count <= 0


func _update_detail_text() -> void:
	if result_list == null or result_list.item_count <= 0:
		detail_label.text = "選択できる種がない。インベントリに種を入れるとここに出る。"
		return

	var selected_items: PackedInt32Array = result_list.get_selected_items()
	if selected_items.is_empty():
		detail_label.text = "作物を選択すると詳細が出る。"
		return

	var recipe_key: String = str(result_list.get_item_metadata(selected_items[0]))
	for entry in _entries:
		if str(entry.get("key", "")) == recipe_key:
			detail_label.text = str(entry.get("detail_text", ""))
			return

	detail_label.text = "詳細を取得できなかった。"


func _emit_selected_recipe() -> void:
	if result_list == null:
		return

	var selected_items: PackedInt32Array = result_list.get_selected_items()
	if selected_items.is_empty():
		return

	_selected_recipe_key = str(result_list.get_item_metadata(selected_items[0]))
	recipe_selected.emit(_selected_recipe_key)


func _resolve_item_count(item_data: ItemData) -> int:
	if item_data == null:
		return -1
	if not _item_count_resolver.is_valid():
		return -1

	var value: Variant = _item_count_resolver.call(item_data)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return max(int(value), 0)
	return -1


func _resolve_recipe_exp(recipe: CropRecipe) -> int:
	if recipe == null:
		return 0
	if not _exp_resolver.is_valid():
		return 0

	var value: Variant = _exp_resolver.call(recipe)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return 0


func _get_recipe_key(recipe: CropRecipe) -> String:
	if recipe == null:
		return ""
	if not recipe.resource_path.is_empty():
		return recipe.resource_path
	if not str(recipe.id).is_empty():
		return str(recipe.id)
	return recipe.get_display_name()


func _on_search_text_changed(new_text: String) -> void:
	_apply_filter(new_text)


func _on_result_list_item_selected(_index: int) -> void:
	_update_detail_text()


func _on_result_list_item_activated(_index: int) -> void:
	_emit_selected_recipe()
	hide()


func _on_confirmed() -> void:
	_emit_selected_recipe()

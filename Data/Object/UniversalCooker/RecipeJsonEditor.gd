@tool
extends Control
class_name RecipeJsonEditor

var recipe_database: RecipeDatabase = RecipeDatabase.new()
var registry: ItemRegistry = ItemRegistry.new()
var recipe_rows: Array = []
var preview_recipes: Array[CookingRecipe] = []
var preview_errors: PackedStringArray = PackedStringArray()
var available_food_items: Array[ItemData] = []
var available_labels: Array[ItemTag] = []
var selected_recipe_model_index: int = -1
var selected_ingredient_index: int = -1
var is_dirty: bool = false
var _suppress_text_changed: bool = false

@onready var json_path_edit: LineEdit = $Panel/VBoxContainer/PathsVBox/JsonPathEdit
@onready var item_folder_edit: LineEdit = $Panel/VBoxContainer/PathsVBox/ItemFolderEdit
@onready var condition_folder_edit: LineEdit = $Panel/VBoxContainer/PathsVBox/ConditionFolderEdit
@onready var load_button: Button = $Panel/VBoxContainer/TopButtonsHBox/LoadButton
@onready var apply_json_button: Button = $Panel/VBoxContainer/TopButtonsHBox/ApplyJsonButton
@onready var validate_button: Button = $Panel/VBoxContainer/TopButtonsHBox/ValidateButton
@onready var pretty_button: Button = $Panel/VBoxContainer/TopButtonsHBox/PrettyButton
@onready var save_button: Button = $Panel/VBoxContainer/TopButtonsHBox/SaveButton
@onready var recipe_search_edit: LineEdit = $Panel/VBoxContainer/HSplitContainer/LeftVBox/RecipeSearchEdit
@onready var recipe_list: ItemList = $Panel/VBoxContainer/HSplitContainer/LeftVBox/RecipeList
@onready var new_recipe_button: Button = $Panel/VBoxContainer/HSplitContainer/LeftVBox/RecipeButtonsHBox/NewRecipeButton
@onready var add_recipe_button: Button = $Panel/VBoxContainer/HSplitContainer/LeftVBox/RecipeButtonsHBox/AddRecipeButton
@onready var update_recipe_button: Button = $Panel/VBoxContainer/HSplitContainer/LeftVBox/RecipeButtonsHBox/UpdateRecipeButton
@onready var delete_recipe_button: Button = $Panel/VBoxContainer/HSplitContainer/LeftVBox/RecipeButtonsHBox/DeleteRecipeButton
@onready var recipe_id_edit: LineEdit = $Panel/VBoxContainer/HSplitContainer/CenterVBox/FormGrid/RecipeIdEdit
@onready var recipe_name_edit: LineEdit = $Panel/VBoxContainer/HSplitContainer/CenterVBox/FormGrid/RecipeNameEdit
@onready var description_edit: TextEdit = $Panel/VBoxContainer/HSplitContainer/CenterVBox/FormGrid/DescriptionEdit
@onready var result_item_option: OptionButton = $Panel/VBoxContainer/HSplitContainer/CenterVBox/FormGrid/ResultItemOption
@onready var result_count_spin: SpinBox = $Panel/VBoxContainer/HSplitContainer/CenterVBox/FormGrid/ResultCountSpin
@onready var cook_minutes_spin: SpinBox = $Panel/VBoxContainer/HSplitContainer/CenterVBox/FormGrid/CookMinutesSpin
@onready var station_option: OptionButton = $Panel/VBoxContainer/HSplitContainer/CenterVBox/FormGrid/StationOption
@onready var upgrade_level_spin: SpinBox = $Panel/VBoxContainer/HSplitContainer/CenterVBox/FormGrid/UpgradeLevelSpin
@onready var quality_multiplier_spin: SpinBox = $Panel/VBoxContainer/HSplitContainer/CenterVBox/FormGrid/QualityMultiplierSpin
@onready var cooking_exp_spin: SpinBox = $Panel/VBoxContainer/HSplitContainer/CenterVBox/FormGrid/CookingExpSpin
@onready var food_search_edit: LineEdit = $Panel/VBoxContainer/HSplitContainer/CenterVBox/CandidateSplit/FoodVBox/FoodSearchEdit
@onready var food_item_list: ItemList = $Panel/VBoxContainer/HSplitContainer/CenterVBox/CandidateSplit/FoodVBox/FoodItemList
@onready var set_result_button: Button = $Panel/VBoxContainer/HSplitContainer/CenterVBox/CandidateSplit/FoodVBox/FoodButtonsHBox/SetResultButton
@onready var add_item_ingredient_button: Button = $Panel/VBoxContainer/HSplitContainer/CenterVBox/CandidateSplit/FoodVBox/FoodButtonsHBox/AddItemIngredientButton
@onready var label_search_edit: LineEdit = $Panel/VBoxContainer/HSplitContainer/CenterVBox/CandidateSplit/LabelVBox/LabelSearchEdit
@onready var label_list: ItemList = $Panel/VBoxContainer/HSplitContainer/CenterVBox/CandidateSplit/LabelVBox/LabelList
@onready var add_label_ingredient_button: Button = $Panel/VBoxContainer/HSplitContainer/CenterVBox/CandidateSplit/LabelVBox/AddLabelIngredientButton
@onready var ingredient_list: ItemList = $Panel/VBoxContainer/HSplitContainer/CenterVBox/IngredientVBox/IngredientList
@onready var ingredient_slot_name_edit: LineEdit = $Panel/VBoxContainer/HSplitContainer/CenterVBox/IngredientVBox/IngredientEditHBox/IngredientSlotNameEdit
@onready var ingredient_count_spin: SpinBox = $Panel/VBoxContainer/HSplitContainer/CenterVBox/IngredientVBox/IngredientEditHBox/IngredientCountSpin
@onready var apply_ingredient_button: Button = $Panel/VBoxContainer/HSplitContainer/CenterVBox/IngredientVBox/IngredientButtonsHBox/ApplyIngredientButton
@onready var remove_ingredient_button: Button = $Panel/VBoxContainer/HSplitContainer/CenterVBox/IngredientVBox/IngredientButtonsHBox/RemoveIngredientButton
@onready var move_up_ingredient_button: Button = $Panel/VBoxContainer/HSplitContainer/CenterVBox/IngredientVBox/IngredientButtonsHBox/MoveUpIngredientButton
@onready var move_down_ingredient_button: Button = $Panel/VBoxContainer/HSplitContainer/CenterVBox/IngredientVBox/IngredientButtonsHBox/MoveDownIngredientButton
@onready var status_label: Label = $Panel/VBoxContainer/HSplitContainer/RightVBox/StatusLabel
@onready var detail_label: RichTextLabel = $Panel/VBoxContainer/HSplitContainer/RightVBox/DetailLabel
@onready var text_edit: TextEdit = $Panel/VBoxContainer/HSplitContainer/RightVBox/TextEdit


func _ready() -> void:
	_setup_station_option()
	load_button.pressed.connect(_on_load_pressed)
	apply_json_button.pressed.connect(_on_apply_json_pressed)
	validate_button.pressed.connect(_on_validate_pressed)
	pretty_button.pressed.connect(_on_pretty_pressed)
	save_button.pressed.connect(_on_save_pressed)
	recipe_search_edit.text_changed.connect(_on_recipe_search_changed)
	recipe_list.item_selected.connect(_on_recipe_list_selected)
	recipe_list.item_clicked.connect(_on_recipe_list_clicked)
	new_recipe_button.pressed.connect(_on_new_recipe_pressed)
	add_recipe_button.pressed.connect(_on_add_recipe_pressed)
	update_recipe_button.pressed.connect(_on_update_recipe_pressed)
	delete_recipe_button.pressed.connect(_on_delete_recipe_pressed)
	food_search_edit.text_changed.connect(_on_food_search_changed)
	food_item_list.item_selected.connect(_on_food_item_selected)
	label_search_edit.text_changed.connect(_on_label_search_changed)
	label_list.item_selected.connect(_on_label_selected)
	set_result_button.pressed.connect(_on_set_result_pressed)
	add_item_ingredient_button.pressed.connect(_on_add_item_ingredient_pressed)
	add_label_ingredient_button.pressed.connect(_on_add_label_ingredient_pressed)
	ingredient_list.item_selected.connect(_on_ingredient_list_selected)
	ingredient_list.item_clicked.connect(_on_ingredient_list_clicked)
	apply_ingredient_button.pressed.connect(_on_apply_ingredient_pressed)
	remove_ingredient_button.pressed.connect(_on_remove_ingredient_pressed)
	move_up_ingredient_button.pressed.connect(_on_move_up_ingredient_pressed)
	move_down_ingredient_button.pressed.connect(_on_move_down_ingredient_pressed)
	text_edit.text_changed.connect(_on_text_changed)

	if json_path_edit.text.is_empty():
		json_path_edit.text = "res://Data/Cooking_Recipe/recipes.json"
	if item_folder_edit.text.is_empty():
		item_folder_edit.text = "res://Data/Items"
	if condition_folder_edit.text.is_empty():
		condition_folder_edit.text = "res://Data/Cooking_Condition"

	_reload_registry()
	_clear_form()
	_refresh_recipe_list()
	_refresh_candidate_lists()
	_update_detail_panel()
	_update_status("食材タグ対応レシピエディタ準備OK")


func _setup_station_option() -> void:
	station_option.clear()
	station_option.add_item("混ぜる", 0)
	station_option.set_item_metadata(0, "mix")
	station_option.add_item("加熱", 1)
	station_option.set_item_metadata(1, "cook")
	station_option.add_item("煮込み", 2)
	station_option.set_item_metadata(2, "boil")
	station_option.add_item("焼成", 3)
	station_option.set_item_metadata(3, "bake")
	station_option.add_item("飲み物", 4)
	station_option.set_item_metadata(4, "drink")
	station_option.add_item("発酵", 5)
	station_option.set_item_metadata(5, "ferment")
	station_option.add_item("ANY", 6)
	station_option.set_item_metadata(6, "any")


func _reload_registry() -> void:
	registry.clear()
	registry.load_items_from_folder(item_folder_edit.text.strip_edges(), true)
	registry.load_conditions_from_folder(condition_folder_edit.text.strip_edges(), true)
	_rebuild_food_items_and_labels()
	_refresh_result_options()


func _rebuild_food_items_and_labels() -> void:
	available_food_items.clear()
	available_labels.clear()

	var item_seen: Dictionary = {}
	var label_seen: Dictionary = {}

	for key in registry.items_by_id.keys():
		var item_data: ItemData = registry.items_by_id[key] as ItemData
		if item_data == null:
			continue

		var item_key: String = _get_item_key(item_data)
		if item_key.is_empty() or item_seen.has(item_key):
			continue
		item_seen[item_key] = true

		if _is_food_item(item_data):
			available_food_items.append(item_data)
			for label in item_data.get_valid_labels():
				if label == null:
					continue
				if _is_food_label(label):
					continue
				var label_key: String = String(label.id)
				if label_key.is_empty() or label_seen.has(label_key):
					continue
				label_seen[label_key] = true
				available_labels.append(label)

	available_food_items.sort_custom(_sort_food_items)
	available_labels.sort_custom(_sort_labels)


func _is_food_item(item_data: ItemData) -> bool:
	if item_data == null:
		return false
	if item_data.has_tag_id(&"food"):
		return true

	for label in item_data.get_valid_labels():
		if label == null:
			continue
		if _is_food_label(label):
			return true

	return false


func _is_food_label(label: ItemTag) -> bool:
	if label == null:
		return false
	var id_text: String = String(label.id).to_lower()
	var name_text: String = label.get_display_name().to_lower()
	return id_text == "food" or id_text == "食品" or name_text == "食品"


func _get_food_label_id() -> String:
	for label in registry.labels_by_id.values():
		var item_tag: ItemTag = label as ItemTag
		if _is_food_label(item_tag):
			return String(item_tag.id)
	return "food"




func _sort_food_items(a: ItemData, b: ItemData) -> bool:
	return _get_item_display_name(a) < _get_item_display_name(b)


func _sort_labels(a: ItemTag, b: ItemTag) -> bool:
	return a.get_display_name() < b.get_display_name()

func _refresh_result_options() -> void:
	var current_result_id: String = _get_selected_result_item_id()
	result_item_option.clear()

	for item_data in available_food_items:
		var item_index: int = result_item_option.item_count
		result_item_option.add_item(_get_item_display_name(item_data))
		result_item_option.set_item_metadata(item_index, String(item_data.id))

	if result_item_option.item_count <= 0:
		return

	var select_index: int = 0
	for i in range(result_item_option.item_count):
		if str(result_item_option.get_item_metadata(i)) == current_result_id:
			select_index = i
			break
	result_item_option.select(select_index)


func _refresh_current_ingredient_list() -> void:
	ingredient_list.clear()

	for i in range(current_ingredient_rows.size()):
		var row: Dictionary = current_ingredient_rows[i]
		var idx: int = ingredient_list.item_count
		ingredient_list.add_item(_build_ingredient_line(row))
		ingredient_list.set_item_metadata(idx, i)

	if ingredient_list.item_count <= 0:
		selected_ingredient_index = -1
		_apply_selected_ingredient_to_form()
		return

	if selected_ingredient_index < 0 or selected_ingredient_index >= ingredient_list.item_count:
		selected_ingredient_index = 0

	ingredient_list.select(selected_ingredient_index)
	_apply_selected_ingredient_to_form()


func _refresh_food_item_list() -> void:
	food_item_list.clear()
	var search_text: String = food_search_edit.text.strip_edges().to_lower()
	for item_data in available_food_items:
		var line: String = _get_item_display_name(item_data)
		if not search_text.is_empty() and line.to_lower().find(search_text) == -1:
			continue
		var idx: int = food_item_list.item_count
		food_item_list.add_item(line)
		food_item_list.set_item_metadata(idx, String(item_data.id))


func _refresh_label_list() -> void:
	label_list.clear()
	var search_text: String = label_search_edit.text.strip_edges().to_lower()
	for label in available_labels:
		var line: String = "%s [%s]" % [label.get_display_name(), String(label.category)]
		if not search_text.is_empty() and line.to_lower().find(search_text) == -1:
			continue
		var idx: int = label_list.item_count
		label_list.add_item(line)
		label_list.set_item_metadata(idx, String(label.id))


func _refresh_candidate_lists() -> void:
	_refresh_food_item_list()
	_refresh_label_list()


func _on_load_pressed() -> void:
	var path: String = json_path_edit.text.strip_edges()
	if path.is_empty():
		_update_status("JSONパスが空")
		return
	if not FileAccess.file_exists(path):
		_update_status("JSONが見つからない: %s" % path)
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_update_status("JSONを開けない: %s" % path)
		return

	_set_text_edit_text(file.get_as_text())
	is_dirty = false
	_apply_text_to_model(true)


func _on_apply_json_pressed() -> void:
	_apply_text_to_model(true)


func _on_validate_pressed() -> void:
	_reload_registry()
	_validate_current_text()
	_refresh_recipe_list()
	_update_detail_panel()


func _on_pretty_pressed() -> void:
	var parse_result: Dictionary = _parse_recipe_rows_from_text(text_edit.text)
	if not bool(parse_result.get("success", false)):
		_update_status(str(parse_result.get("message", "整形できない")))
		return
	recipe_rows = parse_result.get("rows", [])
	_commit_rows_to_text_and_refresh(false)
	is_dirty = true
	_update_status("JSONを整形した")


func _on_save_pressed() -> void:
	var path: String = json_path_edit.text.strip_edges()
	if path.is_empty():
		_update_status("保存先パスが空")
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_update_status("保存失敗: %s\nres:// に書けない環境なら user:// を使うか、エディタ上で実行してくれ" % path)
		return

	file.store_string(text_edit.text)
	is_dirty = false
	_update_status("保存した: %s" % path)
	_validate_current_text()
	_update_detail_panel()


func _apply_text_to_model(reset_selection: bool) -> void:
	var parse_result: Dictionary = _parse_recipe_rows_from_text(text_edit.text)
	if not bool(parse_result.get("success", false)):
		_update_status(str(parse_result.get("message", "JSON反映に失敗した")))
		return

	recipe_rows = parse_result.get("rows", [])
	_reload_registry()
	_validate_current_text()
	if reset_selection:
		selected_recipe_model_index = 0 if recipe_rows.size() > 0 else -1
	if selected_recipe_model_index < 0 and recipe_rows.size() > 0:
		selected_recipe_model_index = 0
	_refresh_recipe_list()
	if selected_recipe_model_index >= 0 and selected_recipe_model_index < recipe_rows.size():
		_load_form_from_recipe_row(recipe_rows[selected_recipe_model_index])
	else:
		_clear_form()
	_update_detail_panel()
	_update_status("JSONを反映した: %d件" % recipe_rows.size())


func _parse_recipe_rows_from_text(json_text: String) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"rows": [],
		"message": "JSON解析に失敗した"
	}

	var json: JSON = JSON.new()
	var err: int = json.parse(json_text)
	if err != OK:
		result["message"] = "JSON parse失敗: line=%d msg=%s" % [json.get_error_line(), json.get_error_message()]
		return result

	var data: Variant = json.data
	var rows: Array = []
	if typeof(data) == TYPE_ARRAY:
		rows = data
	elif typeof(data) == TYPE_DICTIONARY:
		var dict: Dictionary = data
		var recipe_array: Variant = dict.get("recipes", [])
		if typeof(recipe_array) == TYPE_ARRAY:
			rows = recipe_array
		else:
			result["message"] = "recipes が配列ではない"
			return result
	else:
		result["message"] = "トップレベルが配列か recipes 辞書ではない"
		return result

	var normalized_rows: Array = []
	for row_variant in rows:
		if typeof(row_variant) != TYPE_DICTIONARY:
			continue
		normalized_rows.append(_normalize_recipe_row(row_variant))

	result["success"] = true
	result["rows"] = normalized_rows
	result["message"] = "OK"
	return result


func _normalize_recipe_row(row: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	normalized["id"] = str(row.get("id", "")).strip_edges()
	normalized["recipe_name"] = str(row.get("recipe_name", row.get("name", ""))).strip_edges()
	normalized["description"] = str(row.get("description", ""))
	normalized["result_item_id"] = str(row.get("result_item_id", row.get("result_id", ""))).strip_edges()
	normalized["result_count"] = max(int(row.get("result_count", 1)), 1)
	normalized["cook_minutes"] = max(int(row.get("cook_minutes", 1)), 1)
	normalized["station_flags"] = _normalize_station_flags(row.get("station_flags", row.get("station", ["mix"])))
	normalized["required_upgrade_level"] = max(int(row.get("required_upgrade_level", 1)), 1)
	normalized["base_quality_multiplier"] = max(float(row.get("base_quality_multiplier", 1.0)), 0.1)
	normalized["cooking_exp"] = max(int(row.get("cooking_exp", 1)), 0)

	var ingredients: Array = []
	var ingredients_variant: Variant = row.get("ingredients", [])
	if typeof(ingredients_variant) == TYPE_ARRAY:
		for ingredient_variant in ingredients_variant:
			if typeof(ingredient_variant) != TYPE_DICTIONARY:
				continue
			ingredients.append(_normalize_ingredient_row(ingredient_variant))
	normalized["ingredients"] = ingredients
	return normalized


func _normalize_ingredient_row(row: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	normalized["slot_name"] = str(row.get("slot_name", row.get("name", ""))).strip_edges()
	normalized["count"] = max(int(row.get("count", 1)), 1)
	normalized["consume_on_cook"] = bool(row.get("consume_on_cook", true))

	if row.has("item_id"):
		normalized["item_id"] = str(row.get("item_id", "")).strip_edges()
	if row.has("item_path"):
		normalized["item_path"] = str(row.get("item_path", "")).strip_edges()
	if row.has("condition_id"):
		normalized["condition_id"] = str(row.get("condition_id", "")).strip_edges()
	if row.has("condition_path"):
		normalized["condition_path"] = str(row.get("condition_path", "")).strip_edges()

	var condition_variant: Variant = row.get("condition", null)
	if typeof(condition_variant) == TYPE_DICTIONARY:
		normalized["condition"] = _normalize_condition_dict(condition_variant)
	elif row.has("require_all_label_ids") or row.has("require_any_label_ids") or row.has("forbid_label_ids") or row.has("label_id") or row.has("label_ids"):
		normalized["condition"] = _normalize_condition_dict(row)

	return normalized


func _normalize_condition_dict(source: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	var condition_name: String = str(source.get("condition_name", source.get("name", ""))).strip_edges()
	if not condition_name.is_empty():
		normalized["condition_name"] = condition_name

	var all_ids: Array = _normalize_string_array(source.get("require_all_label_ids", []))
	var any_ids: Array = _normalize_string_array(source.get("require_any_label_ids", source.get("label_ids", [])))
	var forbid_ids: Array = _normalize_string_array(source.get("forbid_label_ids", []))
	var single_label_id: String = str(source.get("label_id", "")).strip_edges()
	if not single_label_id.is_empty():
		any_ids.append(single_label_id)

	all_ids = _dedupe_string_array(all_ids)
	any_ids = _dedupe_string_array(any_ids)
	forbid_ids = _dedupe_string_array(forbid_ids)

	if all_ids.size() > 0:
		normalized["require_all_label_ids"] = all_ids
	if any_ids.size() > 0:
		normalized["require_any_label_ids"] = any_ids
	if forbid_ids.size() > 0:
		normalized["forbid_label_ids"] = forbid_ids
	return normalized


func _normalize_station_flags(source: Variant) -> Array:
	var result: Array = []
	if typeof(source) == TYPE_STRING:
		result.append(_normalize_station_string(str(source)))
	elif typeof(source) == TYPE_ARRAY:
		for entry in source:
			result.append(_normalize_station_string(str(entry)))
	elif typeof(source) == TYPE_INT:
		result.append(_station_string_from_flags(int(source)))
	if result.is_empty():
		result.append("mix")
	return _dedupe_string_array(result)


func _normalize_station_string(value: String) -> String:
	match value.strip_edges().to_lower():
		"cook", "加熱":
			return "cook"
		"boil", "煮込み", "boiled":
			return "boil"
		"mix", "混ぜる":
			return "mix"
		"bake", "焼成":
			return "bake"
		"drink", "飲み物":
			return "drink"
		"ferment", "発酵":
			return "ferment"
		_:
			return "any"


func _station_string_from_flags(flags: int) -> String:
	if (flags & CookingRecipe.StationType.MIX) != 0:
		return "mix"
	if (flags & CookingRecipe.StationType.COOK) != 0:
		return "cook"
	if (flags & CookingRecipe.StationType.BOIL) != 0:
		return "boil"
	if (flags & CookingRecipe.StationType.BAKE) != 0:
		return "bake"
	if (flags & CookingRecipe.StationType.DRINK) != 0:
		return "drink"
	if (flags & CookingRecipe.StationType.FERMENT) != 0:
		return "ferment"
	return "any"


func _normalize_string_array(source: Variant) -> Array:
	var result: Array = []
	if typeof(source) == TYPE_STRING:
		var single: String = str(source).strip_edges()
		if not single.is_empty():
			result.append(single)
	elif typeof(source) == TYPE_ARRAY:
		for entry in source:
			var text: String = str(entry).strip_edges()
			if not text.is_empty():
				result.append(text)
	return result


func _dedupe_string_array(source: Array) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for entry in source:
		var text: String = str(entry).strip_edges()
		if text.is_empty() or seen.has(text):
			continue
		seen[text] = true
		result.append(text)
	return result


func _validate_current_text() -> void:
	preview_recipes = recipe_database.load_recipes_from_json_text(text_edit.text, registry, json_path_edit.text.strip_edges())
	preview_errors = PackedStringArray()
	for registry_error in registry.errors:
		preview_errors.append(registry_error)
	for recipe_error in recipe_database.errors:
		preview_errors.append(recipe_error)


func _on_recipe_search_changed(_new_text: String) -> void:
	_refresh_recipe_list()


func _on_recipe_list_selected(list_index: int) -> void:
	_select_recipe_list_index(list_index)


func _on_recipe_list_clicked(list_index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	_select_recipe_list_index(list_index)


func _select_recipe_list_index(list_index: int) -> void:
	if list_index < 0 or list_index >= recipe_list.item_count:
		selected_recipe_model_index = -1
		_update_detail_panel()
		return

	selected_recipe_model_index = int(recipe_list.get_item_metadata(list_index))

	if selected_recipe_model_index >= 0 and selected_recipe_model_index < recipe_rows.size():
		_load_form_from_recipe_row(recipe_rows[selected_recipe_model_index])

	_update_detail_panel()


func _refresh_recipe_list() -> void:
	recipe_list.clear()
	var search_text: String = recipe_search_edit.text.strip_edges().to_lower()
	var selected_list_index: int = -1

	for i in range(recipe_rows.size()):
		var row: Dictionary = recipe_rows[i]
		var line: String = "%s [%s]" % [_get_recipe_row_display_name(row), ", ".join(row.get("station_flags", []))]
		var haystack: String = (line + " " + str(row.get("description", ""))).to_lower()
		if not search_text.is_empty() and haystack.find(search_text) == -1:
			continue
		var idx: int = recipe_list.item_count
		recipe_list.add_item(line)
		recipe_list.set_item_metadata(idx, i)
		if i == selected_recipe_model_index:
			selected_list_index = idx

	if selected_list_index >= 0:
		recipe_list.select(selected_list_index)
		selected_recipe_model_index = int(recipe_list.get_item_metadata(selected_list_index))
	elif recipe_list.item_count > 0:
		recipe_list.select(0)
		selected_recipe_model_index = int(recipe_list.get_item_metadata(0))
	else:
		selected_recipe_model_index = -1


func _get_recipe_row_display_name(row: Dictionary) -> String:
	var recipe_name: String = str(row.get("recipe_name", "")).strip_edges()
	if not recipe_name.is_empty():
		return recipe_name
	var id_text: String = str(row.get("id", "")).strip_edges()
	if not id_text.is_empty():
		return id_text
	return "新規レシピ"


func _on_new_recipe_pressed() -> void:
	selected_recipe_model_index = -1
	_clear_form()
	_update_detail_panel()
	_update_status("新規レシピ入力モード")


func _on_add_recipe_pressed() -> void:
	var row: Dictionary = _build_recipe_row_from_form()
	if row.is_empty():
		return
	recipe_rows.append(row)
	selected_recipe_model_index = recipe_rows.size() - 1
	_commit_rows_to_text_and_refresh(true)
	_update_status("新規レシピを追加した")


func _on_update_recipe_pressed() -> void:
	_sync_selected_recipe_index_from_ui()
	if selected_recipe_model_index < 0 or selected_recipe_model_index >= recipe_rows.size():
		_update_status("上書き対象のレシピを選んでくれ")
		return

	var keep_ingredient_index: int = selected_ingredient_index

	var row: Dictionary = _build_recipe_row_from_form()
	if row.is_empty():
		return

	recipe_rows[selected_recipe_model_index] = row
	_commit_rows_to_text_and_refresh(false)

	if selected_recipe_model_index >= 0 and selected_recipe_model_index < recipe_rows.size():
		_load_form_from_recipe_row(recipe_rows[selected_recipe_model_index])
		if current_ingredient_rows.is_empty():
			_select_ingredient_index(-1)
		else:
			_select_ingredient_index(clamp(keep_ingredient_index, 0, current_ingredient_rows.size() - 1))

	_update_status("選択中レシピを上書きした")


func _on_delete_recipe_pressed() -> void:
	_sync_selected_recipe_index_from_ui()
	if selected_recipe_model_index < 0 or selected_recipe_model_index >= recipe_rows.size():
		_update_status("削除するレシピを選んでくれ")
		return
	recipe_rows.remove_at(selected_recipe_model_index)
	if recipe_rows.is_empty():
		selected_recipe_model_index = -1
		_clear_form()
	else:
		selected_recipe_model_index = clamp(selected_recipe_model_index, 0, recipe_rows.size() - 1)
		_load_form_from_recipe_row(recipe_rows[selected_recipe_model_index])
	_commit_rows_to_text_and_refresh(true)
	_update_status("レシピを削除した")


func _build_recipe_row_from_form() -> Dictionary:
	var recipe_id: String = recipe_id_edit.text.strip_edges()
	var recipe_name: String = recipe_name_edit.text.strip_edges()
	var result_item_id: String = _get_selected_result_item_id()
	if recipe_id.is_empty():
		_update_status("レシピIDを入れてくれ")
		return {}
	if recipe_name.is_empty():
		_update_status("レシピ名を入れてくれ")
		return {}
	if result_item_id.is_empty():
		_update_status("完成品を選んでくれ")
		return {}
	if current_ingredient_rows.is_empty():
		_update_status("材料が1個もない")
		return {}

	var row: Dictionary = {
		"id": recipe_id,
		"recipe_name": recipe_name,
		"description": description_edit.text,
		"result_item_id": result_item_id,
		"result_count": int(result_count_spin.value),
		"cook_minutes": int(cook_minutes_spin.value),
		"station_flags": [_get_selected_station_key()],
		"required_upgrade_level": int(upgrade_level_spin.value),
		"base_quality_multiplier": float(quality_multiplier_spin.value),
		"cooking_exp": int(cooking_exp_spin.value),
		"ingredients": current_ingredient_rows.duplicate(true)
	}
	return _normalize_recipe_row(row)


var current_ingredient_rows: Array = []


func _clear_form() -> void:
	recipe_id_edit.text = ""
	recipe_name_edit.text = ""
	description_edit.text = ""
	if result_item_option.item_count > 0:
		result_item_option.select(0)
	result_count_spin.value = 1
	cook_minutes_spin.value = 10
	station_option.select(0)
	upgrade_level_spin.value = 1
	quality_multiplier_spin.value = 1.0
	cooking_exp_spin.value = 1
	current_ingredient_rows.clear()
	selected_ingredient_index = -1
	ingredient_slot_name_edit.text = ""
	ingredient_count_spin.value = 1
	_refresh_current_ingredient_list()


func _load_form_from_recipe_row(row: Dictionary) -> void:
	var keep_ingredient_index: int = selected_ingredient_index
	recipe_id_edit.text = str(row.get("id", ""))
	recipe_name_edit.text = str(row.get("recipe_name", ""))
	description_edit.text = str(row.get("description", ""))
	_select_result_item_id(str(row.get("result_item_id", "")))
	result_count_spin.value = max(int(row.get("result_count", 1)), 1)
	cook_minutes_spin.value = max(int(row.get("cook_minutes", 1)), 1)
	_select_station_key(_get_station_key_from_row(row))
	upgrade_level_spin.value = max(int(row.get("required_upgrade_level", 1)), 1)
	quality_multiplier_spin.value = max(float(row.get("base_quality_multiplier", 1.0)), 0.1)
	cooking_exp_spin.value = max(int(row.get("cooking_exp", 1)), 0)
	current_ingredient_rows = (row.get("ingredients", []) as Array).duplicate(true)

	ingredient_slot_name_edit.text = ""
	ingredient_count_spin.value = 1
	_refresh_current_ingredient_list()

	if current_ingredient_rows.is_empty():
		selected_ingredient_index = -1
		if ingredient_list != null:
			ingredient_list.deselect_all()
	else:
		if keep_ingredient_index < 0:
			keep_ingredient_index = 0
		_select_ingredient_index(clamp(keep_ingredient_index, 0, current_ingredient_rows.size() - 1))


func _get_station_key_from_row(row: Dictionary) -> String:
	var flags: Array = row.get("station_flags", []) as Array
	if flags.size() > 0:
		return str(flags[0])
	return "mix"


func _get_selected_station_key() -> String:
	if station_option.selected < 0:
		return "mix"
	return str(station_option.get_item_metadata(station_option.selected))


func _select_station_key(station_key: String) -> void:
	for i in range(station_option.item_count):
		if str(station_option.get_item_metadata(i)) == station_key:
			station_option.select(i)
			return
	if station_option.item_count > 0:
		station_option.select(0)


func _select_result_item_id(item_id: String) -> void:
	for i in range(result_item_option.item_count):
		if str(result_item_option.get_item_metadata(i)) == item_id:
			result_item_option.select(i)
			return
	if result_item_option.item_count > 0:
		result_item_option.select(0)


func _get_selected_result_item_id() -> String:
	if result_item_option.item_count <= 0 or result_item_option.selected < 0:
		return ""
	return str(result_item_option.get_item_metadata(result_item_option.selected))


func _on_food_search_changed(_new_text: String) -> void:
	_refresh_food_item_list()


func _on_food_item_selected(_index: int) -> void:
	pass


func _on_label_search_changed(_new_text: String) -> void:
	_refresh_label_list()


func _on_label_selected(_index: int) -> void:
	pass


func _on_set_result_pressed() -> void:
	var item_data: ItemData = _get_selected_food_item()
	if item_data == null:
		_update_status("食材候補を選んでくれ")
		return
	_select_result_item_id(String(item_data.id))
	if recipe_name_edit.text.strip_edges().is_empty():
		recipe_name_edit.text = _get_item_display_name(item_data)
	if recipe_id_edit.text.strip_edges().is_empty():
		recipe_id_edit.text = "%s_recipe" % String(item_data.id)
	_update_status("完成品を %s に設定した" % _get_item_display_name(item_data))


func _get_selected_food_item() -> ItemData:
	var selected_items: PackedInt32Array = food_item_list.get_selected_items()
	if selected_items.size() <= 0:
		return null
	var idx: int = selected_items[0]
	var item_id: String = str(food_item_list.get_item_metadata(idx))
	return registry.resolve_item(StringName(item_id), "")


func _get_selected_label() -> ItemTag:
	var selected_items: PackedInt32Array = label_list.get_selected_items()
	if selected_items.size() <= 0:
		return null
	var idx: int = selected_items[0]
	var label_id: String = str(label_list.get_item_metadata(idx))
	return registry.resolve_label(StringName(label_id))


func _on_add_item_ingredient_pressed() -> void:
	var item_data: ItemData = _get_selected_food_item()
	if item_data == null:
		_update_status("食材候補を選んでくれ")
		return

	var row: Dictionary = {
		"slot_name": _get_item_display_name(item_data),
		"item_id": String(item_data.id),
		"count": max(int(ingredient_count_spin.value), 1),
		"consume_on_cook": true
	}
	current_ingredient_rows.append(_normalize_ingredient_row(row))
	_select_ingredient_index(current_ingredient_rows.size() - 1)
	_sync_selected_recipe_ingredients_to_model(false)
	_update_status("材料に %s を追加した" % _get_item_display_name(item_data))


func _on_add_label_ingredient_pressed() -> void:
	var label: ItemTag = _get_selected_label()
	if label == null:
		_update_status("ラベル候補を選んでくれ")
		return

	var condition_dict: Dictionary = {
		"condition_name": label.get_display_name(),
		"require_all_label_ids": [_get_food_label_id()],
		"require_any_label_ids": [String(label.id)]
	}
	if _is_food_label(label):
		condition_dict["require_any_label_ids"] = []
		condition_dict["require_all_label_ids"] = [String(label.id)]

	var row: Dictionary = {
		"slot_name": label.get_display_name(),
		"count": max(int(ingredient_count_spin.value), 1),
		"consume_on_cook": true,
		"condition": condition_dict
	}
	current_ingredient_rows.append(_normalize_ingredient_row(row))
	_select_ingredient_index(current_ingredient_rows.size() - 1)
	_sync_selected_recipe_ingredients_to_model(false)
	_update_status("ラベル材料に %s を追加した" % label.get_display_name())


func _build_ingredient_line(row: Dictionary) -> String:
	var base_name: String = _get_ingredient_row_display_name(row)
	return "%s x%d" % [base_name, max(int(row.get("count", 1)), 1)]


func _get_ingredient_row_display_name(row: Dictionary) -> String:
	var slot_name: String = str(row.get("slot_name", "")).strip_edges()
	if not slot_name.is_empty():
		return slot_name

	var item_id: String = str(row.get("item_id", "")).strip_edges()
	if not item_id.is_empty():
		var item_data: ItemData = registry.resolve_item(StringName(item_id), "")
		if item_data != null:
			return _get_item_display_name(item_data)
		return item_id

	var condition_variant: Variant = row.get("condition", null)
	if typeof(condition_variant) == TYPE_DICTIONARY:
		return _condition_summary_from_dict(condition_variant)

	var condition_id: String = str(row.get("condition_id", "")).strip_edges()
	if not condition_id.is_empty():
		return condition_id

	return "材料"


func _condition_summary_from_dict(condition_dict: Dictionary) -> String:
	var name_text: String = str(condition_dict.get("condition_name", "")).strip_edges()
	if not name_text.is_empty():
		return name_text

	var all_ids: Array = condition_dict.get("require_all_label_ids", []) as Array
	var any_ids: Array = condition_dict.get("require_any_label_ids", []) as Array
	var parts: PackedStringArray = PackedStringArray()
	if all_ids.size() > 0:
		parts.append("全部:%s" % ",".join(_label_id_array_to_names(all_ids)))
	if any_ids.size() > 0:
		parts.append("どれか:%s" % ",".join(_label_id_array_to_names(any_ids)))
	if parts.is_empty():
		return "条件材料"
	return " / ".join(parts)


func _label_id_array_to_names(label_ids: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for label_id_variant in label_ids:
		var label_id: String = str(label_id_variant)
		var label: ItemTag = registry.resolve_label(StringName(label_id))
		if label != null:
			result.append(label.get_display_name())
		else:
			result.append(label_id)
	return result


func _apply_selected_ingredient_to_form() -> void:
	if selected_ingredient_index < 0 or selected_ingredient_index >= current_ingredient_rows.size():
		ingredient_slot_name_edit.text = ""
		ingredient_count_spin.value = 1
		return

	var row: Dictionary = current_ingredient_rows[selected_ingredient_index]
	var slot_name: String = str(row.get("slot_name", "")).strip_edges()

	if slot_name.is_empty():
		slot_name = _get_ingredient_row_display_name(row)

	ingredient_slot_name_edit.text = slot_name
	ingredient_count_spin.value = max(int(row.get("count", 1)), 1)


func _on_ingredient_list_selected(list_index: int) -> void:
	_select_ingredient_list_index(list_index)


func _on_ingredient_list_clicked(list_index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	_select_ingredient_list_index(list_index)


func _select_ingredient_list_index(list_index: int) -> void:
	if list_index < 0 or list_index >= ingredient_list.item_count:
		selected_ingredient_index = -1
		_apply_selected_ingredient_to_form()
		return

	selected_ingredient_index = int(ingredient_list.get_item_metadata(list_index))
	_apply_selected_ingredient_to_form()


func _on_apply_ingredient_pressed() -> void:
	_sync_selected_ingredient_index_from_ui()
	if selected_ingredient_index < 0 or selected_ingredient_index >= current_ingredient_rows.size():
		_update_status("編集する材料を選んでくれ")
		return
	var row: Dictionary = current_ingredient_rows[selected_ingredient_index]
	row["slot_name"] = ingredient_slot_name_edit.text.strip_edges()
	row["count"] = max(int(ingredient_count_spin.value), 1)
	current_ingredient_rows[selected_ingredient_index] = _normalize_ingredient_row(row)
	_select_ingredient_index(selected_ingredient_index)
	_sync_selected_recipe_ingredients_to_model(false)
	_update_status("材料表示名と個数を更新した")


func _on_remove_ingredient_pressed() -> void:
	_sync_selected_ingredient_index_from_ui()
	if selected_ingredient_index < 0 or selected_ingredient_index >= current_ingredient_rows.size():
		_update_status("削除する材料を選んでくれ")
		return

	current_ingredient_rows.remove_at(selected_ingredient_index)

	if current_ingredient_rows.is_empty():
		_select_ingredient_index(-1)
	else:
		var next_index: int = min(selected_ingredient_index, current_ingredient_rows.size() - 1)
		_select_ingredient_index(next_index)

	_sync_selected_recipe_ingredients_to_model(false)
	_update_status("材料を削除した")


func _on_move_up_ingredient_pressed() -> void:
	_sync_selected_ingredient_index_from_ui()
	if selected_ingredient_index <= 0 or selected_ingredient_index >= current_ingredient_rows.size():
		return
	var temp: Dictionary = current_ingredient_rows[selected_ingredient_index - 1]
	current_ingredient_rows[selected_ingredient_index - 1] = current_ingredient_rows[selected_ingredient_index]
	current_ingredient_rows[selected_ingredient_index] = temp
	selected_ingredient_index -= 1
	_select_ingredient_index(selected_ingredient_index)
	_sync_selected_recipe_ingredients_to_model(false)


func _on_move_down_ingredient_pressed() -> void:
	_sync_selected_ingredient_index_from_ui()
	if selected_ingredient_index < 0 or selected_ingredient_index >= current_ingredient_rows.size() - 1:
		return
	var temp: Dictionary = current_ingredient_rows[selected_ingredient_index + 1]
	current_ingredient_rows[selected_ingredient_index + 1] = current_ingredient_rows[selected_ingredient_index]
	current_ingredient_rows[selected_ingredient_index] = temp
	selected_ingredient_index += 1
	_select_ingredient_index(selected_ingredient_index)
	_sync_selected_recipe_ingredients_to_model(false)


func _commit_rows_to_text_and_refresh(load_form: bool) -> void:
	var keep_recipe_index: int = selected_recipe_model_index
	_set_text_edit_text(JSON.stringify(recipe_rows, "\t", true))
	_validate_current_text()
	_refresh_recipe_list()
	selected_recipe_model_index = keep_recipe_index
	if selected_recipe_model_index >= 0:
		for i in range(recipe_list.item_count):
			if int(recipe_list.get_item_metadata(i)) == selected_recipe_model_index:
				recipe_list.select(i)
				break
	if load_form and selected_recipe_model_index >= 0 and selected_recipe_model_index < recipe_rows.size():
		_load_form_from_recipe_row(recipe_rows[selected_recipe_model_index])
	_update_detail_panel()


func _sync_selected_recipe_ingredients_to_model(load_form: bool) -> void:
	_sync_selected_recipe_index_from_ui()
	if selected_recipe_model_index < 0 or selected_recipe_model_index >= recipe_rows.size():
		_refresh_current_ingredient_list()
		_update_detail_panel()
		return

	var row: Dictionary = recipe_rows[selected_recipe_model_index].duplicate(true)
	row["ingredients"] = current_ingredient_rows.duplicate(true)
	recipe_rows[selected_recipe_model_index] = _normalize_recipe_row(row)
	_commit_rows_to_text_and_refresh(load_form)
	is_dirty = true


func _update_detail_panel() -> void:
	var lines: PackedStringArray = PackedStringArray()
	if selected_recipe_model_index >= 0 and selected_recipe_model_index < recipe_rows.size():
		var row: Dictionary = recipe_rows[selected_recipe_model_index]
		lines.append("[b]%s[/b]" % _get_recipe_row_display_name(row))
		lines.append("ID: %s" % str(row.get("id", "")))
		lines.append("完成品ID: %s x%d" % [str(row.get("result_item_id", "")), int(row.get("result_count", 1))])
		lines.append("時間: %d分 / 方式: %s / 必要Lv: %d / EXP: %d" % [int(row.get("cook_minutes", 1)), ", ".join(row.get("station_flags", [])), int(row.get("required_upgrade_level", 1)), int(row.get("cooking_exp", 0))])
		lines.append("品質倍率: %.2f" % float(row.get("base_quality_multiplier", 1.0)))
		if not str(row.get("description", "")).is_empty():
			lines.append("説明: %s" % str(row.get("description", "")))
		lines.append("")
		lines.append("[b]材料[/b]")
		for ingredient_row_variant in row.get("ingredients", []):
			if typeof(ingredient_row_variant) != TYPE_DICTIONARY:
				continue
			lines.append("- %s" % _build_ingredient_line(ingredient_row_variant))
	else:
		lines.append("[b]レシピ未選択[/b]")
		lines.append("左でレシピを選ぶか、新規作成してくれ。")

	if not preview_errors.is_empty():
		lines.append("")
		lines.append("[b]検証結果[/b]")
		for err_text in preview_errors:
			lines.append("- %s" % err_text)
	else:
		lines.append("")
		lines.append("[b]検証結果[/b]")
		lines.append("- OK")

	detail_label.text = "\n".join(lines)


func _set_text_edit_text(new_text: String) -> void:
	_suppress_text_changed = true
	text_edit.text = new_text
	_suppress_text_changed = false


func _on_text_changed() -> void:
	if _suppress_text_changed:
		return
	is_dirty = true
	_update_status("JSON編集中（未保存）")


func _get_item_key(item_data: ItemData) -> String:
	if item_data == null:
		return ""
	if not String(item_data.id).is_empty():
		return String(item_data.id)
	return item_data.resource_path


func _get_item_display_name(item_data: ItemData) -> String:
	if item_data == null:
		return "?"
	if not item_data.item_name.is_empty():
		return item_data.item_name
	if not String(item_data.id).is_empty():
		return String(item_data.id)
	return item_data.resource_path.get_file().get_basename()


func _update_status(text: String) -> void:
	var dirty_suffix: String = " [未保存]" if is_dirty else ""
	status_label.text = text + dirty_suffix

func _select_ingredient_index(index: int) -> void:
	if index < 0 or index >= current_ingredient_rows.size():
		selected_ingredient_index = -1
		if ingredient_list != null:
			ingredient_list.deselect_all()
		_apply_selected_ingredient_to_form()
		return

	selected_ingredient_index = index
	_refresh_current_ingredient_list()
	if ingredient_list != null and selected_ingredient_index < ingredient_list.item_count:
		ingredient_list.select(selected_ingredient_index)
	_apply_selected_ingredient_to_form()

func _sync_selected_recipe_index_from_ui() -> void:
	var selected_items: PackedInt32Array = recipe_list.get_selected_items()
	if selected_items.is_empty():
		selected_recipe_model_index = -1
		return

	var list_index: int = selected_items[0]
	if list_index < 0 or list_index >= recipe_list.item_count:
		selected_recipe_model_index = -1
		return

	selected_recipe_model_index = int(recipe_list.get_item_metadata(list_index))


func _sync_selected_ingredient_index_from_ui() -> void:
	var selected_items: PackedInt32Array = ingredient_list.get_selected_items()
	if selected_items.is_empty():
		selected_ingredient_index = -1
		return

	var list_index: int = selected_items[0]
	if list_index < 0 or list_index >= ingredient_list.item_count:
		selected_ingredient_index = -1
		return

	selected_ingredient_index = int(ingredient_list.get_item_metadata(list_index))

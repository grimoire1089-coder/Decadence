extends RefCounted
class_name RecipeDatabase

var errors: PackedStringArray = PackedStringArray()


func clear_errors() -> void:
	errors = PackedStringArray()


func load_recipes_from_json_files(json_paths: Array[String], registry: ItemRegistry) -> Array:
	clear_errors()
	var recipes: Array = []
	for json_path in json_paths:
		if json_path.is_empty():
			continue
		for recipe in _load_single_file(json_path, registry):
			recipes.append(recipe)
	return recipes


func load_recipes_from_json_text(json_text: String, registry: ItemRegistry, source_name: String = "<json_text>") -> Array:
	clear_errors()
	return _load_rows_from_text(json_text, registry, source_name)


func _load_single_file(json_path: String, registry: ItemRegistry) -> Array:
	if not FileAccess.file_exists(json_path):
		errors.append("JSONレシピが見つからない: %s" % json_path)
		return []

	var file: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		errors.append("JSONレシピを開けない: %s" % json_path)
		return []

	return _load_rows_from_text(file.get_as_text(), registry, json_path)


func _load_rows_from_text(json_text: String, registry: ItemRegistry, source_name: String) -> Array:
	var results: Array = []
	var json: JSON = JSON.new()
	var err: int = json.parse(json_text)
	if err != OK:
		errors.append("JSON parse失敗: %s line=%d msg=%s" % [source_name, json.get_error_line(), json.get_error_message()])
		return results

	var data: Variant = json.data
	var rows: Array = []
	if typeof(data) == TYPE_ARRAY:
		rows = data
	elif typeof(data) == TYPE_DICTIONARY:
		var dict: Dictionary = data
		var recipe_rows: Variant = dict.get("recipes", [])
		if typeof(recipe_rows) == TYPE_ARRAY:
			rows = recipe_rows
	else:
		errors.append("JSONのトップレベルが配列か recipes 辞書ではない: %s" % source_name)
		return results

	for i in range(rows.size()):
		var row: Variant = rows[i]
		if typeof(row) != TYPE_DICTIONARY:
			errors.append("レシピ行が辞書ではない: %s index=%d" % [source_name, i])
			continue
		var recipe: CookingRecipe = _build_recipe_from_dict(row, registry, source_name, i)
		if recipe != null and recipe.is_valid_recipe():
			results.append(recipe)

	return results


func _build_recipe_from_dict(source: Dictionary, registry: ItemRegistry, json_path: String, index_in_file: int) -> CookingRecipe:
	var recipe: CookingRecipe = CookingRecipe.new()
	recipe.id = StringName(str(source.get("id", "")))
	recipe.recipe_name = str(source.get("recipe_name", source.get("name", "")))
	recipe.description = str(source.get("description", ""))
	recipe.result_count = max(int(source.get("result_count", 1)), 1)
	recipe.cook_minutes = max(int(source.get("cook_minutes", 1)), 1)
	recipe.station_flags = _parse_station_flags(source.get("station_flags", source.get("station", [])))
	recipe.required_upgrade_level = max(int(source.get("required_upgrade_level", 1)), 1)
	recipe.base_quality_multiplier = max(float(source.get("base_quality_multiplier", 1.0)), 0.1)
	recipe.cooking_exp = max(int(source.get("cooking_exp", 1)), 0)

	var result_item: ItemData = registry.resolve_item(
		StringName(str(source.get("result_item_id", source.get("result_id", "")))),
		str(source.get("result_item_path", ""))
	)
	if result_item == null:
		errors.append("完成品アイテムを解決できない: %s index=%d" % [json_path, index_in_file])
		return null
	recipe.result_item = result_item

	var ingredients_variant: Variant = source.get("ingredients", [])
	if typeof(ingredients_variant) != TYPE_ARRAY:
		errors.append("ingredients が配列ではない: %s index=%d" % [json_path, index_in_file])
		return null

	var ingredients_rows: Array = ingredients_variant
	for ingredient_index in range(ingredients_rows.size()):
		var ingredient_row: Variant = ingredients_rows[ingredient_index]
		if typeof(ingredient_row) != TYPE_DICTIONARY:
			errors.append("ingredient が辞書ではない: %s recipe=%s ingredient=%d" % [json_path, recipe.get_display_name(), ingredient_index])
			continue
		var ingredient: RecipeIngredient = _build_ingredient_from_dict(ingredient_row, registry, recipe.get_display_name(), ingredient_index)
		if ingredient == null:
			continue
		recipe.ingredients.append(ingredient)
		recipe.ingredient_counts.append(max(int((ingredient_row as Dictionary).get("count", 1)), 1))

	recipe.normalize_ingredient_counts()
	if not recipe.is_valid_recipe():
		errors.append("無効なレシピをスキップ: %s" % recipe.get_display_name())
		return null

	return recipe


func _build_ingredient_from_dict(source: Dictionary, registry: ItemRegistry, recipe_name: String, ingredient_index: int) -> RecipeIngredient:
	var ingredient: RecipeIngredient = RecipeIngredient.new()
	ingredient.slot_name = str(source.get("slot_name", source.get("name", "")))
	ingredient.consume_on_cook = bool(source.get("consume_on_cook", true))

	var item_id: StringName = StringName(str(source.get("item_id", "")))
	var item_path: String = str(source.get("item_path", ""))
	var condition_id: StringName = StringName(str(source.get("condition_id", "")))
	var condition_path: String = str(source.get("condition_path", ""))
	var condition_variant: Variant = source.get("condition", null)

	if not String(item_id).is_empty() or not item_path.is_empty():
		ingredient.specific_item = registry.resolve_item(item_id, item_path)
		if ingredient.specific_item == null:
			errors.append("材料アイテムを解決できない: recipe=%s ingredient=%d" % [recipe_name, ingredient_index])
			return null
	elif typeof(condition_variant) == TYPE_DICTIONARY or _has_inline_condition_keys(source):
		ingredient.item_condition = _build_inline_condition(source if _has_inline_condition_keys(source) else condition_variant, registry, recipe_name, ingredient_index)
		if ingredient.item_condition == null:
			return null
	elif not String(condition_id).is_empty() or not condition_path.is_empty():
		ingredient.item_condition = registry.resolve_condition(condition_id, condition_path)
		if ingredient.item_condition == null:
			errors.append("材料条件を解決できない: recipe=%s ingredient=%d" % [recipe_name, ingredient_index])
			return null
	else:
		errors.append("材料に item_id/item_path/condition/condition_id/condition_path のどれもない: recipe=%s ingredient=%d" % [recipe_name, ingredient_index])
		return null

	return ingredient


func _has_inline_condition_keys(source: Dictionary) -> bool:
	return source.has("require_all_label_ids") or source.has("require_any_label_ids") or source.has("forbid_label_ids") or source.has("label_id") or source.has("label_ids")


func _build_inline_condition(source: Dictionary, registry: ItemRegistry, recipe_name: String, ingredient_index: int) -> ItemCondition:
	var condition: ItemCondition = ItemCondition.new()
	condition.condition_name = str(source.get("condition_name", source.get("name", "")))

	var all_ids: Array = _collect_label_id_array(source, "require_all_label_ids")
	var any_ids: Array = _collect_label_id_array(source, "require_any_label_ids")
	var forbid_ids: Array = _collect_label_id_array(source, "forbid_label_ids")

	if source.has("label_id"):
		var single_label_id: String = str(source.get("label_id", "")).strip_edges()
		if not single_label_id.is_empty():
			any_ids.append(single_label_id)

	if source.has("label_ids"):
		for extra_id in _collect_label_id_array(source, "label_ids"):
			any_ids.append(extra_id)

	condition.require_all_labels = _resolve_labels(all_ids, registry, recipe_name, ingredient_index, "require_all_label_ids")
	condition.require_any_labels = _resolve_labels(any_ids, registry, recipe_name, ingredient_index, "require_any_label_ids")
	condition.forbid_labels = _resolve_labels(forbid_ids, registry, recipe_name, ingredient_index, "forbid_label_ids")

	if condition.require_all_labels.is_empty() and condition.require_any_labels.is_empty() and condition.forbid_labels.is_empty():
		errors.append("インライン条件に有効なラベルがない: recipe=%s ingredient=%d" % [recipe_name, ingredient_index])
		return null

	return condition


func _collect_label_id_array(source: Dictionary, key: String) -> Array:
	var result: Array = []
	if not source.has(key):
		return result

	var value: Variant = source.get(key)
	if typeof(value) == TYPE_STRING:
		var text_value: String = str(value).strip_edges()
		if not text_value.is_empty():
			result.append(text_value)
	elif typeof(value) == TYPE_ARRAY:
		for entry in value:
			var text_entry: String = str(entry).strip_edges()
			if not text_entry.is_empty():
				result.append(text_entry)

	return result


func _resolve_labels(label_ids: Array, registry: ItemRegistry, recipe_name: String, ingredient_index: int, field_name: String) -> Array:
	var result: Array = []
	var seen: Dictionary = {}

	for label_id_variant in label_ids:
		var label_id_text: String = str(label_id_variant).strip_edges()
		if label_id_text.is_empty():
			continue
		if seen.has(label_id_text):
			continue

		var label: ItemTag = registry.resolve_label(StringName(label_id_text))
		if label == null:
			errors.append("ラベルを解決できない: recipe=%s ingredient=%d field=%s label=%s" % [recipe_name, ingredient_index, field_name, label_id_text])
			continue

		seen[label_id_text] = true
		result.append(label)

	return result


func _parse_station_flags(source: Variant) -> int:
	if typeof(source) == TYPE_INT:
		return int(source)

	var flags: int = 0
	if typeof(source) == TYPE_STRING:
		flags |= _station_flag_from_string(str(source))
	elif typeof(source) == TYPE_ARRAY:
		for value in source:
			flags |= _station_flag_from_string(str(value))

	if flags == 0:
		flags = CookingRecipe.StationType.ANY
	return flags


func _station_flag_from_string(value: String) -> int:
	match value.strip_edges().to_lower():
		"cook", "加熱":
			return CookingRecipe.StationType.COOK
		"boil", "煮込み", "boiled":
			return CookingRecipe.StationType.BOIL
		"mix", "混ぜる":
			return CookingRecipe.StationType.MIX
		"bake", "焼成":
			return CookingRecipe.StationType.BAKE
		"drink", "飲み物":
			return CookingRecipe.StationType.DRINK
		"ferment", "発酵":
			return CookingRecipe.StationType.FERMENT
		"any", "":
			return CookingRecipe.StationType.ANY
		_:
			return 0

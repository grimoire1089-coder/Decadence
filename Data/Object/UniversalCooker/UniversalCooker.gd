extends StaticBody2D
class_name UniversalCooker

const SAVE_PATH_PREFIX: String = "user://universal_cooker_"

@export var machine_name: String = "万能調理器"
@export_range(1, 99) var cooker_level: int = 1
@export_range(1, 99) var slot_count: int = 2
@export_range(0.1, 99.0, 0.1) var speed_multiplier: float = 1.0
@export_range(0.0, 100.0, 0.1) var quality_bonus: float = 0.0
@export_flags(
	"加熱:1",
	"煮込み:2",
	"混ぜる:4",
	"焼成:8",
	"飲み物:16",
	"発酵:32"
) var station_flags: int = 63
@export var available_recipes: Array[CookingRecipe] = []
@export_dir var recipe_folder_path: String = "res://Data/Cooking_Recipe"
@export var include_subfolders: bool = false
@export var use_json_recipes: bool = true
@export_file("*.json") var recipe_json_path: String = "res://Data/Cooking_Recipe/recipes.json"
@export var recipe_json_paths: Array[String] = []
@export_dir var item_data_folder_path: String = "res://Data/Items"
@export_dir var condition_folder_path: String = "res://Data/Cooking_Condition"
@export var registry_include_subfolders: bool = true

var slots: Array[Dictionary] = []
var _last_total_minutes: int = -1
var _base_available_recipes: Array[CookingRecipe] = []
var _base_available_recipes_cached: bool = false

@onready var interact_area: Area2D = get_node_or_null("InteractArea") as Area2D


func _ready() -> void:
	_init_slots()
	_cache_base_available_recipes()
	_reload_available_recipes()
	load_data()
	_connect_interact_area()
	_connect_time_manager()
	_sync_last_total_minutes()


func _exit_tree() -> void:
	_disconnect_time_manager()


func _init_slots() -> void:
	slots.clear()
	for _i in range(slot_count):
		slots.append(_make_empty_slot())


func _make_empty_slot() -> Dictionary:
	return {
		"recipe_key": "",
		"display_name": "",
		"result_item_path": "",
		"result_count": 0,
		"total_minutes": 0,
		"remaining_minutes": 0,
		"queued_count": 0,
		"ready_count": 0,
		"output_quality": 0,
		"output_rank": 0,
		"cooking_exp_per_cycle": 0
	}


func _cache_base_available_recipes() -> void:
	if _base_available_recipes_cached:
		return

	_base_available_recipes_cached = true
	_base_available_recipes.clear()

	for recipe in available_recipes:
		if recipe != null:
			_base_available_recipes.append(recipe)


func _reload_available_recipes() -> void:
	var merged: Array[CookingRecipe] = []
	var seen: Dictionary = {}
	var base_count: int = 0
	var folder_count: int = 0
	var json_count: int = 0

	for recipe in _base_available_recipes:
		if _append_unique_recipe(merged, seen, recipe):
			base_count += 1

	var folder_recipes: Array[CookingRecipe] = _load_recipes_from_folder(recipe_folder_path, include_subfolders)
	for recipe in folder_recipes:
		if _append_unique_recipe(merged, seen, recipe):
			folder_count += 1

	var json_recipes: Array[CookingRecipe] = _load_recipes_from_json()
	for recipe in json_recipes:
		if _append_unique_recipe(merged, seen, recipe):
			json_count += 1

	available_recipes = merged
	_log_debug("万能調理器レシピ再読込: 手動%d / フォルダ%d / JSON%d / 合計%d" % [base_count, folder_count, json_count, available_recipes.size()])


func _append_unique_recipe(target: Array[CookingRecipe], seen: Dictionary, recipe: CookingRecipe) -> bool:
	if recipe == null:
		return false
	if not recipe.is_valid_recipe():
		return false

	var key: String = _get_recipe_unique_key(recipe)
	if key.is_empty():
		return false
	if seen.has(key):
		return false

	seen[key] = true
	target.append(recipe)
	return true


func _get_recipe_unique_key(recipe: CookingRecipe) -> String:
	if recipe == null:
		return ""
	if not recipe.resource_path.is_empty():
		return recipe.resource_path
	if not str(recipe.id).is_empty():
		return str(recipe.id)
	return recipe.get_display_name()


func _load_recipes_from_folder(folder_path: String, recursive: bool) -> Array[CookingRecipe]:
	var results: Array[CookingRecipe] = []
	if folder_path.is_empty():
		return results
	if not DirAccess.dir_exists_absolute(folder_path):
		_log_debug("料理レシピフォルダが見つからない: %s" % folder_path)
		return results

	_collect_recipes_in_folder(folder_path, recursive, results)
	return results


func _load_recipes_from_json() -> Array[CookingRecipe]:
	var results: Array[CookingRecipe] = []
	if not use_json_recipes:
		_log_debug("JSONレシピ読み込み: OFF")
		return results

	var effective_json_paths: Array[String] = _get_effective_json_paths()
	if effective_json_paths.is_empty():
		_log_debug("JSONレシピ読み込み: パス未設定")
		return results

	for json_path in effective_json_paths:
		if FileAccess.file_exists(json_path):
			_log_debug("JSONレシピ候補: %s" % json_path)
		else:
			_log_error("JSONレシピが見つからない: %s" % json_path)

	var registry: ItemRegistry = ItemRegistry.new()
	registry.load_items_from_folder(item_data_folder_path, registry_include_subfolders)
	registry.load_conditions_from_folder(condition_folder_path, registry_include_subfolders)

	for registry_error in registry.errors:
		_log_debug(String(registry_error))

	var database: RecipeDatabase = RecipeDatabase.new()
	results = database.load_recipes_from_json_files(effective_json_paths, registry)

	for db_error in database.errors:
		_log_error(String(db_error))

	_log_debug("JSONレシピ読み込み結果: %d件" % results.size())
	return results


func _get_effective_json_paths() -> Array[String]:
	var paths: Array[String] = []
	var seen: Dictionary = {}

	if not recipe_json_path.is_empty() and not seen.has(recipe_json_path):
		seen[recipe_json_path] = true
		paths.append(recipe_json_path)

	for extra_path in recipe_json_paths:
		if extra_path.is_empty():
			continue
		if seen.has(extra_path):
			continue
		seen[extra_path] = true
		paths.append(extra_path)

	return paths


func _collect_recipes_in_folder(folder_path: String, recursive: bool, out_results: Array[CookingRecipe]) -> void:
	var dir: DirAccess = DirAccess.open(folder_path)
	if dir == null:
		_log_error("料理レシピフォルダを開けない: %s" % folder_path)
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
				_collect_recipes_in_folder(full_path, true, out_results)
			continue

		var lower_entry: String = entry.to_lower()
		if not lower_entry.ends_with(".tres") and not lower_entry.ends_with(".res"):
			continue

		var recipe: CookingRecipe = load(full_path) as CookingRecipe
		if recipe == null:
			continue
		if not recipe.is_valid_recipe():
			_log_debug("無効な料理レシピをスキップ: %s" % full_path)
			continue

		out_results.append(recipe)

	dir.list_dir_end()


func _connect_interact_area() -> void:
	if interact_area == null:
		return

	if not interact_area.body_entered.is_connected(_on_body_entered):
		interact_area.body_entered.connect(_on_body_entered)

	if not interact_area.body_exited.is_connected(_on_body_exited):
		interact_area.body_exited.connect(_on_body_exited)


func _connect_time_manager() -> void:
	var time_manager: Node = _get_time_manager()
	if time_manager == null:
		return

	var callable: Callable = Callable(self, "_on_time_changed")
	if time_manager.has_signal("time_changed") and not time_manager.is_connected("time_changed", callable):
		time_manager.connect("time_changed", callable)


func _disconnect_time_manager() -> void:
	var time_manager: Node = _get_time_manager()
	if time_manager == null:
		return

	var callable: Callable = Callable(self, "_on_time_changed")
	if time_manager.has_signal("time_changed") and time_manager.is_connected("time_changed", callable):
		time_manager.disconnect("time_changed", callable)


func _sync_last_total_minutes() -> void:
	var time_manager: Node = _get_time_manager()
	if time_manager == null:
		_last_total_minutes = -1
		return

	var current_day: int = int(time_manager.get("day"))
	var current_hour: int = int(time_manager.get("hour"))
	var current_minute: int = int(time_manager.get("minute"))
	_last_total_minutes = _to_total_minutes(current_day, current_hour, current_minute)


func _to_total_minutes(day: int, hour: int, minute: int) -> int:
	return ((max(day, 1) - 1) * 24 * 60) + (clamp(hour, 0, 23) * 60) + clamp(minute, 0, 59)


func _on_time_changed(day: int, hour: int, minute: int) -> void:
	var new_total: int = _to_total_minutes(day, hour, minute)
	if _last_total_minutes < 0:
		_last_total_minutes = new_total
		return

	var delta_minutes: int = new_total - _last_total_minutes
	_last_total_minutes = new_total
	if delta_minutes <= 0:
		return

	_advance_cooking(delta_minutes)


func _advance_cooking(delta_minutes: int) -> void:
	var changed: bool = false

	for i in range(slots.size()):
		if is_slot_empty(i):
			continue

		var slot_before: Dictionary = slots[i].duplicate(true)
		var slot: Dictionary = slots[i]
		var ready_before: int = max(int(slot.get("ready_count", 0)), 0)
		var delta_left: int = delta_minutes

		while delta_left > 0 and max(int(slot.get("queued_count", 0)), 0) > 0:
			var current_remaining: int = max(int(slot.get("remaining_minutes", 0)), 0)
			if current_remaining <= 0:
				current_remaining = max(int(slot.get("total_minutes", 0)), 1)
				slot["remaining_minutes"] = current_remaining

			if delta_left >= current_remaining:
				delta_left -= current_remaining
				slot["ready_count"] = max(int(slot.get("ready_count", 0)), 0) + 1
				slot["queued_count"] = max(int(slot.get("queued_count", 0)), 0) - 1

				if max(int(slot.get("queued_count", 0)), 0) > 0:
					slot["remaining_minutes"] = max(int(slot.get("total_minutes", 0)), 1)
				else:
					slot["remaining_minutes"] = 0
			else:
				slot["remaining_minutes"] = current_remaining - delta_left
				delta_left = 0

		var ready_after: int = max(int(slot.get("ready_count", 0)), 0)
		if ready_after > ready_before:
			var added_ready: int = ready_after - ready_before
			_log_system("%sのスロット%dで%sが %d 回分 完成待ちになった" % [machine_name, i + 1, get_slot_display_name_from_slot(slot), added_ready])

		if slot != slot_before:
			slots[i] = slot
			changed = true

	if changed:
		save_data()
		_refresh_open_ui()


func interact(player: Node) -> void:
	_reload_available_recipes()

	var ui: Node = get_tree().get_first_node_in_group("universal_cooker_ui")
	if ui != null and ui.has_method("open_machine"):
		ui.call("open_machine", self, player)


func can_stack_recipe(slot_index: int, recipe: CookingRecipe) -> bool:
	if not _is_valid_slot_index(slot_index):
		return false
	if recipe == null or not recipe.is_valid_recipe():
		return false
	if is_slot_empty(slot_index):
		return false

	var slot: Dictionary = slots[slot_index]
	var slot_recipe_key: String = str(slot.get("recipe_key", ""))
	var recipe_key: String = _get_recipe_unique_key(recipe)
	return not slot_recipe_key.is_empty() and slot_recipe_key == recipe_key


func can_start_recipe_in_slot(slot_index: int, recipe: CookingRecipe) -> bool:
	if not _is_valid_slot_index(slot_index):
		return false
	if recipe == null or not recipe.is_valid_recipe():
		return false
	if is_slot_empty(slot_index):
		return true
	return can_stack_recipe(slot_index, recipe)


func start_recipe(slot_index: int, recipe: CookingRecipe, craft_count: int, player: Node) -> Dictionary:
	var result: Dictionary = _validate_start_request(slot_index, recipe, craft_count, player)
	if not str(result.get("message", "")).is_empty():
		return result

	var plan: Dictionary = _build_consumption_plan(recipe, craft_count)
	if not bool(plan.get("success", false)):
		result["message"] = str(plan.get("message", "材料が足りない"))
		return result

	var remove_list_variant: Variant = plan.get("remove_list", [])
	if typeof(remove_list_variant) != TYPE_ARRAY:
		result["message"] = "材料消費計画が壊れている"
		return result

	return _apply_recipe_start(slot_index, recipe, craft_count, player, remove_list_variant, int(plan.get("output_quality", 0)), int(plan.get("output_rank", 0)))


func start_recipe_with_prepared_ingredients(slot_index: int, recipe: CookingRecipe, craft_count: int, player: Node, prepared_entries: Array) -> Dictionary:
	var result: Dictionary = _validate_start_request(slot_index, recipe, craft_count, player)
	if not str(result.get("message", "")).is_empty():
		return result
	if prepared_entries.is_empty():
		result["message"] = "材料投入スロットが空だ"
		return result

	var plan: Dictionary = _build_prepared_consumption_plan(recipe, craft_count, prepared_entries)
	if not bool(plan.get("success", false)):
		result["message"] = str(plan.get("message", "材料が足りない"))
		return result

	var remove_list_variant: Variant = plan.get("remove_list", [])
	if typeof(remove_list_variant) != TYPE_ARRAY:
		result["message"] = "材料消費計画が壊れている"
		return result

	return _apply_recipe_start(slot_index, recipe, craft_count, player, remove_list_variant, int(plan.get("output_quality", 0)), int(plan.get("output_rank", 0)))


func _validate_start_request(slot_index: int, recipe: CookingRecipe, craft_count: int, player: Node) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"message": "",
		"quality": 0,
		"rank": 0,
		"craft_count": 0
	}

	if not _is_valid_slot_index(slot_index):
		result["message"] = "無効なスロット"
		return result
	if recipe == null or not recipe.is_valid_recipe():
		result["message"] = "無効な料理レシピ"
		return result
	if craft_count <= 0:
		result["message"] = "調理回数が不正"
		return result
	if player == null:
		result["message"] = "プレイヤーがいない"
		return result
	if cooker_level < int(recipe.required_upgrade_level):
		result["message"] = "万能調理器レベルが足りない"
		return result
	if not recipe.can_use_station(station_flags):
		result["message"] = "この調理器ではそのレシピを使えない"
		return result
	if not can_start_recipe_in_slot(slot_index, recipe):
		result["message"] = "使用中スロットには同じ料理だけ追加できる"
		return result
	return result


func _apply_recipe_start(slot_index: int, recipe: CookingRecipe, craft_count: int, player: Node, remove_list: Array, new_quality: int, new_rank: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"message": "開始できなかった",
		"quality": 0,
		"rank": 0,
		"craft_count": 0
	}

	if not is_slot_empty(slot_index):
		var slot_existing: Dictionary = slots[slot_index]
		if int(slot_existing.get("output_quality", -1)) != new_quality or int(slot_existing.get("output_rank", -1)) != new_rank:
			result["message"] = "同じ料理でも品質が違うので別スロットを使ってくれ"
			return result

		var existing_result_path: String = str(slot_existing.get("result_item_path", ""))
		if existing_result_path != recipe.result_item.resource_path:
			result["message"] = "別の完成品が入っている"
			return result

	if not _apply_consumption_plan(player, remove_list):
		result["message"] = "材料の消費に失敗した"
		return result

	if is_slot_empty(slot_index):
		var new_slot: Dictionary = _make_empty_slot()
		new_slot["recipe_key"] = _get_recipe_unique_key(recipe)
		new_slot["display_name"] = recipe.get_display_name()
		new_slot["result_item_path"] = recipe.result_item.resource_path
		new_slot["result_count"] = max(int(recipe.result_count), 1)
		new_slot["total_minutes"] = max(int(round(float(recipe.cook_minutes) / max(speed_multiplier, 0.1))), 1)
		new_slot["remaining_minutes"] = int(new_slot["total_minutes"])
		new_slot["queued_count"] = craft_count
		new_slot["ready_count"] = 0
		new_slot["output_quality"] = new_quality
		new_slot["output_rank"] = new_rank
		new_slot["cooking_exp_per_cycle"] = max(int(recipe.cooking_exp), 0)
		slots[slot_index] = new_slot
	else:
		var slot_to_add: Dictionary = slots[slot_index]
		slot_to_add["queued_count"] = max(int(slot_to_add.get("queued_count", 0)), 0) + craft_count
		if int(slot_to_add.get("remaining_minutes", 0)) <= 0:
			slot_to_add["remaining_minutes"] = max(int(slot_to_add.get("total_minutes", 0)), 1)
		slots[slot_index] = slot_to_add

	save_data()
	_refresh_open_ui()

	result["success"] = true
	result["message"] = "%sを %d 回分 セットした（品質%d / %s）" % [recipe.get_display_name(), craft_count, new_quality, _rank_to_stars(new_rank)]
	result["quality"] = new_quality
	result["rank"] = new_rank
	result["craft_count"] = craft_count
	return result


func _build_consumption_plan(recipe: CookingRecipe, craft_count: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"message": "材料が足りない",
		"remove_list": [],
		"output_quality": 0,
		"output_rank": 0
	}

	var inventory_ui: Node = _get_inventory_ui()
	if inventory_ui == null:
		result["message"] = "InventoryUI が見つからない"
		return result

	var items_variant: Variant = inventory_ui.get("items")
	if typeof(items_variant) != TYPE_ARRAY:
		result["message"] = "インベントリ内容を読めない"
		return result

	var items: Array = items_variant
	var temp_entries: Array[Dictionary] = []
	for entry_variant in items:
		if entry_variant == null:
			continue

		var item_data: ItemData = entry_variant.item_data as ItemData
		var count_value: int = int(entry_variant.count)

		if item_data == null or count_value <= 0:
			continue

		temp_entries.append({
			"item_data": item_data,
			"count": count_value
		})

	var remove_chunks: Array[Dictionary] = []
	var total_quality_points: float = 0.0
	var total_taken_count: int = 0

	for i in range(recipe.ingredients.size()):
		var ingredient: RecipeIngredient = recipe.ingredients[i]
		if ingredient == null:
			continue
		if not ingredient.consume_on_cook:
			continue

		var need_per_craft: int = recipe.get_ingredient_count_at(i)
		var need: int = max(need_per_craft, 0) * craft_count
		var display_name: String = ingredient.get_display_name()

		for temp_entry in temp_entries:
			if need <= 0:
				break

			var temp_item: ItemData = temp_entry.get("item_data") as ItemData
			var available_count: int = int(temp_entry.get("count", 0))
			if temp_item == null or available_count <= 0:
				continue
			if not ingredient.matches_item(temp_item):
				continue

			var take_count: int = min(available_count, need)
			temp_entry["count"] = available_count - take_count
			need -= take_count
			remove_chunks.append({
				"item_data": temp_item,
				"count": take_count
			})
			total_quality_points += float(temp_item.get_quality()) * float(take_count)
			total_taken_count += take_count

		if need > 0:
			result["message"] = "%s が %d 個 足りない" % [display_name, need]
			return result

	var aggregated_remove_list: Array[Dictionary] = _aggregate_remove_chunks(remove_chunks)
	var average_quality: float = 0.0
	if total_taken_count > 0:
		average_quality = total_quality_points / float(total_taken_count)

	var output_quality: int = clamp(int(round((average_quality * max(recipe.base_quality_multiplier, 0.1)) + quality_bonus + _get_cooking_skill_quality_bonus())), 0, 100)
	var output_rank: int = _get_rank_from_quality(output_quality)

	result["success"] = true
	result["message"] = "OK"
	result["remove_list"] = aggregated_remove_list
	result["output_quality"] = output_quality
	result["output_rank"] = output_rank
	return result


func _build_prepared_consumption_plan(recipe: CookingRecipe, craft_count: int, prepared_entries: Array) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"message": "材料が足りない",
		"remove_list": [],
		"output_quality": 0,
		"output_rank": 0
	}

	if recipe == null or not recipe.is_valid_recipe():
		result["message"] = "無効な料理レシピ"
		return result
	if craft_count <= 0:
		result["message"] = "調理回数が不正"
		return result

	var requested_by_signature: Dictionary = {}
	var remove_chunks: Array[Dictionary] = []
	var total_quality_points: float = 0.0
	var total_taken_count: int = 0
	var seen_ingredient_indices: Dictionary = {}

	for entry_variant in prepared_entries:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			result["message"] = "材料投入データが壊れている"
			return result
		var entry: Dictionary = entry_variant
		var ingredient_index: int = int(entry.get("ingredient_index", -1))
		if ingredient_index < 0 or ingredient_index >= recipe.ingredients.size():
			result["message"] = "材料投入先が不正"
			return result
		if seen_ingredient_indices.has(ingredient_index):
			result["message"] = "同じ材料枠が重複している"
			return result
		seen_ingredient_indices[ingredient_index] = true

		var ingredient: RecipeIngredient = recipe.ingredients[ingredient_index]
		if ingredient == null or not ingredient.consume_on_cook:
			result["message"] = "材料設定が壊れている"
			return result

		var item_data: ItemData = entry.get("item_data", null) as ItemData
		if item_data == null:
			result["message"] = "%s が未投入" % ingredient.get_display_name()
			return result
		if not ingredient.matches_item(item_data):
			result["message"] = "%s に合わない材料が入っている" % ingredient.get_display_name()
			return result

		var required_count: int = max(recipe.get_ingredient_count_at(ingredient_index), 0) * craft_count
		var provided_count: int = int(entry.get("count", 0))
		if provided_count != required_count:
			result["message"] = "%s の必要数が変わった。もう一度材料を入れ直してくれ" % ingredient.get_display_name()
			return result

		var signature: String = _get_item_signature(item_data)
		var existing_request: Dictionary = requested_by_signature.get(signature, {})
		requested_by_signature[signature] = {
			"item_data": item_data,
			"count": int(existing_request.get("count", 0)) + required_count
		}
		remove_chunks.append({
			"item_data": item_data,
			"count": required_count
		})
		total_quality_points += float(item_data.get_quality()) * float(required_count)
		total_taken_count += required_count

	for ingredient_index in range(recipe.ingredients.size()):
		var ingredient: RecipeIngredient = recipe.ingredients[ingredient_index]
		if ingredient == null or not ingredient.consume_on_cook:
			continue
		var need_total: int = max(recipe.get_ingredient_count_at(ingredient_index), 0) * craft_count
		if need_total <= 0:
			continue
		if not seen_ingredient_indices.has(ingredient_index):
			result["message"] = "%s が未投入" % ingredient.get_display_name()
			return result

	for signature in requested_by_signature.keys():
		var request_entry: Dictionary = requested_by_signature[signature]
		var item_data: ItemData = request_entry.get("item_data", null) as ItemData
		var requested_count: int = int(request_entry.get("count", 0))
		var available_count: int = _get_inventory_item_count_exact(item_data)
		if available_count < requested_count:
			result["message"] = "%s が %d 個 足りない" % [item_data.item_name, requested_count - available_count]
			return result

	var average_quality: float = 0.0
	if total_taken_count > 0:
		average_quality = total_quality_points / float(total_taken_count)

	var output_quality: int = clamp(int(round((average_quality * max(recipe.base_quality_multiplier, 0.1)) + quality_bonus + _get_cooking_skill_quality_bonus())), 0, 100)
	var output_rank: int = _get_rank_from_quality(output_quality)

	result["success"] = true
	result["message"] = "OK"
	result["remove_list"] = _aggregate_remove_chunks(remove_chunks)
	result["output_quality"] = output_quality
	result["output_rank"] = output_rank
	return result


func _get_item_signature(item_data: ItemData) -> String:
	if item_data == null:
		return ""
	var key: String = str(item_data.id)
	if key.is_empty():
		key = item_data.resource_path
	return "%s|q=%d|r=%d" % [key, item_data.get_quality(), item_data.get_rank()]


func _get_inventory_item_count_exact(item_data: ItemData) -> int:
	var inventory_ui: Node = _get_inventory_ui()
	if inventory_ui == null or item_data == null:
		return 0
	if inventory_ui.has_method("get_item_count_by_data"):
		return int(inventory_ui.call("get_item_count_by_data", item_data))
	return 0


func _aggregate_remove_chunks(remove_chunks: Array[Dictionary]) -> Array[Dictionary]:
	var aggregated: Array[Dictionary] = []
	for chunk in remove_chunks:
		var chunk_item: ItemData = chunk.get("item_data") as ItemData
		var chunk_count: int = int(chunk.get("count", 0))
		if chunk_item == null or chunk_count <= 0:
			continue

		var merged: bool = false
		for entry in aggregated:
			var existing_item: ItemData = entry.get("item_data") as ItemData
			if _can_stack_items(existing_item, chunk_item):
				entry["count"] = int(entry.get("count", 0)) + chunk_count
				merged = true
				break

		if not merged:
			aggregated.append({
				"item_data": chunk_item,
				"count": chunk_count
			})

	return aggregated


func _apply_consumption_plan(player: Node, remove_list: Array[Dictionary]) -> bool:
	var removed_entries: Array[Dictionary] = []
	for entry in remove_list:
		var item_data: ItemData = entry.get("item_data") as ItemData
		var count_value: int = int(entry.get("count", 0))
		if item_data == null or count_value <= 0:
			continue

		var removed_ok: bool = bool(player.call("remove_item_from_inventory", item_data, count_value))
		if not removed_ok:
			for rollback in removed_entries:
				var rollback_item: ItemData = rollback.get("item_data") as ItemData
				var rollback_count: int = int(rollback.get("count", 0))
				if rollback_item != null and rollback_count > 0:
					player.call("add_item_to_inventory", rollback_item, rollback_count)
			return false

		removed_entries.append({
			"item_data": item_data,
			"count": count_value
		})

	return true


func _get_inventory_ui() -> Node:
	return get_tree().get_first_node_in_group("inventory_ui")


func _can_stack_items(a: ItemData, b: ItemData) -> bool:
	if a == null or b == null:
		return false

	var a_id: String = str(a.id)
	var b_id: String = str(b.id)
	if not a_id.is_empty() or not b_id.is_empty():
		if a_id != b_id:
			return false
	else:
		if a.resource_path != b.resource_path and a != b:
			return false

	return a.get_quality() == b.get_quality() and a.get_rank() == b.get_rank()


func _get_cooking_skill_quality_bonus() -> float:
	var stats_manager: Node = _get_player_stats_manager()
	if stats_manager == null or not stats_manager.has_method("get_skill"):
		return 0.0

	var cooking_level: int = int(stats_manager.call("get_skill", "cooking"))
	return clamp(float(cooking_level) * 0.25, 0.0, 25.0)


func _get_rank_from_quality(quality_value: int) -> int:
	if quality_value <= 0:
		return 0
	return clamp(int(ceil(float(quality_value) / 20.0)), 0, 5)


func _rank_to_stars(rank_value: int) -> String:
	var clamped_rank: int = clamp(rank_value, 0, 5)
	var stars: String = ""
	for _i in range(clamped_rank):
		stars += "★"
	for _i in range(5 - clamped_rank):
		stars += "☆"
	return stars


func collect_slot(slot_index: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"item_data": null,
		"amount": 0,
		"ready_cycles": 0,
		"quality": 0,
		"rank": 0,
		"cooking_exp": 0
	}

	if not _is_valid_slot_index(slot_index):
		return result
	if is_slot_empty(slot_index):
		return result

	var ready_cycles: int = get_slot_ready_count(slot_index)
	if ready_cycles <= 0:
		return result

	var base_item: ItemData = get_slot_result_item(slot_index)
	if base_item == null:
		_log_error("完成アイテムが読み込めない")
		return result

	var result_count_per_cycle: int = max(int(slots[slot_index].get("result_count", 0)), 0)
	if result_count_per_cycle <= 0:
		return result

	var total_amount: int = ready_cycles * result_count_per_cycle
	var quality_value: int = int(slots[slot_index].get("output_quality", 0))
	var rank_value: int = int(slots[slot_index].get("output_rank", 0))
	var output_item: ItemData = _build_output_item(base_item, quality_value, rank_value)
	if output_item == null:
		return result

	result["success"] = true
	result["item_data"] = output_item
	result["amount"] = total_amount
	result["ready_cycles"] = ready_cycles
	result["quality"] = output_item.get_quality()
	result["rank"] = output_item.get_rank()
	result["cooking_exp"] = ready_cycles * max(int(slots[slot_index].get("cooking_exp_per_cycle", 0)), 0)

	var slot: Dictionary = slots[slot_index]
	slot["ready_count"] = 0
	if max(int(slot.get("queued_count", 0)), 0) <= 0:
		slots[slot_index] = _make_empty_slot()
	else:
		slots[slot_index] = slot

	save_data()
	_refresh_open_ui()
	return result


func _build_output_item(base_item: ItemData, quality_value: int, rank_value: int) -> ItemData:
	if base_item == null:
		return null

	var output_item: ItemData = base_item.duplicate(true) as ItemData
	if output_item == null:
		output_item = base_item

	output_item.quality = clamp(quality_value, 0, 100)
	output_item.rank = clamp(rank_value, 0, 5)
	return output_item


func get_slot_discard_preview(slot_index: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"display_name": "",
		"ready_amount": 0,
		"ready_cycles": 0,
		"queued_count": 0
	}

	if not _is_valid_slot_index(slot_index):
		return result
	if is_slot_empty(slot_index):
		return result

	result["success"] = true
	result["display_name"] = get_slot_display_name(slot_index)
	result["ready_cycles"] = get_slot_ready_count(slot_index)
	result["ready_amount"] = get_slot_ready_count(slot_index) * get_slot_result_count(slot_index)
	result["queued_count"] = get_slot_queued_count(slot_index)
	return result


func discard_slot(slot_index: int) -> Dictionary:
	var result: Dictionary = get_slot_discard_preview(slot_index)
	if not bool(result.get("success", false)):
		return result

	slots[slot_index] = _make_empty_slot()
	save_data()
	_refresh_open_ui()
	return result


func clear_slot(slot_index: int) -> void:
	if not _is_valid_slot_index(slot_index):
		return
	
	slots[slot_index] = _make_empty_slot()
	save_data()
	_refresh_open_ui()


func is_slot_empty(slot_index: int) -> bool:
	if not _is_valid_slot_index(slot_index):
		return true

	var slot: Dictionary = slots[slot_index]
	var result_path: String = str(slot.get("result_item_path", ""))
	var queued_count: int = max(int(slot.get("queued_count", 0)), 0)
	var ready_count: int = max(int(slot.get("ready_count", 0)), 0)
	return result_path.is_empty() or (queued_count <= 0 and ready_count <= 0)


func is_slot_ready(slot_index: int) -> bool:
	if not _is_valid_slot_index(slot_index):
		return false
	if is_slot_empty(slot_index):
		return false
	return get_slot_ready_count(slot_index) > 0


func has_slot_active_cooking(slot_index: int) -> bool:
	if not _is_valid_slot_index(slot_index):
		return false
	if is_slot_empty(slot_index):
		return false
	return get_slot_queued_count(slot_index) > 0


func get_slot_display_name(slot_index: int) -> String:
	if not _is_valid_slot_index(slot_index):
		return "-"
	if is_slot_empty(slot_index):
		return "空"
	return get_slot_display_name_from_slot(slots[slot_index])


func get_slot_display_name_from_slot(slot: Dictionary) -> String:
	var display_name: String = str(slot.get("display_name", ""))
	if not display_name.is_empty():
		return display_name

	var result_item_path: String = str(slot.get("result_item_path", ""))
	if not result_item_path.is_empty():
		var result_item: ItemData = load(result_item_path) as ItemData
		if result_item != null:
			if not result_item.item_name.is_empty():
				return result_item.item_name
			return str(result_item.id)

	return "料理"


func get_slot_remaining_minutes(slot_index: int) -> int:
	if not _is_valid_slot_index(slot_index):
		return 0
	if is_slot_empty(slot_index):
		return 0
	if not has_slot_active_cooking(slot_index):
		return 0
	return max(int(slots[slot_index].get("remaining_minutes", 0)), 0)


func get_slot_total_minutes(slot_index: int) -> int:
	if not _is_valid_slot_index(slot_index):
		return 0
	if is_slot_empty(slot_index):
		return 0
	return max(int(slots[slot_index].get("total_minutes", 0)), 0)


func get_slot_progress_ratio(slot_index: int) -> float:
	if not _is_valid_slot_index(slot_index):
		return 0.0
	if is_slot_empty(slot_index):
		return 0.0
	if not has_slot_active_cooking(slot_index):
		return 1.0

	var total_minutes: int = get_slot_total_minutes(slot_index)
	if total_minutes <= 0:
		return 0.0

	var remaining_minutes: int = get_slot_remaining_minutes(slot_index)
	var cooked_minutes: int = total_minutes - remaining_minutes
	return clamp(float(cooked_minutes) / float(total_minutes), 0.0, 1.0)


func get_slot_status_text(slot_index: int) -> String:
	if not _is_valid_slot_index(slot_index):
		return "無効"
	if is_slot_empty(slot_index):
		return "空きスロット"

	var display_name: String = get_slot_display_name(slot_index)
	var ready_count: int = get_slot_ready_count(slot_index)
	var queued_count: int = get_slot_queued_count(slot_index)
	var quality_value: int = get_slot_output_quality(slot_index)
	var rank_value: int = get_slot_output_rank(slot_index)
	var quality_text: String = "品質%d / %s" % [quality_value, _rank_to_stars(rank_value)]

	if queued_count <= 0 and ready_count > 0:
		return "%s\n完成待ち: %d回分\n%s" % [display_name, ready_count, quality_text]

	var remaining_minutes: int = get_slot_remaining_minutes(slot_index)
	var progress_percent: int = int(round(get_slot_progress_ratio(slot_index) * 100.0))
	return "%s\n進行中: %d回 / 完成待ち: %d回\n現在: 残り%d分 / %d%%\n%s" % [display_name, queued_count, ready_count, remaining_minutes, progress_percent, quality_text]


func get_slot_result_count(slot_index: int) -> int:
	if not _is_valid_slot_index(slot_index):
		return 0
	if is_slot_empty(slot_index):
		return 0
	return max(int(slots[slot_index].get("result_count", 0)), 0)


func get_slot_ready_count(slot_index: int) -> int:
	if not _is_valid_slot_index(slot_index):
		return 0
	if is_slot_empty(slot_index):
		return 0
	return max(int(slots[slot_index].get("ready_count", 0)), 0)


func get_slot_queued_count(slot_index: int) -> int:
	if not _is_valid_slot_index(slot_index):
		return 0
	if is_slot_empty(slot_index):
		return 0
	return max(int(slots[slot_index].get("queued_count", 0)), 0)


func get_slot_output_quality(slot_index: int) -> int:
	if not _is_valid_slot_index(slot_index):
		return 0
	if is_slot_empty(slot_index):
		return 0
	return clamp(int(slots[slot_index].get("output_quality", 0)), 0, 100)


func get_slot_output_rank(slot_index: int) -> int:
	if not _is_valid_slot_index(slot_index):
		return 0
	if is_slot_empty(slot_index):
		return 0
	return clamp(int(slots[slot_index].get("output_rank", 0)), 0, 5)


func get_slot_result_item(slot_index: int) -> ItemData:
	if not _is_valid_slot_index(slot_index):
		return null
	if is_slot_empty(slot_index):
		return null

	var path: String = str(slots[slot_index].get("result_item_path", ""))
	if path.is_empty():
		return null
	return load(path) as ItemData


func _is_valid_slot_index(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slots.size()


func _get_save_path() -> String:
	var unique_name: String = str(name)
	if unique_name.is_empty():
		unique_name = machine_name
	if unique_name.is_empty():
		unique_name = "default"
	return SAVE_PATH_PREFIX + unique_name + ".json"


func save_data() -> void:
	var data: Dictionary = {
		"slots": slots
	}

	var file: FileAccess = FileAccess.open(_get_save_path(), FileAccess.WRITE)
	if file == null:
		push_error("万能調理器セーブ失敗: %s" % _get_save_path())
		return

	file.store_string(JSON.stringify(data))


func load_data() -> void:
	var save_path: String = _get_save_path()
	if not FileAccess.file_exists(save_path):
		return

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("万能調理器ロード失敗: %s" % save_path)
		return

	var text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("万能調理器JSON読み込み失敗: %s" % save_path)
		return

	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return

	var loaded_slots_variant: Variant = data.get("slots", [])
	if typeof(loaded_slots_variant) != TYPE_ARRAY:
		return

	var loaded_slots: Array = loaded_slots_variant
	var count: int = min(slot_count, loaded_slots.size())
	for i in range(count):
		var slot_variant: Variant = loaded_slots[i]
		if typeof(slot_variant) != TYPE_DICTIONARY:
			continue

		var incoming: Dictionary = slot_variant
		var slot: Dictionary = _make_empty_slot()
		slot["recipe_key"] = str(incoming.get("recipe_key", ""))
		slot["display_name"] = str(incoming.get("display_name", ""))
		slot["result_item_path"] = str(incoming.get("result_item_path", ""))
		slot["result_count"] = max(int(incoming.get("result_count", 0)), 0)
		slot["total_minutes"] = max(int(incoming.get("total_minutes", 0)), 0)
		slot["remaining_minutes"] = max(int(incoming.get("remaining_minutes", 0)), 0)
		slot["queued_count"] = max(int(incoming.get("queued_count", 0)), 0)
		slot["ready_count"] = max(int(incoming.get("ready_count", 0)), 0)
		slot["output_quality"] = clamp(int(incoming.get("output_quality", 0)), 0, 100)
		slot["output_rank"] = clamp(int(incoming.get("output_rank", 0)), 0, 5)
		slot["cooking_exp_per_cycle"] = max(int(incoming.get("cooking_exp_per_cycle", 0)), 0)

		if max(int(slot.get("queued_count", 0)), 0) <= 0 and max(int(slot.get("ready_count", 0)), 0) <= 0:
			slot = _make_empty_slot()

		slots[i] = slot


func _refresh_open_ui() -> void:
	var ui: Node = get_tree().get_first_node_in_group("universal_cooker_ui")
	if ui != null and bool(ui.get("visible")) and ui.has_method("refresh"):
		ui.call("refresh")


func _get_time_manager() -> Node:
	return get_node_or_null("/root/TimeManager")


func _get_player_stats_manager() -> Node:
	return get_node_or_null("/root/PlayerStatsManager")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("register_interactable"):
		body.register_interactable(self)
		_log_debug("プレイヤーが万能調理器の範囲に入った")


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("unregister_interactable"):
		body.unregister_interactable(self)


func _get_message_log() -> Node:
	return get_node_or_null("/root/MessageLog")


func _log_debug(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_debug"):
		log_node.call("add_debug", text)


func _log_system(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_system"):
		log_node.call("add_system", text)


func _log_error(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_error"):
		log_node.call("add_error", text)

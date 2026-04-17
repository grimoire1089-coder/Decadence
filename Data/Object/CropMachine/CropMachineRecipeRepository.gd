extends RefCounted
class_name CropMachineRecipeRepository


func reload_available_recipes(machine: Node) -> void:
	if machine == null:
		return

	var merged: Array[CropRecipe] = []
	var seen: Dictionary = {}

	for recipe in machine.available_recipes:
		append_unique_recipe(merged, seen, recipe)

	for recipe in load_recipes_from_folder(machine, machine.recipe_folder_path, machine.include_subfolders):
		append_unique_recipe(merged, seen, recipe)

	machine.available_recipes = merged


func append_unique_recipe(target: Array[CropRecipe], seen: Dictionary, recipe: CropRecipe) -> bool:
	if recipe == null:
		return false
	if not recipe.is_valid_recipe():
		return false

	var key: String = get_recipe_unique_key(recipe)
	if key.is_empty():
		return false
	if seen.has(key):
		return false

	seen[key] = true
	target.append(recipe)
	return true


func get_recipe_unique_key(recipe: CropRecipe) -> String:
	if recipe == null:
		return ""
	if not recipe.resource_path.is_empty():
		return recipe.resource_path
	if not str(recipe.id).is_empty():
		return str(recipe.id)
	return recipe.get_display_name()


func load_recipes_from_folder(machine: Node, folder_path: String, recursive: bool) -> Array[CropRecipe]:
	var results: Array[CropRecipe] = []
	if folder_path.is_empty():
		return results
	if not DirAccess.dir_exists_absolute(folder_path):
		_log_debug(machine, "栽培レシピフォルダが見つからない: %s" % folder_path)
		return results

	collect_recipes_in_folder(machine, folder_path, recursive, results)
	return results


func collect_recipes_in_folder(machine: Node, folder_path: String, recursive: bool, out_results: Array[CropRecipe]) -> void:
	var dir: DirAccess = DirAccess.open(folder_path)
	if dir == null:
		_log_error(machine, "栽培レシピフォルダを開けない: %s" % folder_path)
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
				collect_recipes_in_folder(machine, full_path, true, out_results)
			continue

		var lower_entry: String = entry.to_lower()
		if not lower_entry.ends_with(".tres") and not lower_entry.ends_with(".res"):
			continue

		var recipe: CropRecipe = load(full_path) as CropRecipe
		if recipe == null:
			continue
		if not recipe.is_valid_recipe():
			_log_debug(machine, "無効な栽培レシピをスキップ: %s" % full_path)
			continue

		out_results.append(recipe)

	dir.list_dir_end()


func _log_debug(machine: Node, text: String) -> void:
	if machine != null and machine.has_method("_log_debug"):
		machine.call("_log_debug", text)


func _log_error(machine: Node, text: String) -> void:
	if machine != null and machine.has_method("_log_error"):
		machine.call("_log_error", text)

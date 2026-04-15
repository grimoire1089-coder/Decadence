extends Resource
class_name CookingRecipe

enum StationType {
	ANY = 0,
	COOK = 1 << 0,
	BOIL = 1 << 1,
	MIX = 1 << 2,
	BAKE = 1 << 3,
	DRINK = 1 << 4,
	FERMENT = 1 << 5
}

@export var id: StringName
@export var recipe_name: String = ""
@export_multiline var description: String = ""

@export var ingredients: Array[RecipeIngredient] = []
@export var ingredient_counts: PackedInt32Array = []

@export var result_item: ItemData
@export_range(1, 999999) var result_count: int = 1
@export_range(1, 999999) var cook_minutes: int = 10

@export_flags(
	"加熱:1",
	"煮込み:2",
	"混ぜる:4",
	"焼成:8",
	"飲み物:16",
	"発酵:32"
) var station_flags: int = StationType.ANY

@export_range(1, 99) var required_upgrade_level: int = 1
@export_range(0.1, 99.0, 0.1) var base_quality_multiplier: float = 1.0
@export_range(0, 999999) var cooking_exp: int = 1


func is_valid_recipe() -> bool:
	if result_item == null:
		return false
	if result_count <= 0:
		return false
	if cook_minutes <= 0:
		return false
	if ingredients.is_empty():
		return false

	for i in range(ingredients.size()):
		var ingredient: RecipeIngredient = ingredients[i]
		if ingredient == null:
			return false
		if not ingredient.is_valid_ingredient():
			return false
		if get_ingredient_count_at(i) <= 0:
			return false

	return true


func get_display_name() -> String:
	if not recipe_name.is_empty():
		return recipe_name

	if result_item != null:
		if not result_item.item_name.is_empty():
			return result_item.item_name
		return str(result_item.id)

	if not str(id).is_empty():
		return str(id)

	return "料理"


func can_use_station(machine_station_flags: int) -> bool:
	if station_flags == StationType.ANY:
		return true
	return (machine_station_flags & station_flags) != 0


func get_ingredient_count_at(index: int) -> int:
	if index < 0 or index >= ingredient_counts.size():
		return 1
	return max(int(ingredient_counts[index]), 1)


func get_ingredients_summary_text() -> String:
	var parts: PackedStringArray = PackedStringArray()

	for i in range(ingredients.size()):
		var ingredient: RecipeIngredient = ingredients[i]
		if ingredient == null:
			continue

		parts.append("%s x%d" % [
			ingredient.get_display_name(),
			get_ingredient_count_at(i)
		])

	return " / ".join(parts)


func normalize_ingredient_counts() -> void:
	var new_counts: PackedInt32Array = PackedInt32Array()

	for i in range(ingredients.size()):
		if i < ingredient_counts.size():
			new_counts.append(max(int(ingredient_counts[i]), 1))
		else:
			new_counts.append(1)

	ingredient_counts = new_counts

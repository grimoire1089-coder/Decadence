extends Resource
class_name CropRecipe

@export var id: StringName
@export var recipe_name: String = ""
@export var seed_item: ItemData
@export var harvest_item: ItemData
@export_range(1, 999999) var grow_minutes: int = 60
@export_range(1, 999999) var harvest_amount: int = 1
@export_range(0, 999999) var farming_exp_per_harvest_cycle: int = 1


func is_valid_recipe() -> bool:
	return seed_item != null and harvest_item != null and grow_minutes > 0 and harvest_amount > 0


func get_display_name() -> String:
	if not recipe_name.is_empty():
		return recipe_name

	if harvest_item != null:
		if not harvest_item.item_name.is_empty():
			return harvest_item.item_name
		return str(harvest_item.id)

	if seed_item != null:
		if not seed_item.item_name.is_empty():
			return seed_item.item_name
		return str(seed_item.id)

	if not str(id).is_empty():
		return str(id)

	return "作物"

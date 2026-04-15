extends Resource
class_name RecipeIngredient

@export var slot_name: String = ""
@export var specific_item: ItemData
@export var item_condition: ItemCondition
@export var consume_on_cook: bool = true


func is_valid_ingredient() -> bool:
	if specific_item == null and item_condition == null:
		return false
	return true


func matches_item(item_data: ItemData) -> bool:
	if item_data == null:
		return false

	if specific_item != null:
		if specific_item == item_data:
			return true
		if not str(specific_item.id).is_empty() and specific_item.id == item_data.id:
			return true
		if not specific_item.resource_path.is_empty() and specific_item.resource_path == item_data.resource_path:
			return true
		return false

	if item_condition != null:
		return item_condition.matches(item_data)

	return false


func get_display_name() -> String:
	if not slot_name.is_empty():
		return slot_name

	if specific_item != null:
		if not specific_item.item_name.is_empty():
			return specific_item.item_name
		return str(specific_item.id)

	if item_condition != null:
		return item_condition.get_summary_text()

	return "食材"

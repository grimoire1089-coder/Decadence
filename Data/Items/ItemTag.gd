@tool
extends Resource
class_name ItemTag

@export var id: StringName = &""
@export var display_name: String = ""
@export var category: StringName = &"generic"
@export_multiline var description: String = ""


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if not String(id).is_empty():
		return String(id)
	return "ラベル"

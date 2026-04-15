@tool
extends EditorInspectorPlugin

const ItemLabelPropertyEditor = preload("res://addons/item_label_inspector/item_label_property.gd")

const TARGET_PROPERTIES := {
	&"labels": "Labels",
	&"require_all_labels": "Require All Labels",
	&"require_any_labels": "Require Any Labels",
	&"forbid_labels": "Forbid Labels",
}


func _can_handle(object: Object) -> bool:
	return object is Resource and _has_target_property(object)


func _parse_property(
	object: Object,
	type: Variant.Type,
	name: String,
	hint_type: PropertyHint,
	hint_string: String,
	usage_flags: int,
	wide: bool = false
) -> bool:
	var property_name := StringName(name)
	if not TARGET_PROPERTIES.has(property_name):
		return false

	var editor := ItemLabelPropertyEditor.new()
	add_property_editor(name, editor, false, TARGET_PROPERTIES[property_name])
	return true


func _has_target_property(object: Object) -> bool:
	for property_info in object.get_property_list():
		var property_name := StringName(property_info["name"] if property_info.has("name") else "")
		if TARGET_PROPERTIES.has(property_name):
			return true
	return false

extends RefCounted
class_name PlayerNameplateController

var owner: CharacterBody2D = null
var _root: Node2D = null
var _label: Label = null


func setup(owner_node: CharacterBody2D) -> void:
	owner = owner_node
	_resolve_nodes()


func refresh_display() -> void:
	_resolve_nodes()
	if _root == null or _label == null or owner == null:
		return

	var display_name: String = ""
	if owner.has_method("get_player_display_name"):
		display_name = String(owner.call("get_player_display_name")).strip_edges()

	_label.text = display_name
	_root.visible = not display_name.is_empty()


func _resolve_nodes() -> void:
	if owner == null:
		return

	if _root == null and owner.nameplate_root_path != NodePath():
		_root = owner.get_node_or_null(owner.nameplate_root_path) as Node2D

	if _label == null and owner.nameplate_label_path != NodePath():
		_label = owner.get_node_or_null(owner.nameplate_label_path) as Label

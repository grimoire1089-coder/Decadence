extends Node
class_name PlayerSkillController

const MODAL_UI_GROUPS: Array[StringName] = [
	&"vending_ui",
	&"crop_machine_ui",
	&"skill_ui",
	&"npc_dialog_ui",
	&"pause_menu_ui"
]

@export_node_path("CanvasLayer") var hotbar_path: NodePath
@export_node_path("Node") var skill_caster_path: NodePath
@export_node_path("Node2D") var self_target_path: NodePath
@export var use_self_as_default_target: bool = true
@export var show_fail_log: bool = true
@export var show_setup_log: bool = true

var _hotbar: CanvasLayer = null
var _skill_caster: Node = null
var _self_target: Node2D = null


func _ready() -> void:
	_resolve_references()
	_log_missing_references()
	_connect_hotbar_signals()
	_connect_skill_caster_signals()
	_refresh_all_hotbar_cooldowns()


func _resolve_references() -> void:
	_hotbar = _find_hotbar()
	_skill_caster = _find_skill_caster()
	_self_target = _find_self_target()


func _find_hotbar() -> CanvasLayer:
	if not hotbar_path.is_empty():
		var by_path: Node = get_node_or_null(hotbar_path)
		if by_path is CanvasLayer:
			return by_path as CanvasLayer

	var by_group: Node = get_tree().get_first_node_in_group("skill_hotbar_ui")
	if by_group is CanvasLayer:
		return by_group as CanvasLayer

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		var found: Node = current_scene.find_child("SkillHotbarUI", true, false)
		if found is CanvasLayer:
			return found as CanvasLayer

	return null


func _find_skill_caster() -> Node:
	if not skill_caster_path.is_empty():
		var by_path: Node = get_node_or_null(skill_caster_path)
		if by_path != null:
			return by_path

	var parent_node: Node = get_parent()
	if parent_node != null:
		var direct_from_parent: Node = parent_node.get_node_or_null("SkillCaster")
		if direct_from_parent != null:
			return direct_from_parent

		for child in parent_node.get_children():
			if child is Node and child.has_method("cast_skill") and child.has_signal("cooldown_updated"):
				return child as Node

	var owner_node: Node = owner
	if owner_node != null:
		var direct_from_owner: Node = owner_node.get_node_or_null("SkillCaster")
		if direct_from_owner != null:
			return direct_from_owner

		for child in owner_node.get_children():
			if child is Node and child.has_method("cast_skill") and child.has_signal("cooldown_updated"):
				return child as Node

	return null


func _find_self_target() -> Node2D:
	var parent_node: Node = get_parent()
	if parent_node is Node2D:
		return parent_node as Node2D

	if not self_target_path.is_empty():
		var by_path: Node = get_node_or_null(self_target_path)
		if by_path is Node2D:
			return by_path as Node2D

	if owner is Node2D:
		return owner as Node2D

	return null


func _log_missing_references() -> void:
	if not show_setup_log:
		return

	if _hotbar == null:
		SkillHelpers.add_system_log("[Skill] SkillHotbarUI が見つかりません")
	if _skill_caster == null:
		SkillHelpers.add_system_log("[Skill] SkillCaster が見つかりません")
	if _self_target == null:
		SkillHelpers.add_system_log("[Skill] 自己対象ノードが見つかりません")


func _connect_hotbar_signals() -> void:
	if _hotbar == null:
		return
	if not _hotbar.has_signal("skill_slot_pressed"):
		return

	var callback := Callable(self, "_on_hotbar_skill_slot_pressed")
	if not _hotbar.is_connected("skill_slot_pressed", callback):
		_hotbar.connect("skill_slot_pressed", callback)

	if _hotbar.has_signal("slot_skill_assigned"):
		var assigned_callback := Callable(self, "_on_slot_skill_assigned")
		if not _hotbar.is_connected("slot_skill_assigned", assigned_callback):
			_hotbar.connect("slot_skill_assigned", assigned_callback)

	if _hotbar.has_signal("slot_cleared"):
		var cleared_callback := Callable(self, "_on_slot_cleared")
		if not _hotbar.is_connected("slot_cleared", cleared_callback):
			_hotbar.connect("slot_cleared", cleared_callback)


func _connect_skill_caster_signals() -> void:
	if _skill_caster == null:
		return

	if _skill_caster.has_signal("cooldown_updated"):
		var cooldown_callback := Callable(self, "_on_skill_cooldown_updated")
		if not _skill_caster.is_connected("cooldown_updated", cooldown_callback):
			_skill_caster.connect("cooldown_updated", cooldown_callback)

	if _skill_caster.has_signal("skill_cast_failed"):
		var failed_callback := Callable(self, "_on_skill_cast_failed")
		if not _skill_caster.is_connected("skill_cast_failed", failed_callback):
			_skill_caster.connect("skill_cast_failed", failed_callback)


func _on_hotbar_skill_slot_pressed(slot_index: int) -> void:
	if _hotbar == null or _skill_caster == null:
		return
	if _is_any_modal_ui_visible():
		return

	if not _hotbar.has_method("get_slot_skill_resource"):
		return

	var skill_resource: Variant = _hotbar.call("get_slot_skill_resource", slot_index)
	if not (skill_resource is Resource):
		return

	_self_target = _find_self_target()
	var target: Node2D = _resolve_cast_target(skill_resource as Resource)
	if target == null:
		if show_fail_log:
			SkillHelpers.add_system_log("対象がいないためスキルを使えない")
		return

	if _skill_caster == null:
		if show_fail_log:
			SkillHelpers.add_system_log("SkillCaster が見つかりません")
		return

	if not _skill_caster.has_method("cast_skill"):
		if show_fail_log:
			SkillHelpers.add_system_log("SkillCaster ノードに cast_skill がありません")
		return

	_skill_caster.call("cast_skill", skill_resource, target)


func _resolve_cast_target(_skill_resource: Resource) -> Node2D:
	if use_self_as_default_target:
		return _self_target
	return _self_target


func _on_skill_cooldown_updated(skill_id: String, remaining: float, total: float) -> void:
	if _hotbar == null:
		return

	for slot_index in range(_get_hotbar_slot_count()):
		var slot_skill_id: String = _get_hotbar_slot_skill_id(slot_index)
		if slot_skill_id != skill_id:
			continue

		var ratio: float = 0.0
		if total > 0.0:
			ratio = clampf(remaining / total, 0.0, 1.0)

		var label_text: String = ""
		if remaining > 0.0:
			label_text = _format_cooldown_label(remaining)

		if _hotbar.has_method("set_slot_cooldown"):
			_hotbar.call("set_slot_cooldown", slot_index, ratio, label_text)


func _on_slot_skill_assigned(_slot_index: int, _skill_id: String) -> void:
	_refresh_all_hotbar_cooldowns()


func _on_slot_cleared(slot_index: int) -> void:
	if _hotbar != null and _hotbar.has_method("set_slot_cooldown"):
		_hotbar.call("set_slot_cooldown", slot_index, 0.0, "")


func _refresh_all_hotbar_cooldowns() -> void:
	if _hotbar == null or _skill_caster == null:
		return

	for slot_index in range(_get_hotbar_slot_count()):
		var skill_id: String = _get_hotbar_slot_skill_id(slot_index)
		if skill_id.is_empty():
			if _hotbar.has_method("set_slot_cooldown"):
				_hotbar.call("set_slot_cooldown", slot_index, 0.0, "")
			continue

		var remaining: float = 0.0
		var ratio: float = 0.0
		if _skill_caster.has_method("get_cooldown_remaining"):
			remaining = float(_skill_caster.call("get_cooldown_remaining", skill_id))
		if _skill_caster.has_method("get_cooldown_ratio"):
			ratio = float(_skill_caster.call("get_cooldown_ratio", skill_id))

		var label_text: String = ""
		if remaining > 0.0:
			label_text = _format_cooldown_label(remaining)

		if _hotbar.has_method("set_slot_cooldown"):
			_hotbar.call("set_slot_cooldown", slot_index, ratio, label_text)


func _on_skill_cast_failed(skill_id: String, reason: String) -> void:
	if not show_fail_log:
		return

	var prefix: String = "スキル"
	if not skill_id.is_empty():
		prefix = skill_id
	SkillHelpers.add_system_log("%s: %s" % [prefix, reason])


func _get_hotbar_slot_count() -> int:
	if _hotbar == null:
		return 0
	var value: Variant = _hotbar.get("slot_count")
	if value is int:
		return int(value)
	return 0


func _get_hotbar_slot_skill_id(slot_index: int) -> String:
	if _hotbar == null or not _hotbar.has_method("get_slot_skill_id"):
		return ""
	return String(_hotbar.call("get_slot_skill_id", slot_index))


func _format_cooldown_label(remaining: float) -> String:
	if remaining >= 10.0:
		return str(int(ceil(remaining)))
	return String.num(remaining, 1)


func _is_any_modal_ui_visible() -> bool:
	for group_name in MODAL_UI_GROUPS:
		var ui: Control = get_tree().get_first_node_in_group(String(group_name)) as Control
		if ui != null and ui.visible:
			return true
	return false

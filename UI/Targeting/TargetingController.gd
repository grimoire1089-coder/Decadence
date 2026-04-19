extends Node2D
class_name TargetingController

signal target_changed(target)

const MODAL_UI_GROUPS: Array[StringName] = [
	&"vending_ui",
	&"crop_machine_ui",
	&"skill_ui",
	&"npc_dialog_ui",
	&"pause_menu_ui"
]

@export_node_path("Node2D") var player_path: NodePath = NodePath("../CharacterBody2D")
@export_node_path("Node2D") var marker_path: NodePath
@export var clear_on_empty_click: bool = true
@export var allow_toggle_deselect_on_same_click: bool = false
@export var ignore_click_when_pointer_over_ui: bool = true
@export var allow_target_selection_during_modal: bool = false
@export_range(1, 64, 1) var max_pick_results: int = 16
@export_group("Distance")
@export var auto_clear_by_distance: bool = true
@export_range(1.0, 1000.0, 1.0) var max_target_distance_meters: float = 70.0
@export_range(1.0, 256.0, 1.0) var pixels_per_meter: float = 16.0

var _player: Node2D = null
var _marker: Node2D = null
var _current_target: Node2D = null


func _ready() -> void:
	add_to_group("player_targeting_controller")
	_resolve_references()
	_sync_marker()
	set_process(true)


func _process(_delta: float) -> void:
	if _current_target == null:
		_sync_marker()
		return

	if not is_instance_valid(_current_target):
		clear_target(false)
		return

	if not _is_targetable_node(_current_target):
		clear_target(false)
		return

	if auto_clear_by_distance and _is_target_out_of_range(_current_target):
		clear_target()
		return

	_sync_marker()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null:
		return
	if not mouse_event.pressed:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if not allow_target_selection_during_modal and _is_any_modal_ui_visible():
		return

	if ignore_click_when_pointer_over_ui:
		var hovered: Control = get_viewport().gui_get_hovered_control()
		if hovered != null and hovered.visible:
			return

	var picked_target: Node2D = _pick_target_at_mouse_position()
	if picked_target == null:
		if clear_on_empty_click:
			clear_target()
			get_viewport().set_input_as_handled()
		return

	if allow_toggle_deselect_on_same_click and picked_target == _current_target:
		clear_target()
	else:
		set_current_target(picked_target)

	get_viewport().set_input_as_handled()


func set_current_target(target: Node2D) -> void:
	if target == null:
		clear_target()
		return
	if not is_instance_valid(target):
		clear_target()
		return
	if not _is_targetable_node(target):
		return
	if _current_target == target:
		_sync_marker()
		return

	_current_target = target
	_sync_marker()
	target_changed.emit(_current_target)


func clear_target(emit_signal_flag: bool = true) -> void:
	_current_target = null
	_sync_marker()
	if emit_signal_flag:
		target_changed.emit(null)


func get_current_target() -> Node2D:
	if _current_target == null:
		return null
	if not is_instance_valid(_current_target):
		return null
	return _current_target


func has_target() -> bool:
	return get_current_target() != null


func is_current_target_hostile() -> bool:
	var target: Node2D = get_current_target()
	if target == null:
		return false
	return _is_hostile_target(target)


func is_current_target_friendly() -> bool:
	var target: Node2D = get_current_target()
	if target == null:
		return false
	return _is_friendly_target(target)


func _resolve_references() -> void:
	_player = _find_player()
	_marker = _find_marker()


func _find_player() -> Node2D:
	if not player_path.is_empty():
		var by_path: Node = get_node_or_null(player_path)
		if by_path is Node2D:
			return by_path as Node2D

	var parent_node: Node = get_parent()
	if parent_node != null:
		var sibling: Node = parent_node.get_node_or_null("CharacterBody2D")
		if sibling is Node2D:
			return sibling as Node2D

	var group_target: Node = get_tree().get_first_node_in_group("player")
	if group_target is Node2D:
		return group_target as Node2D

	return null


func _find_marker() -> Node2D:
	if not marker_path.is_empty():
		var by_path: Node = get_node_or_null(marker_path)
		if by_path is Node2D:
			return by_path as Node2D

	var parent_node: Node = get_parent()
	if parent_node != null:
		var sibling: Node = parent_node.get_node_or_null("TargetMarker2D")
		if sibling is Node2D:
			return sibling as Node2D

	return null


func _pick_target_at_mouse_position() -> Node2D:
	var world := get_world_2d()
	if world == null:
		return null

	var query := PhysicsPointQueryParameters2D.new()
	query.position = get_global_mouse_position()
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var results: Array = world.direct_space_state.intersect_point(query, max_pick_results)
	for hit_variant in results:
		if typeof(hit_variant) != TYPE_DICTIONARY:
			continue

		var hit: Dictionary = hit_variant
		var collider_variant: Variant = hit.get("collider", null)
		if not (collider_variant is Node):
			continue

		var resolved: Node2D = _resolve_target_from_node(collider_variant as Node)
		if resolved != null:
			return resolved

	return null


func _resolve_target_from_node(node: Node) -> Node2D:
	var current: Node = node
	while current != null:
		if current is Node2D:
			var candidate: Node2D = current as Node2D
			if _is_targetable_node(candidate):
				return candidate
		current = current.get_parent()
	return null


func _is_targetable_node(node: Node) -> bool:
	if node == null:
		return false
	if not is_instance_valid(node):
		return false
	if node.is_in_group("player"):
		return false
	if node.is_in_group("targetable"):
		return true
	if node is EnemyNPC:
		return true
	if node is NPC:
		return true
	if node.has_method("is_target_selectable"):
		return _variant_to_bool(node.call("is_target_selectable"))
	if node.has_method("get_target_display_name"):
		return true
	if node.has_method("get_hp") and node.has_method("get_max_hp"):
		return true
	return false


func _is_hostile_target(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.is_in_group("hostile_target"):
		return true
	return node is EnemyNPC


func _is_friendly_target(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.is_in_group("friendly_target"):
		return true
	return node is NPC


func _is_target_out_of_range(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return true

	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
	if _player == null or not is_instance_valid(_player):
		return false

	var max_distance_pixels: float = max(max_target_distance_meters, 0.0) * max(pixels_per_meter, 0.0)
	if max_distance_pixels <= 0.0:
		return false

	return _player.global_position.distance_to(target.global_position) > max_distance_pixels


func _sync_marker() -> void:
	if _marker == null:
		return
	if _marker.has_method("set_target"):
		_marker.call("set_target", get_current_target())


func _is_any_modal_ui_visible() -> bool:
	for group_name in MODAL_UI_GROUPS:
		var ui: Control = get_tree().get_first_node_in_group(String(group_name)) as Control
		if ui != null and ui.visible:
			return true
	return false


func _variant_to_bool(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int:
		return value != 0
	if value is float:
		return not is_zero_approx(value)
	return false

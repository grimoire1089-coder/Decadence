extends RefCounted
class_name PlayerInteractionController

var owner: CharacterBody2D = null
var ui_modal_manager_script_name: String = ""
var pause_menu_scene_path: String = ""
var modal_ui_groups: Array = []


func setup(owner_node: CharacterBody2D, modal_manager_script_name: String, pause_scene_path: String, groups: Array) -> void:
	owner = owner_node
	ui_modal_manager_script_name = modal_manager_script_name
	pause_menu_scene_path = pause_scene_path
	modal_ui_groups = groups.duplicate()


func register_interactable(target: Node2D) -> void:
	if not _is_local_gameplay_owner():
		return
	if owner == null or target == null:
		return

	if not owner.nearby_interactables.has(target):
		owner.nearby_interactables.append(target)

	update_current_interactable()


func unregister_interactable(target: Node2D) -> void:
	if not _is_local_gameplay_owner():
		return
	if owner == null or target == null:
		return

	owner.nearby_interactables.erase(target)
	update_current_interactable()


func update_current_interactable() -> void:
	if owner == null:
		return

	if not _is_local_gameplay_owner():
		if owner.current_interactable != null:
			owner.current_interactable = null
			owner.interactable_changed.emit(owner.current_interactable)
		owner.nearby_interactables.clear()
		return

	for i in range(owner.nearby_interactables.size() - 1, -1, -1):
		if not is_instance_valid(owner.nearby_interactables[i]):
			owner.nearby_interactables.remove_at(i)

	var nearest: Node2D = null
	var nearest_distance: float = INF

	for target in owner.nearby_interactables:
		var dist: float = owner.global_position.distance_squared_to(target.global_position)
		if dist < nearest_distance:
			nearest_distance = dist
			nearest = target

	if owner.current_interactable != nearest:
		owner.current_interactable = nearest
		owner.interactable_changed.emit(owner.current_interactable)


func is_interaction_ui_open() -> bool:
	if not _is_local_gameplay_owner():
		return false
	return is_any_modal_ui_visible()


func is_player_control_locked() -> bool:
	if not _is_local_gameplay_owner():
		return false
	if owner == null:
		return false

	if owner._input_locked:
		return true

	var any_modal_visible: bool = is_any_modal_ui_visible()
	var ui_modal_manager: Node = find_ui_modal_manager()
	if ui_modal_manager != null and ui_modal_manager.has_method("is_player_input_blocked"):
		var blocked_by_manager: bool = bool(ui_modal_manager.call("is_player_input_blocked"))
		if blocked_by_manager and any_modal_visible:
			return true

	return any_modal_visible


func is_any_modal_ui_visible() -> bool:
	if not _is_local_gameplay_owner():
		return false
	if owner == null:
		return false

	for group_name in modal_ui_groups:
		var ui: Control = owner.get_tree().get_first_node_in_group(String(group_name)) as Control
		if ui != null and ui.visible:
			return true
	return false


func has_non_pause_modal_visible() -> bool:
	if not _is_local_gameplay_owner():
		return false
	if owner == null:
		return false

	for group_name in modal_ui_groups:
		if String(group_name) == "pause_menu_ui":
			continue

		var ui: Control = owner.get_tree().get_first_node_in_group(String(group_name)) as Control
		if ui != null and ui.visible:
			return true

	return false


func get_pause_menu_ui() -> Control:
	if not _is_local_gameplay_owner():
		return null
	if owner == null:
		return null
	return owner.get_tree().get_first_node_in_group("pause_menu_ui") as Control


func ensure_pause_menu_exists() -> Control:
	if not _is_local_gameplay_owner():
		return null
	if owner == null:
		return null

	var existing: Control = get_pause_menu_ui()
	if existing != null:
		return existing

	if not ResourceLoader.exists(pause_menu_scene_path):
		return null

	var packed_scene: PackedScene = load(pause_menu_scene_path) as PackedScene
	if packed_scene == null:
		return null

	var instance: Control = packed_scene.instantiate() as Control
	if instance == null:
		return null

	var parent_node: Node = owner.get_tree().current_scene
	if parent_node == null:
		parent_node = owner.get_tree().root

	parent_node.add_child(instance)
	return instance


func find_ui_modal_manager() -> Node:
	if not _is_local_gameplay_owner():
		return null
	if owner == null:
		return null

	var by_path: Node = owner.get_node_or_null("/root/UIModalManager")
	if by_path != null:
		return by_path

	var by_group: Node = owner.get_tree().get_first_node_in_group("ui_modal_manager")
	if by_group != null:
		return by_group

	for child in owner.get_tree().root.get_children():
		var script_value: Variant = child.get_script()
		if script_value is Script:
			var script_ref: Script = script_value as Script
			if script_ref != null and script_ref.resource_path.get_file() == ui_modal_manager_script_name:
				return child

	return null


func _is_local_gameplay_owner() -> bool:
	if owner == null or not is_instance_valid(owner):
		return false
	if owner.has_method("is_network_remote_player"):
		return not bool(owner.call("is_network_remote_player"))
	return true

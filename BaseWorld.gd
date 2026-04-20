extends Node2D
class_name BaseWorld

@export_file("*.tscn") var default_map_scene_path: String = "res://Maps/TownMap_MainExtract.tscn"

@onready var player: Node = $Sortables/Player
@onready var loading_overlay: Node = $UI/LoadingOverlay
@onready var inventory_ui: Node = $UI/InventoryUI
@onready var map_transition_manager: Node = get_node_or_null("MapTransitionManager")

var _boot_started: bool = false


func _ready() -> void:
	_ensure_map_transition_manager()
	if map_transition_manager != null and map_transition_manager.has_method("set_default_map_scene_path"):
		map_transition_manager.call("set_default_map_scene_path", default_map_scene_path)
	call_deferred("_boot_game")


func prepare_world_before_restore(save_data: Dictionary) -> void:
	_ensure_map_transition_manager()
	if map_transition_manager != null and map_transition_manager.has_method("prepare_world_before_restore"):
		map_transition_manager.call("prepare_world_before_restore", save_data)


func export_save_data() -> Dictionary:
	_ensure_map_transition_manager()
	if map_transition_manager != null and map_transition_manager.has_method("export_save_data"):
		var exported: Variant = map_transition_manager.call("export_save_data")
		if typeof(exported) == TYPE_DICTIONARY:
			return exported as Dictionary
	return {}


func import_save_data(save_data: Dictionary) -> void:
	_ensure_map_transition_manager()
	if map_transition_manager != null and map_transition_manager.has_method("import_save_data"):
		map_transition_manager.call("import_save_data", save_data)


func get_current_map_scene_path() -> String:
	_ensure_map_transition_manager()
	if map_transition_manager != null and map_transition_manager.has_method("get_current_map_scene_path"):
		return String(map_transition_manager.call("get_current_map_scene_path")).strip_edges()
	return ""


func get_map_transition_manager() -> Node:
	_ensure_map_transition_manager()
	return map_transition_manager


func request_map_transition(target_map_scene_path: String, target_spawn_id: String = "", transition_name: String = "", log_text: String = "") -> void:
	_ensure_map_transition_manager()
	if map_transition_manager != null and map_transition_manager.has_method("request_transition"):
		map_transition_manager.call("request_transition", target_map_scene_path, target_spawn_id, transition_name, log_text)


func _boot_game() -> void:
	if _boot_started:
		return
	_boot_started = true

	_ensure_map_transition_manager()
	_set_player_input_locked(true)
	_open_loading_overlay("読み込み中…", 0)
	await get_tree().process_frame

	if get_current_map_scene_path().is_empty() and map_transition_manager != null and map_transition_manager.has_method("prepare_world_before_restore"):
		map_transition_manager.call("prepare_world_before_restore", {})

	_update_loading_overlay("インベントリデータを読み込み中…", 30)
	if inventory_ui != null and inventory_ui.has_method("boot_initialize"):
		inventory_ui.call("boot_initialize")
	await get_tree().process_frame

	_update_loading_overlay("完了", 100)
	await get_tree().create_timer(0.15).timeout

	_close_loading_overlay()
	await get_tree().process_frame
	_reapply_saved_player_state()
	_reapply_saved_persistent_nodes()
	_apply_pending_boot_spawn_if_needed()
	_resume_time_manager()
	_set_player_input_locked(false)


func _ensure_map_transition_manager() -> void:
	if map_transition_manager != null and is_instance_valid(map_transition_manager):
		return

	map_transition_manager = get_node_or_null("MapTransitionManager")
	if map_transition_manager != null and is_instance_valid(map_transition_manager):
		return

	var manager_script: Script = load("res://Scripts/System/MapTransitionManager.gd") as Script
	if manager_script == null:
		push_warning("BaseWorld: MapTransitionManager.gd を読み込めません")
		return

	var manager: Node = Node.new()
	manager.name = "MapTransitionManager"
	manager.set_script(manager_script)
	add_child(manager)
	move_child(manager, 0)
	map_transition_manager = manager

	if map_transition_manager != null and map_transition_manager.has_method("set_default_map_scene_path"):
		map_transition_manager.call("set_default_map_scene_path", default_map_scene_path)


func _apply_pending_boot_spawn_if_needed() -> void:
	_ensure_map_transition_manager()
	if map_transition_manager != null and map_transition_manager.has_method("apply_pending_boot_spawn_if_needed"):
		map_transition_manager.call("apply_pending_boot_spawn_if_needed")


func _reapply_saved_player_state() -> void:
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_method("reapply_player_state_deferred"):
		save_manager.call("reapply_player_state_deferred", self, 2)


func _reapply_saved_persistent_nodes() -> void:
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_method("reapply_persistent_nodes_deferred"):
		save_manager.call("reapply_persistent_nodes_deferred", self, 2)


func _resume_time_manager() -> void:
	var time_manager: Node = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return

	if time_manager.has_method("start_time"):
		time_manager.call("start_time")
		return

	if time_manager.has_method("set_time_running"):
		time_manager.call("set_time_running", true)
		return

	for property_info in time_manager.get_property_list():
		if String(property_info.get("name", "")) == "is_running":
			time_manager.set("is_running", true)
			return


func _set_player_input_locked(value: bool) -> void:
	if player != null and player.has_method("set_input_locked"):
		player.call("set_input_locked", value)


func _open_loading_overlay(text: String, progress: float = -1.0) -> void:
	if loading_overlay != null and loading_overlay.has_method("open"):
		loading_overlay.call("open", text, progress)


func _update_loading_overlay(text: String, progress: float = -1.0) -> void:
	if loading_overlay == null:
		return

	if loading_overlay.has_method("set_status"):
		loading_overlay.call("set_status", text)

	if loading_overlay.has_method("set_progress"):
		loading_overlay.call("set_progress", progress)


func _close_loading_overlay() -> void:
	if loading_overlay != null and loading_overlay.has_method("close"):
		loading_overlay.call("close")

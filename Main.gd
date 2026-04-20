extends Node2D

const META_PENDING_SCENE_PATH: StringName = &"scene_transition_target_scene_path"
const META_PENDING_SPAWN_ID: StringName = &"scene_transition_target_spawn_id"

@onready var player: Node = get_node_or_null("Sortables/Player")
@onready var loading_overlay: Node = get_node_or_null("UI/LoadingOverlay")
@onready var inventory_ui: Node = get_node_or_null("UI/InventoryUI")

func _ready() -> void:
	call_deferred("_boot_game")


func _boot_game() -> void:
	_set_player_input_locked(true)
	_open_loading_overlay("読み込み中…", 0)
	await get_tree().process_frame

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
	_apply_pending_scene_transition_spawn()
	_resume_time_manager()
	_set_player_input_locked(false)


func _reapply_saved_player_state() -> void:
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_method("reapply_player_state_deferred"):
		save_manager.call("reapply_player_state_deferred", self, 2)


func _reapply_saved_persistent_nodes() -> void:
	var save_manager: Node = get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_method("reapply_persistent_nodes_deferred"):
		save_manager.call("reapply_persistent_nodes_deferred", self, 2)


func _apply_pending_scene_transition_spawn() -> void:
	var root_node: Window = get_tree().root
	if root_node == null:
		return
	if not root_node.has_meta(META_PENDING_SCENE_PATH):
		return

	var expected_scene_path: String = String(root_node.get_meta(META_PENDING_SCENE_PATH, "")).strip_edges()
	var pending_spawn_id: String = String(root_node.get_meta(META_PENDING_SPAWN_ID, "")).strip_edges()
	_clear_pending_scene_transition_meta()

	if pending_spawn_id.is_empty():
		return

	var current_scene_path: String = String(scene_file_path).strip_edges()
	if not expected_scene_path.is_empty() and current_scene_path != expected_scene_path:
		return

	var spawn_point: Node2D = _find_scene_spawn_point(pending_spawn_id)
	var player_node: Node2D = player as Node2D
	if spawn_point == null or player_node == null:
		return

	player_node.global_position = spawn_point.global_position


func _clear_pending_scene_transition_meta() -> void:
	var root_node: Window = get_tree().root
	if root_node == null:
		return
	if root_node.has_meta(META_PENDING_SCENE_PATH):
		root_node.remove_meta(META_PENDING_SCENE_PATH)
	if root_node.has_meta(META_PENDING_SPAWN_ID):
		root_node.remove_meta(META_PENDING_SPAWN_ID)


func _find_scene_spawn_point(spawn_id: String) -> Node2D:
	for node_obj in get_tree().get_nodes_in_group("scene_spawn_point"):
		var node: Node = node_obj as Node
		if node == null:
			continue
		if not _is_descendant_of(self, node):
			continue

		var node_spawn_id: String = ""
		if node.has_method("get_spawn_id"):
			node_spawn_id = String(node.call("get_spawn_id")).strip_edges()
		else:
			node_spawn_id = String(node.get("spawn_id")).strip_edges()

		if node_spawn_id == spawn_id and node is Node2D:
			return node as Node2D

	return null


func _is_descendant_of(root: Node, candidate: Node) -> bool:
	if root == null or candidate == null:
		return false

	var current: Node = candidate
	while current != null:
		if current == root:
			return true
		current = current.get_parent()
	return false


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


func _load_item_defs() -> void:
	pass


func _load_recipe_defs() -> void:
	pass


func _init_shop_data() -> void:
	pass


func _init_crop_data() -> void:
	pass


func _build_ui() -> void:
	pass

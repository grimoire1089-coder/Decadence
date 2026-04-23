extends Node
class_name MapTransitionManager

signal transition_started(request: Dictionary)
signal transition_finished(request: Dictionary)
signal map_loaded(map_scene_path: String)
signal map_load_failed(map_scene_path: String)

@export_file("*.tscn") var default_map_scene_path: String = "res://Maps/TownMap_MainExtract.tscn"
@export_node_path("Node2D") var map_root_path: NodePath = NodePath("../MapRoot")
@export_node_path("Node2D") var sortables_path: NodePath = NodePath("../Sortables")
@export_node_path("Node") var player_path: NodePath = NodePath("../Sortables/Player")
@export_node_path("Node") var loading_overlay_path: NodePath = NodePath("../UI/LoadingOverlay")

@export_group("Transition FX")
@export var use_fade_transition: bool = true
@export_range(0.0, 2.0, 0.01) var fade_out_duration: float = 0.18
@export_range(0.0, 2.0, 0.01) var fade_in_duration: float = 0.18
@export_range(0.0, 1.0, 0.01) var transition_hold_duration: float = 0.03
@export_range(0.0, 1.0, 0.01) var post_spawn_fade_in_delay: float = 0.10
@export_range(0.0, 1.0, 0.01) var transition_black_alpha: float = 1.0
@export var default_transition_sfx: AudioStream
@export var transition_sfx_bus: StringName = &"Master"

@onready var map_root: Node2D = get_node_or_null(map_root_path) as Node2D
@onready var sortables: Node2D = get_node_or_null(sortables_path) as Node2D
@onready var player: Node = get_node_or_null(player_path)
@onready var loading_overlay: Node = get_node_or_null(loading_overlay_path)

var _active_map_scene_path: String = ""
var _active_map_root_nodes: Array[Node] = []
var _active_map_sortable_nodes: Array[Node] = []
var _map_session_state_by_path: Dictionary = {}
var _transition_in_progress: bool = false
var _transition_sfx_player: AudioStreamPlayer = null


func _ready() -> void:
	add_to_group("map_transition_manager")
	_ensure_transition_sfx_player()


func set_default_map_scene_path(value: String) -> void:
	default_map_scene_path = value.strip_edges()


func get_current_map_scene_path() -> String:
	return _active_map_scene_path


func is_transition_in_progress() -> bool:
	return _transition_in_progress


func export_save_data() -> Dictionary:
	return {
		"current_map_scene": _active_map_scene_path,
	}


func import_save_data(save_data: Dictionary) -> void:
	var target_map_scene_path: String = String(save_data.get("current_map_scene", "")).strip_edges()
	if target_map_scene_path.is_empty():
		return
	if _active_map_scene_path == target_map_scene_path:
		return
	_load_map_scene(target_map_scene_path)


func prepare_world_before_restore(save_data: Dictionary) -> void:
	var target_map_scene_path: String = _extract_target_map_scene_path_from_save(save_data)
	if target_map_scene_path.is_empty():
		target_map_scene_path = default_map_scene_path.strip_edges()
	_load_map_scene(target_map_scene_path)


func request_transition(target_map_scene_path: String, target_spawn_id: String = "", transition_name: String = "", log_text: String = "") -> void:
	request_transition_request({
		"target_map_scene_path": target_map_scene_path,
		"target_spawn_id": target_spawn_id,
		"transition_name": transition_name,
		"log_text": log_text,
	})


func request_transition_request(request: Dictionary) -> void:
	if _transition_in_progress:
		return

	var normalized_scene_path: String = String(request.get("target_map_scene_path", request.get("scene_path", request.get("target_scene_path", "")))).strip_edges()
	if normalized_scene_path.is_empty():
		push_warning("MapTransitionManager: target_map_scene_path が未設定です")
		return

	var normalized_request: Dictionary = {
		"target_map_scene_path": normalized_scene_path,
		"target_spawn_id": String(request.get("target_spawn_id", request.get("spawn_id", ""))).strip_edges(),
		"transition_name": String(request.get("transition_name", request.get("name", ""))),
		"log_text": String(request.get("log_text", request.get("message_text", request.get("log", "")))),
		"use_fade_transition": _as_bool(request.get("use_fade_transition", use_fade_transition), use_fade_transition),
		"fade_out_duration": max(float(request.get("fade_out_duration", fade_out_duration)), 0.0),
		"fade_in_duration": max(float(request.get("fade_in_duration", fade_in_duration)), 0.0),
		"transition_hold_duration": max(float(request.get("transition_hold_duration", transition_hold_duration)), 0.0),
		"post_spawn_fade_in_delay": max(float(request.get("post_spawn_fade_in_delay", post_spawn_fade_in_delay)), 0.0),
		"transition_black_alpha": clamp(float(request.get("transition_black_alpha", transition_black_alpha)), 0.0, 1.0),
		"transition_sfx": request.get("transition_sfx", default_transition_sfx),
		"transition_sfx_path": String(request.get("transition_sfx_path", "")).strip_edges(),
		"transition_sfx_bus": StringName(String(request.get("transition_sfx_bus", String(transition_sfx_bus)))),
	}

	call_deferred("_perform_map_transition", normalized_request)


func _perform_map_transition(request: Dictionary) -> void:
	var target_map_scene_path: String = String(request.get("target_map_scene_path", "")).strip_edges()
	if target_map_scene_path.is_empty():
		return

	_transition_in_progress = true
	emit_signal("transition_started", request)

	_set_player_input_locked(true)

	var should_fade: bool = _as_bool(request.get("use_fade_transition", use_fade_transition), use_fade_transition)
	var fade_out_time: float = max(float(request.get("fade_out_duration", fade_out_duration)), 0.0)
	var fade_in_time: float = max(float(request.get("fade_in_duration", fade_in_duration)), 0.0)
	var hold_time: float = max(float(request.get("transition_hold_duration", transition_hold_duration)), 0.0)
	var black_alpha: float = clamp(float(request.get("transition_black_alpha", transition_black_alpha)), 0.0, 1.0)
	var post_spawn_delay: float = max(float(request.get("post_spawn_fade_in_delay", post_spawn_fade_in_delay)), 0.0)

	_play_transition_sfx(request)

	if should_fade and loading_overlay != null and loading_overlay.has_method("fade_out_to_black"):
		await loading_overlay.call("fade_out_to_black", fade_out_time, black_alpha)
		if hold_time > 0.0:
			await get_tree().create_timer(hold_time).timeout
	else:
		_open_loading_overlay("移動中…", 0)
		await get_tree().process_frame

	var loaded: bool = _load_map_scene(target_map_scene_path)
	await get_tree().process_frame

	if loaded:
		var target_spawn_id: String = String(request.get("target_spawn_id", "")).strip_edges()
		if not target_spawn_id.is_empty():
			_apply_spawn_by_id(target_spawn_id)

		var log_text: String = String(request.get("log_text", ""))
		var transition_name: String = String(request.get("transition_name", ""))
		if not log_text.is_empty():
			_write_log(log_text)
		elif not transition_name.is_empty():
			_write_log("%sへ移動した" % transition_name)
	else:
		push_warning("MapTransitionManager: マップ切替に失敗しました: %s" % target_map_scene_path)

	if loaded and should_fade:
		await _wait_after_spawn_before_fade_in(post_spawn_delay)

	if should_fade and loading_overlay != null and loading_overlay.has_method("fade_in_from_black"):
		await loading_overlay.call("fade_in_from_black", fade_in_time)
	else:
		_close_loading_overlay()

	_set_player_input_locked(false)

	_transition_in_progress = false
	if loaded:
		emit_signal("transition_finished", request)


func _ensure_transition_sfx_player() -> void:
	if _transition_sfx_player != null and is_instance_valid(_transition_sfx_player):
		return

	_transition_sfx_player = get_node_or_null("TransitionSfxPlayer") as AudioStreamPlayer
	if _transition_sfx_player != null:
		return

	var player_node := AudioStreamPlayer.new()
	player_node.name = "TransitionSfxPlayer"
	player_node.bus = transition_sfx_bus
	add_child(player_node)
	_transition_sfx_player = player_node


func _play_transition_sfx(request: Dictionary) -> void:
	var stream: AudioStream = _resolve_transition_sfx_from_request(request)
	if stream == null:
		return

	_ensure_transition_sfx_player()
	if _transition_sfx_player == null:
		return

	var bus_name: StringName = StringName(String(request.get("transition_sfx_bus", String(transition_sfx_bus))))
	_transition_sfx_player.bus = bus_name
	_transition_sfx_player.stream = stream
	_transition_sfx_player.play()


func _resolve_transition_sfx_from_request(request: Dictionary) -> AudioStream:
	var path_text: String = String(request.get("transition_sfx_path", "")).strip_edges()
	if not path_text.is_empty() and ResourceLoader.exists(path_text):
		var loaded_stream: AudioStream = load(path_text) as AudioStream
		if loaded_stream != null:
			return loaded_stream

	var direct_stream: AudioStream = request.get("transition_sfx", default_transition_sfx) as AudioStream
	if direct_stream != null:
		return direct_stream

	return default_transition_sfx


func _instantiate_map_fragment(target_map_scene_path: String) -> Node:
	var normalized_target_map_scene_path: String = target_map_scene_path.strip_edges()
	if normalized_target_map_scene_path.is_empty():
		push_warning("MapTransitionManager: target_map_scene_path が未設定です")
		return null
	if not ResourceLoader.exists(normalized_target_map_scene_path):
		push_warning("MapTransitionManager: マップシーンが見つかりません: %s" % normalized_target_map_scene_path)
		return null

	var packed_scene: PackedScene = load(normalized_target_map_scene_path) as PackedScene
	if packed_scene == null:
		push_warning("MapTransitionManager: PackedScene を読み込めません: %s" % normalized_target_map_scene_path)
		return null

	var map_fragment: Node = packed_scene.instantiate()
	if map_fragment == null:
		push_warning("MapTransitionManager: マップシーンを生成できません: %s" % normalized_target_map_scene_path)
		return null

	return map_fragment


func _load_map_scene(target_map_scene_path: String) -> bool:
	var normalized_target_map_scene_path: String = target_map_scene_path.strip_edges()
	if normalized_target_map_scene_path.is_empty():
		push_warning("MapTransitionManager: target_map_scene_path が未設定です")
		return false

	if map_root == null or sortables == null:
		push_warning("MapTransitionManager: MapRoot / Sortables の参照解決に失敗しました")
		return false

	var map_fragment: Node = _instantiate_map_fragment(normalized_target_map_scene_path)
	if map_fragment == null:
		emit_signal("map_load_failed", normalized_target_map_scene_path)
		return false

	_cache_active_map_session_state()
	_clear_active_map_nodes()

	var fragment_children: Array = map_fragment.get_children()
	for child_obj in fragment_children:
		var child: Node = child_obj as Node
		if child == null:
			continue

		map_fragment.remove_child(child)

		if child.name == "Sortables":
			var sortable_children: Array = child.get_children()
			for sortable_child_obj in sortable_children:
				var sortable_child: Node = sortable_child_obj as Node
				if sortable_child == null:
					continue
				child.remove_child(sortable_child)
				_clear_owner_recursive(sortable_child)
				sortables.add_child(sortable_child)
				_active_map_sortable_nodes.append(sortable_child)
			child.queue_free()
		else:
			_clear_owner_recursive(child)
			map_root.add_child(child)
			_active_map_root_nodes.append(child)

	map_fragment.queue_free()
	_active_map_scene_path = normalized_target_map_scene_path
	_apply_cached_state_to_active_map()
	emit_signal("map_loaded", normalized_target_map_scene_path)
	return true


func _clear_owner_recursive(node: Node) -> void:
	if node == null:
		return

	node.owner = null
	for child_obj in node.get_children():
		var child: Node = child_obj as Node
		if child != null:
			_clear_owner_recursive(child)


func _cache_active_map_session_state() -> void:
	if _active_map_scene_path.is_empty():
		return

	var persistent_nodes: Dictionary = {}
	for node_obj in get_tree().get_nodes_in_group("save_persistent"):
		var node: Node = node_obj as Node
		if node == null:
			continue
		if not _is_node_belonging_to_active_map(node):
			continue
		if not node.has_method("export_save_data"):
			continue

		var persistent_id: String = _get_persistent_id(node)
		if persistent_id.is_empty():
			continue

		var export_data: Variant = node.call("export_save_data")
		if typeof(export_data) != TYPE_DICTIONARY:
			continue

		persistent_nodes[persistent_id] = export_data

	_map_session_state_by_path[_active_map_scene_path] = {
		"persistent_nodes": persistent_nodes,
	}


func _apply_cached_state_to_active_map() -> void:
	if _active_map_scene_path.is_empty():
		return
	if not _map_session_state_by_path.has(_active_map_scene_path):
		return

	var state: Dictionary = _map_session_state_by_path.get(_active_map_scene_path, {}) as Dictionary
	var persistent_nodes: Dictionary = state.get("persistent_nodes", {}) as Dictionary
	if persistent_nodes.is_empty():
		return

	for node_obj in get_tree().get_nodes_in_group("save_persistent"):
		var node: Node = node_obj as Node
		if node == null:
			continue
		if not _is_node_belonging_to_active_map(node):
			continue
		if not node.has_method("import_save_data"):
			continue

		var persistent_id: String = _get_persistent_id(node)
		if persistent_id.is_empty() or not persistent_nodes.has(persistent_id):
			continue

		node.call("import_save_data", persistent_nodes[persistent_id])


func _clear_active_map_nodes() -> void:
	for node in _active_map_root_nodes:
		if is_instance_valid(node):
			node.queue_free()
	for node in _active_map_sortable_nodes:
		if is_instance_valid(node):
			node.queue_free()

	_active_map_root_nodes.clear()
	_active_map_sortable_nodes.clear()
	_active_map_scene_path = ""


func _apply_spawn_by_id(spawn_id: String) -> void:
	var normalized_spawn_id: String = spawn_id.strip_edges()
	if normalized_spawn_id.is_empty():
		return

	var spawn_point: Node2D = _find_scene_spawn_point(normalized_spawn_id)
	var player_node: Node2D = player as Node2D
	if spawn_point == null or player_node == null:
		return

	player_node.global_position = spawn_point.global_position


func _find_scene_spawn_point(spawn_id: String) -> Node2D:
	for node_obj in get_tree().get_nodes_in_group("scene_spawn_point"):
		var node: Node = node_obj as Node
		if node == null:
			continue
		if not _is_node_belonging_to_active_map(node):
			continue

		var node_spawn_id: String = ""
		if node.has_method("get_spawn_id"):
			node_spawn_id = String(node.call("get_spawn_id")).strip_edges()
		else:
			node_spawn_id = String(node.get("spawn_id")).strip_edges()

		if node_spawn_id == spawn_id and node is Node2D:
			return node as Node2D

	return null


func _extract_target_map_scene_path_from_save(save_data: Dictionary) -> String:
	var world_data: Dictionary = save_data.get("world", {}) as Dictionary
	var root_data: Dictionary = world_data.get("scene_root", {}) as Dictionary
	return String(root_data.get("current_map_scene", "")).strip_edges()


func _is_node_belonging_to_active_map(node: Node) -> bool:
	for root_node in _active_map_root_nodes:
		if is_instance_valid(root_node) and _is_descendant_of(root_node, node):
			return true
	for sortable_node in _active_map_sortable_nodes:
		if is_instance_valid(sortable_node) and _is_descendant_of(sortable_node, node):
			return true
	return false


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


func _wait_after_spawn_before_fade_in(delay: float) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout


func _get_persistent_id(node: Node) -> String:
	if node.has_method("get_persistent_save_id"):
		return String(node.call("get_persistent_save_id")).strip_edges()
	var value: Variant = node.get("persistent_id")
	if typeof(value) == TYPE_STRING:
		return String(value).strip_edges()
	return ""


func _is_descendant_of(root: Node, candidate: Node) -> bool:
	if root == null or candidate == null:
		return false

	var current: Node = candidate
	while current != null:
		if current == root:
			return true
		current = current.get_parent()
	return false


func _write_log(text: String) -> void:
	if text.is_empty():
		return
	var log_node: Node = get_node_or_null("/root/MessageLog")
	if log_node == null:
		return

	if log_node.has_method("add_system"):
		log_node.call("add_system", text)
	elif log_node.has_method("add_message"):
		log_node.call("add_message", text, "SYSTEM")


func _as_bool(value: Variant, default_value: bool) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			return value != 0
		TYPE_FLOAT:
			return not is_zero_approx(value)
		TYPE_STRING, TYPE_STRING_NAME:
			var text: String = String(value).strip_edges().to_lower()
			if text in ["true", "1", "yes", "on"]:
				return true
			if text in ["false", "0", "no", "off", ""]:
				return false
	return default_value

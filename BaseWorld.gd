extends Node2D
class_name BaseWorld

const NETWORK_BOOT_MODE_DISABLED: String = "disabled"
const NETWORK_BOOT_MODE_HOST: String = "host"
const NETWORK_BOOT_MODE_CLIENT: String = "client"
const NETWORK_SESSION_MANAGER_SCRIPT_PATH: String = "res://Core/Network/NetworkSessionManager.gd"

@export_file("*.tscn") var default_map_scene_path: String = "res://Maps/TownMap_MainExtract.tscn"

@export_group("Network")
@export_enum("disabled", "host", "client") var network_boot_mode: String = NETWORK_BOOT_MODE_DISABLED
@export var network_host_port: int = 7000
@export var network_client_address: String = "127.0.0.1"
@export var network_client_port: int = 7000
@export var network_session_manager_root_path: NodePath = NodePath("/root/NetworkSessionManager")
@export var remote_player_spawn_offset: Vector2 = Vector2(40.0, 0.0)
@export var network_peer_sync_interval_sec: float = 0.25
@export var network_snapshot_send_interval_sec: float = 0.05

@onready var player: Node = get_node_or_null("Sortables/Player")
@onready var loading_overlay: Node = $UI/LoadingOverlay
@onready var inventory_ui: Node = $UI/InventoryUI
@onready var map_transition_manager: Node = get_node_or_null("MapTransitionManager")
@onready var sortables_root: Node = get_node_or_null("Sortables")

var _boot_started: bool = false
var _network_session_manager: Node = null
var _network_signals_connected: bool = false
var _network_players_root: Node2D = null
var _remote_players_by_peer_id: Dictionary = {}
var _remote_player_roots_by_peer_id: Dictionary = {}
var _local_player_spawn_source: Node = null
var _network_peer_sync_accumulator: float = 0.0
var _network_snapshot_send_accumulator: float = 0.0



func _resolve_local_player_actor() -> Node:
	if player != null and is_instance_valid(player) and player.has_method("configure_network_peer"):
		return player

	var direct_root: Node = get_node_or_null("Sortables/Player")
	if direct_root != null and is_instance_valid(direct_root):
		_local_player_spawn_source = direct_root
		if direct_root.has_method("configure_network_peer"):
			player = direct_root
			return player

		var nested_actor: Node = _find_first_network_player_node(direct_root)
		if nested_actor != null:
			player = nested_actor
			return player

	var sortables: Node = sortables_root
	if sortables == null:
		sortables = get_node_or_null("Sortables")

	if sortables != null and is_instance_valid(sortables):
		var found_actor: Node = _find_first_network_player_node(sortables)
		if found_actor != null:
			player = found_actor
			if _local_player_spawn_source == null:
				var actor_parent: Node = found_actor.get_parent()
				_local_player_spawn_source = actor_parent if actor_parent != null else found_actor
			return player

	return player


func _resolve_local_player_spawn_source() -> Node:
	if _local_player_spawn_source != null and is_instance_valid(_local_player_spawn_source):
		return _local_player_spawn_source

	var direct_root: Node = get_node_or_null("Sortables/Player")
	if direct_root != null and is_instance_valid(direct_root):
		_local_player_spawn_source = direct_root
		return _local_player_spawn_source

	var actor: Node = _resolve_local_player_actor()
	if actor != null and is_instance_valid(actor):
		var actor_parent: Node = actor.get_parent()
		_local_player_spawn_source = actor_parent if actor_parent != null else actor

	return _local_player_spawn_source


func _find_first_network_player_node(root: Node) -> Node:
	if root == null:
		return null

	for child in root.get_children():
		var node: Node = child as Node
		if node == null:
			continue
		if node.has_method("configure_network_peer"):
			return node
		var nested: Node = _find_first_network_player_node(node)
		if nested != null:
			return nested

	return null


func _find_network_player_actor_in_instance(root: Node) -> Node:
	if root == null:
		return null
	if root.has_method("configure_network_peer"):
		return root
	return _find_first_network_player_node(root)


func _ready() -> void:
	_resolve_local_player_actor()
	_resolve_local_player_spawn_source()
	_ensure_map_transition_manager()
	if map_transition_manager != null and map_transition_manager.has_method("set_default_map_scene_path"):
		map_transition_manager.call("set_default_map_scene_path", default_map_scene_path)
	if network_boot_mode != NETWORK_BOOT_MODE_DISABLED:
		_ensure_network_session_manager()
		_connect_network_session_signals()
	call_deferred("_boot_game")


func _process(delta: float) -> void:
	if network_boot_mode == NETWORK_BOOT_MODE_DISABLED:
		return

	if not _is_network_online():
		return

	_network_peer_sync_accumulator += maxf(delta, 0.0)
	if _network_peer_sync_accumulator >= maxf(network_peer_sync_interval_sec, 0.05):
		_network_peer_sync_accumulator = 0.0
		_sync_remote_network_players_from_session()

	_network_snapshot_send_accumulator += maxf(delta, 0.0)
	if _network_snapshot_send_accumulator >= maxf(network_snapshot_send_interval_sec, 0.01):
		_network_snapshot_send_accumulator = 0.0
		_send_local_player_snapshot_if_needed()


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


func get_network_session_manager() -> Node:
	_ensure_network_session_manager()
	return _network_session_manager


func request_map_transition(target_map_scene_path: String, target_spawn_id: String = "", transition_name: String = "", log_text: String = "") -> void:
	_ensure_map_transition_manager()
	if map_transition_manager != null and map_transition_manager.has_method("request_transition"):
		map_transition_manager.call("request_transition", target_map_scene_path, target_spawn_id, transition_name, log_text)


func start_network_host(port: int = -1) -> bool:
	_ensure_network_session_manager()
	_connect_network_session_signals()
	if _network_session_manager == null or not _network_session_manager.has_method("host_game"):
		return false

	var resolved_port: int = network_host_port if port <= 0 else port
	var result: Variant = _network_session_manager.call("host_game", resolved_port)
	return _variant_to_bool(result)


func start_network_client(address: String = "", port: int = -1) -> bool:
	_ensure_network_session_manager()
	_connect_network_session_signals()
	if _network_session_manager == null or not _network_session_manager.has_method("join_game"):
		return false

	var resolved_address: String = address.strip_edges()
	if resolved_address.is_empty():
		resolved_address = network_client_address.strip_edges()

	var resolved_port: int = network_client_port if port <= 0 else port
	var result: Variant = _network_session_manager.call("join_game", resolved_address, resolved_port)
	return _variant_to_bool(result)


func stop_network_session() -> void:
	_ensure_network_session_manager()
	if _network_session_manager != null and _network_session_manager.has_method("close_session"):
		_network_session_manager.call("close_session")
	_clear_remote_network_players()
	_configure_local_network_player()
	_network_peer_sync_accumulator = 0.0
	_network_snapshot_send_accumulator = 0.0


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
	_bootstrap_network_session_if_needed()
	_configure_local_network_player()
	_sync_remote_network_players_from_session()
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


func _ensure_network_session_manager() -> void:
	if _network_session_manager != null and is_instance_valid(_network_session_manager):
		return

	var by_root_path: Node = get_node_or_null(network_session_manager_root_path)
	if by_root_path != null and is_instance_valid(by_root_path):
		_network_session_manager = by_root_path
		return

	var root: Node = get_tree().root
	if root == null:
		return

	var by_name: Node = root.get_node_or_null("NetworkSessionManager")
	if by_name != null and is_instance_valid(by_name):
		_network_session_manager = by_name
		return

	if not ResourceLoader.exists(NETWORK_SESSION_MANAGER_SCRIPT_PATH):
		return

	var manager_script: Script = load(NETWORK_SESSION_MANAGER_SCRIPT_PATH) as Script
	if manager_script == null:
		push_warning("BaseWorld: NetworkSessionManager.gd を読み込めません")
		return

	var manager: Node = Node.new()
	manager.name = "NetworkSessionManager"
	manager.set_script(manager_script)
	root.add_child(manager)
	_network_session_manager = manager


func _connect_network_session_signals() -> void:
	if _network_signals_connected:
		return

	_ensure_network_session_manager()
	if _network_session_manager == null:
		return

	if _network_session_manager.has_signal("peer_joined"):
		_network_session_manager.peer_joined.connect(_on_network_peer_joined)
	if _network_session_manager.has_signal("peer_left"):
		_network_session_manager.peer_left.connect(_on_network_peer_left)
	if _network_session_manager.has_signal("connected_to_session"):
		_network_session_manager.connected_to_session.connect(_on_network_connected_to_session)
	if _network_session_manager.has_signal("disconnected_from_session"):
		_network_session_manager.disconnected_from_session.connect(_on_network_disconnected_from_session)
	if _network_session_manager.has_signal("local_peer_id_changed"):
		_network_session_manager.local_peer_id_changed.connect(_on_network_local_peer_id_changed)
	if _network_session_manager.has_signal("hosting_started"):
		_network_session_manager.hosting_started.connect(_on_network_hosting_started)

	_network_signals_connected = true


func _bootstrap_network_session_if_needed() -> void:
	if network_boot_mode == NETWORK_BOOT_MODE_DISABLED:
		return

	_ensure_network_session_manager()
	_connect_network_session_signals()
	if _network_session_manager == null:
		push_warning("BaseWorld: NetworkSessionManager が見つかりません")
		return

	if _network_session_manager.has_method("is_online"):
		var is_online_variant: Variant = _network_session_manager.call("is_online")
		if _variant_to_bool(is_online_variant):
			return

	var ok: bool = false
	match network_boot_mode:
		NETWORK_BOOT_MODE_HOST:
			ok = start_network_host()
		NETWORK_BOOT_MODE_CLIENT:
			ok = start_network_client()
		_:
			ok = false

	if not ok:
		push_warning("BaseWorld: ネットワークセッションの初期化に失敗しました")


func _ensure_network_players_root() -> void:
	if _network_players_root != null and is_instance_valid(_network_players_root):
		return

	var parent_node: Node = sortables_root
	if parent_node == null:
		parent_node = self

	var existing: Node = parent_node.get_node_or_null("NetworkPlayers")
	if existing is Node2D:
		_network_players_root = existing as Node2D
		return

	var root_node := Node2D.new()
	root_node.name = "NetworkPlayers"
	parent_node.add_child(root_node)
	_network_players_root = root_node


func _configure_local_network_player() -> void:
	var local_player_actor: Node = _resolve_local_player_actor()
	if local_player_actor == null:
		return

	var local_peer_id: int = _get_local_network_peer_id()
	if local_player_actor.has_method("configure_network_peer"):
		local_player_actor.call("configure_network_peer", local_peer_id, local_peer_id, local_peer_id, "Player %d" % max(local_peer_id, 1))
	if local_player_actor.has_method("set_network_local_player"):
		local_player_actor.call("set_network_local_player", true)
	if local_player_actor.has_method("set_network_authority_peer_id"):
		local_player_actor.call("set_network_authority_peer_id", max(local_peer_id, 1))


func _sync_remote_network_players_from_session() -> void:
	_ensure_network_session_manager()

	if _network_session_manager == null or not _is_network_online():
		_clear_remote_network_players()
		return

	var local_peer_id: int = _get_local_network_peer_id()
	var desired_peer_ids: Dictionary = {}

	if _network_session_manager.has_method("get_remote_peer_ids"):
		var peers_variant: Variant = _network_session_manager.call("get_remote_peer_ids")
		var peers: PackedInt32Array = PackedInt32Array()
		if peers_variant is PackedInt32Array:
			peers = peers_variant as PackedInt32Array

		for peer_id in peers:
			if peer_id <= 0 or peer_id == local_peer_id:
				continue
			desired_peer_ids[peer_id] = true
			_spawn_remote_network_player_for_peer(peer_id)

	var existing_peer_ids: Array = _remote_players_by_peer_id.keys()
	for peer_id_variant in existing_peer_ids:
		var peer_id: int = int(peer_id_variant)
		if not desired_peer_ids.has(peer_id):
			_remove_remote_network_player(peer_id)


func _spawn_remote_network_player_for_peer(peer_id: int) -> Node:
	if peer_id <= 0:
		return null

	var local_peer_id: int = _get_local_network_peer_id()
	if peer_id == local_peer_id:
		return _resolve_local_player_actor()

	var existing: Node = _remote_players_by_peer_id.get(peer_id, null) as Node
	if existing != null and is_instance_valid(existing):
		return existing

	var local_spawn_source: Node = _resolve_local_player_spawn_source()
	if local_spawn_source == null:
		return null

	_ensure_network_players_root()

	var remote_root: Node = _instantiate_network_player_clone()
	if remote_root == null:
		return null

	remote_root.name = "RemotePlayer_%d" % peer_id

	var remote_actor: Node = _find_network_player_actor_in_instance(remote_root)
	if remote_actor == null:
		remote_root.queue_free()
		return null

	if remote_actor.has_method("configure_network_peer"):
		remote_actor.call("configure_network_peer", local_peer_id, peer_id, peer_id, "Peer %d" % peer_id)
	if remote_actor.has_method("set_network_local_player"):
		remote_actor.call("set_network_local_player", false)
	if remote_actor.has_method("set_network_authority_peer_id"):
		remote_actor.call("set_network_authority_peer_id", peer_id)

	_network_players_root.add_child(remote_root)

	if remote_root is Node2D:
		var remote_root_2d: Node2D = remote_root as Node2D
		var spawn_position: Vector2 = _get_remote_network_spawn_position(peer_id)
		remote_root_2d.global_position = spawn_position

		if local_spawn_source is Node2D:
			var local_source_2d: Node2D = local_spawn_source as Node2D
			remote_root_2d.scale = local_source_2d.scale
			remote_root_2d.rotation = local_source_2d.rotation

	remote_root.remove_from_group("player")
	remote_root.add_to_group("remote_player")
	remote_actor.remove_from_group("player")
	remote_actor.add_to_group("remote_player")

	_remote_player_roots_by_peer_id[peer_id] = remote_root
	_remote_players_by_peer_id[peer_id] = remote_actor
	return remote_actor


func _instantiate_network_player_clone() -> Node:
	var local_spawn_source: Node = _resolve_local_player_spawn_source()
	if local_spawn_source == null:
		return null

	if local_spawn_source.scene_file_path != "" and ResourceLoader.exists(local_spawn_source.scene_file_path):
		var packed_scene: PackedScene = load(local_spawn_source.scene_file_path) as PackedScene
		if packed_scene != null:
			var instance: Node = packed_scene.instantiate()
			if instance != null:
				return instance

	return local_spawn_source.duplicate()


func _get_remote_network_spawn_position(peer_id: int) -> Vector2:
	var local_spawn_source: Node = _resolve_local_player_spawn_source()
	if not local_spawn_source is Node2D:
		var local_player_actor: Node = _resolve_local_player_actor()
		if not local_player_actor is Node2D:
			return Vector2.ZERO
		local_spawn_source = local_player_actor

	var local_player_2d: Node2D = local_spawn_source as Node2D

	var peer_ids: Array[int] = []
	for key in _remote_players_by_peer_id.keys():
		peer_ids.append(int(key))

	if not peer_ids.has(peer_id):
		peer_ids.append(peer_id)

	peer_ids.sort()

	var slot_index: int = peer_ids.find(peer_id) + 1
	if slot_index <= 0:
		slot_index = 1

	return local_player_2d.global_position + (remote_player_spawn_offset * float(slot_index))


func _remove_remote_network_player(peer_id: int) -> void:
	var remote_root: Node = _remote_player_roots_by_peer_id.get(peer_id, null) as Node
	var remote_player: Node = _remote_players_by_peer_id.get(peer_id, null) as Node
	_remote_player_roots_by_peer_id.erase(peer_id)
	_remote_players_by_peer_id.erase(peer_id)

	if remote_root != null and is_instance_valid(remote_root):
		remote_root.queue_free()
		return

	if remote_player != null and is_instance_valid(remote_player):
		remote_player.queue_free()


func _clear_remote_network_players() -> void:
	var peer_ids: Array = _remote_players_by_peer_id.keys()
	for peer_id_variant in peer_ids:
		_remove_remote_network_player(int(peer_id_variant))
	_remote_players_by_peer_id.clear()


func _is_network_online() -> bool:
	if _network_session_manager == null or not _network_session_manager.has_method("is_online"):
		return false
	return _variant_to_bool(_network_session_manager.call("is_online"))


func _get_local_network_peer_id() -> int:
	if _network_session_manager == null or not _network_session_manager.has_method("get_local_peer_id"):
		return 1
	return max(int(_network_session_manager.call("get_local_peer_id")), 1)


func _send_local_player_snapshot_if_needed() -> void:
	var local_player_actor: Node = _resolve_local_player_actor()
	if local_player_actor == null:
		return
	if not _is_network_online():
		return
	if not local_player_actor.has_method("get_network_snapshot_payload"):
		return

	var peers_variant: Variant = PackedInt32Array()
	if _network_session_manager != null and _network_session_manager.has_method("get_remote_peer_ids"):
		peers_variant = _network_session_manager.call("get_remote_peer_ids")

	if peers_variant is PackedInt32Array and (peers_variant as PackedInt32Array).is_empty():
		return

	var payload_variant: Variant = local_player_actor.call("get_network_snapshot_payload")
	if typeof(payload_variant) != TYPE_DICTIONARY:
		return

	var payload: Dictionary = payload_variant as Dictionary
	if payload.is_empty():
		return

	rpc("_rpc_receive_player_snapshot", payload)


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_receive_player_snapshot(payload: Dictionary) -> void:
	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if sender_peer_id <= 0:
		sender_peer_id = int(payload.get("peer_id", 0))

	if sender_peer_id <= 0:
		return

	if sender_peer_id == _get_local_network_peer_id():
		return

	var remote_player: Node = _spawn_remote_network_player_for_peer(sender_peer_id)
	if remote_player == null:
		return

	if remote_player.has_method("apply_remote_network_snapshot"):
		remote_player.call("apply_remote_network_snapshot", payload)


func _on_network_peer_joined(peer_id: int) -> void:
	_spawn_remote_network_player_for_peer(peer_id)


func _on_network_peer_left(peer_id: int) -> void:
	_remove_remote_network_player(peer_id)


func _on_network_connected_to_session() -> void:
	_configure_local_network_player()
	_sync_remote_network_players_from_session()


func _on_network_disconnected_from_session() -> void:
	_clear_remote_network_players()
	_configure_local_network_player()


func _on_network_local_peer_id_changed(_peer_id: int) -> void:
	_configure_local_network_player()
	_sync_remote_network_players_from_session()


func _on_network_hosting_started(_port: int, _max_clients: int) -> void:
	_configure_local_network_player()
	_sync_remote_network_players_from_session()


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
	var local_player_actor: Node = _resolve_local_player_actor()
	if local_player_actor != null and local_player_actor.has_method("set_input_locked"):
		local_player_actor.call("set_input_locked", value)


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


func _variant_to_bool(value: Variant) -> bool:
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
	return false

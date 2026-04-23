extends Node2D
class_name BaseWorld

const NETWORK_BOOT_MODE_DISABLED: String = "disabled"
const NETWORK_BOOT_MODE_HOST: String = "host"
const NETWORK_BOOT_MODE_CLIENT: String = "client"
const NETWORK_SESSION_MANAGER_SCRIPT_PATH: String = "res://Core/Network/NetworkSessionManager.gd"
const NETWORK_HELPER_SCRIPT_PATH: String = "res://Core/Network/BaseWorldNetworkHelper.gd"
const WORLD_TIME_SYNC_MODULE_SCRIPT_PATH: String = "res://Core/World/BaseWorldTimeSyncModule.gd"
const WORLD_INTERACTION_MODULE_SCRIPT_PATH: String = "res://Core/World/BaseWorldInteractionModule.gd"
const WORLD_PLAYER_REGISTRY_SCRIPT_PATH: String = "res://Core/World/BaseWorldPlayerRegistry.gd"
const WORLD_INVENTORY_SYNC_MODULE_SCRIPT_PATH: String = "res://Core/World/BaseWorldInventorySyncModule.gd"
const WORLD_SHARED_CREDITS_MODULE_SCRIPT_PATH: String = "res://Core/World/BaseWorldSharedCreditsModule.gd"

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
@export var network_time_sync_interval_sec: float = 0.25

@export_group("Local Player Identity")
@export var host_player_display_name: String = "Host"
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var host_front_texture_path: String = ""
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var host_back_texture_path: String = ""
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var host_side_texture_path: String = ""
@export var client_player_display_name: String = "Client"
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var client_front_texture_path: String = ""
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var client_back_texture_path: String = ""
@export_file("*.png", "*.jpg", "*.jpeg", "*.webp") var client_side_texture_path: String = ""

@onready var player: Node = get_node_or_null("Sortables/Player")
@onready var loading_overlay: Node = $UI/LoadingOverlay
@onready var inventory_ui: Node = $UI/InventoryUI
@onready var map_transition_manager: Node = get_node_or_null("MapTransitionManager")
@onready var sortables_root: Node = get_node_or_null("Sortables")

var _boot_started: bool = false
var _network_session_manager: Node = null
var _network_signals_connected: bool = false
var _network_peer_sync_accumulator: float = 0.0
var _network_snapshot_send_accumulator: float = 0.0
var _network_helper: BaseWorldNetworkHelper = null
var _time_sync_module: BaseWorldTimeSyncModule = null
var _interaction_module: BaseWorldInteractionModule = null
var _player_registry: BaseWorldPlayerRegistry = null
var _inventory_sync_module: BaseWorldInventorySyncModule = null
var _shared_credits_module: BaseWorldSharedCreditsModule = null


func _ready() -> void:
	_ensure_player_registry()
	_register_local_player_if_possible()
	_ensure_network_helper()
	_ensure_time_sync_module()
	_ensure_interaction_module()
	_ensure_inventory_sync_module()
	_ensure_shared_credits_module()
	_ensure_map_transition_manager()
	_connect_shared_credits_signal()
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
		if _network_helper != null:
			_network_helper.sync_remote_network_players_from_session()

	_network_snapshot_send_accumulator += maxf(delta, 0.0)
	if _network_snapshot_send_accumulator >= maxf(network_snapshot_send_interval_sec, 0.01):
		_network_snapshot_send_accumulator = 0.0
		if _network_helper != null:
			_network_helper.send_local_player_snapshot_if_needed()

	if _time_sync_module != null:
		_time_sync_module.process(delta)


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


func get_player_registry() -> BaseWorldPlayerRegistry:
	_ensure_player_registry()
	return _player_registry


func get_local_player() -> Node:
	_ensure_player_registry()
	if _player_registry != null:
		var local_player: Node = _player_registry.get_local_player()
		if local_player != null:
			return local_player
	return player


func get_player_by_peer_id(peer_id: int) -> Node:
	_ensure_player_registry()
	if _player_registry == null:
		return null
	return _player_registry.get_player_by_peer_id(peer_id)


func request_map_transition(target_map_scene_path: String, target_spawn_id: String = "", transition_name: String = "", log_text: String = "") -> void:
	_ensure_map_transition_manager()
	if map_transition_manager != null and map_transition_manager.has_method("request_transition"):
		map_transition_manager.call("request_transition", target_map_scene_path, target_spawn_id, transition_name, log_text)


func request_networked_map_transition(request: Dictionary) -> void:
	var normalized_request: Dictionary = _normalize_map_transition_request(request)
	if normalized_request.is_empty():
		return

	if not _is_network_online():
		_apply_map_transition_request_local(normalized_request)
		return

	_ensure_network_session_manager()
	if _can_accept_network_gameplay_requests():
		_apply_map_transition_request_local(normalized_request)
		rpc("_rpc_apply_map_transition_request", normalized_request)
		return

	rpc_id(1, "_rpc_request_map_transition", normalized_request)


func request_networked_world_interaction(request: Dictionary) -> void:
	var normalized_request: Dictionary = _normalize_world_interaction_request(request)
	if normalized_request.is_empty():
		return

	if not _is_network_online():
		_apply_world_interaction_request_local(normalized_request, _get_local_network_peer_id())
		return

	_ensure_network_session_manager()
	if _can_accept_network_gameplay_requests():
		_apply_world_interaction_request_local(normalized_request, _get_local_network_peer_id())
		return

	rpc_id(1, "_rpc_request_world_interaction", normalized_request)


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
	if _network_helper != null:
		_network_helper.clear_remote_network_players()
		_network_helper.configure_local_network_player()
	_apply_local_player_identity_preset()
	_bind_local_inventory_ui()
	_network_peer_sync_accumulator = 0.0
	_network_snapshot_send_accumulator = 0.0


func _boot_game() -> void:
	if _boot_started:
		return
	_boot_started = true

	_ensure_player_registry()
	_register_local_player_if_possible()
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
	if _network_helper != null:
		_network_helper.configure_local_network_player()
	_apply_local_player_identity_preset()
	_bind_local_inventory_ui()
	if _network_helper != null:
		_network_helper.sync_remote_network_players_from_session()
		_network_helper.send_local_player_snapshot_now()
	_resume_time_manager()
	_set_player_input_locked(false)


func _ensure_player_registry() -> void:
	if _player_registry != null:
		return
	if not ResourceLoader.exists(WORLD_PLAYER_REGISTRY_SCRIPT_PATH):
		return

	var registry_script: Script = load(WORLD_PLAYER_REGISTRY_SCRIPT_PATH) as Script
	if registry_script == null:
		push_warning("BaseWorld: BaseWorldPlayerRegistry.gd を読み込めません")
		return

	var registry_instance: Variant = registry_script.new()
	if registry_instance is BaseWorldPlayerRegistry:
		_player_registry = registry_instance as BaseWorldPlayerRegistry
		_player_registry.setup(self)


func _register_local_player_if_possible() -> void:
	_ensure_player_registry()
	if _player_registry == null:
		return
	if player == null or not is_instance_valid(player):
		return
	_player_registry.register_local_player(player)


func _bind_local_inventory_ui() -> void:
	_ensure_inventory_sync_module()
	if _inventory_sync_module != null:
		_inventory_sync_module.bind_inventory_ui_to_local_player()
		return
	if inventory_ui == null or not is_instance_valid(inventory_ui):
		return
	if not inventory_ui.has_method("bind_player"):
		return
	var local_player: Node = get_local_player()
	if local_player == null or not is_instance_valid(local_player):
		return
	inventory_ui.call("bind_player", local_player)


func _get_inventory_save_data_for_player(player_id: int) -> Dictionary:
	if inventory_ui == null or not is_instance_valid(inventory_ui):
		return {}
	if not inventory_ui.has_method("get_player_inventory_save_data"):
		return {}
	var exported: Variant = inventory_ui.call("get_player_inventory_save_data", player_id)
	if typeof(exported) == TYPE_DICTIONARY:
		return exported as Dictionary
	return {}


func _apply_player_inventory_state_local(player_id: int, inventory_save_data: Dictionary) -> void:
	if inventory_ui == null or not is_instance_valid(inventory_ui):
		return
	if not inventory_ui.has_method("apply_player_inventory_save_data"):
		return
	inventory_ui.call("apply_player_inventory_save_data", player_id, inventory_save_data, true, false)


func request_networked_player_inventory_sync(player_id: int, inventory_save_data: Dictionary) -> void:
	_ensure_inventory_sync_module()
	if _inventory_sync_module != null:
		_inventory_sync_module.request_player_inventory_sync(player_id, inventory_save_data)
		return
	var resolved_player_id: int = max(player_id, 1)
	var normalized_inventory: Dictionary = inventory_save_data.duplicate(true)
	if not _is_network_online():
		_apply_player_inventory_state_local(resolved_player_id, normalized_inventory)
		return
	if _can_accept_network_gameplay_requests():
		_apply_player_inventory_state_local(resolved_player_id, normalized_inventory)
		return
	rpc_id(1, "_rpc_request_player_inventory_sync", resolved_player_id, normalized_inventory)


func request_saved_player_inventory_sync() -> void:
	_ensure_inventory_sync_module()
	if _inventory_sync_module != null:
		_inventory_sync_module.request_saved_inventory_from_authority_if_needed()
		return
	if not _is_network_online():
		return
	if _can_accept_network_gameplay_requests():
		var local_player: Node = get_local_player()
		if local_player == null or not is_instance_valid(local_player):
			return
		if not local_player.has_method("get_player_id"):
			return
		var host_player_id: int = max(int(local_player.call("get_player_id")), 1)
		_apply_player_inventory_state_local(host_player_id, _get_inventory_save_data_for_player(host_player_id))
		return
	rpc_id(1, "_rpc_request_saved_player_inventory_sync")


func _apply_local_player_identity_preset() -> void:
	var local_player: Node = get_local_player()
	if local_player == null or not is_instance_valid(local_player):
		return

	var payload: Dictionary = _build_local_player_identity_payload()
	if payload.is_empty():
		return

	if local_player.has_method("apply_peer_identity_payload"):
		local_player.call("apply_peer_identity_payload", payload)
	elif local_player.has_method("set_player_display_name") and payload.has("display_name"):
		local_player.call("set_player_display_name", String(payload.get("display_name", "")))


func _build_local_player_identity_payload() -> Dictionary:
	var use_client_preset: bool = network_boot_mode == NETWORK_BOOT_MODE_CLIENT

	var display_name: String = client_player_display_name.strip_edges() if use_client_preset else host_player_display_name.strip_edges()
	var front_path: String = client_front_texture_path.strip_edges() if use_client_preset else host_front_texture_path.strip_edges()
	var back_path: String = client_back_texture_path.strip_edges() if use_client_preset else host_back_texture_path.strip_edges()
	var side_path: String = client_side_texture_path.strip_edges() if use_client_preset else host_side_texture_path.strip_edges()

	var payload: Dictionary = {}
	if not display_name.is_empty():
		payload["display_name"] = display_name
	if not front_path.is_empty():
		payload["appearance_front_texture_path"] = front_path
	if not back_path.is_empty():
		payload["appearance_back_texture_path"] = back_path
	if not side_path.is_empty():
		payload["appearance_side_texture_path"] = side_path

	return payload


func _ensure_network_helper() -> void:
	if _network_helper != null:
		return
	if not ResourceLoader.exists(NETWORK_HELPER_SCRIPT_PATH):
		return

	var helper_script: Script = load(NETWORK_HELPER_SCRIPT_PATH) as Script
	if helper_script == null:
		push_warning("BaseWorld: BaseWorldNetworkHelper.gd を読み込めません")
		return

	var helper_instance: Variant = helper_script.new()
	if helper_instance is BaseWorldNetworkHelper:
		_network_helper = helper_instance as BaseWorldNetworkHelper
		_network_helper.setup(self)


func _ensure_time_sync_module() -> void:
	if _time_sync_module != null:
		return
	if not ResourceLoader.exists(WORLD_TIME_SYNC_MODULE_SCRIPT_PATH):
		return

	var module_script: Script = load(WORLD_TIME_SYNC_MODULE_SCRIPT_PATH) as Script
	if module_script == null:
		push_warning("BaseWorld: BaseWorldTimeSyncModule.gd を読み込めません")
		return

	var module_instance: Variant = module_script.new()
	if module_instance is BaseWorldTimeSyncModule:
		_time_sync_module = module_instance as BaseWorldTimeSyncModule
		_time_sync_module.setup(self)


func _ensure_interaction_module() -> void:
	if _interaction_module != null:
		return
	if not ResourceLoader.exists(WORLD_INTERACTION_MODULE_SCRIPT_PATH):
		return

	var module_script: Script = load(WORLD_INTERACTION_MODULE_SCRIPT_PATH) as Script
	if module_script == null:
		push_warning("BaseWorld: BaseWorldInteractionModule.gd を読み込めません")
		return

	var module_instance: Variant = module_script.new()
	if module_instance is BaseWorldInteractionModule:
		_interaction_module = module_instance as BaseWorldInteractionModule
		_interaction_module.setup(self)


func _ensure_inventory_sync_module() -> void:
	if _inventory_sync_module != null:
		return
	if not ResourceLoader.exists(WORLD_INVENTORY_SYNC_MODULE_SCRIPT_PATH):
		return

	var module_script: Script = load(WORLD_INVENTORY_SYNC_MODULE_SCRIPT_PATH) as Script
	if module_script == null:
		push_warning("BaseWorld: BaseWorldInventorySyncModule.gd を読み込めません")
		return

	var module_instance: Variant = module_script.new()
	if module_instance is BaseWorldInventorySyncModule:
		_inventory_sync_module = module_instance as BaseWorldInventorySyncModule
		_inventory_sync_module.setup(self)


func _ensure_shared_credits_module() -> void:
	if _shared_credits_module != null:
		return
	if not ResourceLoader.exists(WORLD_SHARED_CREDITS_MODULE_SCRIPT_PATH):
		return

	var module_script: Script = load(WORLD_SHARED_CREDITS_MODULE_SCRIPT_PATH) as Script
	if module_script == null:
		push_warning("BaseWorld: BaseWorldSharedCreditsModule.gd を読み込めません")
		return

	var module_instance: Variant = module_script.new()
	if module_instance is BaseWorldSharedCreditsModule:
		_shared_credits_module = module_instance as BaseWorldSharedCreditsModule
		_shared_credits_module.setup(self)


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


func _is_network_online() -> bool:
	if _network_session_manager == null or not _network_session_manager.has_method("is_online"):
		return false
	return _variant_to_bool(_network_session_manager.call("is_online"))


func _get_local_network_peer_id() -> int:
	if _network_session_manager == null or not _network_session_manager.has_method("get_local_peer_id"):
		return 1
	return max(int(_network_session_manager.call("get_local_peer_id")), 1)


func _can_accept_network_gameplay_requests() -> bool:
	if not _is_network_online():
		return false
	if _network_session_manager == null:
		return false
	if _network_session_manager.has_method("can_accept_gameplay_requests"):
		return _variant_to_bool(_network_session_manager.call("can_accept_gameplay_requests"))
	if _network_session_manager.has_method("is_host"):
		return _variant_to_bool(_network_session_manager.call("is_host"))
	return multiplayer != null and multiplayer.is_server()


@rpc("any_peer", "call_remote", "unreliable")
func _rpc_receive_player_snapshot(payload: Dictionary) -> void:
	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if sender_peer_id <= 0:
		sender_peer_id = int(payload.get("peer_id", 0))
	if _network_helper != null:
		_network_helper.receive_remote_player_snapshot(payload, sender_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_map_transition(request: Dictionary) -> void:
	if not _can_accept_network_gameplay_requests():
		return

	var normalized_request: Dictionary = _normalize_map_transition_request(request)
	if normalized_request.is_empty():
		return

	_apply_map_transition_request_local(normalized_request)
	if _is_network_online():
		rpc("_rpc_apply_map_transition_request", normalized_request)


@rpc("authority", "call_remote", "reliable")
func _rpc_apply_map_transition_request(request: Dictionary) -> void:
	var normalized_request: Dictionary = _normalize_map_transition_request(request)
	if normalized_request.is_empty():
		return
	_apply_map_transition_request_local(normalized_request)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_world_interaction(request: Dictionary) -> void:
	if not _can_accept_network_gameplay_requests():
		return

	var normalized_request: Dictionary = _normalize_world_interaction_request(request)
	if normalized_request.is_empty():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if sender_peer_id <= 0:
		sender_peer_id = int(normalized_request.get("request_peer_id", 0))

	_apply_world_interaction_request_local(normalized_request, sender_peer_id)


@rpc("authority", "call_remote", "reliable")
func _rpc_open_vending_machine(machine_path: String) -> void:
	if _interaction_module != null:
		_interaction_module.open_vending_machine_local(machine_path)


@rpc("authority", "call_remote", "reliable")
func _rpc_open_crop_machine(machine_path: String) -> void:
	if _interaction_module != null:
		_interaction_module.open_crop_machine_local(machine_path)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_vending_machine_state(machine_path: String, state: Dictionary) -> void:
	if _interaction_module != null:
		_interaction_module.apply_vending_machine_state_local(machine_path, state)


@rpc("authority", "call_remote", "reliable")
func _rpc_vending_action_result(machine_path: String, result: Dictionary) -> void:
	if _interaction_module != null:
		_interaction_module.deliver_vending_action_result_local(machine_path, result)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_crop_machine_state(machine_path: String, state_payload: Dictionary) -> void:
	if _interaction_module != null:
		_interaction_module.apply_crop_machine_state_local(machine_path, state_payload)


@rpc("authority", "call_remote", "reliable")
func _rpc_handle_crop_machine_plant_result(result: Dictionary) -> void:
	if _interaction_module != null:
		_interaction_module.handle_crop_machine_plant_result_local(result)


@rpc("authority", "call_remote", "reliable")
func _rpc_handle_crop_machine_unlock_result(result: Dictionary) -> void:
	if _interaction_module != null:
		_interaction_module.handle_crop_machine_unlock_result_local(result)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_world_time_state(state: Dictionary) -> void:
	if _time_sync_module != null:
		_time_sync_module.apply_remote_time_state(state)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_shared_credits(credits_value: int) -> void:
	_set_shared_credits_local(credits_value)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_shared_credits_sync() -> void:
	if not _can_accept_network_gameplay_requests():
		return
	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if sender_peer_id <= 0:
		return
	_push_shared_credits_to_peer(sender_peer_id)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_player_inventory_sync(player_id: int, inventory_save_data: Dictionary) -> void:
	if not _can_accept_network_gameplay_requests():
		return
	_ensure_inventory_sync_module()
	if _inventory_sync_module != null:
		_inventory_sync_module.on_request_player_inventory_sync(player_id, inventory_save_data)
		return
	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if sender_peer_id <= 0:
		return
	var resolved_player_id: int = max(player_id, sender_peer_id)
	_apply_player_inventory_state_local(resolved_player_id, inventory_save_data)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_saved_player_inventory_sync() -> void:
	if not _can_accept_network_gameplay_requests():
		return
	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if sender_peer_id <= 0:
		return
	_ensure_inventory_sync_module()
	if _inventory_sync_module != null:
		_inventory_sync_module.on_request_saved_player_inventory(sender_peer_id)
		return
	var saved_inventory: Dictionary = _get_inventory_save_data_for_player(sender_peer_id)
	rpc_id(sender_peer_id, "_rpc_apply_player_inventory_sync", sender_peer_id, saved_inventory)


@rpc("authority", "call_remote", "reliable")
func _rpc_apply_player_inventory_sync(player_id: int, inventory_save_data: Dictionary) -> void:
	_apply_player_inventory_state_local(player_id, inventory_save_data)


func _normalize_map_transition_request(request: Dictionary) -> Dictionary:
	var normalized_scene_path: String = String(request.get("target_map_scene_path", request.get("scene_path", request.get("target_scene_path", "")))).strip_edges()
	if normalized_scene_path.is_empty():
		return {}

	var normalized_request: Dictionary = request.duplicate(true)
	normalized_request["target_map_scene_path"] = normalized_scene_path
	normalized_request["target_spawn_id"] = String(request.get("target_spawn_id", request.get("spawn_id", ""))).strip_edges()
	normalized_request["transition_name"] = String(request.get("transition_name", request.get("name", "")))
	normalized_request["log_text"] = String(request.get("log_text", request.get("message_text", request.get("log", ""))))
	return normalized_request


func _apply_map_transition_request_local(request: Dictionary) -> void:
	_ensure_map_transition_manager()
	if map_transition_manager != null and map_transition_manager.has_method("request_transition_request"):
		map_transition_manager.call("request_transition_request", request)
		return

	request_map_transition(
		String(request.get("target_map_scene_path", "")),
		String(request.get("target_spawn_id", "")),
		String(request.get("transition_name", "")),
		String(request.get("log_text", ""))
	)


func _normalize_world_interaction_request(request: Dictionary) -> Dictionary:
	if _interaction_module != null:
		return _interaction_module.normalize_world_interaction_request(request)
	return {}


func _apply_world_interaction_request_local(request: Dictionary, requesting_peer_id: int) -> void:
	if _interaction_module != null:
		_interaction_module.apply_world_interaction_request_local(request, requesting_peer_id)


func _broadcast_time_manager_state() -> void:
	if _time_sync_module != null:
		_time_sync_module.push_current_time_state_to_peers()


func _sync_time_manager_state_to_peer(peer_id: int) -> void:
	if _time_sync_module != null:
		_time_sync_module.push_current_time_state_to_peer(peer_id)


func _on_network_peer_joined(peer_id: int) -> void:
	if _network_helper != null:
		_network_helper.spawn_remote_network_player_for_peer(peer_id)
	if _time_sync_module != null:
		_time_sync_module.on_network_peer_joined(peer_id)
	_ensure_shared_credits_module()
	if _shared_credits_module != null:
		_shared_credits_module.on_network_peer_joined(peer_id)
		return
	if _can_accept_network_gameplay_requests():
		_push_shared_credits_to_peer(peer_id)


func _on_network_peer_left(peer_id: int) -> void:
	if _network_helper != null:
		_network_helper.remove_remote_network_player(peer_id)


func _on_network_connected_to_session() -> void:
	if _network_helper != null:
		_network_helper.configure_local_network_player()
	_apply_local_player_identity_preset()
	_bind_local_inventory_ui()
	if _network_helper != null:
		_network_helper.sync_remote_network_players_from_session()
		_network_helper.send_local_player_snapshot_now()
	if _time_sync_module != null:
		_time_sync_module.on_network_connected_to_session()
	_ensure_inventory_sync_module()
	if _inventory_sync_module != null:
		_inventory_sync_module.on_network_connected()
	_ensure_shared_credits_module()
	if _shared_credits_module != null:
		_shared_credits_module.on_network_connected()


func _on_network_disconnected_from_session() -> void:
	if _network_helper != null:
		_network_helper.clear_remote_network_players()
		_network_helper.configure_local_network_player()
	_apply_local_player_identity_preset()
	_bind_local_inventory_ui()
	if _time_sync_module != null:
		_time_sync_module.on_network_disconnected_from_session()
	_ensure_inventory_sync_module()
	if _inventory_sync_module != null:
		_inventory_sync_module.on_network_disconnected()


func _on_network_local_peer_id_changed(_peer_id: int) -> void:
	if _network_helper != null:
		_network_helper.configure_local_network_player()
	_apply_local_player_identity_preset()
	_bind_local_inventory_ui()
	if _network_helper != null:
		_network_helper.sync_remote_network_players_from_session()
		_network_helper.send_local_player_snapshot_now()
	if _time_sync_module != null:
		_time_sync_module.on_network_local_peer_id_changed()
	_ensure_inventory_sync_module()
	if _inventory_sync_module != null:
		_inventory_sync_module.on_network_local_peer_id_changed()


func _on_network_hosting_started(_port: int, _max_clients: int) -> void:
	if _network_helper != null:
		_network_helper.configure_local_network_player()
	_apply_local_player_identity_preset()
	_bind_local_inventory_ui()
	if _network_helper != null:
		_network_helper.sync_remote_network_players_from_session()
		_network_helper.send_local_player_snapshot_now()
	if _time_sync_module != null:
		_time_sync_module.on_network_hosting_started()
	_ensure_inventory_sync_module()
	if _inventory_sync_module != null:
		_inventory_sync_module.on_network_hosting_started()


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
	if _time_sync_module != null:
		_time_sync_module.resume_time_manager()
		return

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
	var local_player: Node = get_local_player()
	if local_player != null and local_player.has_method("set_input_locked"):
		local_player.call("set_input_locked", value)


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


func _connect_shared_credits_signal() -> void:
	_ensure_shared_credits_module()
	if _shared_credits_module != null:
		_shared_credits_module.connect_signal()
		return
	if CurrencyManager == null:
		return
	if CurrencyManager.has_signal("credits_changed") and not CurrencyManager.credits_changed.is_connected(_on_shared_credits_changed):
		CurrencyManager.credits_changed.connect(_on_shared_credits_changed)


func _on_shared_credits_changed(_value: int) -> void:
	_ensure_shared_credits_module()
	if _shared_credits_module != null:
		_shared_credits_module.push_shared_credits_to_remote_peers()
		return
	if not _is_network_online():
		return
	if not _can_accept_network_gameplay_requests():
		return
	_push_shared_credits_to_remote_peers()


func _get_shared_credits() -> int:
	_ensure_shared_credits_module()
	if _shared_credits_module != null:
		return _shared_credits_module.get_shared_credits()
	if CurrencyManager != null and CurrencyManager.has_method("get_credits"):
		return int(CurrencyManager.get_credits())
	return 0


func _set_shared_credits_local(value: int) -> void:
	_ensure_shared_credits_module()
	if _shared_credits_module != null:
		_shared_credits_module.sync_shared_credits_local(value)
		return
	var clamped_value: int = max(value, 0)
	if CurrencyManager != null and CurrencyManager.has_method("set_credits"):
		CurrencyManager.set_credits(clamped_value)


func _add_shared_credits(amount: int) -> void:
	if amount <= 0:
		return
	if CurrencyManager != null and CurrencyManager.has_method("add_credits"):
		CurrencyManager.add_credits(amount)
		return
	_set_shared_credits_local(_get_shared_credits() + amount)


func _can_spend_shared_credits(amount: int) -> bool:
	if amount < 0:
		return false
	if CurrencyManager != null and CurrencyManager.has_method("can_spend"):
		return bool(CurrencyManager.can_spend(amount))
	return _get_shared_credits() >= amount


func _spend_shared_credits(amount: int) -> bool:
	if amount <= 0:
		return false
	if CurrencyManager != null and CurrencyManager.has_method("spend_credits"):
		return bool(CurrencyManager.spend_credits(amount))
	var current_credits: int = _get_shared_credits()
	if current_credits < amount:
		return false
	_set_shared_credits_local(current_credits - amount)
	return true


func _push_shared_credits_to_remote_peers() -> void:
	_ensure_shared_credits_module()
	if _shared_credits_module != null:
		_shared_credits_module.push_shared_credits_to_remote_peers()
		return
	if not _is_network_online():
		return
	rpc("_rpc_sync_shared_credits", _get_shared_credits())


func _push_shared_credits_to_peer(peer_id: int) -> void:
	_ensure_shared_credits_module()
	if _shared_credits_module != null:
		_shared_credits_module.push_shared_credits_to_peer(peer_id)
		return
	var target_peer_id: int = max(peer_id, 1)
	if not _is_network_online():
		return
	if target_peer_id == _get_local_network_peer_id():
		_set_shared_credits_local(_get_shared_credits())
		return
	rpc_id(target_peer_id, "_rpc_sync_shared_credits", _get_shared_credits())


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

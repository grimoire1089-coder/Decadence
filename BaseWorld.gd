extends Node2D
class_name BaseWorld

const NETWORK_BOOT_MODE_DISABLED: String = "disabled"
const NETWORK_BOOT_MODE_HOST: String = "host"
const NETWORK_BOOT_MODE_CLIENT: String = "client"
const NETWORK_SESSION_MANAGER_SCRIPT_PATH: String = "res://Core/Network/NetworkSessionManager.gd"
const NETWORK_HELPER_SCRIPT_PATH: String = "res://Core/Network/BaseWorldNetworkHelper.gd"
const WORLD_TIME_SYNC_MODULE_SCRIPT_PATH: String = "res://Core/World/BaseWorldTimeSyncModule.gd"

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


func _ready() -> void:
	_ensure_network_helper()
	_ensure_time_sync_module()
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
	if _network_helper != null:
		_network_helper.configure_local_network_player()
		_network_helper.sync_remote_network_players_from_session()
	_resume_time_manager()
	_set_player_input_locked(false)


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
	_open_vending_machine_local(machine_path)


@rpc("authority", "call_remote", "reliable")
func _rpc_open_crop_machine(machine_path: String) -> void:
	_open_crop_machine_local(machine_path)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_vending_machine_state(machine_path: String, state: Dictionary) -> void:
	_apply_vending_machine_state_local(machine_path, state)


@rpc("authority", "call_remote", "reliable")
func _rpc_vending_action_result(machine_path: String, result: Dictionary) -> void:
	_deliver_vending_action_result_local(machine_path, result)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_crop_machine_state(machine_path: String, state_payload: Dictionary) -> void:
	_apply_crop_machine_state_local(machine_path, state_payload)


@rpc("authority", "call_remote", "reliable")
func _rpc_handle_crop_machine_plant_result(result: Dictionary) -> void:
	_handle_crop_machine_plant_result_local(result)

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_world_time_state(state: Dictionary) -> void:
	if _time_sync_module != null:
		_time_sync_module.apply_remote_time_state(state)



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
	var interaction_kind: String = String(request.get("interaction_kind", request.get("kind", ""))).strip_edges()
	if interaction_kind.is_empty():
		return {}

	var normalized_request: Dictionary = request.duplicate(true)
	normalized_request["interaction_kind"] = interaction_kind
	normalized_request["machine_path"] = String(request.get("machine_path", request.get("target_node_path", ""))).strip_edges()
	normalized_request["request_peer_id"] = int(request.get("request_peer_id", _get_local_network_peer_id()))
	normalized_request["slot_index"] = int(request.get("slot_index", -1))
	normalized_request["plant_count"] = max(int(request.get("plant_count", 1)), 1)
	normalized_request["recipe_key"] = String(request.get("recipe_key", "")).strip_edges()

	var seed_item_payload_variant: Variant = request.get("seed_item_payload", {})
	normalized_request["seed_item_payload"] = seed_item_payload_variant if typeof(seed_item_payload_variant) == TYPE_DICTIONARY else {}

	var removed_entries_payload_variant: Variant = request.get("removed_entries_payload", [])
	normalized_request["removed_entries_payload"] = removed_entries_payload_variant if typeof(removed_entries_payload_variant) == TYPE_ARRAY else []

	return normalized_request


func _apply_world_interaction_request_local(request: Dictionary, requesting_peer_id: int) -> void:
	var interaction_kind: String = String(request.get("interaction_kind", "")).strip_edges()
	match interaction_kind:
		"vending_machine_open":
			var vending_machine_path: String = String(request.get("machine_path", "")).strip_edges()
			if vending_machine_path.is_empty():
				return

			if _can_accept_network_gameplay_requests():
				var vending_target_peer_id: int = max(requesting_peer_id, 1)
				if vending_target_peer_id == _get_local_network_peer_id():
					_open_vending_machine_local(vending_machine_path)
				elif _is_network_online():
					rpc_id(vending_target_peer_id, "_rpc_open_vending_machine", vending_machine_path)
				return

			_open_vending_machine_local(vending_machine_path)

		"vending_machine_stock_one":
			var stock_machine_path: String = String(request.get("machine_path", "")).strip_edges()
			var stock_target_peer_id: int = max(requesting_peer_id, 1)
			if stock_machine_path.is_empty():
				_send_vending_action_result_to_peer(stock_target_peer_id, stock_machine_path, {
					"interaction_kind": interaction_kind,
					"success": false,
					"message": "自販機が見つからない",
				})
				return

			var stock_machine_node: Node = get_node_or_null(NodePath(stock_machine_path))
			var stock_machine: VendingMachine = stock_machine_node as VendingMachine
			if stock_machine == null:
				_send_vending_action_result_to_peer(stock_target_peer_id, stock_machine_path, {
					"interaction_kind": interaction_kind,
					"success": false,
					"message": "自販機が見つからない",
				})
				return

			var stock_slot_index: int = int(request.get("slot_index", -1))
			var stock_amount: int = max(int(request.get("action_amount", 0)), 0)
			var stock_item_payload: Dictionary = request.get("item_payload", {}) as Dictionary
			var stock_item_data: Resource = null
			if stock_machine.has_method("build_item_from_network_payload"):
				stock_item_data = stock_machine.call("build_item_from_network_payload", stock_item_payload) as Resource

			if stock_item_data == null or stock_amount <= 0:
				_send_vending_action_result_to_peer(stock_target_peer_id, stock_machine_path, {
					"interaction_kind": interaction_kind,
					"success": false,
					"message": "補充データが不正",
					"rollback_item_payload": stock_item_payload,
					"rollback_amount": stock_amount,
				})
				return

			var stocked: bool = stock_machine.stock_item(stock_slot_index, stock_item_data, stock_amount, 0)
			if not stocked:
				_send_vending_action_result_to_peer(stock_target_peer_id, stock_machine_path, {
					"interaction_kind": interaction_kind,
					"success": false,
					"message": "そのスロットには別の商品が入ってる",
					"rollback_item_payload": stock_item_payload,
					"rollback_amount": stock_amount,
				})
				return

			var stock_sell_price: int = stock_machine.peek_slot_price(stock_slot_index)
			if stock_machine.has_method("export_network_state"):
				_push_vending_machine_state_to_remote_peers(stock_machine_path, stock_machine.call("export_network_state") as Dictionary)

			_send_vending_action_result_to_peer(stock_target_peer_id, stock_machine_path, {
				"interaction_kind": interaction_kind,
				"success": true,
				"message": "%d個補充した（売値: %d Cr）" % [stock_amount, stock_sell_price],
			})

		"vending_machine_take_back_one":
			var take_machine_path: String = String(request.get("machine_path", "")).strip_edges()
			var take_target_peer_id: int = max(requesting_peer_id, 1)
			if take_machine_path.is_empty():
				_send_vending_action_result_to_peer(take_target_peer_id, take_machine_path, {
					"interaction_kind": interaction_kind,
					"success": false,
					"message": "自販機が見つからない",
				})
				return

			var take_machine_node: Node = get_node_or_null(NodePath(take_machine_path))
			var take_machine: VendingMachine = take_machine_node as VendingMachine
			if take_machine == null:
				_send_vending_action_result_to_peer(take_target_peer_id, take_machine_path, {
					"interaction_kind": interaction_kind,
					"success": false,
					"message": "自販機が見つからない",
				})
				return

			var take_slot_index: int = int(request.get("slot_index", -1))
			var take_amount: int = max(int(request.get("action_amount", 0)), 0)
			var take_result: Dictionary = take_machine.take_back_item(take_slot_index, take_amount)
			if not bool(take_result.get("success", false)):
				_send_vending_action_result_to_peer(take_target_peer_id, take_machine_path, {
					"interaction_kind": interaction_kind,
					"success": false,
					"message": "取り出せない",
				})
				return

			var returned_item: Resource = take_result.get("item_data", null) as Resource
			var returned_amount: int = max(int(take_result.get("amount", 0)), 0)
			var returned_payload: Dictionary = {}
			if returned_item != null and take_machine.has_method("build_network_item_payload"):
				returned_payload = take_machine.call("build_network_item_payload", returned_item) as Dictionary

			if take_machine.has_method("export_network_state"):
				_push_vending_machine_state_to_remote_peers(take_machine_path, take_machine.call("export_network_state") as Dictionary)

			_send_vending_action_result_to_peer(take_target_peer_id, take_machine_path, {
				"interaction_kind": interaction_kind,
				"success": true,
				"message": "%d個取り戻した" % returned_amount,
				"returned_item_payload": returned_payload,
				"returned_amount": returned_amount,
			})

		"vending_machine_collect_earnings":
			var collect_machine_path: String = String(request.get("machine_path", "")).strip_edges()
			var collect_target_peer_id: int = max(requesting_peer_id, 1)
			if collect_machine_path.is_empty():
				_send_vending_action_result_to_peer(collect_target_peer_id, collect_machine_path, {
					"interaction_kind": interaction_kind,
					"success": false,
					"message": "自販機が見つからない",
				})
				return

			var collect_machine_node: Node = get_node_or_null(NodePath(collect_machine_path))
			var collect_machine: VendingMachine = collect_machine_node as VendingMachine
			if collect_machine == null:
				_send_vending_action_result_to_peer(collect_target_peer_id, collect_machine_path, {
					"interaction_kind": interaction_kind,
					"success": false,
					"message": "自販機が見つからない",
				})
				return

			var collected_amount: int = 0
			if collect_machine.has_method("consume_earnings_for_network"):
				collected_amount = int(collect_machine.call("consume_earnings_for_network"))
			else:
				collected_amount = collect_machine.collect_earnings(player)

			if collected_amount <= 0:
				_send_vending_action_result_to_peer(collect_target_peer_id, collect_machine_path, {
					"interaction_kind": interaction_kind,
					"success": false,
					"message": "回収できる売上がない",
				})
				return

			if collect_machine.has_method("export_network_state"):
				_push_vending_machine_state_to_remote_peers(collect_machine_path, collect_machine.call("export_network_state") as Dictionary)

			_send_vending_action_result_to_peer(collect_target_peer_id, collect_machine_path, {
				"interaction_kind": interaction_kind,
				"success": true,
				"message": "売上を回収した",
				"collected_amount": collected_amount,
			})

		"crop_machine_open":
			var crop_machine_path: String = String(request.get("machine_path", "")).strip_edges()
			if crop_machine_path.is_empty():
				return

			if _can_accept_network_gameplay_requests():
				var crop_target_peer_id: int = max(requesting_peer_id, 1)
				if crop_target_peer_id == _get_local_network_peer_id():
					_open_crop_machine_local(crop_machine_path)
				elif _is_network_online():
					rpc_id(crop_target_peer_id, "_rpc_open_crop_machine", crop_machine_path)
				return

			_open_crop_machine_local(crop_machine_path)

		_:
			return


func _open_vending_machine_local(machine_path: String) -> void:
	var normalized_machine_path: String = machine_path.strip_edges()
	if normalized_machine_path.is_empty():
		return

	var machine_node: Node = get_node_or_null(NodePath(normalized_machine_path))
	var machine: VendingMachine = machine_node as VendingMachine
	if machine == null:
		return

	var vending_ui: Node = get_tree().get_first_node_in_group("vending_ui")
	if vending_ui != null and vending_ui.has_method("open_machine"):
		vending_ui.call("open_machine", machine, player)


func _open_crop_machine_local(machine_path: String) -> void:
	var normalized_machine_path: String = machine_path.strip_edges()
	if normalized_machine_path.is_empty():
		return

	var machine_node: Node = get_node_or_null(NodePath(normalized_machine_path))
	var machine: CropMachine = machine_node as CropMachine
	if machine == null:
		return

	var crop_machine_ui: Node = get_tree().get_first_node_in_group("crop_machine_ui")
	if crop_machine_ui != null and crop_machine_ui.has_method("open_machine"):
		crop_machine_ui.call("open_machine", machine, player)


func _apply_vending_machine_state_local(machine_path: String, state: Dictionary) -> void:
	var normalized_machine_path: String = machine_path.strip_edges()
	if normalized_machine_path.is_empty():
		return

	var machine_node: Node = get_node_or_null(NodePath(normalized_machine_path))
	var machine: VendingMachine = machine_node as VendingMachine
	if machine == null:
		return

	if machine.has_method("import_network_state"):
		machine.call("import_network_state", state)


func _push_vending_machine_state_to_remote_peers(machine_path: String, state: Dictionary) -> void:
	if not _is_network_online():
		return
	rpc("_rpc_sync_vending_machine_state", machine_path, state)


func _send_vending_action_result_to_peer(target_peer_id: int, machine_path: String, result: Dictionary) -> void:
	var resolved_peer_id: int = max(target_peer_id, 1)
	var normalized_result: Dictionary = result.duplicate(true)
	normalized_result["machine_path"] = machine_path.strip_edges()

	if not _is_network_online() or resolved_peer_id == _get_local_network_peer_id():
		_deliver_vending_action_result_local(machine_path, normalized_result)
		return

	rpc_id(resolved_peer_id, "_rpc_vending_action_result", machine_path, normalized_result)


func _deliver_vending_action_result_local(machine_path: String, result: Dictionary) -> void:
	var normalized_machine_path: String = machine_path.strip_edges()
	if not normalized_machine_path.is_empty():
		var machine_node: Node = get_node_or_null(NodePath(normalized_machine_path))
		var machine: VendingMachine = machine_node as VendingMachine
		if machine != null and result.has("machine_state") and machine.has_method("import_network_state"):
			machine.call("import_network_state", result.get("machine_state", {}) as Dictionary)

	var vending_ui: Node = get_tree().get_first_node_in_group("vending_ui")
	if vending_ui != null and vending_ui.has_method("handle_network_action_result"):
		vending_ui.call("handle_network_action_result", result)


func _perform_crop_machine_plant_request(request: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"interaction_kind": "crop_machine_plant",
		"success": false,
		"message": "",
		"machine_path": String(request.get("machine_path", "")).strip_edges(),
		"rollback_removed_entries_payload": request.get("removed_entries_payload", [])
	}

	var machine_path: String = String(request.get("machine_path", "")).strip_edges()
	if machine_path.is_empty():
		result["message"] = "栽培機が見つからない"
		return result

	var machine_node: Node = get_node_or_null(NodePath(machine_path))
	var machine: CropMachine = machine_node as CropMachine
	if machine == null:
		result["message"] = "栽培機が見つからない"
		return result

	var recipe_key: String = String(request.get("recipe_key", "")).strip_edges()
	var recipe: CropRecipe = _find_crop_machine_recipe_by_key(machine, recipe_key)
	if recipe == null:
		result["message"] = "植え付けレシピがない"
		return result

	var slot_index: int = int(request.get("slot_index", -1))
	var plant_count: int = max(int(request.get("plant_count", 1)), 1)
	if slot_index < 0 or slot_index >= machine.slots.size():
		result["message"] = "スロット未選択"
		return result

	if recipe.seed_item == null:
		result["message"] = "種アイテムが未設定"
		return result

	if not machine.can_plant_recipe_in_slot(slot_index, recipe):
		result["message"] = "使用中スロットには同じ作物だけ追加投入できる"
		return result

	var representative_seed_item: ItemData = recipe.seed_item
	var seed_item_payload: Dictionary = request.get("seed_item_payload", {}) as Dictionary
	if machine.has_method("build_item_from_network_payload"):
		var built_seed_item: ItemData = machine.call("build_item_from_network_payload", seed_item_payload) as ItemData
		if built_seed_item != null:
			representative_seed_item = built_seed_item

	var was_empty: bool = machine.is_slot_empty(slot_index)
	var planted: bool = machine.plant_slot(slot_index, recipe, plant_count, representative_seed_item)
	if not planted:
		result["message"] = "植え付けできなかった"
		return result

	machine.save_data()
	machine._refresh_open_ui()

	result["success"] = true
	result["message"] = "%sを %d 回分 セットした" % [recipe.get_display_name(), plant_count] if was_empty else "%sを %d 回分 追加投入した" % [recipe.get_display_name(), plant_count]
	if machine.has_method("export_network_state_payload"):
		result["machine_state"] = machine.call("export_network_state_payload")
	else:
		result["machine_state"] = machine.get_save_payload()

	return result


func _find_crop_machine_recipe_by_key(machine: CropMachine, recipe_key: String) -> CropRecipe:
	if machine == null or recipe_key.is_empty():
		return null

	for recipe_variant in machine.available_recipes:
		var recipe: CropRecipe = recipe_variant as CropRecipe
		if recipe == null or not recipe.is_valid_recipe():
			continue

		var current_key: String = ""
		if machine.has_method("_get_recipe_unique_key"):
			current_key = String(machine.call("_get_recipe_unique_key", recipe))
		elif not recipe.resource_path.is_empty():
			current_key = recipe.resource_path
		elif not str(recipe.id).is_empty():
			current_key = str(recipe.id)
		else:
			current_key = recipe.get_display_name()

		if current_key == recipe_key:
			return recipe

	return null


func _apply_crop_machine_state_local(machine_path: String, state_payload: Dictionary) -> void:
	var normalized_machine_path: String = machine_path.strip_edges()
	if normalized_machine_path.is_empty():
		return

	var machine_node: Node = get_node_or_null(NodePath(normalized_machine_path))
	var machine: CropMachine = machine_node as CropMachine
	if machine == null:
		return

	if machine.has_method("apply_network_state_payload"):
		machine.call("apply_network_state_payload", state_payload)
		return

	machine.apply_save_payload(state_payload)
	machine._refresh_open_ui()


func _handle_crop_machine_plant_result_local(result: Dictionary) -> void:
	var crop_machine_ui: Node = get_tree().get_first_node_in_group("crop_machine_ui")
	if crop_machine_ui != null and crop_machine_ui.has_method("handle_network_plant_result"):
		crop_machine_ui.call("handle_network_plant_result", result)



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


func _on_network_peer_left(peer_id: int) -> void:
	if _network_helper != null:
		_network_helper.remove_remote_network_player(peer_id)


func _on_network_connected_to_session() -> void:
	if _network_helper != null:
		_network_helper.configure_local_network_player()
		_network_helper.sync_remote_network_players_from_session()
	if _time_sync_module != null:
		_time_sync_module.on_network_connected_to_session()


func _on_network_disconnected_from_session() -> void:
	if _network_helper != null:
		_network_helper.clear_remote_network_players()
		_network_helper.configure_local_network_player()
	if _time_sync_module != null:
		_time_sync_module.on_network_disconnected_from_session()


func _on_network_local_peer_id_changed(_peer_id: int) -> void:
	if _network_helper != null:
		_network_helper.configure_local_network_player()
		_network_helper.sync_remote_network_players_from_session()
	if _time_sync_module != null:
		_time_sync_module.on_network_local_peer_id_changed()


func _on_network_hosting_started(_port: int, _max_clients: int) -> void:
	if _network_helper != null:
		_network_helper.configure_local_network_player()
		_network_helper.sync_remote_network_players_from_session()
	if _time_sync_module != null:
		_time_sync_module.on_network_hosting_started()


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

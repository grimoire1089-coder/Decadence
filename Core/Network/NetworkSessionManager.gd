extends Node
class_name NetworkSessionManager

signal session_mode_changed(mode: String)
signal hosting_started(port: int, max_clients: int)
signal hosting_failed(message: String)
signal join_started(address: String, port: int)
signal join_failed(message: String)
signal connected_to_session()
signal disconnected_from_session()
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal local_peer_id_changed(peer_id: int)

const MODE_OFFLINE: StringName = &"offline"
const MODE_HOST: StringName = &"host"
const MODE_CLIENT: StringName = &"client"

const DEFAULT_PORT: int = 18080
const DEFAULT_MAX_REMOTE_PLAYERS: int = 1
const ENET_ADAPTER_SCRIPT_PATH: String = "res://Core/Network/EnetSessionAdapter.gd"

var session_mode: StringName = MODE_OFFLINE
var local_peer_id: int = 1
var current_port: int = DEFAULT_PORT
var current_address: String = ""
var last_error_message: String = ""

var _signals_connected: bool = false
var _enet_adapter: EnetSessionAdapter = null


func _ready() -> void:
	add_to_group("network_session_manager")
	_ensure_enet_adapter()
	_refresh_local_peer_id()


func host_game(port: int = DEFAULT_PORT, max_remote_players: int = DEFAULT_MAX_REMOTE_PLAYERS) -> bool:
	close_session()

	var adapter: EnetSessionAdapter = _ensure_enet_adapter()
	if adapter == null:
		last_error_message = "EnetSessionAdapter を読み込めません"
		hosting_failed.emit(last_error_message)
		return false

	var peer: ENetMultiplayerPeer = adapter.create_server_peer(port, max_remote_players)
	if peer == null:
		last_error_message = adapter.get_last_error_message()
		hosting_failed.emit(last_error_message)
		return false

	current_port = adapter.get_current_port()
	current_address = adapter.get_current_address()
	_attach_peer(peer, MODE_HOST)
	hosting_started.emit(current_port, adapter.get_max_remote_players())
	return true


func join_game(address: String, port: int = DEFAULT_PORT) -> bool:
	close_session()

	var normalized_address: String = address.strip_edges()
	if normalized_address.is_empty():
		last_error_message = "参加先アドレスが空です"
		join_failed.emit(last_error_message)
		return false

	join_started.emit(normalized_address, port)

	var adapter: EnetSessionAdapter = _ensure_enet_adapter()
	if adapter == null:
		last_error_message = "EnetSessionAdapter を読み込めません"
		join_failed.emit(last_error_message)
		return false

	var peer: ENetMultiplayerPeer = adapter.create_client_peer(normalized_address, port)
	if peer == null:
		last_error_message = adapter.get_last_error_message()
		join_failed.emit(last_error_message)
		return false

	current_port = adapter.get_current_port()
	current_address = adapter.get_current_address()
	_attach_peer(peer, MODE_CLIENT)
	return true


func close_session() -> void:
	_disconnect_multiplayer_signals()

	var api: MultiplayerAPI = _get_multiplayer_api()
	var current_peer: MultiplayerPeer = null
	if api != null:
		current_peer = api.multiplayer_peer
	if current_peer != null:
		current_peer.close()

	if api != null:
		api.multiplayer_peer = null

	if _enet_adapter != null:
		_enet_adapter.close()

	current_port = DEFAULT_PORT
	current_address = ""
	last_error_message = ""
	_set_session_mode(MODE_OFFLINE)
	_refresh_local_peer_id()


func is_online() -> bool:
	var api: MultiplayerAPI = _get_multiplayer_api()
	if api == null:
		return false
	return api.multiplayer_peer != null and session_mode != MODE_OFFLINE


func is_host() -> bool:
	return session_mode == MODE_HOST


func is_client() -> bool:
	return session_mode == MODE_CLIENT


func get_session_mode() -> String:
	return String(session_mode)


func get_local_peer_id() -> int:
	return local_peer_id


func get_remote_peer_ids() -> PackedInt32Array:
	var api: MultiplayerAPI = _get_multiplayer_api()
	if api == null:
		return PackedInt32Array()
	return api.get_peers()


func get_current_port() -> int:
	return current_port


func get_current_address() -> String:
	return current_address


func can_accept_gameplay_requests() -> bool:
	return is_host()


func _ensure_enet_adapter() -> EnetSessionAdapter:
	if _enet_adapter != null:
		return _enet_adapter

	if not ResourceLoader.exists(ENET_ADAPTER_SCRIPT_PATH):
		return null

	var script_ref: Script = load(ENET_ADAPTER_SCRIPT_PATH) as Script
	if script_ref == null:
		return null

	var adapter_instance: Variant = script_ref.new()
	if adapter_instance is EnetSessionAdapter:
		_enet_adapter = adapter_instance as EnetSessionAdapter
		return _enet_adapter

	return null


func _attach_peer(peer: MultiplayerPeer, mode: StringName) -> void:
	var api: MultiplayerAPI = _get_multiplayer_api()
	if api == null:
		return
	api.multiplayer_peer = peer
	_connect_multiplayer_signals()
	_set_session_mode(mode)
	_refresh_local_peer_id()


func _set_session_mode(next_mode: StringName) -> void:
	if session_mode == next_mode:
		return
	session_mode = next_mode
	session_mode_changed.emit(String(session_mode))


func _refresh_local_peer_id() -> void:
	var next_peer_id: int = 1
	var api: MultiplayerAPI = _get_multiplayer_api()
	if api != null and api.multiplayer_peer != null:
		next_peer_id = api.get_unique_id()

	if local_peer_id == next_peer_id:
		return

	local_peer_id = next_peer_id
	local_peer_id_changed.emit(local_peer_id)


func _connect_multiplayer_signals() -> void:
	if _signals_connected:
		return

	var api: MultiplayerAPI = _get_multiplayer_api()
	if api == null:
		return

	api.peer_connected.connect(_on_peer_connected)
	api.peer_disconnected.connect(_on_peer_disconnected)
	api.connected_to_server.connect(_on_connected_to_server)
	api.connection_failed.connect(_on_connection_failed)
	api.server_disconnected.connect(_on_server_disconnected)
	_signals_connected = true


func _disconnect_multiplayer_signals() -> void:
	if not _signals_connected:
		return

	var api: MultiplayerAPI = _get_multiplayer_api()
	if api == null:
		_signals_connected = false
		return

	if api.peer_connected.is_connected(_on_peer_connected):
		api.peer_connected.disconnect(_on_peer_connected)
	if api.peer_disconnected.is_connected(_on_peer_disconnected):
		api.peer_disconnected.disconnect(_on_peer_disconnected)
	if api.connected_to_server.is_connected(_on_connected_to_server):
		api.connected_to_server.disconnect(_on_connected_to_server)
	if api.connection_failed.is_connected(_on_connection_failed):
		api.connection_failed.disconnect(_on_connection_failed)
	if api.server_disconnected.is_connected(_on_server_disconnected):
		api.server_disconnected.disconnect(_on_server_disconnected)

	_signals_connected = false


func _on_peer_connected(peer_id: int) -> void:
	_refresh_local_peer_id()
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)


func _on_connected_to_server() -> void:
	_refresh_local_peer_id()
	connected_to_session.emit()


func _on_connection_failed() -> void:
	last_error_message = "サーバーとの接続に失敗しました"
	_disconnect_multiplayer_signals()
	var api: MultiplayerAPI = _get_multiplayer_api()
	if api != null:
		api.multiplayer_peer = null
	if _enet_adapter != null:
		_enet_adapter.close()
	current_port = DEFAULT_PORT
	current_address = ""
	_set_session_mode(MODE_OFFLINE)
	_refresh_local_peer_id()
	join_failed.emit(last_error_message)


func _on_server_disconnected() -> void:
	last_error_message = "サーバーとの接続が切断されました"
	_disconnect_multiplayer_signals()
	var api: MultiplayerAPI = _get_multiplayer_api()
	if api != null:
		api.multiplayer_peer = null
	if _enet_adapter != null:
		_enet_adapter.close()
	current_port = DEFAULT_PORT
	current_address = ""
	_set_session_mode(MODE_OFFLINE)
	_refresh_local_peer_id()
	disconnected_from_session.emit()


func _get_multiplayer_api() -> MultiplayerAPI:
	var api: MultiplayerAPI = multiplayer
	if api == null:
		return null
	return api

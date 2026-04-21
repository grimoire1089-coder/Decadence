extends RefCounted
class_name EnetSessionAdapter

const MODE_NONE: StringName = &"none"
const MODE_SERVER: StringName = &"server"
const MODE_CLIENT: StringName = &"client"

var _peer: ENetMultiplayerPeer = null
var _mode: StringName = MODE_NONE
var _current_port: int = 0
var _current_address: String = ""
var _max_remote_players: int = 0
var _last_error_code: int = OK
var _last_error_message: String = ""


func create_server_peer(port: int, max_remote_players: int = 1) -> ENetMultiplayerPeer:
	close()

	var normalized_port: int = maxi(port, 1)
	var normalized_max_remote_players: int = maxi(max_remote_players, 1)
	var peer := ENetMultiplayerPeer.new()
	var result: int = peer.create_server(normalized_port, normalized_max_remote_players)
	if result != OK:
		_set_error(result, "ENet サーバー開始に失敗しました")
		return null

	_clear_error()
	_peer = peer
	_mode = MODE_SERVER
	_current_port = normalized_port
	_current_address = ""
	_max_remote_players = normalized_max_remote_players
	return _peer


func create_client_peer(address: String, port: int) -> ENetMultiplayerPeer:
	close()

	var normalized_address: String = address.strip_edges()
	if normalized_address.is_empty():
		_set_custom_error(ERR_INVALID_PARAMETER, "参加先アドレスが空です")
		return null

	var normalized_port: int = maxi(port, 1)
	var peer := ENetMultiplayerPeer.new()
	var result: int = peer.create_client(normalized_address, normalized_port)
	if result != OK:
		_set_error(result, "ENet クライアント接続開始に失敗しました")
		return null

	_clear_error()
	_peer = peer
	_mode = MODE_CLIENT
	_current_port = normalized_port
	_current_address = normalized_address
	_max_remote_players = 0
	return _peer


func close() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	_mode = MODE_NONE
	_current_port = 0
	_current_address = ""
	_max_remote_players = 0


func has_active_peer() -> bool:
	return _peer != null


func get_peer() -> MultiplayerPeer:
	return _peer


func get_mode() -> String:
	return String(_mode)


func is_server() -> bool:
	return _mode == MODE_SERVER and _peer != null


func is_client() -> bool:
	return _mode == MODE_CLIENT and _peer != null


func get_current_port() -> int:
	return _current_port


func get_current_address() -> String:
	return _current_address


func get_max_remote_players() -> int:
	return _max_remote_players


func get_last_error_code() -> int:
	return _last_error_code


func get_last_error_message() -> String:
	return _last_error_message


func _set_error(error_code: int, prefix: String) -> void:
	_last_error_code = error_code
	_last_error_message = "%s: %s" % [prefix, error_string(error_code)]


func _set_custom_error(error_code: int, message: String) -> void:
	_last_error_code = error_code
	_last_error_message = message


func _clear_error() -> void:
	_last_error_code = OK
	_last_error_message = ""

extends RefCounted
class_name BaseWorldPlayerRegistry

var world: BaseWorld = null
var local_player: Node = null
var players_by_peer_id: Dictionary = {}
var players_by_player_id: Dictionary = {}
var remote_players_by_peer_id: Dictionary = {}


func setup(owner_world: BaseWorld) -> void:
	world = owner_world


func register_local_player(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return

	if local_player != null and is_instance_valid(local_player) and local_player != player:
		_remove_player_indexes(local_player)

	local_player = player
	_index_player(player)


func register_remote_player(peer_id: int, player: Node) -> void:
	if peer_id <= 0:
		return
	if player == null or not is_instance_valid(player):
		return

	var existing: Node = remote_players_by_peer_id.get(peer_id, null) as Node
	if existing != null and is_instance_valid(existing) and existing != player:
		_remove_player_indexes(existing)

	remote_players_by_peer_id[peer_id] = player
	_index_player(player)


func unregister_remote_player(peer_id: int) -> void:
	var remote_player: Node = remote_players_by_peer_id.get(peer_id, null) as Node
	remote_players_by_peer_id.erase(peer_id)
	if remote_player != null and is_instance_valid(remote_player):
		_remove_player_indexes(remote_player)


func clear_remote_players() -> void:
	var peer_ids: Array = remote_players_by_peer_id.keys()
	for peer_id_variant in peer_ids:
		unregister_remote_player(int(peer_id_variant))
	remote_players_by_peer_id.clear()


func get_local_player() -> Node:
	if local_player != null and is_instance_valid(local_player):
		return local_player
	return null


func get_player_by_peer_id(peer_id: int) -> Node:
	var player: Node = players_by_peer_id.get(peer_id, null) as Node
	if player != null and is_instance_valid(player):
		return player
	return null


func get_player_by_player_id(player_id: int) -> Node:
	var player: Node = players_by_player_id.get(player_id, null) as Node
	if player != null and is_instance_valid(player):
		return player
	return null


func get_all_players() -> Array:
	var result: Array = []
	var seen: Dictionary = {}

	var local_ref: Node = get_local_player()
	if local_ref != null:
		result.append(local_ref)
		seen[local_ref] = true

	for player in remote_players_by_peer_id.values():
		if player == null or not is_instance_valid(player):
			continue
		if seen.has(player):
			continue
		result.append(player)
		seen[player] = true

	return result


func has_player_peer(peer_id: int) -> bool:
	return get_player_by_peer_id(peer_id) != null


func _index_player(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return

	var peer_id: int = _extract_peer_id(player)
	if peer_id > 0:
		players_by_peer_id[peer_id] = player

	var player_id: int = _extract_player_id(player)
	if player_id > 0:
		players_by_player_id[player_id] = player


func _remove_player_indexes(player: Node) -> void:
	if player == null:
		return

	var peer_keys: Array = players_by_peer_id.keys()
	for peer_key in peer_keys:
		if players_by_peer_id.get(peer_key, null) == player:
			players_by_peer_id.erase(peer_key)

	var player_keys: Array = players_by_player_id.keys()
	for player_key in player_keys:
		if players_by_player_id.get(player_key, null) == player:
			players_by_player_id.erase(player_key)

	if local_player == player:
		local_player = null


func _extract_peer_id(player: Node) -> int:
	if player == null or not is_instance_valid(player):
		return 0
	if player.has_method("get_peer_id"):
		return max(int(player.call("get_peer_id")), 0)
	if player.has_method("get_network_peer_id"):
		return max(int(player.call("get_network_peer_id")), 0)
	return 0


func _extract_player_id(player: Node) -> int:
	if player == null or not is_instance_valid(player):
		return 0
	if player.has_method("get_player_id"):
		return max(int(player.call("get_player_id")), 0)
	if player.has_method("get_network_player_id"):
		return max(int(player.call("get_network_player_id")), 0)
	return 0

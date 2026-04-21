extends RefCounted
class_name BaseWorldNetworkHelper

var world: BaseWorld = null
var network_players_root: Node2D = null
var remote_players_by_peer_id: Dictionary = {}


func setup(owner_world: BaseWorld) -> void:
	world = owner_world


func configure_local_network_player() -> void:
	if world == null:
		return
	if world.player == null or not is_instance_valid(world.player):
		return

	var local_peer_id: int = world._get_local_network_peer_id()
	if world.player.has_method("configure_network_peer"):
		world.player.call("configure_network_peer", local_peer_id, local_peer_id, local_peer_id, "Player %d" % max(local_peer_id, 1))
	if world.player.has_method("set_network_local_player"):
		world.player.call("set_network_local_player", true)
	if world.player.has_method("set_network_authority_peer_id"):
		world.player.call("set_network_authority_peer_id", max(local_peer_id, 1))


func sync_remote_network_players_from_session() -> void:
	if world == null:
		return

	var session_manager: Node = world.get_network_session_manager()
	if session_manager == null or not world._is_network_online():
		clear_remote_network_players()
		return

	var local_peer_id: int = world._get_local_network_peer_id()
	var desired_peer_ids: Dictionary = {}

	if session_manager.has_method("get_remote_peer_ids"):
		var peers_variant: Variant = session_manager.call("get_remote_peer_ids")
		var peers: PackedInt32Array = PackedInt32Array()
		if peers_variant is PackedInt32Array:
			peers = peers_variant as PackedInt32Array

		for peer_id in peers:
			if peer_id <= 0 or peer_id == local_peer_id:
				continue
			desired_peer_ids[peer_id] = true
			spawn_remote_network_player_for_peer(peer_id)

	var existing_peer_ids: Array = remote_players_by_peer_id.keys()
	for peer_id_variant in existing_peer_ids:
		var peer_id: int = int(peer_id_variant)
		if not desired_peer_ids.has(peer_id):
			remove_remote_network_player(peer_id)


func send_local_player_snapshot_if_needed() -> void:
	_send_local_player_snapshot(false)


func send_local_player_snapshot_now() -> void:
	_send_local_player_snapshot(true)


func receive_remote_player_snapshot(payload: Dictionary, sender_peer_id: int) -> void:
	if world == null:
		return
	if sender_peer_id <= 0:
		return
	if sender_peer_id == world._get_local_network_peer_id():
		return

	var remote_player: Node = spawn_remote_network_player_for_peer(sender_peer_id)
	if remote_player == null:
		return

	var waiting_initial_snapshot: bool = bool(remote_player.get_meta("_waiting_initial_network_snapshot", false))
	if waiting_initial_snapshot:
		_apply_initial_snapshot_visual_state(remote_player, payload)

	if remote_player.has_method("apply_remote_network_snapshot"):
		remote_player.call("apply_remote_network_snapshot", payload)

	if waiting_initial_snapshot:
		remote_player.set_meta("_waiting_initial_network_snapshot", false)
		if remote_player is CanvasItem:
			(remote_player as CanvasItem).visible = true


func spawn_remote_network_player_for_peer(peer_id: int) -> Node:
	if world == null:
		return null
	if peer_id <= 0:
		return null

	var local_peer_id: int = world._get_local_network_peer_id()
	if peer_id == local_peer_id:
		return world.player

	var existing: Node = remote_players_by_peer_id.get(peer_id, null) as Node
	if existing != null and is_instance_valid(existing):
		return existing

	if world.player == null or not is_instance_valid(world.player):
		return null

	ensure_network_players_root()

	var remote_player: Node = instantiate_network_player_clone()
	if remote_player == null:
		return null

	remote_player.name = "RemotePlayer_%d" % peer_id

	if remote_player.has_method("configure_network_peer"):
		remote_player.call("configure_network_peer", local_peer_id, peer_id, peer_id, "Peer %d" % peer_id)
	if remote_player.has_method("set_network_local_player"):
		remote_player.call("set_network_local_player", false)
	if remote_player.has_method("set_network_authority_peer_id"):
		remote_player.call("set_network_authority_peer_id", peer_id)

	var spawn_position: Vector2 = get_remote_network_spawn_position(peer_id)
	if remote_player is Node2D:
		(remote_player as Node2D).global_position = spawn_position

	network_players_root.add_child(remote_player)
	_prepare_remote_network_player_instance(remote_player, peer_id, spawn_position)

	remote_players_by_peer_id[peer_id] = remote_player
	return remote_player


func remove_remote_network_player(peer_id: int) -> void:
	var remote_player: Node = remote_players_by_peer_id.get(peer_id, null) as Node
	remote_players_by_peer_id.erase(peer_id)
	if remote_player != null and is_instance_valid(remote_player):
		remote_player.queue_free()


func clear_remote_network_players() -> void:
	var peer_ids: Array = remote_players_by_peer_id.keys()
	for peer_id_variant in peer_ids:
		remove_remote_network_player(int(peer_id_variant))
	remote_players_by_peer_id.clear()


func ensure_network_players_root() -> void:
	if network_players_root != null and is_instance_valid(network_players_root):
		return
	if world == null:
		return

	var parent_node: Node = world.sortables_root
	if parent_node == null:
		parent_node = world

	var existing: Node = parent_node.get_node_or_null("NetworkPlayers")
	if existing is Node2D:
		network_players_root = existing as Node2D
		return

	var root_node := Node2D.new()
	root_node.name = "NetworkPlayers"
	parent_node.add_child(root_node)
	network_players_root = root_node


func instantiate_network_player_clone() -> Node:
	if world == null:
		return null
	if world.player == null or not is_instance_valid(world.player):
		return null

	if world.player.scene_file_path != "" and ResourceLoader.exists(world.player.scene_file_path):
		var packed_scene: PackedScene = load(world.player.scene_file_path) as PackedScene
		if packed_scene != null:
			var instance: Node = packed_scene.instantiate()
			if instance != null:
				return instance

	return world.player.duplicate()


func get_remote_network_spawn_position(peer_id: int) -> Vector2:
	if world == null:
		return Vector2.ZERO
	if not world.player is Node2D:
		return Vector2.ZERO

	var local_player_2d: Node2D = world.player as Node2D

	var peer_ids: Array[int] = []
	for key in remote_players_by_peer_id.keys():
		peer_ids.append(int(key))

	if not peer_ids.has(peer_id):
		peer_ids.append(peer_id)

	peer_ids.sort()

	var slot_index: int = peer_ids.find(peer_id) + 1
	if slot_index <= 0:
		slot_index = 1

	return local_player_2d.global_position + (world.remote_player_spawn_offset * float(slot_index))


func _send_local_player_snapshot(force_send: bool) -> void:
	if world == null:
		return
	if world.player == null or not is_instance_valid(world.player):
		return
	if not world._is_network_online():
		return
	if not world.player.has_method("get_network_snapshot_payload"):
		return

	var session_manager: Node = world.get_network_session_manager()
	var peers_variant: Variant = PackedInt32Array()
	if session_manager != null and session_manager.has_method("get_remote_peer_ids"):
		peers_variant = session_manager.call("get_remote_peer_ids")

	if peers_variant is PackedInt32Array and (peers_variant as PackedInt32Array).is_empty():
		return

	var payload_variant: Variant = world.player.call("get_network_snapshot_payload")
	if typeof(payload_variant) != TYPE_DICTIONARY:
		return

	var payload: Dictionary = payload_variant as Dictionary
	if payload.is_empty():
		return

	if force_send and world.has_method("rpc"):
		world.rpc("_rpc_receive_player_snapshot", payload)
		return

	world.rpc("_rpc_receive_player_snapshot", payload)


func _prepare_remote_network_player_instance(remote_player: Node, _peer_id: int, spawn_position: Vector2) -> void:
	if remote_player == null or not is_instance_valid(remote_player):
		return

	if remote_player is Node2D:
		var remote_player_2d: Node2D = remote_player as Node2D
		remote_player_2d.global_position = spawn_position

	if remote_player is CharacterBody2D:
		var remote_body: CharacterBody2D = remote_player as CharacterBody2D
		remote_body.velocity = Vector2.ZERO

	remote_player.set("current_interactable", null)
	remote_player.set("nearby_interactables", [])
	remote_player.set("selected_item_data", null)
	remote_player.set("selected_item_amount", 0)

	if remote_player.has_method("_reset_walk_bob_immediate"):
		remote_player.call("_reset_walk_bob_immediate")

	remote_player.remove_from_group("player")
	remote_player.add_to_group("remote_player")
	remote_player.set_meta("_waiting_initial_network_snapshot", true)

	if remote_player is CanvasItem:
		(remote_player as CanvasItem).visible = false


func _apply_initial_snapshot_visual_state(remote_player: Node, payload: Dictionary) -> void:
	if remote_player == null or not is_instance_valid(remote_player):
		return

	var snapshot_position: Vector2 = _extract_snapshot_position(payload)
	var snapshot_facing: int = int(payload.get("facing", 0))

	if remote_player is Node2D:
		(remote_player as Node2D).global_position = snapshot_position

	if remote_player is CharacterBody2D:
		var remote_body: CharacterBody2D = remote_player as CharacterBody2D
		remote_body.velocity = Vector2.ZERO

	remote_player.set("_facing", snapshot_facing)
	if remote_player.has_method("_apply_facing_visual"):
		remote_player.call("_apply_facing_visual")
	if remote_player.has_method("_reset_walk_bob_immediate"):
		remote_player.call("_reset_walk_bob_immediate")


func _extract_snapshot_position(payload: Dictionary) -> Vector2:
	return Vector2(
		float(payload.get("position_x", 0.0)),
		float(payload.get("position_y", 0.0))
	)

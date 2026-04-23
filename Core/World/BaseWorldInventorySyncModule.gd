extends RefCounted
class_name BaseWorldInventorySyncModule

var world: BaseWorld = null

func setup(owner_world: BaseWorld) -> void:
	world = owner_world

func bind_inventory_ui_to_local_player() -> void:
	if world == null:
		return
	var inventory_ui: Node = world.inventory_ui
	if inventory_ui == null or not is_instance_valid(inventory_ui):
		return
	if inventory_ui.has_method("bind_player"):
		inventory_ui.call("bind_player", world.get_local_player())

func on_network_connected() -> void:
	bind_inventory_ui_to_local_player()
	request_saved_inventory_from_authority_if_needed()

func on_network_local_peer_id_changed() -> void:
	bind_inventory_ui_to_local_player()
	request_saved_inventory_from_authority_if_needed()

func on_network_hosting_started() -> void:
	bind_inventory_ui_to_local_player()

func on_network_disconnected() -> void:
	bind_inventory_ui_to_local_player()

func request_player_inventory_sync(player_id: int, inventory_save_data: Dictionary) -> void:
	if world == null:
		return
	if player_id <= 0:
		return
	if not world._is_network_online():
		apply_player_inventory_save_data_local(player_id, inventory_save_data, true)
		return
	if world._can_accept_network_gameplay_requests():
		apply_player_inventory_save_data_local(player_id, inventory_save_data, true)
		if world.has_method("rpc"):
			world.rpc("_rpc_sync_player_inventory_data", player_id, inventory_save_data)
		return
	if world.has_method("rpc_id"):
		world.rpc_id(1, "_rpc_request_player_inventory_sync", player_id, inventory_save_data)

func apply_player_inventory_save_data_local(player_id: int, inventory_save_data: Dictionary, update_visible: bool = true) -> void:
	if world == null:
		return
	var inventory_ui: Node = world.inventory_ui
	if inventory_ui == null or not is_instance_valid(inventory_ui):
		return
	if inventory_ui.has_method("apply_player_inventory_save_data"):
		inventory_ui.call("apply_player_inventory_save_data", player_id, inventory_save_data, update_visible, false)

func request_saved_inventory_from_authority_if_needed() -> void:
	if world == null:
		return
	if not world._is_network_online():
		return
	if world._can_accept_network_gameplay_requests():
		return
	var local_player: Node = world.get_local_player()
	if local_player == null or not is_instance_valid(local_player):
		return
	var player_id: int = 0
	if local_player.has_method("get_player_id"):
		player_id = int(local_player.call("get_player_id"))
	if player_id <= 0 and local_player.has_method("get_peer_id"):
		player_id = int(local_player.call("get_peer_id"))
	if player_id <= 0:
		player_id = world._get_local_network_peer_id()
	if world.has_method("rpc_id"):
		world.rpc_id(1, "_rpc_request_saved_player_inventory", player_id)

func on_request_player_inventory_sync(player_id: int, inventory_save_data: Dictionary) -> void:
	if world == null or not world._can_accept_network_gameplay_requests():
		return
	apply_player_inventory_save_data_local(player_id, inventory_save_data, false)
	if world._is_network_online() and world.has_method("rpc"):
		world.rpc("_rpc_sync_player_inventory_data", player_id, inventory_save_data)

func on_request_saved_player_inventory(requested_player_id: int, requester_peer_id: int) -> void:
	if world == null or not world._can_accept_network_gameplay_requests():
		return
	if requester_peer_id <= 0:
		return
	var inventory_ui: Node = world.inventory_ui
	if inventory_ui == null or not is_instance_valid(inventory_ui):
		return
	if not inventory_ui.has_method("get_player_inventory_save_data"):
		return
	var inventory_save_data: Dictionary = inventory_ui.call("get_player_inventory_save_data", requested_player_id) as Dictionary
	if world._is_network_online() and world.has_method("rpc_id"):
		world.rpc_id(requester_peer_id, "_rpc_sync_player_inventory_data", requested_player_id, inventory_save_data)

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
	if not inventory_ui.has_method("bind_player"):
		return
	var local_player: Node = world.get_local_player()
	if local_player == null or not is_instance_valid(local_player):
		return
	inventory_ui.call("bind_player", local_player)


func request_player_inventory_sync(player_id: int, inventory_save_data: Dictionary) -> void:
	if world == null:
		return
	var resolved_player_id: int = max(player_id, 1)
	var normalized_inventory: Dictionary = inventory_save_data.duplicate(true)
	if not world._is_network_online():
		apply_player_inventory_save_data_local(resolved_player_id, normalized_inventory, true)
		return
	if world._can_accept_network_gameplay_requests():
		apply_player_inventory_save_data_local(resolved_player_id, normalized_inventory, true)
		return
	world.rpc_id(1, "_rpc_request_player_inventory_sync", resolved_player_id, normalized_inventory)


func request_saved_inventory_from_authority_if_needed() -> void:
	if world == null:
		return
	if not world._is_network_online():
		return
	if world._can_accept_network_gameplay_requests():
		var local_player: Node = world.get_local_player()
		if local_player == null or not is_instance_valid(local_player):
			return
		if not local_player.has_method("get_player_id"):
			return
		var host_player_id: int = max(int(local_player.call("get_player_id")), 1)
		apply_player_inventory_save_data_local(host_player_id, get_player_inventory_save_data(host_player_id), true)
		return
	world.rpc_id(1, "_rpc_request_saved_player_inventory_sync")


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


func on_request_player_inventory_sync(player_id: int, inventory_save_data: Dictionary) -> void:
	if world == null:
		return
	if not world._can_accept_network_gameplay_requests():
		return
	var sender_peer_id: int = world.multiplayer.get_remote_sender_id()
	if sender_peer_id <= 0:
		return
	var resolved_player_id: int = max(player_id, sender_peer_id)
	apply_player_inventory_save_data_local(resolved_player_id, inventory_save_data, false)


func on_request_saved_player_inventory(requester_peer_id: int) -> void:
	if world == null:
		return
	if not world._can_accept_network_gameplay_requests():
		return
	var target_peer_id: int = max(requester_peer_id, 0)
	if target_peer_id <= 0:
		return
	var inventory_save_data: Dictionary = get_player_inventory_save_data(target_peer_id)
	world.rpc_id(target_peer_id, "_rpc_apply_player_inventory_sync", target_peer_id, inventory_save_data)


func apply_player_inventory_save_data_local(player_id: int, inventory_save_data: Dictionary, update_visible: bool = true) -> void:
	if world == null:
		return
	var inventory_ui: Node = world.inventory_ui
	if inventory_ui == null or not is_instance_valid(inventory_ui):
		return
	if not inventory_ui.has_method("apply_player_inventory_save_data"):
		return
	inventory_ui.call("apply_player_inventory_save_data", player_id, inventory_save_data, update_visible, false)


func get_player_inventory_save_data(player_id: int) -> Dictionary:
	if world == null:
		return {}
	var inventory_ui: Node = world.inventory_ui
	if inventory_ui == null or not is_instance_valid(inventory_ui):
		return {}
	if not inventory_ui.has_method("get_player_inventory_save_data"):
		return {}
	var exported: Variant = inventory_ui.call("get_player_inventory_save_data", player_id)
	if typeof(exported) == TYPE_DICTIONARY:
		return exported as Dictionary
	return {}

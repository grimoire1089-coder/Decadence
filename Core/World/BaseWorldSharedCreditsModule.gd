extends RefCounted
class_name BaseWorldSharedCreditsModule

var world: BaseWorld = null


func setup(owner_world: BaseWorld) -> void:
	world = owner_world


func connect_signal() -> void:
	if CurrencyManager == null:
		return
	if CurrencyManager.has_signal("credits_changed") and not CurrencyManager.credits_changed.is_connected(_on_shared_credits_changed):
		CurrencyManager.credits_changed.connect(_on_shared_credits_changed)


func on_network_connected() -> void:
	if world == null:
		return
	if world._is_network_online() and not world._can_accept_network_gameplay_requests():
		world.rpc_id(1, "_rpc_request_shared_credits_sync")


func on_network_peer_joined(peer_id: int) -> void:
	if world == null:
		return
	if world._can_accept_network_gameplay_requests():
		push_shared_credits_to_peer(peer_id)


func sync_shared_credits_local(credits_value: int) -> void:
	if world == null:
		return
	var clamped_value: int = max(credits_value, 0)
	if CurrencyManager != null and CurrencyManager.has_method("set_credits"):
		CurrencyManager.set_credits(clamped_value)


func get_shared_credits() -> int:
	if CurrencyManager != null and CurrencyManager.has_method("get_credits"):
		return int(CurrencyManager.get_credits())
	return 0


func push_shared_credits_to_remote_peers() -> void:
	if world == null or not world._is_network_online():
		return
	world.rpc("_rpc_sync_shared_credits", get_shared_credits())


func push_shared_credits_to_peer(peer_id: int) -> void:
	if world == null or not world._is_network_online():
		return
	var target_peer_id: int = max(peer_id, 1)
	if target_peer_id == world._get_local_network_peer_id():
		sync_shared_credits_local(get_shared_credits())
		return
	world.rpc_id(target_peer_id, "_rpc_sync_shared_credits", get_shared_credits())


func _on_shared_credits_changed(_value: int) -> void:
	if world == null:
		return
	if not world._is_network_online():
		return
	if not world._can_accept_network_gameplay_requests():
		return
	push_shared_credits_to_remote_peers()

extends RefCounted
class_name PlayerNetworkController

const PLAYER_NETWORK_STATE_SCRIPT_PATH: String = "res://Gameplay/Player/PlayerNetworkState.gd"

var owner: CharacterBody2D = null
var player_network_state: PlayerNetworkState = null


func setup(owner_node: CharacterBody2D) -> void:
	owner = owner_node


func ensure_state() -> void:
	if player_network_state != null:
		return

	if not ResourceLoader.exists(PLAYER_NETWORK_STATE_SCRIPT_PATH):
		return

	var state_script: Script = load(PLAYER_NETWORK_STATE_SCRIPT_PATH) as Script
	if state_script == null:
		push_warning("PlayerNetworkController: PlayerNetworkState.gd を読み込めません")
		return

	var instance: Variant = state_script.new()
	if instance is PlayerNetworkState:
		player_network_state = instance as PlayerNetworkState
		player_network_state.set_local_remote_flags(true, false)


func configure_network_peer(local_peer_id: int, target_peer_id: int, new_player_id: int = 0, new_display_name: String = "") -> void:
	ensure_state()
	if player_network_state == null:
		return

	player_network_state.configure_from_peer(local_peer_id, target_peer_id, new_player_id, new_display_name)

	var peer_state: PlayerPeerState = _get_owner_peer_state()
	if peer_state != null:
		peer_state.configure_from_peer(local_peer_id, target_peer_id, new_player_id, new_display_name)


func set_network_local_player(value: bool) -> void:
	ensure_state()
	if player_network_state == null:
		return

	player_network_state.set_local_remote_flags(value, not value)

	var peer_state: PlayerPeerState = _get_owner_peer_state()
	if peer_state != null:
		peer_state.set_local_remote_flags(value, not value)


func set_network_authority_peer_id(value: int) -> void:
	ensure_state()
	if player_network_state == null:
		return

	player_network_state.set_authority_peer_id(value)

	var peer_state: PlayerPeerState = _get_owner_peer_state()
	if peer_state != null:
		peer_state.set_authority_peer_id(value)


func apply_remote_network_snapshot(payload: Dictionary) -> void:
	ensure_state()
	if player_network_state == null:
		return

	player_network_state.apply_snapshot_payload(payload)

	var peer_state: PlayerPeerState = _get_owner_peer_state()
	if peer_state != null:
		peer_state.apply_identity_payload(payload)

	if owner != null and owner.has_method("apply_peer_identity_payload"):
		owner.call("apply_peer_identity_payload", payload)


func export_network_spawn_payload() -> Dictionary:
	ensure_state()
	if player_network_state == null:
		return {}

	var payload: Dictionary = player_network_state.to_spawn_payload()
	var identity_payload: Dictionary = _get_owner_identity_payload()
	if not identity_payload.is_empty():
		payload.merge(identity_payload, true)
	return payload


func get_network_snapshot_payload(position: Vector2, velocity: Vector2, facing: int) -> Dictionary:
	var payload: Dictionary = {
		"player_id": get_network_player_id(),
		"peer_id": get_network_peer_id(),
		"position_x": position.x,
		"position_y": position.y,
		"velocity_x": velocity.x,
		"velocity_y": velocity.y,
		"facing": facing,
		"snapshot_time_msec": Time.get_ticks_msec(),
	}

	var identity_payload: Dictionary = _get_owner_identity_payload()
	if not identity_payload.is_empty():
		payload.merge(identity_payload, true)

	return payload


func get_network_player_id() -> int:
	ensure_state()
	if player_network_state == null:
		return 0
	return player_network_state.player_id


func get_network_peer_id() -> int:
	ensure_state()
	if player_network_state == null:
		return 0
	return player_network_state.peer_id


func is_remote_network_player() -> bool:
	if player_network_state == null:
		return false
	return player_network_state.should_accept_remote_sync()


func is_local_network_player() -> bool:
	return not is_remote_network_player()


func has_remote_snapshot() -> bool:
	return player_network_state != null and player_network_state.has_remote_snapshot


func apply_remote_position(current_position: Vector2, delta: float) -> Vector2:
	if player_network_state == null:
		return current_position
	return player_network_state.apply_remote_position(current_position, delta)


func get_remote_velocity() -> Vector2:
	if player_network_state == null:
		return Vector2.ZERO
	return player_network_state.remote_velocity


func get_remote_facing() -> int:
	if player_network_state == null:
		return -1
	return player_network_state.remote_facing


func _get_owner_peer_state() -> PlayerPeerState:
	if owner == null:
		return null
	if not owner.has_method("get_player_peer_state"):
		return null

	var state_variant: Variant = owner.call("get_player_peer_state")
	if state_variant is PlayerPeerState:
		return state_variant as PlayerPeerState
	return null


func _get_owner_identity_payload() -> Dictionary:
	if owner == null:
		return {}
	if not owner.has_method("get_network_identity_payload"):
		return {}

	var payload_variant: Variant = owner.call("get_network_identity_payload")
	if typeof(payload_variant) == TYPE_DICTIONARY:
		return payload_variant as Dictionary
	return {}

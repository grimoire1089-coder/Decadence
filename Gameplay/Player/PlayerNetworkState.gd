extends RefCounted
class_name PlayerNetworkState

signal ownership_changed(state: PlayerNetworkState)
signal remote_snapshot_received(state: PlayerNetworkState)

const INVALID_PEER_ID: int = 0
const SERVER_PEER_ID: int = 1

var player_id: int = 0
var peer_id: int = INVALID_PEER_ID
var authority_peer_id: int = SERVER_PEER_ID
var display_name: String = ""

var is_local_player: bool = false
var is_remote_player: bool = false

var has_remote_snapshot: bool = false
var remote_position: Vector2 = Vector2.ZERO
var remote_velocity: Vector2 = Vector2.ZERO
var remote_facing: int = 0
var last_snapshot_time_msec: int = 0

var interpolation_enabled: bool = true
var interpolation_speed: float = 14.0
var teleport_distance: float = 96.0


func clear() -> void:
	player_id = 0
	peer_id = INVALID_PEER_ID
	authority_peer_id = SERVER_PEER_ID
	display_name = ""
	is_local_player = false
	is_remote_player = false
	clear_remote_snapshot()
	emit_signal("ownership_changed", self)


func configure(new_player_id: int, new_peer_id: int, local_player: bool = false, remote_player: bool = false, new_display_name: String = "") -> void:
	player_id = max(new_player_id, 0)
	peer_id = max(new_peer_id, INVALID_PEER_ID)
	display_name = new_display_name.strip_edges()
	set_local_remote_flags(local_player, remote_player)


func set_authority_peer_id(value: int) -> void:
	authority_peer_id = max(value, SERVER_PEER_ID)
	emit_signal("ownership_changed", self)


func set_local_remote_flags(local_player: bool, remote_player: bool) -> void:
	is_local_player = local_player
	is_remote_player = remote_player if not local_player else false
	emit_signal("ownership_changed", self)


func configure_from_peer(local_peer_id: int, target_peer_id: int, new_player_id: int = 0, new_display_name: String = "") -> void:
	var resolved_peer_id: int = max(target_peer_id, INVALID_PEER_ID)
	player_id = max(new_player_id, 0)
	peer_id = resolved_peer_id
	display_name = new_display_name.strip_edges()
	is_local_player = local_peer_id > INVALID_PEER_ID and resolved_peer_id == local_peer_id
	is_remote_player = not is_local_player and resolved_peer_id > INVALID_PEER_ID
	emit_signal("ownership_changed", self)


func is_configured() -> bool:
	return peer_id > INVALID_PEER_ID


func is_owned_by_local_peer(local_peer_id: int) -> bool:
	return local_peer_id > INVALID_PEER_ID and peer_id == local_peer_id


func should_read_local_input() -> bool:
	return is_local_player


func should_accept_remote_sync() -> bool:
	return is_remote_player


func set_remote_snapshot(position: Vector2, velocity: Vector2 = Vector2.ZERO, facing: int = 0, snapshot_time_msec: int = 0) -> void:
	remote_position = position
	remote_velocity = velocity
	remote_facing = facing
	last_snapshot_time_msec = snapshot_time_msec if snapshot_time_msec > 0 else Time.get_ticks_msec()
	has_remote_snapshot = true
	emit_signal("remote_snapshot_received", self)


func clear_remote_snapshot() -> void:
	has_remote_snapshot = false
	remote_position = Vector2.ZERO
	remote_velocity = Vector2.ZERO
	remote_facing = 0
	last_snapshot_time_msec = 0


func should_snap_instantly(current_position: Vector2) -> bool:
	if not has_remote_snapshot:
		return false
	return current_position.distance_to(remote_position) >= teleport_distance


func apply_remote_position(current_position: Vector2, delta: float) -> Vector2:
	if not has_remote_snapshot:
		return current_position

	if not interpolation_enabled or delta <= 0.0 or should_snap_instantly(current_position):
		return remote_position

	var weight: float = clampf(delta * interpolation_speed, 0.0, 1.0)
	return current_position.lerp(remote_position, weight)


func to_spawn_payload() -> Dictionary:
	return {
		"player_id": player_id,
		"peer_id": peer_id,
		"authority_peer_id": authority_peer_id,
		"display_name": display_name,
		"is_local_player": is_local_player,
		"is_remote_player": is_remote_player,
	}


func to_snapshot_payload() -> Dictionary:
	return {
		"player_id": player_id,
		"peer_id": peer_id,
		"position_x": remote_position.x,
		"position_y": remote_position.y,
		"velocity_x": remote_velocity.x,
		"velocity_y": remote_velocity.y,
		"facing": remote_facing,
		"snapshot_time_msec": last_snapshot_time_msec,
	}


func apply_spawn_payload(payload: Dictionary, local_peer_id: int = INVALID_PEER_ID) -> void:
	player_id = max(int(payload.get("player_id", player_id)), 0)
	peer_id = max(int(payload.get("peer_id", peer_id)), INVALID_PEER_ID)
	authority_peer_id = max(int(payload.get("authority_peer_id", SERVER_PEER_ID)), SERVER_PEER_ID)
	display_name = String(payload.get("display_name", display_name)).strip_edges()

	if payload.has("is_local_player") or payload.has("is_remote_player"):
		set_local_remote_flags(
			bool(payload.get("is_local_player", false)),
			bool(payload.get("is_remote_player", false))
		)
	else:
		configure_from_peer(local_peer_id, peer_id, player_id, display_name)


func apply_snapshot_payload(payload: Dictionary) -> void:
	set_remote_snapshot(
		Vector2(
			float(payload.get("position_x", remote_position.x)),
			float(payload.get("position_y", remote_position.y))
		),
		Vector2(
			float(payload.get("velocity_x", remote_velocity.x)),
			float(payload.get("velocity_y", remote_velocity.y))
		),
		int(payload.get("facing", remote_facing)),
		int(payload.get("snapshot_time_msec", 0))
	)

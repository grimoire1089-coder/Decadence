extends RefCounted
class_name PlayerPeerState

signal identity_changed(state: PlayerPeerState)
signal ownership_changed(state: PlayerPeerState)

const INVALID_PEER_ID: int = 0
const SERVER_PEER_ID: int = 1

var player_id: int = 0
var peer_id: int = INVALID_PEER_ID
var authority_peer_id: int = SERVER_PEER_ID
var display_name: String = ""

var is_local_player: bool = false
var is_remote_player: bool = false

var selected_item_id: String = ""
var current_interactable_path: NodePath = NodePath("")

var appearance_front_texture_path: String = ""
var appearance_back_texture_path: String = ""
var appearance_side_texture_path: String = ""

var metadata: Dictionary = {}


func clear() -> void:
	player_id = 0
	peer_id = INVALID_PEER_ID
	authority_peer_id = SERVER_PEER_ID
	display_name = ""
	is_local_player = false
	is_remote_player = false
	selected_item_id = ""
	current_interactable_path = NodePath("")
	appearance_front_texture_path = ""
	appearance_back_texture_path = ""
	appearance_side_texture_path = ""
	metadata.clear()
	emit_signal("ownership_changed", self)
	emit_signal("identity_changed", self)


func configure_from_peer(local_peer_id: int, target_peer_id: int, new_player_id: int = 0, new_display_name: String = "") -> void:
	var resolved_peer_id: int = max(target_peer_id, INVALID_PEER_ID)
	player_id = max(new_player_id, 0)
	peer_id = resolved_peer_id
	if not new_display_name.strip_edges().is_empty():
		display_name = new_display_name.strip_edges()

	is_local_player = local_peer_id > INVALID_PEER_ID and resolved_peer_id == local_peer_id
	is_remote_player = not is_local_player and resolved_peer_id > INVALID_PEER_ID

	emit_signal("ownership_changed", self)
	emit_signal("identity_changed", self)


func set_local_remote_flags(local_player: bool, remote_player: bool) -> void:
	is_local_player = local_player
	is_remote_player = remote_player if not local_player else false
	emit_signal("ownership_changed", self)


func set_authority_peer_id(value: int) -> void:
	authority_peer_id = max(value, SERVER_PEER_ID)
	emit_signal("ownership_changed", self)


func set_display_name(value: String) -> void:
	var normalized_value: String = value.strip_edges()
	if display_name == normalized_value:
		return
	display_name = normalized_value
	emit_signal("identity_changed", self)


func set_selected_item_id(value: String) -> void:
	var normalized_value: String = value.strip_edges()
	if selected_item_id == normalized_value:
		return
	selected_item_id = normalized_value
	emit_signal("identity_changed", self)


func set_current_interactable_path(value: NodePath) -> void:
	if current_interactable_path == value:
		return
	current_interactable_path = value
	emit_signal("identity_changed", self)


func set_appearance_paths(front_path: String, back_path: String, side_path: String) -> void:
	var normalized_front: String = front_path.strip_edges()
	var normalized_back: String = back_path.strip_edges()
	var normalized_side: String = side_path.strip_edges()

	if (
		appearance_front_texture_path == normalized_front
		and appearance_back_texture_path == normalized_back
		and appearance_side_texture_path == normalized_side
	):
		return

	appearance_front_texture_path = normalized_front
	appearance_back_texture_path = normalized_back
	appearance_side_texture_path = normalized_side
	emit_signal("identity_changed", self)


func to_identity_payload() -> Dictionary:
	return {
		"player_id": player_id,
		"peer_id": peer_id,
		"authority_peer_id": authority_peer_id,
		"display_name": display_name,
		"is_local_player": is_local_player,
		"is_remote_player": is_remote_player,
		"selected_item_id": selected_item_id,
		"current_interactable_path": str(current_interactable_path),
		"appearance_front_texture_path": appearance_front_texture_path,
		"appearance_back_texture_path": appearance_back_texture_path,
		"appearance_side_texture_path": appearance_side_texture_path,
	}


func apply_identity_payload(payload: Dictionary) -> void:
	player_id = max(int(payload.get("player_id", player_id)), 0)
	peer_id = max(int(payload.get("peer_id", peer_id)), INVALID_PEER_ID)
	authority_peer_id = max(int(payload.get("authority_peer_id", authority_peer_id)), SERVER_PEER_ID)

	if payload.has("display_name"):
		display_name = String(payload.get("display_name", display_name)).strip_edges()

	if payload.has("is_local_player") or payload.has("is_remote_player"):
		set_local_remote_flags(
			bool(payload.get("is_local_player", is_local_player)),
			bool(payload.get("is_remote_player", is_remote_player))
		)

	if payload.has("selected_item_id"):
		selected_item_id = String(payload.get("selected_item_id", selected_item_id)).strip_edges()

	if payload.has("current_interactable_path"):
		current_interactable_path = NodePath(String(payload.get("current_interactable_path", str(current_interactable_path))))

	set_appearance_paths(
		String(payload.get("appearance_front_texture_path", appearance_front_texture_path)),
		String(payload.get("appearance_back_texture_path", appearance_back_texture_path)),
		String(payload.get("appearance_side_texture_path", appearance_side_texture_path))
	)

	emit_signal("identity_changed", self)

extends RefCounted
class_name PlayerSpawnConfig

const DEFAULT_PLAYER_ID_PREFIX: String = "player_"

var player_id: String = ""
var peer_id: int = 1
var authority_peer_id: int = 1
var display_name: String = ""
var player_scene_path: String = ""
var spawn_position: Vector2 = Vector2.ZERO
var spawn_map_scene_path: String = ""
var spawn_id: String = ""
var is_local_player: bool = false
var is_remote_player: bool = false


func configure(
		configured_player_id: String,
		configured_peer_id: int,
		configured_authority_peer_id: int,
		configured_display_name: String,
		configured_player_scene_path: String,
		configured_spawn_position: Vector2,
		configured_spawn_map_scene_path: String = "",
		configured_spawn_id: String = "",
		configured_is_local_player: bool = false,
		configured_is_remote_player: bool = false
) -> PlayerSpawnConfig:
	player_id = _normalize_player_id(configured_player_id, configured_peer_id)
	peer_id = max(configured_peer_id, 1)
	authority_peer_id = max(configured_authority_peer_id, 1)
	display_name = configured_display_name.strip_edges()
	player_scene_path = configured_player_scene_path.strip_edges()
	spawn_position = configured_spawn_position
	spawn_map_scene_path = configured_spawn_map_scene_path.strip_edges()
	spawn_id = configured_spawn_id.strip_edges()
	is_local_player = configured_is_local_player
	is_remote_player = configured_is_remote_player
	_normalize_local_remote_flags()
	return self


func configure_from_peer(
		configured_peer_id: int,
		configured_player_scene_path: String,
		configured_spawn_position: Vector2,
		configured_spawn_map_scene_path: String = "",
		configured_spawn_id: String = "",
		configured_is_local_player: bool = false
) -> PlayerSpawnConfig:
	return configure(
		"",
		configured_peer_id,
		configured_peer_id,
		"",
		configured_player_scene_path,
		configured_spawn_position,
		configured_spawn_map_scene_path,
		configured_spawn_id,
		configured_is_local_player,
		not configured_is_local_player
	)


func duplicate_config() -> PlayerSpawnConfig:
	var copy := PlayerSpawnConfig.new()
	copy.configure(
		player_id,
		peer_id,
		authority_peer_id,
		display_name,
		player_scene_path,
		spawn_position,
		spawn_map_scene_path,
		spawn_id,
		is_local_player,
		is_remote_player
	)
	return copy


func is_valid() -> bool:
	return peer_id > 0 and authority_peer_id > 0 and not player_id.is_empty()


func has_explicit_scene_path() -> bool:
	return not player_scene_path.is_empty()


func resolve_player_scene_path(default_scene_path: String = "") -> String:
	if not player_scene_path.is_empty():
		return player_scene_path
	return default_scene_path.strip_edges()


func to_payload() -> Dictionary:
	return {
		"player_id": player_id,
		"peer_id": peer_id,
		"authority_peer_id": authority_peer_id,
		"display_name": display_name,
		"player_scene_path": player_scene_path,
		"spawn_position": {
			"x": spawn_position.x,
			"y": spawn_position.y,
		},
		"spawn_map_scene_path": spawn_map_scene_path,
		"spawn_id": spawn_id,
		"is_local_player": is_local_player,
		"is_remote_player": is_remote_player,
	}


func apply_payload(payload: Dictionary) -> PlayerSpawnConfig:
	var configured_spawn_position: Vector2 = _read_vector2(payload.get("spawn_position", {}), Vector2.ZERO)
	return configure(
		String(payload.get("player_id", "")),
		int(payload.get("peer_id", 1)),
		int(payload.get("authority_peer_id", int(payload.get("peer_id", 1)))),
		String(payload.get("display_name", "")),
		String(payload.get("player_scene_path", "")),
		configured_spawn_position,
		String(payload.get("spawn_map_scene_path", "")),
		String(payload.get("spawn_id", "")),
		_as_bool(payload.get("is_local_player", false)),
		_as_bool(payload.get("is_remote_player", false))
	)


func get_spawn_position_dictionary() -> Dictionary:
	return {
		"x": spawn_position.x,
		"y": spawn_position.y,
	}


func _normalize_player_id(source_player_id: String, source_peer_id: int) -> String:
	var normalized_player_id: String = source_player_id.strip_edges()
	if not normalized_player_id.is_empty():
		return normalized_player_id
	return "%s%d" % [DEFAULT_PLAYER_ID_PREFIX, max(source_peer_id, 1)]


func _normalize_local_remote_flags() -> void:
	if is_local_player and is_remote_player:
		is_remote_player = false
	elif not is_local_player and not is_remote_player:
		is_remote_player = true


func _read_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value

	if value is Dictionary:
		var dict_value: Dictionary = value as Dictionary
		return Vector2(
			float(dict_value.get("x", fallback.x)),
			float(dict_value.get("y", fallback.y))
		)

	return fallback


func _as_bool(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			return value != 0
		TYPE_FLOAT:
			return not is_zero_approx(value)
		TYPE_STRING, TYPE_STRING_NAME:
			var text: String = String(value).strip_edges().to_lower()
			if text in ["true", "1", "yes", "on"]:
				return true
			if text in ["false", "0", "no", "off", ""]:
				return false
	return false

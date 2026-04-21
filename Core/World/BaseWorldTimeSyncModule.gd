extends RefCounted
class_name BaseWorldTimeSyncModule

const DEFAULT_TIME_SYNC_INTERVAL_SEC: float = 0.25
const NETWORK_HOST_PAUSE_SOURCE: String = "__network_host_pause__"
const NETWORK_CLIENT_AUTHORITY_PAUSE_SOURCE: String = "__network_client_authority_pause__"

var _world: BaseWorld = null
var _sync_accumulator: float = 0.0


func setup(world_owner: BaseWorld) -> void:
	_world = world_owner
	_sync_accumulator = 0.0


func process(delta: float) -> void:
	if _world == null:
		return
	if not _world._is_network_online():
		return
	if not _world._can_accept_network_gameplay_requests():
		return

	_sync_accumulator += maxf(delta, 0.0)
	if _sync_accumulator < _get_sync_interval_sec():
		return

	_sync_accumulator = 0.0
	push_current_time_state_to_peers()


func on_network_peer_joined(peer_id: int) -> void:
	_sync_accumulator = 0.0
	if _world == null:
		return
	if not _world._can_accept_network_gameplay_requests():
		return
	push_current_time_state_to_peer(peer_id)


func on_network_connected_to_session() -> void:
	_sync_accumulator = 0.0
	if _world == null:
		return

	var time_manager: Node = _get_time_manager()
	if time_manager != null and not _world._can_accept_network_gameplay_requests():
		_request_client_authority_pause(time_manager)

	if _world._can_accept_network_gameplay_requests():
		push_current_time_state_to_peers()


func on_network_disconnected_from_session() -> void:
	_sync_accumulator = 0.0
	var time_manager: Node = _get_time_manager()
	if time_manager == null:
		return
	_clear_network_pause_sources(time_manager)


func on_network_local_peer_id_changed() -> void:
	_sync_accumulator = 0.0
	if _world == null:
		return

	var time_manager: Node = _get_time_manager()
	if time_manager != null:
		if _world._can_accept_network_gameplay_requests():
			_release_client_authority_pause(time_manager)
		else:
			_request_client_authority_pause(time_manager)

	if _world._can_accept_network_gameplay_requests():
		push_current_time_state_to_peers()


func on_network_hosting_started() -> void:
	_sync_accumulator = 0.0
	if _world == null:
		return

	var time_manager: Node = _get_time_manager()
	if time_manager != null:
		_release_client_authority_pause(time_manager)

	if _world._can_accept_network_gameplay_requests():
		push_current_time_state_to_peers()


func resume_time_manager() -> void:
	var time_manager: Node = _get_time_manager()
	if time_manager == null:
		return

	if time_manager.has_method("start_time"):
		time_manager.call("start_time")
		return

	if time_manager.has_method("set_time_running"):
		time_manager.call("set_time_running", true)
		return

	for property_info in time_manager.get_property_list():
		if String(property_info.get("name", "")) == "is_running":
			time_manager.set("is_running", true)
			return


func build_current_time_state() -> Dictionary:
	var time_manager: Node = _get_time_manager()
	if time_manager == null:
		return {}

	if time_manager.has_method("export_network_state"):
		var state_variant: Variant = time_manager.call("export_network_state")
		if typeof(state_variant) == TYPE_DICTIONARY:
			return (state_variant as Dictionary).duplicate(true)

	var state: Dictionary = {}
	state["day"] = int(time_manager.get("day"))
	state["hour"] = int(time_manager.get("hour"))
	state["minute"] = int(time_manager.get("minute"))
	state["is_running"] = bool(time_manager.get("is_running"))
	state["real_seconds_per_game_minute"] = float(time_manager.get("real_seconds_per_game_minute"))
	if time_manager.has_method("is_time_paused"):
		state["is_paused"] = bool(time_manager.call("is_time_paused"))
	else:
		state["is_paused"] = false
	return state


func push_current_time_state_to_peers() -> void:
	if _world == null:
		return
	if not _world._is_network_online():
		return
	if not _world._can_accept_network_gameplay_requests():
		return

	var state: Dictionary = build_current_time_state()
	if state.is_empty():
		return

	_world.rpc("_rpc_sync_world_time_state", state)


func push_current_time_state_to_peer(peer_id: int) -> void:
	if _world == null:
		return
	if peer_id <= 0:
		return
	if not _world._is_network_online():
		return
	if not _world._can_accept_network_gameplay_requests():
		return

	var state: Dictionary = build_current_time_state()
	if state.is_empty():
		return

	if peer_id == _world._get_local_network_peer_id():
		apply_remote_time_state(state)
		return

	_world.rpc_id(peer_id, "_rpc_sync_world_time_state", state)


func apply_remote_time_state(state: Dictionary) -> void:
	var time_manager: Node = _get_time_manager()
	if time_manager == null or state.is_empty():
		return

	if time_manager.has_method("import_network_state"):
		time_manager.call("import_network_state", state)
		_request_client_authority_pause(time_manager)
		return

	_apply_time_state_fallback(time_manager, state)


func _get_sync_interval_sec() -> float:
	if _world == null:
		return DEFAULT_TIME_SYNC_INTERVAL_SEC
	return maxf(float(_world.network_time_sync_interval_sec), 0.05)


func _get_time_manager() -> Node:
	if _world == null:
		return null

	var time_manager: Node = _world.get_node_or_null("/root/TimeManager")
	if time_manager != null:
		return time_manager

	return _world.get_tree().get_first_node_in_group("time_manager")


func _apply_time_state_fallback(time_manager: Node, state: Dictionary) -> void:
	var next_wait_time: float = max(float(state.get("real_seconds_per_game_minute", time_manager.get("real_seconds_per_game_minute"))), 0.001)
	if float(time_manager.get("real_seconds_per_game_minute")) != next_wait_time:
		time_manager.set("real_seconds_per_game_minute", next_wait_time)
	var tick_timer: Timer = time_manager.get("tick_timer") as Timer
	if tick_timer != null and tick_timer.wait_time != next_wait_time:
		tick_timer.wait_time = next_wait_time

	var next_day: int = int(state.get("day", time_manager.get("day")))
	var next_hour: int = int(state.get("hour", time_manager.get("hour")))
	var next_minute: int = int(state.get("minute", time_manager.get("minute")))
	var current_day: int = int(time_manager.get("day"))
	var current_hour: int = int(time_manager.get("hour"))
	var current_minute: int = int(time_manager.get("minute"))
	var time_changed: bool = next_day != current_day or next_hour != current_hour or next_minute != current_minute
	if time_changed:
		if time_manager.has_method("set_time"):
			time_manager.call("set_time", next_day, next_hour, next_minute)
		else:
			time_manager.set("day", next_day)
			time_manager.set("hour", clampi(next_hour, 0, 23))
			time_manager.set("minute", clampi(next_minute, 0, 59))
			if time_manager.has_method("_update_period"):
				time_manager.call("_update_period")
			if time_manager.has_method("_emit_time_changed"):
				time_manager.call("_emit_time_changed")

	var next_running: bool = bool(state.get("is_running", time_manager.get("is_running")))
	if bool(time_manager.get("is_running")) != next_running:
		if time_manager.has_method("set_time_running"):
			time_manager.call("set_time_running", next_running)
		elif time_manager.has_method("start_time") and next_running:
			time_manager.call("start_time")
		elif time_manager.has_method("stop_time") and not next_running:
			time_manager.call("stop_time")
		else:
			time_manager.set("is_running", next_running)

	var host_paused: bool = bool(state.get("is_paused", false))
	if host_paused:
		_request_network_host_pause(time_manager)
	else:
		_release_network_host_pause(time_manager)

	_request_client_authority_pause(time_manager)


func _request_network_host_pause(time_manager: Node) -> void:
	_request_pause_source(time_manager, NETWORK_HOST_PAUSE_SOURCE)


func _release_network_host_pause(time_manager: Node) -> void:
	_release_pause_source(time_manager, NETWORK_HOST_PAUSE_SOURCE)


func _request_client_authority_pause(time_manager: Node) -> void:
	if _world == null:
		return
	if not _world._is_network_online():
		return
	if _world._can_accept_network_gameplay_requests():
		_release_pause_source(time_manager, NETWORK_CLIENT_AUTHORITY_PAUSE_SOURCE)
		return
	_request_pause_source(time_manager, NETWORK_CLIENT_AUTHORITY_PAUSE_SOURCE)


func _release_client_authority_pause(time_manager: Node) -> void:
	_release_pause_source(time_manager, NETWORK_CLIENT_AUTHORITY_PAUSE_SOURCE)


func _clear_network_pause_sources(time_manager: Node) -> void:
	_release_network_host_pause(time_manager)
	_release_client_authority_pause(time_manager)


func _request_pause_source(time_manager: Node, source: String) -> void:
	if time_manager.has_method("request_pause"):
		time_manager.call("request_pause", source)
	elif time_manager.has_method("pause_time"):
		time_manager.call("pause_time", source)


func _release_pause_source(time_manager: Node, source: String) -> void:
	if time_manager.has_method("release_pause"):
		time_manager.call("release_pause", source)
	elif time_manager.has_method("resume_time"):
		time_manager.call("resume_time", source)

extends CharacterBody2D

@warning_ignore("unused_signal")
signal interactable_changed(target)

const UI_MODAL_MANAGER_SCRIPT_NAME: String = "UIModalManager.gd"
const PAUSE_MENU_SCENE_PATH: String = "res://UI/PauseMenuUI.tscn"
const DEBUG_SAVE_SLOT_NAME: String = "slot_01"
const PLAYER_PEER_STATE_SCRIPT_PATH: String = "res://Gameplay/Player/PlayerPeerState.gd"
const PLAYER_NETWORK_CONTROLLER_SCRIPT_PATH: String = "res://Gameplay/Player/PlayerNetworkController.gd"
const PLAYER_INPUT_CONTROLLER_SCRIPT_PATH: String = "res://Gameplay/Player/PlayerInputController.gd"
const PLAYER_SUPPORT_CONTROLLER_SCRIPT_PATH: String = "res://Gameplay/Player/PlayerSupportController.gd"
const PLAYER_INTERACTION_CONTROLLER_SCRIPT_PATH: String = "res://Gameplay/Player/PlayerInteractionController.gd"
const PLAYER_MOTION_CONTROLLER_SCRIPT_PATH: String = "res://Gameplay/Player/PlayerMotionController.gd"
const PLAYER_NAMEPLATE_CONTROLLER_SCRIPT_PATH: String = "res://Gameplay/Player/PlayerNameplateController.gd"
const MODAL_UI_GROUPS: Array[StringName] = [
	&"vending_ui",
	&"crop_machine_ui",
	&"skill_ui",
	&"npc_dialog_ui",
	&"pause_menu_ui"
]

@export_group("Identity")
@export var default_display_name: String = "Robin"
@export_node_path("Node2D") var nameplate_root_path: NodePath = NodePath("NameplateRoot")
@export_node_path("Label") var nameplate_label_path: NodePath = NodePath("NameplateRoot/Label")

@export var speed: float = 220.0
@export_node_path("Sprite2D") var sprite_path: NodePath = NodePath("Sprite2D")
@export var front_texture: Texture2D
@export var back_texture: Texture2D
@export var side_texture: Texture2D
@export var flip_side_for_left: bool = true

@export_group("Walk Bob")
@export var walk_bob_enabled: bool = true
@export var walk_bob_speed: float = 10.0
@export var walk_bob_side_amount: float = 2.0
@export var walk_bob_up_amount: float = 1.5
@export var walk_bob_tilt_degrees: float = 2.0
@export var walk_bob_return_speed: float = 12.0

enum Facing {
	DOWN,
	UP,
	RIGHT,
	LEFT
}

@warning_ignore("unused_private_class_variable")
var _player_sprite: Sprite2D = null
var _facing: int = Facing.DOWN
@warning_ignore("unused_private_class_variable")
var _sprite_base_position: Vector2 = Vector2.ZERO
@warning_ignore("unused_private_class_variable")
var _walk_anim_time: float = 0.0
var _input_locked: bool = false

var current_interactable: Node2D = null
var nearby_interactables: Array = []

var selected_item_data: Resource = null
var selected_item_amount: int = 0

var player_peer_state: PlayerPeerState = null
var player_network_controller: PlayerNetworkController = null
var player_input_controller: PlayerInputController = null
var player_support_controller: PlayerSupportController = null
var player_interaction_controller: PlayerInteractionController = null
var player_motion_controller: PlayerMotionController = null
var player_nameplate_controller: PlayerNameplateController = null


func _ready() -> void:
	refresh_from_stats()
	_ensure_player_motion_controller()
	_resolve_player_sprite()
	_ensure_player_peer_state()
	_sync_peer_identity_from_visuals()
	_ensure_player_nameplate_controller()
	_refresh_nameplate()
	_ensure_player_network_controller()

	if _is_remote_network_player():
		remove_from_group("player")
		add_to_group("remote_player")
		_refresh_nameplate()
		return

	_ensure_player_input_controller()
	_ensure_player_support_controller()
	_ensure_player_interaction_controller()

	add_to_group("player")
	_refresh_nameplate()

	if PlayerStatsManager != null and not PlayerStatsManager.stats_changed.is_connected(_on_player_stats_changed):
		PlayerStatsManager.stats_changed.connect(_on_player_stats_changed)

	call_deferred("_ensure_pause_menu_exists")


func _exit_tree() -> void:
	if PlayerStatsManager != null and PlayerStatsManager.stats_changed.is_connected(_on_player_stats_changed):
		PlayerStatsManager.stats_changed.disconnect(_on_player_stats_changed)


func _physics_process(delta: float) -> void:
	if _is_remote_network_player():
		_update_remote_network_player(delta)
		return

	if _is_player_control_locked():
		velocity = Vector2.ZERO
		move_and_slide()
		_update_current_interactable()
		_update_walk_bob(delta)
		return

	var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_facing_from_direction(direction)
	velocity = direction * speed
	move_and_slide()

	_update_current_interactable()
	_update_walk_bob(delta)


func _resolve_player_sprite() -> void:
	_ensure_player_motion_controller()
	if player_motion_controller != null:
		player_motion_controller.resolve_player_sprite()


func _update_facing_from_direction(direction: Vector2) -> void:
	_ensure_player_motion_controller()
	if player_motion_controller != null:
		player_motion_controller.update_facing_from_direction(direction)


func _apply_facing_visual() -> void:
	_ensure_player_motion_controller()
	if player_motion_controller != null:
		player_motion_controller.apply_facing_visual()


func _update_walk_bob(delta: float) -> void:
	_ensure_player_motion_controller()
	if player_motion_controller != null:
		player_motion_controller.update_walk_bob(delta)


func _reset_walk_bob_smooth(delta: float) -> void:
	_ensure_player_motion_controller()
	if player_motion_controller != null:
		player_motion_controller.reset_walk_bob_smooth(delta)


func _reset_walk_bob_immediate() -> void:
	_ensure_player_motion_controller()
	if player_motion_controller != null:
		player_motion_controller.reset_walk_bob_immediate()


func _safe_set_input_as_handled() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if player_input_controller != null and player_input_controller.handle_unhandled_input(event):
		return


func _is_interaction_ui_open() -> bool:
	_ensure_player_interaction_controller()
	if player_interaction_controller == null:
		return false
	return player_interaction_controller.is_interaction_ui_open()


func _is_player_control_locked() -> bool:
	_ensure_player_interaction_controller()
	if player_interaction_controller == null:
		return _input_locked
	return player_interaction_controller.is_player_control_locked()


func _is_any_modal_ui_visible() -> bool:
	_ensure_player_interaction_controller()
	if player_interaction_controller == null:
		return false
	return player_interaction_controller.is_any_modal_ui_visible()


func _has_non_pause_modal_visible() -> bool:
	_ensure_player_interaction_controller()
	if player_interaction_controller == null:
		return false
	return player_interaction_controller.has_non_pause_modal_visible()


func _get_pause_menu_ui() -> Control:
	_ensure_player_interaction_controller()
	if player_interaction_controller == null:
		return null
	return player_interaction_controller.get_pause_menu_ui()


func _ensure_pause_menu_exists() -> Control:
	_ensure_player_interaction_controller()
	if player_interaction_controller == null:
		return null
	return player_interaction_controller.ensure_pause_menu_exists()


func _find_ui_modal_manager() -> Node:
	_ensure_player_interaction_controller()
	if player_interaction_controller == null:
		return null
	return player_interaction_controller.find_ui_modal_manager()


func _on_player_stats_changed() -> void:
	refresh_from_stats()


func refresh_from_stats() -> void:
	if PlayerStatsManager == null:
		return

	var base_move_speed: float = 220.0 + float(PlayerStatsManager.get_stat("agility") * 4)
	var hunger_multiplier: float = 1.0
	var fatigue_multiplier: float = 1.0

	match PlayerStatsManager.get_hunger_state():
		PlayerStatsManager.HungerState.WELL_FED:
			hunger_multiplier = 1.05
		PlayerStatsManager.HungerState.NORMAL:
			hunger_multiplier = 1.0
		PlayerStatsManager.HungerState.HUNGRY:
			hunger_multiplier = 0.92
		PlayerStatsManager.HungerState.STARVING:
			hunger_multiplier = 0.85

	match PlayerStatsManager.get_fatigue_state():
		PlayerStatsManager.FatigueState.RESTED:
			fatigue_multiplier = 1.02
		PlayerStatsManager.FatigueState.NORMAL:
			fatigue_multiplier = 1.0
		PlayerStatsManager.FatigueState.TIRED:
			fatigue_multiplier = 0.90
		PlayerStatsManager.FatigueState.EXHAUSTED:
			fatigue_multiplier = 0.78

	speed = base_move_speed * hunger_multiplier * fatigue_multiplier


func get_stat_value(stat_name: String) -> int:
	_ensure_player_support_controller()
	if player_support_controller == null:
		return 0
	return player_support_controller.get_stat_value(stat_name)


func get_skill_value(skill_name: String) -> int:
	_ensure_player_support_controller()
	if player_support_controller == null:
		return 0
	return player_support_controller.get_skill_value(skill_name)


func add_fatigue_for_action(action_name: String, multiplier: float = 1.0, write_log: bool = false) -> int:
	_ensure_player_support_controller()
	if player_support_controller == null:
		return 0
	return player_support_controller.add_fatigue_for_action(action_name, multiplier, write_log)


func register_interactable(target: Node2D) -> void:
	_ensure_player_interaction_controller()
	if player_interaction_controller != null:
		player_interaction_controller.register_interactable(target)


func unregister_interactable(target: Node2D) -> void:
	_ensure_player_interaction_controller()
	if player_interaction_controller != null:
		player_interaction_controller.unregister_interactable(target)


func _update_current_interactable() -> void:
	_ensure_player_interaction_controller()
	if player_interaction_controller != null:
		player_interaction_controller.update_current_interactable()


func set_selected_item(item_data: Resource, amount: int) -> void:
	_ensure_player_support_controller()
	if player_support_controller != null:
		player_support_controller.set_selected_item(item_data, amount)
	_update_selected_item_peer_state()


func clear_selected_item() -> void:
	_ensure_player_support_controller()
	if player_support_controller != null:
		player_support_controller.clear_selected_item()
	_update_selected_item_peer_state()


func try_consume_selected_item() -> bool:
	_ensure_player_support_controller()
	if player_support_controller == null:
		return false
	return player_support_controller.try_consume_selected_item()


func add_item_to_inventory(item_data: Resource, amount: int) -> bool:
	_ensure_player_support_controller()
	if player_support_controller == null:
		return false
	return player_support_controller.add_item_to_inventory(item_data, amount)


func remove_item_from_inventory(item_data: Resource, amount: int) -> bool:
	_ensure_player_support_controller()
	if player_support_controller == null:
		return false
	return player_support_controller.remove_item_from_inventory(item_data, amount)


func get_inventory_count(item_data: Resource) -> int:
	_ensure_player_support_controller()
	if player_support_controller == null:
		return 0
	return player_support_controller.get_inventory_count(item_data)


func add_credits(amount: int) -> void:
	_ensure_player_support_controller()
	if player_support_controller != null:
		player_support_controller.add_credits(amount)


func get_credits() -> int:
	_ensure_player_support_controller()
	if player_support_controller == null:
		return 0
	return player_support_controller.get_credits()


func can_spend_credits(amount: int) -> bool:
	_ensure_player_support_controller()
	if player_support_controller == null:
		return false
	return player_support_controller.can_spend_credits(amount)


func spend_credits(amount: int) -> bool:
	_ensure_player_support_controller()
	if player_support_controller == null:
		return false
	return player_support_controller.spend_credits(amount)


func addCredit(amount: int) -> void:
	add_credits(amount)


func getCredit() -> int:
	return get_credits()


func spendCredit(amount: int) -> bool:
	return spend_credits(amount)


func configure_network_peer(local_peer_id: int, target_peer_id: int, new_player_id: int = 0, new_display_name: String = "") -> void:
	_ensure_player_peer_state()
	_ensure_player_network_controller()
	if player_network_controller == null:
		return
	player_network_controller.configure_network_peer(local_peer_id, target_peer_id, new_player_id, new_display_name)


func set_network_local_player(value: bool) -> void:
	_ensure_player_peer_state()
	_ensure_player_network_controller()
	if player_network_controller == null:
		return
	player_network_controller.set_network_local_player(value)


func set_network_authority_peer_id(value: int) -> void:
	_ensure_player_peer_state()
	_ensure_player_network_controller()
	if player_network_controller == null:
		return
	player_network_controller.set_network_authority_peer_id(value)


func apply_remote_network_snapshot(payload: Dictionary) -> void:
	_ensure_player_peer_state()
	_ensure_player_network_controller()
	if player_network_controller == null:
		return
	player_network_controller.apply_remote_network_snapshot(payload)


func apply_peer_identity_payload(payload: Dictionary) -> void:
	_ensure_player_peer_state()
	if player_peer_state == null:
		return

	player_peer_state.apply_identity_payload(payload)

	var incoming_display_name: String = String(payload.get("display_name", "")).strip_edges()
	if not incoming_display_name.is_empty():
		default_display_name = incoming_display_name

	_apply_appearance_paths(
		String(payload.get("appearance_front_texture_path", "")),
		String(payload.get("appearance_back_texture_path", "")),
		String(payload.get("appearance_side_texture_path", ""))
	)
	_refresh_nameplate()


func export_network_spawn_payload() -> Dictionary:
	_ensure_player_network_controller()
	if player_network_controller == null:
		return {}
	return player_network_controller.export_network_spawn_payload()


func get_network_snapshot_payload() -> Dictionary:
	_ensure_player_network_controller()
	if player_network_controller == null:
		return {}
	return player_network_controller.get_network_snapshot_payload(global_position, velocity, _facing)


func get_network_identity_payload() -> Dictionary:
	_ensure_player_peer_state()
	if player_peer_state == null:
		return {}

	_sync_peer_identity_from_visuals()
	var payload: Dictionary = player_peer_state.to_identity_payload()
	payload["display_name"] = get_player_display_name()
	return payload


func get_current_facing() -> int:
	return _facing


func get_network_player_id() -> int:
	_ensure_player_network_controller()
	if player_network_controller == null:
		return 0
	return player_network_controller.get_network_player_id()


func get_network_peer_id() -> int:
	_ensure_player_network_controller()
	if player_network_controller == null:
		return 0
	return player_network_controller.get_network_peer_id()


func get_player_id() -> int:
	_ensure_player_peer_state()
	if player_peer_state == null:
		return 0
	return player_peer_state.player_id


func get_peer_id() -> int:
	_ensure_player_peer_state()
	if player_peer_state == null:
		return 0
	return player_peer_state.peer_id


func get_player_display_name() -> String:
	_ensure_player_peer_state()
	if player_peer_state != null and not player_peer_state.display_name.is_empty():
		return player_peer_state.display_name
	return default_display_name.strip_edges()


func set_player_display_name(value: String) -> void:
	default_display_name = value.strip_edges()
	_ensure_player_peer_state()
	if player_peer_state != null:
		player_peer_state.set_display_name(default_display_name)
	_refresh_nameplate()


func get_player_peer_state() -> PlayerPeerState:
	_ensure_player_peer_state()
	return player_peer_state


func get_current_appearance_paths() -> Dictionary:
	return {
		"appearance_front_texture_path": _get_texture_resource_path(front_texture),
		"appearance_back_texture_path": _get_texture_resource_path(back_texture),
		"appearance_side_texture_path": _get_texture_resource_path(side_texture),
	}


func is_network_local_player() -> bool:
	return not _is_remote_network_player()


func is_network_remote_player() -> bool:
	return _is_remote_network_player()


func is_local_player_instance() -> bool:
	_ensure_player_peer_state()
	if player_peer_state == null:
		return not _is_remote_network_player()
	return player_peer_state.is_local_player


func is_remote_player_instance() -> bool:
	return _is_remote_network_player()


func set_input_locked(value: bool) -> void:
	_input_locked = value


func _ensure_player_peer_state() -> void:
	if player_peer_state != null:
		return

	if not ResourceLoader.exists(PLAYER_PEER_STATE_SCRIPT_PATH):
		return

	var state_script: Script = load(PLAYER_PEER_STATE_SCRIPT_PATH) as Script
	if state_script == null:
		push_warning("Player: PlayerPeerState.gd を読み込めません")
		return

	var instance: Variant = state_script.new()
	if instance is PlayerPeerState:
		player_peer_state = instance as PlayerPeerState
		player_peer_state.set_display_name(default_display_name)
		player_peer_state.set_appearance_paths(
			_get_texture_resource_path(front_texture),
			_get_texture_resource_path(back_texture),
			_get_texture_resource_path(side_texture)
		)
		if not player_peer_state.identity_changed.is_connected(_on_player_peer_identity_changed):
			player_peer_state.identity_changed.connect(_on_player_peer_identity_changed)
		if not player_peer_state.ownership_changed.is_connected(_on_player_peer_ownership_changed):
			player_peer_state.ownership_changed.connect(_on_player_peer_ownership_changed)


func _ensure_player_network_controller() -> void:
	if player_network_controller != null:
		return

	if not ResourceLoader.exists(PLAYER_NETWORK_CONTROLLER_SCRIPT_PATH):
		return

	var controller_script: Script = load(PLAYER_NETWORK_CONTROLLER_SCRIPT_PATH) as Script
	if controller_script == null:
		push_warning("Player: PlayerNetworkController.gd を読み込めません")
		return

	var instance: Variant = controller_script.new()
	if instance is PlayerNetworkController:
		player_network_controller = instance as PlayerNetworkController
		player_network_controller.setup(self)
		player_network_controller.ensure_state()


func _ensure_player_input_controller() -> void:
	if player_input_controller != null:
		return

	if not ResourceLoader.exists(PLAYER_INPUT_CONTROLLER_SCRIPT_PATH):
		return

	var controller_script: Script = load(PLAYER_INPUT_CONTROLLER_SCRIPT_PATH) as Script
	if controller_script == null:
		push_warning("Player: PlayerInputController.gd を読み込めません")
		return

	var instance: Variant = controller_script.new()
	if instance is PlayerInputController:
		player_input_controller = instance as PlayerInputController
		player_input_controller.setup(self)


func _ensure_player_support_controller() -> void:
	if player_support_controller != null:
		return

	if not ResourceLoader.exists(PLAYER_SUPPORT_CONTROLLER_SCRIPT_PATH):
		return

	var controller_script: Script = load(PLAYER_SUPPORT_CONTROLLER_SCRIPT_PATH) as Script
	if controller_script == null:
		push_warning("Player: PlayerSupportController.gd を読み込めません")
		return

	var instance: Variant = controller_script.new()
	if instance is PlayerSupportController:
		player_support_controller = instance as PlayerSupportController
		player_support_controller.setup(self)


func _ensure_player_interaction_controller() -> void:
	if player_interaction_controller != null:
		return

	if not ResourceLoader.exists(PLAYER_INTERACTION_CONTROLLER_SCRIPT_PATH):
		return

	var controller_script: Script = load(PLAYER_INTERACTION_CONTROLLER_SCRIPT_PATH) as Script
	if controller_script == null:
		push_warning("Player: PlayerInteractionController.gd を読み込めません")
		return

	var instance: Variant = controller_script.new()
	if instance is PlayerInteractionController:
		player_interaction_controller = instance as PlayerInteractionController
		player_interaction_controller.setup(self, UI_MODAL_MANAGER_SCRIPT_NAME, PAUSE_MENU_SCENE_PATH, MODAL_UI_GROUPS)


func _ensure_player_nameplate_controller() -> void:
	if player_nameplate_controller != null:
		return

	if not ResourceLoader.exists(PLAYER_NAMEPLATE_CONTROLLER_SCRIPT_PATH):
		return

	var controller_script: Script = load(PLAYER_NAMEPLATE_CONTROLLER_SCRIPT_PATH) as Script
	if controller_script == null:
		push_warning("Player: PlayerNameplateController.gd を読み込めません")
		return

	var instance: Variant = controller_script.new()
	if instance is PlayerNameplateController:
		player_nameplate_controller = instance as PlayerNameplateController
		player_nameplate_controller.setup(self)


func _refresh_nameplate() -> void:
	_ensure_player_nameplate_controller()
	if player_nameplate_controller != null:
		player_nameplate_controller.refresh_display()


func _on_player_peer_identity_changed(_state: PlayerPeerState) -> void:
	_refresh_nameplate()


func _on_player_peer_ownership_changed(_state: PlayerPeerState) -> void:
	_refresh_nameplate()


func _ensure_player_motion_controller() -> void:
	if player_motion_controller != null:
		return

	if not ResourceLoader.exists(PLAYER_MOTION_CONTROLLER_SCRIPT_PATH):
		return

	var controller_script: Script = load(PLAYER_MOTION_CONTROLLER_SCRIPT_PATH) as Script
	if controller_script == null:
		push_warning("Player: PlayerMotionController.gd を読み込めません")
		return

	var instance: Variant = controller_script.new()
	if instance is PlayerMotionController:
		player_motion_controller = instance as PlayerMotionController
		player_motion_controller.setup(self)


func _is_remote_network_player() -> bool:
	_ensure_player_peer_state()
	if player_peer_state != null:
		return player_peer_state.is_remote_player

	_ensure_player_network_controller()
	if player_network_controller == null:
		return false
	return player_network_controller.is_remote_network_player()


func _update_remote_network_player(delta: float) -> void:
	_ensure_player_motion_controller()
	if player_motion_controller != null:
		player_motion_controller.update_remote_network_player(delta)


func _get_inventory_ui() -> Node:
	_ensure_player_support_controller()
	if player_support_controller == null:
		return null
	return player_support_controller.get_inventory_ui()


func _get_message_log() -> Node:
	_ensure_player_support_controller()
	if player_support_controller == null:
		return null
	return player_support_controller.get_message_log()


func _log_system(text: String) -> void:
	_ensure_player_support_controller()
	if player_support_controller != null:
		player_support_controller.log_system(text)


func _log_warning(text: String) -> void:
	_ensure_player_support_controller()
	if player_support_controller != null:
		player_support_controller.log_warning(text)


func _log_error(text: String) -> void:
	_ensure_player_support_controller()
	if player_support_controller != null:
		player_support_controller.log_error(text)


func _sync_peer_identity_from_visuals() -> void:
	_ensure_player_peer_state()
	if player_peer_state == null:
		return

	if not default_display_name.strip_edges().is_empty():
		player_peer_state.set_display_name(default_display_name)

	var appearance_paths: Dictionary = get_current_appearance_paths()
	player_peer_state.set_appearance_paths(
		String(appearance_paths.get("appearance_front_texture_path", "")),
		String(appearance_paths.get("appearance_back_texture_path", "")),
		String(appearance_paths.get("appearance_side_texture_path", ""))
	)

	_update_selected_item_peer_state()


func _update_selected_item_peer_state() -> void:
	_ensure_player_peer_state()
	if player_peer_state == null:
		return

	var item_id: String = ""
	var item_data: ItemData = selected_item_data as ItemData
	if item_data != null:
		item_id = String(item_data.id)

	player_peer_state.set_selected_item_id(item_id)


func _apply_appearance_paths(front_path: String, back_path: String, side_path: String) -> void:
	_ensure_player_peer_state()

	var did_update_texture: bool = false

	if not front_path.strip_edges().is_empty():
		var loaded_front: Texture2D = _load_texture_from_path(front_path)
		if loaded_front != null and _needs_texture_update(front_texture, front_path):
			front_texture = loaded_front
			did_update_texture = true

	if not back_path.strip_edges().is_empty():
		var loaded_back: Texture2D = _load_texture_from_path(back_path)
		if loaded_back != null and _needs_texture_update(back_texture, back_path):
			back_texture = loaded_back
			did_update_texture = true

	if not side_path.strip_edges().is_empty():
		var loaded_side: Texture2D = _load_texture_from_path(side_path)
		if loaded_side != null and _needs_texture_update(side_texture, side_path):
			side_texture = loaded_side
			did_update_texture = true

	if not did_update_texture:
		return

	_resolve_player_sprite()
	_apply_facing_visual()

	if player_peer_state != null:
		player_peer_state.set_appearance_paths(
			_get_texture_resource_path(front_texture),
			_get_texture_resource_path(back_texture),
			_get_texture_resource_path(side_texture)
		)

	_refresh_nameplate()


func _load_texture_from_path(texture_path: String) -> Texture2D:
	var normalized_path: String = texture_path.strip_edges()
	if normalized_path.is_empty():
		return null
	if not ResourceLoader.exists(normalized_path):
		return null

	var texture_resource: Resource = load(normalized_path)
	if texture_resource is Texture2D:
		return texture_resource as Texture2D
	return null


func _needs_texture_update(current_texture: Texture2D, desired_path: String) -> bool:
	return _get_texture_resource_path(current_texture) != desired_path.strip_edges()


func _get_texture_resource_path(texture: Texture2D) -> String:
	if texture == null:
		return ""
	return String(texture.resource_path).strip_edges()

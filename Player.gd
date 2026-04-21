extends CharacterBody2D

signal interactable_changed(target)

const UI_MODAL_MANAGER_SCRIPT_NAME: String = "UIModalManager.gd"
const PAUSE_MENU_SCENE_PATH: String = "res://UI/PauseMenuUI.tscn"
const DEBUG_SAVE_SLOT_NAME: String = "slot_01"
const PLAYER_NETWORK_CONTROLLER_SCRIPT_PATH: String = "res://Gameplay/Player/PlayerNetworkController.gd"
const PLAYER_INPUT_CONTROLLER_SCRIPT_PATH: String = "res://Gameplay/Player/PlayerInputController.gd"
const PLAYER_SUPPORT_CONTROLLER_SCRIPT_PATH: String = "res://Gameplay/Player/PlayerSupportController.gd"
const PLAYER_INTERACTION_CONTROLLER_SCRIPT_PATH: String = "res://Gameplay/Player/PlayerInteractionController.gd"
const MODAL_UI_GROUPS: Array[StringName] = [
	&"vending_ui",
	&"crop_machine_ui",
	&"skill_ui",
	&"npc_dialog_ui",
	&"pause_menu_ui"
]

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

var _player_sprite: Sprite2D = null
var _facing: int = Facing.DOWN
var _sprite_base_position: Vector2 = Vector2.ZERO
var _walk_anim_time: float = 0.0
var _input_locked: bool = false

var current_interactable: Node2D = null
var nearby_interactables: Array = []

var selected_item_data: Resource = null
var selected_item_amount: int = 0

var player_network_controller: PlayerNetworkController = null
var player_input_controller: PlayerInputController = null
var player_support_controller: PlayerSupportController = null
var player_interaction_controller: PlayerInteractionController = null


func _ready() -> void:
	add_to_group("player")
	refresh_from_stats()
	_resolve_player_sprite()
	_ensure_player_network_controller()
	_ensure_player_input_controller()
	_ensure_player_support_controller()
	_ensure_player_interaction_controller()

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
	if sprite_path != NodePath():
		_player_sprite = get_node_or_null(sprite_path) as Sprite2D

	if _player_sprite == null:
		_player_sprite = get_node_or_null("Sprite2D") as Sprite2D

	if _player_sprite == null:
		return

	_sprite_base_position = _player_sprite.position

	if front_texture == null:
		front_texture = _player_sprite.texture

	_apply_facing_visual()
	_reset_walk_bob_immediate()


func _update_facing_from_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return

	if absf(direction.x) > absf(direction.y):
		_facing = Facing.RIGHT if direction.x > 0.0 else Facing.LEFT
	else:
		_facing = Facing.DOWN if direction.y > 0.0 else Facing.UP

	_apply_facing_visual()


func _apply_facing_visual() -> void:
	if _player_sprite == null:
		return

	match _facing:
		Facing.DOWN:
			if front_texture != null:
				_player_sprite.texture = front_texture
			_player_sprite.flip_h = false
		Facing.UP:
			if back_texture != null:
				_player_sprite.texture = back_texture
			elif front_texture != null:
				_player_sprite.texture = front_texture
			_player_sprite.flip_h = false
		Facing.RIGHT:
			if side_texture != null:
				_player_sprite.texture = side_texture
			elif front_texture != null:
				_player_sprite.texture = front_texture
			_player_sprite.flip_h = false
		Facing.LEFT:
			if side_texture != null:
				_player_sprite.texture = side_texture
			elif front_texture != null:
				_player_sprite.texture = front_texture
			_player_sprite.flip_h = flip_side_for_left


func _update_walk_bob(delta: float) -> void:
	if _player_sprite == null:
		return

	if not walk_bob_enabled:
		_reset_walk_bob_smooth(delta)
		return

	var moving: bool = velocity.length_squared() > 1.0
	if moving:
		var speed_ratio: float = 1.0
		if speed > 0.0:
			speed_ratio = clampf(velocity.length() / speed, 0.0, 1.5)

		_walk_anim_time += delta * walk_bob_speed * maxf(speed_ratio, 0.2)

		var side_offset: float = sin(_walk_anim_time) * walk_bob_side_amount
		var up_offset: float = -absf(cos(_walk_anim_time)) * walk_bob_up_amount
		var tilt_amount: float = sin(_walk_anim_time) * walk_bob_tilt_degrees
		var target_position: Vector2 = _sprite_base_position + Vector2(side_offset, up_offset)

		_player_sprite.position = _player_sprite.position.lerp(target_position, clampf(delta * walk_bob_return_speed, 0.0, 1.0))
		_player_sprite.rotation_degrees = lerpf(_player_sprite.rotation_degrees, tilt_amount, clampf(delta * walk_bob_return_speed, 0.0, 1.0))
	else:
		_reset_walk_bob_smooth(delta)


func _reset_walk_bob_smooth(delta: float) -> void:
	if _player_sprite == null:
		return

	_player_sprite.position = _player_sprite.position.lerp(_sprite_base_position, clampf(delta * walk_bob_return_speed, 0.0, 1.0))
	_player_sprite.rotation_degrees = lerpf(_player_sprite.rotation_degrees, 0.0, clampf(delta * walk_bob_return_speed, 0.0, 1.0))
	_walk_anim_time = 0.0 if _player_sprite.position.distance_squared_to(_sprite_base_position) < 0.01 and absf(_player_sprite.rotation_degrees) < 0.05 else _walk_anim_time


func _reset_walk_bob_immediate() -> void:
	if _player_sprite == null:
		return

	_walk_anim_time = 0.0
	_player_sprite.position = _sprite_base_position
	_player_sprite.rotation_degrees = 0.0


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


func clear_selected_item() -> void:
	_ensure_player_support_controller()
	if player_support_controller != null:
		player_support_controller.clear_selected_item()


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
	_ensure_player_network_controller()
	if player_network_controller == null:
		return
	player_network_controller.configure_network_peer(local_peer_id, target_peer_id, new_player_id, new_display_name)


func set_network_local_player(value: bool) -> void:
	_ensure_player_network_controller()
	if player_network_controller == null:
		return
	player_network_controller.set_network_local_player(value)


func set_network_authority_peer_id(value: int) -> void:
	_ensure_player_network_controller()
	if player_network_controller == null:
		return
	player_network_controller.set_network_authority_peer_id(value)


func apply_remote_network_snapshot(payload: Dictionary) -> void:
	_ensure_player_network_controller()
	if player_network_controller == null:
		return
	player_network_controller.apply_remote_network_snapshot(payload)


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


func is_network_local_player() -> bool:
	return not _is_remote_network_player()


func is_network_remote_player() -> bool:
	return _is_remote_network_player()


func set_input_locked(value: bool) -> void:
	_input_locked = value


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


func _is_remote_network_player() -> bool:
	if player_network_controller == null:
		return false
	return player_network_controller.is_remote_network_player()


func _update_remote_network_player(delta: float) -> void:
	if player_network_controller == null:
		velocity = Vector2.ZERO
		_update_current_interactable()
		_update_walk_bob(delta)
		return

	if player_network_controller.has_remote_snapshot():
		global_position = player_network_controller.apply_remote_position(global_position, delta)
		velocity = player_network_controller.get_remote_velocity()

		var remote_facing: int = player_network_controller.get_remote_facing()
		if remote_facing >= Facing.DOWN and remote_facing <= Facing.LEFT:
			if _facing != remote_facing:
				_facing = remote_facing
				_apply_facing_visual()
	else:
		velocity = Vector2.ZERO

	_update_current_interactable()
	_update_walk_bob(delta)


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

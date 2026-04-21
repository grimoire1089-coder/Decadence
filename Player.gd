extends CharacterBody2D

signal interactable_changed(target)

const UI_MODAL_MANAGER_SCRIPT_NAME: String = "UIModalManager.gd"
const PAUSE_MENU_SCENE_PATH: String = "res://UI/PauseMenuUI.tscn"
const DEBUG_SAVE_SLOT_NAME: String = "slot_01"
const PLAYER_NETWORK_CONTROLLER_SCRIPT_PATH: String = "res://Gameplay/Player/PlayerNetworkController.gd"
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

var current_interactable: Node2D = null
var nearby_interactables: Array = []

var selected_item_data: Resource = null
var selected_item_amount: int = 0

var player_network_controller: PlayerNetworkController = null


func _ready() -> void:
	add_to_group("player")
	refresh_from_stats()
	_resolve_player_sprite()
	_ensure_player_network_controller()

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
	if _is_remote_network_player():
		return

	if _is_player_control_locked():
		if event.is_action_pressed("interact") or event.is_action_pressed("eat_selected_item"):
			_safe_set_input_as_handled()
			return

	if _handle_debug_save_input(event):
		return

	if event.is_action_pressed("ui_cancel"):
		if _has_non_pause_modal_visible():
			return

		var pause_menu: Control = _ensure_pause_menu_exists()
		if pause_menu != null and pause_menu.has_method("toggle_menu"):
			pause_menu.call("toggle_menu")
			_safe_set_input_as_handled()
		return

	if event.is_action_pressed("interact"):
		if _is_interaction_ui_open():
			return

		if current_interactable != null and current_interactable.has_method("interact"):
			current_interactable.interact(self)
			_safe_set_input_as_handled()

	if event.is_action_pressed("eat_selected_item"):
		try_consume_selected_item()


func _handle_debug_save_input(event: InputEvent) -> bool:
	var should_save: bool = false

	if InputMap.has_action("debug_save"):
		should_save = event.is_action_pressed("debug_save")
	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_F5:
			should_save = true

	if not should_save:
		return false

	_debug_save_game()
	_safe_set_input_as_handled()
	return true


func _debug_save_game() -> void:
	if SaveManager == null:
		push_warning("SaveManager が見つかりません")
		return

	var ok: bool = SaveManager.save_game(get_tree().current_scene, DEBUG_SAVE_SLOT_NAME)
	if ok:
		var log_node: Node = get_node_or_null("/root/MessageLog")
		if log_node != null:
			if log_node.has_method("add_system_message"):
				log_node.call("add_system_message", "仮セーブ完了: %s" % DEBUG_SAVE_SLOT_NAME)
			elif log_node.has_method("add_system"):
				log_node.call("add_system", "仮セーブ完了: %s" % DEBUG_SAVE_SLOT_NAME)
		print("仮セーブ完了: %s" % DEBUG_SAVE_SLOT_NAME)
	else:
		push_warning("仮セーブ失敗: %s" % DEBUG_SAVE_SLOT_NAME)


func _is_interaction_ui_open() -> bool:
	return _is_any_modal_ui_visible()


func _is_player_control_locked() -> bool:
	var any_modal_visible: bool = _is_any_modal_ui_visible()

	var ui_modal_manager: Node = _find_ui_modal_manager()
	if ui_modal_manager != null and ui_modal_manager.has_method("is_player_input_blocked"):
		var blocked_by_manager: bool = bool(ui_modal_manager.call("is_player_input_blocked"))

		if blocked_by_manager and any_modal_visible:
			return true

	return any_modal_visible


func _is_any_modal_ui_visible() -> bool:
	for group_name in MODAL_UI_GROUPS:
		var ui: Control = get_tree().get_first_node_in_group(String(group_name)) as Control
		if ui != null and ui.visible:
			return true
	return false


func _has_non_pause_modal_visible() -> bool:
	for group_name in MODAL_UI_GROUPS:
		if group_name == &"pause_menu_ui":
			continue

		var ui: Control = get_tree().get_first_node_in_group(String(group_name)) as Control
		if ui != null and ui.visible:
			return true

	return false


func _get_pause_menu_ui() -> Control:
	return get_tree().get_first_node_in_group("pause_menu_ui") as Control


func _ensure_pause_menu_exists() -> Control:
	var existing: Control = _get_pause_menu_ui()
	if existing != null:
		return existing

	if not ResourceLoader.exists(PAUSE_MENU_SCENE_PATH):
		return null

	var packed_scene: PackedScene = load(PAUSE_MENU_SCENE_PATH) as PackedScene
	if packed_scene == null:
		return null

	var instance: Control = packed_scene.instantiate() as Control
	if instance == null:
		return null

	var parent_node: Node = get_tree().current_scene
	if parent_node == null:
		parent_node = get_tree().root

	parent_node.add_child(instance)
	return instance


func _find_ui_modal_manager() -> Node:
	var by_path: Node = get_node_or_null("/root/UIModalManager")
	if by_path != null:
		return by_path

	var by_group: Node = get_tree().get_first_node_in_group("ui_modal_manager")
	if by_group != null:
		return by_group

	for child in get_tree().root.get_children():
		var script_value: Variant = child.get_script()
		if script_value is Script:
			var script_ref: Script = script_value as Script
			if script_ref != null and script_ref.resource_path.get_file() == UI_MODAL_MANAGER_SCRIPT_NAME:
				return child

	return null


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
	if PlayerStatsManager == null:
		return 0
	return PlayerStatsManager.get_stat(stat_name)


func get_skill_value(skill_name: String) -> int:
	if PlayerStatsManager == null:
		return 0
	return PlayerStatsManager.get_skill(skill_name)


func add_fatigue_for_action(action_name: String, multiplier: float = 1.0, write_log: bool = false) -> int:
	if PlayerStatsManager == null:
		return 0

	var added_amount: int = PlayerStatsManager.apply_fatigue_for_action(action_name, multiplier)

	if write_log and added_amount > 0:
		_log_system("行動疲労: %s（疲労度 +%d）" % [action_name, added_amount])

	return added_amount


func register_interactable(target: Node2D) -> void:
	if target == null:
		return

	if not nearby_interactables.has(target):
		nearby_interactables.append(target)

	_update_current_interactable()


func unregister_interactable(target: Node2D) -> void:
	if target == null:
		return

	nearby_interactables.erase(target)
	_update_current_interactable()


func _update_current_interactable() -> void:
	for i in range(nearby_interactables.size() - 1, -1, -1):
		if not is_instance_valid(nearby_interactables[i]):
			nearby_interactables.remove_at(i)

	var nearest: Node2D = null
	var nearest_distance: float = INF

	for target in nearby_interactables:
		var dist: float = global_position.distance_squared_to(target.global_position)
		if dist < nearest_distance:
			nearest_distance = dist
			nearest = target

	if current_interactable != nearest:
		current_interactable = nearest
		interactable_changed.emit(current_interactable)


func set_selected_item(item_data: Resource, amount: int) -> void:
	selected_item_data = item_data
	selected_item_amount = amount


func clear_selected_item() -> void:
	selected_item_data = null
	selected_item_amount = 0


func try_consume_selected_item() -> bool:
	var item_data: ItemData = selected_item_data as ItemData
	if item_data == null:
		return false

	if not item_data.can_eat():
		_log_warning("このアイテムは食べられない")
		return false

	if not remove_item_from_inventory(item_data, 1):
		return false

	var fullness_amount: int = item_data.get_fullness_restore()
	var fatigue_amount: int = item_data.get_fatigue_restore()

	if PlayerStatsManager != null:
		if fullness_amount > 0:
			PlayerStatsManager.restore_fullness(fullness_amount)
		if fatigue_amount > 0:
			PlayerStatsManager.recover_fatigue(fatigue_amount)

	var item_name_text: String = item_data.item_name
	if item_name_text.is_empty():
		item_name_text = str(item_data.id)

	var parts: Array[String] = []
	if fullness_amount > 0:
		parts.append("満腹度 +%d" % fullness_amount)
	if fatigue_amount > 0:
		parts.append("疲労度 -%d" % fatigue_amount)

	if parts.is_empty():
		_log_system("%sを食べた" % item_name_text)
	else:
		_log_system("%sを食べた（%s）" % [item_name_text, " / ".join(parts)])

	return true


func add_item_to_inventory(item_data: Resource, amount: int) -> bool:
	var inventory_ui: Node = _get_inventory_ui()
	if inventory_ui == null:
		_log_error("InventoryUI が見つからない")
		return false

	if inventory_ui.has_method("add_item"):
		return bool(inventory_ui.call("add_item", item_data, amount))

	_log_error("InventoryUI に add_item() がない")
	return false


func remove_item_from_inventory(item_data: Resource, amount: int) -> bool:
	var inventory_ui: Node = _get_inventory_ui()
	if inventory_ui == null:
		_log_error("InventoryUI が見つからない")
		return false

	if inventory_ui.has_method("remove_item"):
		return bool(inventory_ui.call("remove_item", item_data, amount))

	_log_error("InventoryUI に remove_item() がない")
	return false


func get_inventory_count(item_data: Resource) -> int:
	var inventory_ui: Node = _get_inventory_ui()
	if inventory_ui == null:
		return 0

	if inventory_ui.has_method("get_item_count"):
		return int(inventory_ui.call("get_item_count", item_data))

	return 0


func add_credits(amount: int) -> void:
	if amount <= 0:
		return

	if CurrencyManager != null and CurrencyManager.has_method("add_credits"):
		CurrencyManager.add_credits(amount)
		_log_system("%d Cr を獲得した" % amount)
		return

	_log_error("CurrencyManager に add_credits() がない")


func get_credits() -> int:
	if CurrencyManager != null and CurrencyManager.has_method("get_credits"):
		return int(CurrencyManager.get_credits())
	return 0


func can_spend_credits(amount: int) -> bool:
	if amount < 0:
		return false
	if CurrencyManager != null and CurrencyManager.has_method("can_spend"):
		return bool(CurrencyManager.can_spend(amount))
	return false


func spend_credits(amount: int) -> bool:
	if amount <= 0:
		return false

	if CurrencyManager != null and CurrencyManager.has_method("spend_credits"):
		return bool(CurrencyManager.spend_credits(amount))

	_log_error("CurrencyManager に spend_credits() がない")
	return false


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
	return get_tree().get_first_node_in_group("inventory_ui") as Node


func _get_message_log() -> Node:
	return get_node_or_null("/root/MessageLog")


func _log_system(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node == null:
		return
	if log_node.has_method("add_system"):
		log_node.call("add_system", text)
	elif log_node.has_method("add_message"):
		log_node.call("add_message", text, "SYSTEM")


func _log_warning(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node == null:
		return
	if log_node.has_method("add_warning"):
		log_node.call("add_warning", text)
	elif log_node.has_method("add_message"):
		log_node.call("add_message", text, "WARN")


func _log_error(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node == null:
		return
	if log_node.has_method("add_error"):
		log_node.call("add_error", text)
	elif log_node.has_method("add_message"):
		log_node.call("add_message", text, "ERROR")

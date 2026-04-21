extends RefCounted
class_name PlayerInputController

var owner: CharacterBody2D = null


func setup(owner_node: CharacterBody2D) -> void:
	owner = owner_node


func handle_unhandled_input(event: InputEvent) -> bool:
	if owner == null:
		return false

	if owner._is_remote_network_player():
		return false

	if owner._is_player_control_locked():
		if event.is_action_pressed("interact") or event.is_action_pressed("eat_selected_item"):
			owner._safe_set_input_as_handled()
			return true

	if _handle_debug_save_input(event):
		return true

	if event.is_action_pressed("ui_cancel"):
		if owner._has_non_pause_modal_visible():
			return true

		var pause_menu: Control = owner._ensure_pause_menu_exists()
		if pause_menu != null and pause_menu.has_method("toggle_menu"):
			pause_menu.call("toggle_menu")
			owner._safe_set_input_as_handled()
		return true

	if event.is_action_pressed("interact"):
		if owner._is_interaction_ui_open():
			return true

		if owner.current_interactable != null and owner.current_interactable.has_method("interact"):
			owner.current_interactable.interact(owner)
			owner._safe_set_input_as_handled()
		return true

	if event.is_action_pressed("eat_selected_item"):
		owner.try_consume_selected_item()
		return true

	return false


func _handle_debug_save_input(event: InputEvent) -> bool:
	if owner == null:
		return false

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
	owner._safe_set_input_as_handled()
	return true


func _debug_save_game() -> void:
	if owner == null:
		return

	if SaveManager == null:
		push_warning("SaveManager が見つかりません")
		return

	var ok: bool = SaveManager.save_game(owner.get_tree().current_scene, owner.DEBUG_SAVE_SLOT_NAME)
	if ok:
		var log_node: Node = owner.get_node_or_null("/root/MessageLog")
		if log_node != null:
			if log_node.has_method("add_system_message"):
				log_node.call("add_system_message", "仮セーブ完了: %s" % owner.DEBUG_SAVE_SLOT_NAME)
			elif log_node.has_method("add_system"):
				log_node.call("add_system", "仮セーブ完了: %s" % owner.DEBUG_SAVE_SLOT_NAME)
		print("仮セーブ完了: %s" % owner.DEBUG_SAVE_SLOT_NAME)
	else:
		push_warning("仮セーブ失敗: %s" % owner.DEBUG_SAVE_SLOT_NAME)

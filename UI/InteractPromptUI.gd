extends CanvasLayer
class_name InteractPromptUI

const MODAL_UI_GROUPS: Array[StringName] = [
	&"vending_ui",
	&"crop_machine_ui",
	&"skill_ui",
	&"npc_dialog_ui"
]

@export var use_key_text: String = "E"
@export var default_action_text: String = "調べる"
@export var default_world_offset: Vector2 = Vector2(0, -56)
@export var screen_offset: Vector2 = Vector2.ZERO
@export var follow_target: bool = true
@export var hide_while_modal_ui_visible: bool = true

@onready var prompt_root: PanelContainer = $PromptRoot
@onready var prompt_label: Label = $PromptRoot/MarginContainer/PromptLabel

var _player: Node = null
var _target: Node2D = null


func _ready() -> void:
	visible = true
	if prompt_root != null:
		prompt_root.hide()
	_connect_player_if_needed()
	_call_refresh()


func _process(_delta: float) -> void:
	_connect_player_if_needed()
	_refresh_prompt()


func _connect_player_if_needed() -> void:
	if _player != null and is_instance_valid(_player):
		return

	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	_player = player
	if not _player.is_connected("interactable_changed", Callable(self, "_on_player_interactable_changed")):
		_player.connect("interactable_changed", Callable(self, "_on_player_interactable_changed"))

	var current_target: Variant = _player.get("current_interactable")
	if current_target is Node2D:
		_target = current_target as Node2D
	else:
		_target = null


func _on_player_interactable_changed(target: Variant) -> void:
	if target is Node2D:
		_target = target as Node2D
	else:
		_target = null
	_call_refresh()


func _call_refresh() -> void:
	call_deferred("_refresh_prompt")


func _refresh_prompt() -> void:
	if prompt_root == null or prompt_label == null:
		return

	if _target == null or not is_instance_valid(_target):
		prompt_root.hide()
		return

	if hide_while_modal_ui_visible and _is_any_modal_ui_visible():
		prompt_root.hide()
		return

	prompt_label.text = "[%s] %s" % [use_key_text, _get_action_text(_target)]
	prompt_root.show()

	if follow_target:
		_update_prompt_position()


func _update_prompt_position() -> void:
	if _target == null or not is_instance_valid(_target):
		return

	var world_pos: Vector2 = _target.global_position + _get_world_offset(_target)
	var canvas_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
	var panel_size: Vector2 = prompt_root.size
	if panel_size == Vector2.ZERO:
		panel_size = prompt_root.get_combined_minimum_size()

	prompt_root.position = canvas_pos + screen_offset - panel_size * 0.5


func _get_action_text(target: Node) -> String:
	if target != null and target.has_method("get_interact_action_text"):
		var value: Variant = target.call("get_interact_action_text")
		var text: String = str(value)
		if not text.is_empty():
			return text
	return default_action_text


func _get_world_offset(target: Node) -> Vector2:
	if target != null and target.has_method("get_interact_prompt_offset"):
		var value: Variant = target.call("get_interact_prompt_offset")
		if value is Vector2:
			return value
	return default_world_offset


func _is_any_modal_ui_visible() -> bool:
	for group_name in MODAL_UI_GROUPS:
		var ui: Control = get_tree().get_first_node_in_group(String(group_name)) as Control
		if ui != null and ui.visible:
			return true
	return false

extends StaticBody2D
class_name SceneDoor

@export_group("Door")
@export var door_name: String = "扉"
@export_file("*.tscn") var target_scene_path: String = ""
@export var target_spawn_id: String = ""

@export_group("Interact")
@export var interact_action_text: String = "入る"
@export var interact_prompt_offset: Vector2 = Vector2(0, -72)

@export_group("Message")
@export var write_message_log: bool = false
@export var message_text: String = ""

@export_group("Transition FX")
@export var use_transition_fade: bool = true
@export var transition_sfx: AudioStream

@onready var interact_area: Area2D = $InteractArea


func _ready() -> void:
	if interact_area != null:
		if not interact_area.body_entered.is_connected(_on_body_entered):
			interact_area.body_entered.connect(_on_body_entered)
		if not interact_area.body_exited.is_connected(_on_body_exited):
			interact_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("register_interactable"):
		body.register_interactable(self)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("unregister_interactable"):
		body.unregister_interactable(self)


func interact(_player: Node) -> void:
	var normalized_scene_path: String = target_scene_path.strip_edges()
	if normalized_scene_path.is_empty():
		push_warning("SceneDoor: target_scene_path が未設定です: %s" % name)
		return

	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		push_warning("SceneDoor: current_scene が見つかりません: %s" % name)
		return

	var resolved_message: String = message_text if not message_text.is_empty() else "%sに入った" % door_name
	var fallback_log_text: String = resolved_message if write_message_log else ""

	var request: Dictionary = {
		"target_map_scene_path": normalized_scene_path,
		"target_spawn_id": target_spawn_id.strip_edges(),
		"transition_name": door_name,
		"log_text": fallback_log_text,
		"use_fade_transition": use_transition_fade,
	}

	if transition_sfx != null:
		request["transition_sfx"] = transition_sfx

	if current_scene.has_method("request_networked_map_transition"):
		current_scene.call("request_networked_map_transition", request)
		return

	var map_transition_manager: Node = null
	if current_scene.has_method("get_map_transition_manager"):
		map_transition_manager = current_scene.call("get_map_transition_manager")

	if map_transition_manager != null and map_transition_manager.has_method("request_transition_request"):
		map_transition_manager.call("request_transition_request", request)
		return

	if current_scene.has_method("request_map_transition"):
		current_scene.call(
			"request_map_transition",
			normalized_scene_path,
			target_spawn_id.strip_edges(),
			door_name,
			fallback_log_text
		)
		return

	push_warning("SceneDoor: 遷移先を処理できるノードが見つかりません: %s" % name)


func get_interact_action_text() -> String:
	return interact_action_text


func get_interact_prompt_offset() -> Vector2:
	return interact_prompt_offset


func get_target_display_name() -> String:
	return door_name

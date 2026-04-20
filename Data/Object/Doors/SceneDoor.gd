extends StaticBody2D
class_name SceneDoor

const META_PENDING_SCENE_PATH: StringName = &"scene_transition_target_scene_path"
const META_PENDING_SPAWN_ID: StringName = &"scene_transition_target_spawn_id"

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
	var resolved_message: String = message_text if not message_text.is_empty() else "%sに入った" % door_name
	var current_scene: Node = get_tree().current_scene
	var fallback_log_text: String = resolved_message if write_message_log else ""

	if current_scene != null and current_scene.has_method("request_map_transition"):
		current_scene.call(
			"request_map_transition",
			normalized_scene_path,
			target_spawn_id.strip_edges(),
			door_name,
			fallback_log_text
		)
		return

	if normalized_scene_path.is_empty():
		push_warning("SceneDoor: target_scene_path が未設定です: %s" % name)
		return

	if not ResourceLoader.exists(normalized_scene_path):
		push_warning("SceneDoor: シーンが見つかりません: %s" % normalized_scene_path)
		return

	if write_message_log:
		_write_log(resolved_message)

	var root_node: Window = get_tree().root
	if root_node != null:
		root_node.set_meta(META_PENDING_SCENE_PATH, normalized_scene_path)
		root_node.set_meta(META_PENDING_SPAWN_ID, target_spawn_id.strip_edges())

	get_tree().change_scene_to_file(normalized_scene_path)


func get_interact_action_text() -> String:
	return interact_action_text


func get_interact_prompt_offset() -> Vector2:
	return interact_prompt_offset


func get_target_display_name() -> String:
	return door_name


func _write_log(text: String) -> void:
	var log_node: Node = get_node_or_null("/root/MessageLog")
	if log_node == null or text.is_empty():
		return

	if log_node.has_method("add_system"):
		log_node.call("add_system", text)
	elif log_node.has_method("add_message"):
		log_node.call("add_message", text, "SYSTEM")

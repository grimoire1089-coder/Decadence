extends StaticBody2D
class_name NPC

@export_group("基本")
@export var npc_name: String = "住人"
@export_multiline var talk_lines: PackedStringArray = [
	"こんにちは。",
	"今日もいい日だな。"
]
@export var loop_talk: bool = false
@export_enum("INFO", "DEBUG", "SYSTEM", "WARNING", "ERROR", "SHOP", "TIME") var talk_category: String = "SYSTEM"

@export_group("インタラクト")
@export var interact_action_text: String = "話す"
@export var interact_prompt_offset: Vector2 = Vector2(0, -56)

@export_group("会話UI")
@export var use_dialog_ui: bool = true
@export var start_from_first_line_on_open: bool = true
@export var portrait_texture: Texture2D
@export var dialog_name_override: String = ""

@export_group("ボイス")
@export var voice_lines: Array[AudioStream] = []
@export var voice_bus: StringName = &"Voice"
@export_range(-40.0, 12.0, 0.1) var voice_volume_db: float = 0.0
@export_range(0.5, 2.0, 0.01) var voice_pitch_scale: float = 1.0

@export_group("見た目")
@export var face_player_when_interact: bool = true
@export var sprite_offset: Vector2 = Vector2(0, -16)

@onready var interact_area: Area2D = $InteractArea
@onready var sprite: Sprite2D = $Sprite2D

var _talk_index: int = 0


func _ready() -> void:
	add_to_group("targetable")
	add_to_group("friendly_target")

	if sprite != null:
		sprite.position = sprite_offset

	if interact_area != null:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("register_interactable"):
		body.register_interactable(self)


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("unregister_interactable"):
		body.unregister_interactable(self)


func interact(player: Node) -> void:
	if face_player_when_interact:
		_face_to_player(player)

	if use_dialog_ui and _open_dialog_ui(player):
		return

	var line: String = get_current_line()
	_log_message("%s: %s" % [get_dialog_display_name(), line], talk_category)
	advance_talk_index()


func _open_dialog_ui(player: Node) -> bool:
	var dialog_ui: Node = get_tree().get_first_node_in_group("npc_dialog_ui")
	if dialog_ui == null:
		return false

	if start_from_first_line_on_open:
		reset_talk()

	if dialog_ui.has_method("open_dialog"):
		dialog_ui.call("open_dialog", self, player)
		return true

	return false


func _face_to_player(player: Node) -> void:
	if sprite == null:
		return
	if not (player is Node2D):
		return

	var player_node: Node2D = player as Node2D
	sprite.flip_h = player_node.global_position.x < global_position.x


func get_current_line() -> String:
	if talk_lines.is_empty():
		return "……"

	if _talk_index < 0 or _talk_index >= talk_lines.size():
		_talk_index = 0

	return talk_lines[_talk_index]


func advance_talk_index() -> void:
	if talk_lines.is_empty():
		return

	if loop_talk:
		_talk_index = (_talk_index + 1) % talk_lines.size()
	else:
		_talk_index = min(_talk_index + 1, talk_lines.size() - 1)


func is_last_talk_line() -> bool:
	if talk_lines.is_empty():
		return true
	return _talk_index >= talk_lines.size() - 1


func reset_talk() -> void:
	_talk_index = 0


func get_dialog_display_name() -> String:
	if not dialog_name_override.is_empty():
		return dialog_name_override
	return npc_name


func get_dialog_portrait() -> Texture2D:
	return portrait_texture


func get_current_voice_stream() -> AudioStream:
	if voice_lines.is_empty():
		return null
	if _talk_index < 0 or _talk_index >= voice_lines.size():
		return null
	return voice_lines[_talk_index]


func get_voice_bus() -> StringName:
	return voice_bus


func get_voice_volume_db() -> float:
	return voice_volume_db


func get_voice_pitch_scale() -> float:
	return voice_pitch_scale


func get_interact_action_text() -> String:
	return interact_action_text


func get_interact_prompt_offset() -> Vector2:
	return interact_prompt_offset


func get_target_display_name() -> String:
	return get_dialog_display_name()


func is_target_selectable() -> bool:
	return true


func get_target_marker_world_position() -> Vector2:
	var local_offset: Vector2 = _get_target_marker_local_offset()
	return global_position + Vector2(local_offset.x * absf(global_scale.x), local_offset.y * absf(global_scale.y))


func get_target_ring_radius() -> float:
	var body_collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_collision == null or body_collision.shape == null:
		return 16.0

	var shape: Shape2D = body_collision.shape
	if shape is RectangleShape2D:
		var rect: RectangleShape2D = shape as RectangleShape2D
		var scaled_width: float = rect.size.x * absf(global_scale.x)
		var scaled_height: float = rect.size.y * absf(global_scale.y)
		return max(min(scaled_width, scaled_height) * 0.24, 10.0)
	if shape is CircleShape2D:
		var circle: CircleShape2D = shape as CircleShape2D
		return max(circle.radius * absf(global_scale.x) * 0.90, 10.0)

	return 16.0


func _get_target_marker_local_offset() -> Vector2:
	var body_collision: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_collision == null or body_collision.shape == null:
		return Vector2.ZERO

	var local_offset: Vector2 = body_collision.position
	var shape: Shape2D = body_collision.shape
	if shape is RectangleShape2D:
		var rect: RectangleShape2D = shape as RectangleShape2D
		local_offset.y += rect.size.y * 0.5
	elif shape is CircleShape2D:
		var circle: CircleShape2D = shape as CircleShape2D
		local_offset.y += circle.radius

	return local_offset


func _get_message_log() -> Node:
	return get_node_or_null("/root/MessageLog")


func _log_message(text: String, category: String = "SYSTEM") -> void:
	var log_node: Node = _get_message_log()
	if log_node == null:
		return

	match category:
		"DEBUG":
			if log_node.has_method("add_debug"):
				log_node.call("add_debug", text)
				return
		"SYSTEM":
			if log_node.has_method("add_system"):
				log_node.call("add_system", text)
				return
		"WARNING":
			if log_node.has_method("add_warning"):
				log_node.call("add_warning", text)
				return
		"ERROR":
			if log_node.has_method("add_error"):
				log_node.call("add_error", text)
				return
		"SHOP":
			if log_node.has_method("add_shop"):
				log_node.call("add_shop", text)
				return
		"TIME":
			if log_node.has_method("add_time"):
				log_node.call("add_time", text)
				return
		_:
			if log_node.has_method("add_message"):
				log_node.call("add_message", text, category)
				return

	if log_node.has_method("add_message"):
		log_node.call("add_message", text, category)

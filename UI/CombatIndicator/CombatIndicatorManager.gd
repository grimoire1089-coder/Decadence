extends Node

@export var indicator_scene: PackedScene = preload("res://UI/CombatIndicator/CombatIndicator.tscn")
@export var default_world_offset: Vector2 = Vector2(0, -34)
@export var stack_step_y: float = 10.0
@export var stack_window_seconds: float = 0.45
@export var spawn_jitter_x: float = 4.0

var _target_stack_info: Dictionary = {}


func show_indicator_at(world_position: Vector2, amount: int, kind: String, text_override: String = "") -> void:
	if indicator_scene == null:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var indicator: Node = indicator_scene.instantiate()
	if not (indicator is Node2D):
		return

	scene_root.add_child(indicator)
	var indicator_node: Node2D = indicator as Node2D
	indicator_node.global_position = world_position
	if indicator_node.has_method("setup"):
		indicator_node.call("setup", amount, kind, text_override)


func show_for_node(target: Node, amount: int, kind: String, text_override: String = "") -> void:
	if target == null or not is_instance_valid(target):
		return

	var position: Vector2 = _resolve_world_position(target)
	var offset: Vector2 = default_world_offset + _get_stacked_offset(target)
	offset.x += randf_range(-spawn_jitter_x, spawn_jitter_x)
	show_indicator_at(position + offset, amount, kind, text_override)


func show_for_player(amount: int, kind: String, text_override: String = "") -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		show_for_node(player, amount, kind, text_override)


func _resolve_world_position(target: Node) -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO

	if target is Node2D:
		return (target as Node2D).global_position

	if target is Control:
		var control: Control = target as Control
		return control.get_global_rect().get_center()

	return Vector2.ZERO


func _get_stacked_offset(target: Node) -> Vector2:
	var key: int = target.get_instance_id()
	var now: float = Time.get_ticks_msec() / 1000.0
	var info: Dictionary = _target_stack_info.get(key, {})
	var last_time: float = float(info.get("time", -9999.0))
	var count: int = int(info.get("count", 0))

	if now - last_time > stack_window_seconds:
		count = 0
	else:
		count += 1

	_target_stack_info[key] = {
		"time": now,
		"count": count,
	}

	return Vector2(0, -stack_step_y * count)

extends Node

@export var indicator_scene: PackedScene = preload("res://UI/CombatIndicator/CombatIndicator.tscn")
@export var indicator_script: Script = preload("res://UI/CombatIndicator/CombatIndicator.gd")
@export var default_world_offset: Vector2 = Vector2(0, -30)
@export var stack_step_y: float = 12.0
@export var stack_reset_seconds: float = 0.2

var _stack_state: Dictionary = {}


func show_indicator_at(world_position: Vector2, amount: int, kind: String, text_override: String = "") -> void:
	if indicator_scene == null:
		return

	var host: Node = _get_indicator_host()
	if host == null:
		return

	var indicator: Node = indicator_scene.instantiate()
	if not (indicator is Node2D):
		if indicator != null:
			indicator.queue_free()
		return

	# tscn のスクリプトが外れていても runtime で強制装着する
	if not indicator.has_method("setup") and indicator_script != null:
		indicator.set_script(indicator_script)

	host.add_child(indicator)
	var indicator_node: Node2D = indicator as Node2D
	indicator_node.global_position = world_position

	if indicator.has_method("setup"):
		indicator.call_deferred("setup", amount, kind, text_override)
	else:
		push_warning("CombatIndicator に setup() がありません: %s" % [indicator])


func show_for_node(target: Node, amount: int, kind: String, text_override: String = "") -> void:
	if target == null or not is_instance_valid(target):
		return

	var position: Vector2 = _resolve_world_position(target)
	var stack_offset: Vector2 = _consume_stack_offset(target)
	show_indicator_at(position + default_world_offset + stack_offset, amount, kind, text_override)


func show_for_player(amount: int, kind: String, text_override: String = "") -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		show_for_node(player, amount, kind, text_override)


func _get_indicator_host() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	return tree.root


func _consume_stack_offset(target: Node) -> Vector2:
	var id: int = target.get_instance_id()
	var now: float = Time.get_ticks_msec() / 1000.0
	var state: Dictionary = {}
	if _stack_state.has(id):
		state = _stack_state[id]

	var last_time: float = float(state.get("time", -999.0))
	var count: int = int(state.get("count", 0))
	if now - last_time > stack_reset_seconds:
		count = 0

	state["time"] = now
	state["count"] = count + 1
	_stack_state[id] = state

	return Vector2(0.0, -stack_step_y * count)


func _resolve_world_position(target: Node) -> Vector2:
	if target is Node2D:
		return (target as Node2D).global_position

	if target is Control:
		var control: Control = target as Control
		return control.get_global_rect().get_center()

	if "global_position" in target:
		return target.global_position

	return Vector2.ZERO

extends Node2D

@export var indicator_scene: PackedScene = preload("res://UI/CombatIndicator/CombatIndicator.tscn")
@export var default_world_offset: Vector2 = Vector2(0, -28)

const KIND_NORMAL_DAMAGE := "normal_damage"
const KIND_DOT_DAMAGE := "dot_damage"
const KIND_HP_HEAL := "hp_heal"
const KIND_MP_HEAL := "mp_heal"
const KIND_MP_DAMAGE := "mp_damage"


func show_indicator_at(world_position: Vector2, amount: int, kind: String, text_override: String = "") -> void:
	if indicator_scene == null:
		return

	var indicator := indicator_scene.instantiate()
	if indicator == null:
		return

	if indicator is Node2D:
		add_child(indicator)
		(indicator as Node2D).global_position = world_position
		if indicator.has_method("setup"):
			indicator.call("setup", amount, kind, text_override)


func show_for_node(target: Node, amount: int, kind: String, text_override: String = "") -> void:
	var position := _resolve_world_position(target)
	show_indicator_at(position + default_world_offset, amount, kind, text_override)


func show_for_player(amount: int, kind: String, text_override: String = "") -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		show_for_node(player, amount, kind, text_override)


func _resolve_world_position(target: Node) -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO

	if target is Node2D:
		return (target as Node2D).global_position

	if target is Control:
		var control := target as Control
		return control.get_global_rect().get_center()

	if "global_position" in target:
		return target.global_position

	return Vector2.ZERO

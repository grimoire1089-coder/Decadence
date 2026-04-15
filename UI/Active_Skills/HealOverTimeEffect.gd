extends Node
class_name HealOverTimeEffect

signal effect_finished(skill_id: String, target: Node)

var skill_data: RoleSkillData = null
var target_node: Node = null
var caster_node: Node = null
var remaining_ticks: int = 0
var _tick_accumulator: float = 0.0


func setup(skill: RoleSkillData, target: Node, caster: Node = null) -> void:
	skill_data = skill
	target_node = target
	caster_node = caster
	remaining_ticks = skill.get_total_tick_count()
	_tick_accumulator = 0.0
	name = "HealOverTime_%s" % skill.skill_id


func refresh(skill: RoleSkillData, target: Node, caster: Node = null) -> void:
	setup(skill, target, caster)


func matches_effect(skill_id: String, caster: Node = null) -> bool:
	if skill_data == null:
		return false
	if skill_data.skill_id != skill_id:
		return false

	if caster_node == null or not is_instance_valid(caster_node):
		return caster == null

	return caster_node == caster


func is_buff_visible() -> bool:
	return skill_data != null and remaining_ticks > 0


func get_effect_display_name() -> String:
	if skill_data == null:
		return ""
	return skill_data.display_name


func get_effect_icon() -> Texture2D:
	if skill_data == null:
		return null
	return skill_data.icon


func get_effect_skill_id() -> String:
	if skill_data == null:
		return ""
	return skill_data.skill_id


func get_effect_total_duration_seconds() -> float:
	if skill_data == null:
		return 0.0
	return max(skill_data.effect_duration_seconds, 0.0)


func get_remaining_seconds() -> float:
	if skill_data == null:
		return 0.0
	if remaining_ticks <= 0:
		return 0.0

	var interval: float = max(skill_data.tick_interval_seconds, 0.0)
	var current_segment_remaining: float = 0.0
	if interval > 0.0:
		current_segment_remaining = max(interval - _tick_accumulator, 0.0)

	var future_segments: int = max(remaining_ticks - 1, 0)
	return current_segment_remaining + (float(future_segments) * interval)


func get_effect_ratio() -> float:
	var total: float = get_effect_total_duration_seconds()
	if total <= 0.0:
		return 0.0
	return clampf(get_remaining_seconds() / total, 0.0, 1.0)


func get_effect_instance_key() -> String:
	var skill_id := get_effect_skill_id()
	var caster_id := "none"
	if caster_node != null and is_instance_valid(caster_node):
		caster_id = str(caster_node.get_instance_id())
	return "%s:%s" % [skill_id, caster_id]


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if skill_data == null:
		_finish()
		return

	if target_node == null or not is_instance_valid(target_node):
		_finish()
		return

	if remaining_ticks <= 0:
		_finish()
		return

	_tick_accumulator += delta

	while _tick_accumulator >= skill_data.tick_interval_seconds and remaining_ticks > 0:
		_tick_accumulator -= skill_data.tick_interval_seconds
		_apply_tick()
		remaining_ticks -= 1

	if remaining_ticks <= 0:
		_finish()


func _apply_tick() -> void:
	if target_node == null or not is_instance_valid(target_node):
		return

	var target_stats: Node = SkillHelpers.resolve_stats_manager(target_node)
	if target_stats == null:
		return

	target_stats.call("heal_hp", skill_data.hp_heal_per_tick)


func _finish() -> void:
	var finished_skill_id: String = ""
	if skill_data != null:
		finished_skill_id = skill_data.skill_id

	effect_finished.emit(finished_skill_id, target_node)
	queue_free()

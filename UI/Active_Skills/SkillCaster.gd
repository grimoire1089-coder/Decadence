extends Node
class_name SkillCaster

signal skill_cast_succeeded(skill_id: String, target: Node)
signal skill_cast_failed(skill_id: String, reason: String)
signal cooldown_updated(skill_id: String, remaining: float, total: float)

@export_node_path("Node2D") var caster_path: NodePath
@export var default_pixels_per_meter: float = 16.0

var _cooldowns: Dictionary = {}
var _is_casting: bool = false
var _casting_skill_id: String = ""


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if _cooldowns.is_empty():
		return

	var erase_list: Array[String] = []

	for skill_id in _cooldowns.keys():
		var data: Dictionary = _cooldowns[skill_id]
		var total: float = float(data.get("total", 0.0))
		var remaining: float = max(float(data.get("remaining", 0.0)) - delta, 0.0)
		data["remaining"] = remaining
		_cooldowns[skill_id] = data
		cooldown_updated.emit(skill_id, remaining, total)

		if remaining <= 0.0:
			erase_list.append(skill_id)

	for skill_id in erase_list:
		_cooldowns.erase(skill_id)
		cooldown_updated.emit(skill_id, 0.0, 0.0)


func validate_cast(skill: RoleSkillData, target: Node2D) -> Dictionary:
	if skill == null:
		return {"ok": false, "reason": "スキルデータがありません"}

	var caster: Node2D = _get_caster_node()
	if caster == null:
		return {"ok": false, "reason": "キャスターが見つかりません"}

	if _is_casting:
		return {"ok": false, "reason": "詠唱中です"}

	if target == null or not is_instance_valid(target):
		return {"ok": false, "reason": "対象がいません"}

	if is_on_cooldown(skill.skill_id):
		return {"ok": false, "reason": "クールタイム中です"}

	var caster_stats: Node = SkillHelpers.resolve_stats_manager(caster)
	if caster_stats == null:
		return {"ok": false, "reason": "キャスターのステータス管理が見つかりません"}

	if not SkillHelpers.can_spend_mp(caster_stats, skill.mp_cost):
		return {"ok": false, "reason": "MPが足りません"}

	var target_stats: Node = SkillHelpers.resolve_stats_manager(target)
	if target_stats == null:
		return {"ok": false, "reason": "対象を回復できません"}

	var allowed_distance: float = _get_effective_range_pixels(skill)
	if allowed_distance > 0.0 and caster.global_position.distance_to(target.global_position) > allowed_distance:
		return {"ok": false, "reason": "射程外です"}

	return {"ok": true, "reason": ""}


func cast_skill(skill: RoleSkillData, target: Node2D) -> bool:
	var check: Dictionary = validate_cast(skill, target)
	if check.get("ok", false) != true:
		var failed_skill_id: String = ""
		if skill != null:
			failed_skill_id = skill.skill_id
		skill_cast_failed.emit(failed_skill_id, String(check.get("reason", "発動できません")))
		return false

	var caster: Node2D = _get_caster_node()
	if not SkillHelpers.spend_mp(caster, skill.mp_cost):
		skill_cast_failed.emit(skill.skill_id, "MPの消費に失敗しました")
		return false

	var cast_time: float = max(skill.cast_time_seconds, 0.0)
	if cast_time > 0.0:
		_begin_cast(skill, target, cast_time)
		return true

	return _apply_skill_effect(skill, target)


func is_casting() -> bool:
	return _is_casting


func is_on_cooldown(skill_id: String) -> bool:
	if not _cooldowns.has(skill_id):
		return false
	return float(_cooldowns[skill_id].get("remaining", 0.0)) > 0.0


func get_cooldown_remaining(skill_id: String) -> float:
	if not _cooldowns.has(skill_id):
		return 0.0
	return float(_cooldowns[skill_id].get("remaining", 0.0))


func get_cooldown_ratio(skill_id: String) -> float:
	if not _cooldowns.has(skill_id):
		return 0.0

	var data: Dictionary = _cooldowns[skill_id]
	var total: float = max(float(data.get("total", 0.0)), 0.0001)
	var remaining: float = max(float(data.get("remaining", 0.0)), 0.0)
	return clampf(remaining / total, 0.0, 1.0)


func _get_caster_node() -> Node2D:
	if not caster_path.is_empty():
		var target_node: Node = get_node_or_null(caster_path)
		if target_node is Node2D:
			return target_node as Node2D

	if get_parent() is Node2D:
		return get_parent() as Node2D

	if owner is Node2D:
		return owner as Node2D

	return null


func _get_effective_range_pixels(skill: RoleSkillData) -> float:
	if skill == null:
		return 0.0
	if skill.pixels_per_meter > 0.0:
		return skill.get_range_distance_pixels()
	return max(skill.range_meters, 0.0) * max(default_pixels_per_meter, 0.0)


func _start_cooldown(skill_id: String, seconds: float) -> void:
	if skill_id.is_empty() or seconds <= 0.0:
		return

	_cooldowns[skill_id] = {
		"remaining": seconds,
		"total": seconds
	}
	cooldown_updated.emit(skill_id, seconds, seconds)


func _begin_cast(skill: RoleSkillData, target: Node2D, cast_time: float) -> void:
	_is_casting = true
	_casting_skill_id = skill.skill_id

	var timer := get_tree().create_timer(cast_time)
	timer.timeout.connect(_finish_cast.bind(skill, target), CONNECT_ONE_SHOT)


func _clear_cast_state() -> void:
	_is_casting = false
	_casting_skill_id = ""


func _validate_cast_finish(skill: RoleSkillData, target: Node2D) -> Dictionary:
	if skill == null:
		return {"ok": false, "reason": "スキルデータがありません"}

	var caster: Node2D = _get_caster_node()
	if caster == null:
		return {"ok": false, "reason": "キャスターが見つかりません"}

	if target == null or not is_instance_valid(target):
		return {"ok": false, "reason": "対象がいません"}

	var target_stats: Node = SkillHelpers.resolve_stats_manager(target)
	if target_stats == null:
		return {"ok": false, "reason": "対象を回復できません"}

	var allowed_distance: float = _get_effective_range_pixels(skill)
	if allowed_distance > 0.0 and caster.global_position.distance_to(target.global_position) > allowed_distance:
		return {"ok": false, "reason": "射程外です"}

	return {"ok": true, "reason": ""}


func _finish_cast(skill: RoleSkillData, target: Node2D) -> void:
	var check: Dictionary = _validate_cast_finish(skill, target)
	if check.get("ok", false) != true:
		_clear_cast_state()
		var failed_skill_id: String = ""
		if skill != null:
			failed_skill_id = skill.skill_id
		skill_cast_failed.emit(failed_skill_id, String(check.get("reason", "発動できません")))
		return

	_apply_skill_effect(skill, target)
	_clear_cast_state()


func _apply_skill_effect(skill: RoleSkillData, target: Node2D) -> bool:
	var success: bool = false

	match skill.effect_type:
		"heal":
			success = SkillHelpers.heal_target(target, skill.heal_amount)
		"heal_over_time":
			_apply_heal_over_time(skill, target)
			success = true
		_:
			skill_cast_failed.emit(skill.skill_id, "未対応の効果タイプです")
			return false

	if not success:
		skill_cast_failed.emit(skill.skill_id, "効果の適用に失敗しました")
		return false

	_start_cooldown(skill.skill_id, skill.cooldown_seconds)
	SkillHelpers.add_system_log("%s を発動した" % skill.display_name)
	skill_cast_succeeded.emit(skill.skill_id, target)
	return true


func _apply_heal_over_time(skill: RoleSkillData, target: Node2D) -> void:
	var caster: Node2D = _get_caster_node()

	for child in target.get_children():
		if child is HealOverTimeEffect:
			var effect := child as HealOverTimeEffect
			if effect.matches_effect(skill.skill_id, caster):
				effect.refresh(skill, target, caster)
				return

	var effect: HealOverTimeEffect = HealOverTimeEffect.new()
	effect.setup(skill, target, caster)
	target.add_child(effect)

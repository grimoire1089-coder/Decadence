extends Node
class_name AutoAttackController

signal auto_attack_toggled(enabled: bool)
signal modifier_changed(modifier)
signal attack_performed(target, damage: int)

const MODAL_UI_GROUPS: Array[StringName] = [
	&"vending_ui",
	&"crop_machine_ui",
	&"skill_ui",
	&"npc_dialog_ui",
	&"pause_menu_ui"
]

@export_node_path("Node2D") var attacker_path: NodePath
@export_node_path("Node") var stats_subject_path: NodePath
@export_node_path("Node") var hotbar_path: NodePath
@export_node_path("Node") var targeting_controller_path: NodePath
@export_node_path("Node") var skill_caster_path: NodePath

@export_group("Auto Attack")
@export var auto_attack_enabled: bool = false
@export_range(0.05, 30.0, 0.05) var attack_interval_seconds: float = 1.0
@export_range(1.0, 256.0, 1.0) var pixels_per_meter: float = 16.0
@export_enum("selected_target", "nearest_hostile_in_range") var target_mode: String = "selected_target"
@export var current_modifier: AutoAttackModifierData = null

@export_group("Search")
@export_range(0.0, 100.0, 0.1) var search_radius_meters: float = 25.0

@export_group("Log")
@export var write_attack_log: bool = false
@export var write_state_log: bool = false

var _attacker: Node2D = null
var _stats_subject: Node = null
var _hotbar: Node = null
var _targeting_controller: Node = null
var _skill_caster: Node = null
var _attack_cooldown_remaining: float = 0.0
var _last_state_log: String = ""


func _ready() -> void:
	add_to_group("auto_attack_controller")
	_resolve_references()
	_connect_hotbar()
	_sync_hotbar_state(false)
	set_process(true)
	call_deferred("_late_bind_references")


func _late_bind_references() -> void:
	await get_tree().process_frame
	_resolve_references()
	_connect_hotbar()
	_sync_hotbar_state(false)


func _process(delta: float) -> void:
	if _attack_cooldown_remaining > 0.0:
		_attack_cooldown_remaining = max(_attack_cooldown_remaining - delta, 0.0)

	if _hotbar == null:
		_connect_hotbar()
	if _targeting_controller == null:
		_targeting_controller = _find_targeting_controller()
	if _skill_caster == null:
		_skill_caster = _find_skill_caster()

	if not auto_attack_enabled:
		_log_state_once("auto_attack_off")
		return
	if current_modifier == null:
		_log_state_once("modifier_missing")
		return
	if _attack_cooldown_remaining > 0.0:
		return
	if _is_any_modal_ui_visible():
		_log_state_once("modal_visible")
		return
	if _is_skill_casting():
		_log_state_once("skill_casting")
		return

	_attacker = _find_attacker()
	if _attacker == null:
		_log_state_once("attacker_missing")
		return

	var target: Node2D = _resolve_target()
	if target == null:
		_log_state_once("target_missing")
		return
	if not _is_target_attackable(target):
		_log_state_once("target_not_attackable")
		return
	if not _is_target_in_range(target):
		_log_state_once("target_out_of_range")
		return

	var damage: int = _calculate_damage()
	if damage <= 0:
		_log_state_once("damage_zero")
		return

	var success: bool = SkillHelpers.damage_target(target, damage, "normal_damage")
	if not success:
		_log_state_once("damage_apply_failed")
		return

	_last_state_log = ""
	_attack_cooldown_remaining = max(attack_interval_seconds, 0.05)
	if write_attack_log:
		SkillHelpers.add_system_log("通常攻撃: %s に %d ダメージ" % [_get_target_name(target), damage])
	attack_performed.emit(target, damage)


func set_auto_attack_enabled(enabled: bool, emit_signal_flag: bool = true, sync_hotbar: bool = true) -> void:
	var changed: bool = auto_attack_enabled != enabled
	auto_attack_enabled = enabled

	if sync_hotbar:
		_sync_hotbar_state(false)

	if changed and emit_signal_flag:
		auto_attack_toggled.emit(auto_attack_enabled)


func toggle_auto_attack() -> void:
	set_auto_attack_enabled(not auto_attack_enabled)


func is_auto_attack_enabled() -> bool:
	return auto_attack_enabled


func get_current_modifier() -> AutoAttackModifierData:
	return current_modifier


func set_current_modifier(modifier: AutoAttackModifierData, emit_signal_flag: bool = true) -> void:
	if current_modifier == modifier:
		return

	current_modifier = modifier
	if emit_signal_flag:
		modifier_changed.emit(current_modifier)


func get_attack_interval() -> float:
	return max(attack_interval_seconds, 0.05)


func _resolve_references() -> void:
	_attacker = _find_attacker()
	_stats_subject = _find_stats_subject()
	_hotbar = _find_hotbar()
	_targeting_controller = _find_targeting_controller()
	_skill_caster = _find_skill_caster()


func _find_attacker() -> Node2D:
	if not attacker_path.is_empty():
		var by_path: Node = get_node_or_null(attacker_path)
		if by_path is Node2D:
			return by_path as Node2D

	var parent_node: Node = get_parent()
	if parent_node is Node2D:
		return parent_node as Node2D

	if owner is Node2D:
		return owner as Node2D

	return null


func _find_stats_subject() -> Node:
	if not stats_subject_path.is_empty():
		var by_path: Node = get_node_or_null(stats_subject_path)
		if by_path != null:
			return by_path

	var attacker: Node2D = _find_attacker()
	if attacker != null:
		return attacker

	return get_parent()


func _find_hotbar() -> Node:
	if not hotbar_path.is_empty():
		var by_path: Node = get_node_or_null(hotbar_path)
		if by_path != null:
			return by_path

	var by_group: Node = get_tree().get_first_node_in_group("skill_hotbar_ui")
	if by_group != null:
		return by_group

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		var found: Node = current_scene.find_child("SkillHotbarUI", true, false)
		if found != null:
			return found

	var root: Node = get_tree().root
	if root != null:
		var found_root: Node = root.find_child("SkillHotbarUI", true, false)
		if found_root != null:
			return found_root

	return null


func _find_targeting_controller() -> Node:
	if not targeting_controller_path.is_empty():
		var by_path: Node = get_node_or_null(targeting_controller_path)
		if by_path != null:
			return by_path

	var by_group: Node = get_tree().get_first_node_in_group("player_targeting_controller")
	if by_group != null:
		return by_group

	var parent_node: Node = get_parent()
	if parent_node != null:
		var sibling: Node = parent_node.get_node_or_null("TargetingController")
		if sibling != null:
			return sibling

	return null


func _find_skill_caster() -> Node:
	if not skill_caster_path.is_empty():
		var by_path: Node = get_node_or_null(skill_caster_path)
		if by_path != null:
			return by_path

	var parent_node: Node = get_parent()
	if parent_node != null:
		var sibling: Node = parent_node.get_node_or_null("SkillCaster")
		if sibling != null:
			return sibling

	return null


func _connect_hotbar() -> void:
	var found_hotbar: Node = _find_hotbar()
	if found_hotbar == null:
		return

	if _hotbar != null and _hotbar != found_hotbar:
		var old_callback := Callable(self, "_on_hotbar_auto_attack_toggled")
		if _hotbar.has_signal("auto_attack_toggled") and _hotbar.is_connected("auto_attack_toggled", old_callback):
			_hotbar.disconnect("auto_attack_toggled", old_callback)

	_hotbar = found_hotbar
	if not _hotbar.has_signal("auto_attack_toggled"):
		return

	if _hotbar.has_method("is_auto_attack_enabled"):
		set_auto_attack_enabled(bool(_hotbar.call("is_auto_attack_enabled")), false, false)

	var callback := Callable(self, "_on_hotbar_auto_attack_toggled")
	if not _hotbar.is_connected("auto_attack_toggled", callback):
		_hotbar.connect("auto_attack_toggled", callback)


func _sync_hotbar_state(emit_signal_flag: bool) -> void:
	_hotbar = _find_hotbar()
	if _hotbar == null:
		return
	if _hotbar.has_method("set_auto_attack_enabled"):
		_hotbar.call("set_auto_attack_enabled", auto_attack_enabled, emit_signal_flag)


func _on_hotbar_auto_attack_toggled(enabled: bool) -> void:
	set_auto_attack_enabled(enabled, true, false)


func _is_skill_casting() -> bool:
	_skill_caster = _find_skill_caster()
	if _skill_caster == null:
		return false
	if not _skill_caster.has_method("is_casting"):
		return false
	return bool(_skill_caster.call("is_casting"))


func _resolve_target() -> Node2D:
	match target_mode:
		"nearest_hostile_in_range":
			return _find_nearest_hostile_target()
		_:
			return _get_selected_target()


func _get_selected_target() -> Node2D:
	_targeting_controller = _find_targeting_controller()
	if _targeting_controller == null:
		return null
	if not _targeting_controller.has_method("get_current_target"):
		return null

	var value: Variant = _targeting_controller.call("get_current_target")
	if value is Node2D:
		return value as Node2D
	return null


func _find_nearest_hostile_target() -> Node2D:
	var attacker: Node2D = _find_attacker()
	if attacker == null:
		return null

	var nearest: Node2D = null
	var nearest_distance_sq: float = INF
	var max_distance_px: float = max(search_radius_meters, 0.0) * max(pixels_per_meter, 0.0)

	for node in get_tree().get_nodes_in_group("hostile_target"):
		if not (node is Node2D):
			continue

		var target: Node2D = node as Node2D
		if not _is_target_attackable(target):
			continue

		var distance_sq: float = attacker.global_position.distance_squared_to(target.global_position)
		if max_distance_px > 0.0 and distance_sq > max_distance_px * max_distance_px:
			continue
		if distance_sq < nearest_distance_sq:
			nearest_distance_sq = distance_sq
			nearest = target

	return nearest


func _is_target_attackable(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if not _is_hostile_target(target):
		return false
	return SkillHelpers.resolve_stats_manager(target) != null


func _is_target_in_range(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false

	var attacker: Node2D = _find_attacker()
	if attacker == null:
		return false

	var allowed_distance: float = _get_modifier_range_pixels()
	if allowed_distance <= 0.0:
		return true

	return attacker.global_position.distance_to(target.global_position) <= allowed_distance


func _get_modifier_range_pixels() -> float:
	if current_modifier == null:
		return 0.0
	return max(current_modifier.range_meters, 0.0) * max(pixels_per_meter, 0.0)


func _calculate_damage() -> int:
	var attack_power: int = max(_get_attack_power_from_stats(), 1)
	if current_modifier == null:
		return attack_power
	return max(int(round(float(attack_power) * max(current_modifier.damage_multiplier, 0.0))), 1)


func _get_attack_power_from_stats() -> int:
	_stats_subject = _find_stats_subject()
	var stats_manager: Node = SkillHelpers.resolve_stats_manager(_stats_subject)
	if stats_manager == null:
		return 1

	var source: String = "physical"
	if current_modifier != null:
		source = current_modifier.attack_source

	match source:
		"magical":
			return max(_read_magical_attack_power(stats_manager), 1)
		_:
			return max(_read_physical_attack_power(stats_manager), 1)


func _read_physical_attack_power(stats_manager: Node) -> int:
	if stats_manager.has_method("get_physical_attack_power"):
		return int(stats_manager.call("get_physical_attack_power"))
	if stats_manager.has_method("get_attack_power"):
		return int(stats_manager.call("get_attack_power"))
	if stats_manager.has_method("get_stat"):
		return int(stats_manager.call("get_stat", "strength"))
	if _stats_subject != null and _stats_subject.has_method("get_stat_value"):
		return int(_stats_subject.call("get_stat_value", "strength"))
	if stats_manager.has_method("get_strength"):
		return int(stats_manager.call("get_strength"))
	return 1


func _read_magical_attack_power(stats_manager: Node) -> int:
	if stats_manager.has_method("get_magical_attack_power"):
		return int(stats_manager.call("get_magical_attack_power"))
	if stats_manager.has_method("get_magic_attack_power"):
		return int(stats_manager.call("get_magic_attack_power"))
	if stats_manager.has_method("get_stat"):
		return int(stats_manager.call("get_stat", "intelligence"))
	if _stats_subject != null and _stats_subject.has_method("get_stat_value"):
		return int(_stats_subject.call("get_stat_value", "intelligence"))
	if stats_manager.has_method("get_intelligence"):
		return int(stats_manager.call("get_intelligence"))
	return 1


func _is_hostile_target(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.is_in_group("hostile_target"):
		return true
	return target is EnemyNPC


func _get_target_name(target: Node) -> String:
	if target == null:
		return "対象"
	if target.has_method("get_target_display_name"):
		return String(target.call("get_target_display_name"))
	return String(target.name)


func _is_any_modal_ui_visible() -> bool:
	for group_name in MODAL_UI_GROUPS:
		var ui: Control = get_tree().get_first_node_in_group(String(group_name)) as Control
		if ui != null and ui.visible:
			return true
	return false


func _log_state_once(state_key: String) -> void:
	if not write_state_log:
		return
	if _last_state_log == state_key:
		return
	_last_state_log = state_key
	SkillHelpers.add_system_log("[AutoAttack] %s" % state_key)

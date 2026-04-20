extends Node

signal stats_changed
signal stat_changed(stat_name: String, value: int)
signal skill_changed(skill_name: String, value: int)
signal hp_changed(current_hp: int, max_hp: int)
signal mp_changed(current_mp: int, max_mp: int)
signal stamina_changed(current_stamina: int, max_stamina: int)
signal fullness_changed(current_fullness: int, max_fullness: int)
signal fatigue_changed(current_fatigue: int, max_fatigue: int)
signal level_changed(level: int)
signal skill_exp_changed(skill_name: String, current_exp: int, next_exp: int, level: int, max_level: int)

const SAVE_PATH: String = "user://player_stats.json"
const FARMING_SKILL_NAME: String = "farming"
const COOKING_SKILL_NAME: String = "cooking"
const FARMING_MAX_LEVEL: int = 300
const COOKING_MAX_LEVEL: int = 300
const FARMING_EXP_CURVE_PATH: String = "res://Data/Curves/FarmingExpCurve.tres"
const COOKING_EXP_CURVE_PATH: String = FARMING_EXP_CURVE_PATH

const EXP_SKILL_SETTINGS: Dictionary = {
	FARMING_SKILL_NAME: {
		"display_name": "農業",
		"min_level": 1,
		"max_level": FARMING_MAX_LEVEL,
		"curve_path": FARMING_EXP_CURVE_PATH
	},
	COOKING_SKILL_NAME: {
		"display_name": "料理",
		"min_level": 1,
		"max_level": COOKING_MAX_LEVEL,
		"curve_path": COOKING_EXP_CURVE_PATH
	}
}

const DEFAULT_CORE: Dictionary = {
	"level": 1,
	"exp": 0,
	"next_exp": 100,
	"stat_points": 0,
	"skill_points": 0
}

const DEFAULT_STATS: Dictionary = {
	"strength": 5,
	"vitality": 5,
	"agility": 5,
	"intelligence": 5,
	"dexterity": 5,
	"luck": 5,
	"mp_regen": 1
}

const DEFAULT_VITALS: Dictionary = {
	"hp": 100,
	"max_hp": 100,
	"mp": 50,
	"max_mp": 50,
	"stamina": 100,
	"max_stamina": 100,
	"fullness": 100,
	"max_fullness": 100,
	"fatigue": 0,
	"max_fatigue": 100
}

enum HungerState {
	STARVING,
	HUNGRY,
	NORMAL,
	WELL_FED
}

enum FatigueState {
	RESTED,
	NORMAL,
	TIRED,
	EXHAUSTED
}

const ACTION_FATIGUE_COSTS: Dictionary = {
	"plant": 2,
	"harvest": 3,
	"water": 1,
	"chop": 4,
	"mine": 5,
	"craft": 2,
	"cook": 2,
	"default": 1
}

const DEFAULT_SKILLS: Dictionary = {
	"sword": 0,
	"mining": 0,
	"fishing": 0,
	"cooking": 1,
	"trading": 0,
	"farming": 1
}

const DEFAULT_SKILL_EXPS: Dictionary = {
	"farming": 0,
	"cooking": 0
}

const FULLNESS_DECAY_INTERVAL_MINUTES: int = 10
const FULLNESS_DECAY_AMOUNT: int = 1
const MP_REGEN_INTERVAL_SECONDS: float = 6.0

var core: Dictionary = {}
var stats: Dictionary = {}
var vitals: Dictionary = {}
var skills: Dictionary = {}
var skill_exps: Dictionary = {}
var _skill_exp_curves: Dictionary = {}
var _last_fullness_decay_total_minutes: int = -1
var _mp_regen_elapsed: float = 0.0


func _ready() -> void:
	_load_skill_curves()
	reset_to_default()
	load_data()
	call_deferred("_connect_time_manager")
	_emit_all_changed()


func _process(delta: float) -> void:
	_update_mp_regeneration(delta)


func reset_to_default() -> void:
	core = DEFAULT_CORE.duplicate(true)
	stats = DEFAULT_STATS.duplicate(true)
	vitals = DEFAULT_VITALS.duplicate(true)
	skills = DEFAULT_SKILLS.duplicate(true)
	skill_exps = DEFAULT_SKILL_EXPS.duplicate(true)
	_recalculate_derived_stats(false)


func _connect_time_manager() -> void:
	var time_manager: Node = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return

	var callback := Callable(self, "_on_time_manager_time_changed")
	if not time_manager.is_connected("time_changed", callback):
		time_manager.connect("time_changed", callback)


func _on_time_manager_time_changed(day: int, hour: int, minute: int) -> void:
	var total_minutes: int = ((day - 1) * 24 * 60) + (hour * 60) + minute

	if _last_fullness_decay_total_minutes < 0:
		_last_fullness_decay_total_minutes = total_minutes
		return

	var previous_bucket: int = floori(float(_last_fullness_decay_total_minutes) / float(FULLNESS_DECAY_INTERVAL_MINUTES))
	var current_bucket: int = floori(float(total_minutes) / float(FULLNESS_DECAY_INTERVAL_MINUTES))
	var passed_intervals: int = current_bucket - previous_bucket
	_last_fullness_decay_total_minutes = total_minutes

	if passed_intervals <= 0:
		return

	consume_fullness(passed_intervals * FULLNESS_DECAY_AMOUNT)


# ----------------------------
# 基本取得
# ----------------------------

func get_level() -> int:
	return int(core.get("level", 1))


func get_exp() -> int:
	return int(core.get("exp", 0))


func get_next_exp() -> int:
	return int(core.get("next_exp", 100))


func get_stat_points() -> int:
	return int(core.get("stat_points", 0))


func get_skill_points(_skill_name: String = "") -> int:
	return int(core.get("skill_points", 0))


func get_stat(stat_name: String) -> int:
	return int(stats.get(stat_name, 0))


func get_mp_regen() -> int:
	return max(get_stat("mp_regen"), 0)


func get_skill(skill_name: String) -> int:
	return int(skills.get(skill_name, 0))


func get_skill_exp(skill_name: String) -> int:
	return int(skill_exps.get(skill_name, 0))


func get_skill_max_level(skill_name: String) -> int:
	if not _is_exp_skill(skill_name):
		return 0
	return int(EXP_SKILL_SETTINGS[skill_name].get("max_level", 0))


func get_skill_next_exp(skill_name: String) -> int:
	if not _is_exp_skill(skill_name):
		return 0
	return _get_skill_required_exp(skill_name, get_skill(skill_name))


func get_farming_quality_bonus() -> float:
	var level: int = clamp(get_skill(FARMING_SKILL_NAME), 1, FARMING_MAX_LEVEL)

	if FARMING_MAX_LEVEL <= 1:
		return 0.0

	return clamp(
		float(level - 1) / float(FARMING_MAX_LEVEL - 1),
		0.0,
		1.0
	)


func get_farming_quality_level_bonus() -> int:
	return max(get_skill(FARMING_SKILL_NAME), 0)


func get_farming_quality_passive_flat_bonus() -> int:
	return 0


func get_farming_quality_passive_multiplier() -> float:
	return 1.0


func get_hp() -> int:
	return int(vitals.get("hp", 0))


func get_max_hp() -> int:
	return int(vitals.get("max_hp", 0))


func get_mp() -> int:
	return int(vitals.get("mp", 0))


func get_max_mp() -> int:
	return int(vitals.get("max_mp", 0))


func get_stamina() -> int:
	return int(vitals.get("stamina", 0))


func get_max_stamina() -> int:
	return int(vitals.get("max_stamina", 0))


func get_fullness() -> int:
	return int(vitals.get("fullness", 0))


func get_max_fullness() -> int:
	return int(vitals.get("max_fullness", 100))


func get_fatigue() -> int:
	return int(vitals.get("fatigue", 0))


func get_max_fatigue() -> int:
	return int(vitals.get("max_fatigue", 100))


func get_hunger_state() -> HungerState:
	var max_fullness: int = max(get_max_fullness(), 1)
	var ratio: float = float(get_fullness()) / float(max_fullness)

	if ratio >= 0.85:
		return HungerState.WELL_FED
	if ratio >= 0.50:
		return HungerState.NORMAL
	if ratio >= 0.20:
		return HungerState.HUNGRY
	return HungerState.STARVING


func get_fatigue_state() -> FatigueState:
	var max_fatigue: int = max(get_max_fatigue(), 1)
	var ratio: float = float(get_fatigue()) / float(max_fatigue)

	if ratio <= 0.15:
		return FatigueState.RESTED
	if ratio <= 0.50:
		return FatigueState.NORMAL
	if ratio <= 0.80:
		return FatigueState.TIRED
	return FatigueState.EXHAUSTED


func get_fullness_ratio() -> float:
	var max_fullness: int = max(get_max_fullness(), 1)
	return clamp(float(get_fullness()) / float(max_fullness), 0.0, 1.0)


func get_fatigue_ratio() -> float:
	var max_fatigue: int = max(get_max_fatigue(), 1)
	return clamp(float(get_fatigue()) / float(max_fatigue), 0.0, 1.0)


func get_hunger_state_text() -> String:
	match get_hunger_state():
		HungerState.WELL_FED:
			return "満腹"
		HungerState.NORMAL:
			return "普通"
		HungerState.HUNGRY:
			return "空腹"
		HungerState.STARVING:
			return "飢餓"
	return "不明"


func get_fatigue_state_text() -> String:
	match get_fatigue_state():
		FatigueState.RESTED:
			return "快調"
		FatigueState.NORMAL:
			return "普通"
		FatigueState.TIRED:
			return "疲労"
		FatigueState.EXHAUSTED:
			return "限界"
	return "不明"


# ----------------------------
# ステータス変更
# ----------------------------

func set_stat(stat_name: String, value: int) -> void:
	if not stats.has(stat_name):
		return

	stats[stat_name] = max(value, 0)
	_recalculate_derived_stats(true)
	stat_changed.emit(stat_name, int(stats[stat_name]))
	_after_data_changed()


func add_stat(stat_name: String, amount: int) -> void:
	set_stat(stat_name, get_stat(stat_name) + amount)


func spend_stat_points(stat_name: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	if not stats.has(stat_name):
		return false
	if get_stat_points() < amount:
		return false

	core["stat_points"] = get_stat_points() - amount
	stats[stat_name] = get_stat(stat_name) + amount

	_recalculate_derived_stats(true)
	stat_changed.emit(stat_name, int(stats[stat_name]))
	_after_data_changed()
	return true


# ----------------------------
# スキル変更
# ----------------------------

func set_skill(skill_name: String, value: int) -> void:
	if not skills.has(skill_name):
		return

	var new_value: int = max(value, 0)

	if _is_exp_skill(skill_name):
		new_value = clamp(new_value, _get_skill_min_level(skill_name), get_skill_max_level(skill_name))
		if new_value >= get_skill_max_level(skill_name):
			skill_exps[skill_name] = 0

	skills[skill_name] = new_value
	skill_changed.emit(skill_name, int(skills[skill_name]))
	_emit_skill_progress_changed(skill_name)
	_after_data_changed()


func add_skill(skill_name: String, amount: int = 1) -> void:
	set_skill(skill_name, get_skill(skill_name) + amount)


func gain_skill_exp(skill_name: String, amount: int) -> void:
	if amount <= 0:
		return
	if not skills.has(skill_name):
		return

	if _is_exp_skill(skill_name):
		_gain_exp_skill(skill_name, amount)
	else:
		add_skill(skill_name, amount)


func spend_skill_points(skill_name: String, amount: int = 1) -> bool:
	if amount <= 0:
		return false
	if not skills.has(skill_name):
		return false
	if get_skill_points(skill_name) < amount:
		return false

	var current_value: int = get_skill(skill_name)
	var new_value: int = current_value + amount

	if _is_exp_skill(skill_name):
		new_value = clamp(new_value, _get_skill_min_level(skill_name), get_skill_max_level(skill_name))
		if new_value == current_value:
			return false

	core["skill_points"] = get_skill_points(skill_name) - amount
	skills[skill_name] = new_value

	if _is_exp_skill(skill_name) and new_value >= get_skill_max_level(skill_name):
		skill_exps[skill_name] = 0

	skill_changed.emit(skill_name, int(skills[skill_name]))
	_emit_skill_progress_changed(skill_name)
	_after_data_changed()
	return true


func _gain_exp_skill(skill_name: String, amount: int) -> void:
	if not _is_exp_skill(skill_name):
		return

	var min_level: int = _get_skill_min_level(skill_name)
	var max_level: int = get_skill_max_level(skill_name)
	var level: int = clamp(get_skill(skill_name), min_level, max_level)
	var current_exp: int = max(get_skill_exp(skill_name), 0)

	if level >= max_level:
		skill_exps[skill_name] = 0
		_emit_skill_progress_changed(skill_name)
		_after_data_changed()
		return

	current_exp += amount
	var leveled_up: bool = false

	while level < max_level:
		var required: int = _get_skill_required_exp(skill_name, level)
		if required <= 0 or current_exp < required:
			break

		current_exp -= required
		level += 1
		leveled_up = true

	if level >= max_level:
		level = max_level
		current_exp = 0

	skills[skill_name] = level
	skill_exps[skill_name] = current_exp

	if leveled_up:
		skill_changed.emit(skill_name, level)
		_log_system("%sスキルが Lv.%d になった" % [_get_skill_display_name(skill_name), level])

	_emit_skill_progress_changed(skill_name)
	_after_data_changed()


# ----------------------------
# HP / MP / STAMINA
# ----------------------------

func set_hp(value: int) -> void:
	vitals["hp"] = clamp(value, 0, get_max_hp())
	hp_changed.emit(get_hp(), get_max_hp())
	_after_data_changed()


func heal_hp(amount: int) -> void:
	if amount <= 0:
		return

	var before_hp: int = get_hp()
	set_hp(before_hp + amount)

	var applied_heal: int = get_hp() - before_hp
	if applied_heal > 0:
		_show_combat_indicator(applied_heal, "hp_heal")


func damage_hp(amount: int) -> void:
	if amount <= 0:
		return

	var before_hp: int = get_hp()
	set_hp(before_hp - amount)

	var applied_damage: int = before_hp - get_hp()
	if applied_damage > 0:
		_show_combat_indicator(applied_damage, "normal_damage")


func set_mp(value: int) -> void:
	vitals["mp"] = clamp(value, 0, get_max_mp())
	mp_changed.emit(get_mp(), get_max_mp())
	_after_data_changed()


func heal_mp(amount: int) -> void:
	if amount <= 0:
		return

	var before_mp: int = get_mp()
	set_mp(before_mp + amount)

	var applied_mp: int = get_mp() - before_mp
	if applied_mp > 0:
		_show_combat_indicator(applied_mp, "mp_heal")


func can_spend_mp(amount: int) -> bool:
	if amount <= 0:
		return true
	return get_mp() >= amount


func spend_mp(amount: int) -> bool:
	if not can_spend_mp(amount):
		return false
	consume_mp(amount)
	return true


func consume_mp(amount: int) -> bool:
	if amount <= 0:
		return true
	if get_mp() < amount:
		return false
	set_mp(get_mp() - amount)
	return true


func set_stamina(value: int) -> void:
	vitals["stamina"] = clamp(value, 0, get_max_stamina())
	stamina_changed.emit(get_stamina(), get_max_stamina())
	_after_data_changed()


func set_fullness(value: int) -> void:
	vitals["fullness"] = clamp(value, 0, get_max_fullness())
	fullness_changed.emit(get_fullness(), get_max_fullness())
	_after_data_changed()


func restore_fullness(amount: int) -> void:
	if amount <= 0:
		return
	set_fullness(get_fullness() + amount)


func consume_fullness(amount: int) -> void:
	if amount <= 0:
		return
	set_fullness(get_fullness() - amount)


func set_fatigue(value: int) -> void:
	vitals["fatigue"] = clamp(value, 0, get_max_fatigue())
	fatigue_changed.emit(get_fatigue(), get_max_fatigue())
	_after_data_changed()


func add_fatigue(amount: int) -> void:
	if amount <= 0:
		return
	set_fatigue(get_fatigue() + amount)


func recover_fatigue(amount: int) -> void:
	if amount <= 0:
		return
	set_fatigue(get_fatigue() - amount)


func apply_fatigue_for_action(action_name: String, multiplier: float = 1.0) -> int:
	var key: String = action_name.to_lower().strip_edges()
	var base_amount: int = int(ACTION_FATIGUE_COSTS.get(key, ACTION_FATIGUE_COSTS.get("default", 1)))
	var added_amount: int = max(int(round(float(base_amount) * max(multiplier, 0.0))), 0)

	if added_amount > 0:
		add_fatigue(added_amount)

	return added_amount


func _update_mp_regeneration(delta: float) -> void:
	if delta <= 0.0:
		return

	if get_mp() >= get_max_mp():
		_mp_regen_elapsed = 0.0
		return

	var regen_amount: int = get_mp_regen()
	if regen_amount <= 0:
		_mp_regen_elapsed = 0.0
		return

	_mp_regen_elapsed += delta

	while _mp_regen_elapsed >= MP_REGEN_INTERVAL_SECONDS:
		_mp_regen_elapsed -= MP_REGEN_INTERVAL_SECONDS
		heal_mp(regen_amount)

		if get_mp() >= get_max_mp():
			_mp_regen_elapsed = 0.0
			break


# ----------------------------
# 経験値 / レベル
# ----------------------------

func gain_exp(amount: int) -> void:
	if amount <= 0:
		return

	core["exp"] = get_exp() + amount

	var did_level_up: bool = false

	while true:
		var required: int = get_next_exp()
		if get_exp() < required:
			break

		core["exp"] = get_exp() - required
		core["level"] = get_level() + 1
		core["next_exp"] = int(round(float(required) * 1.25))
		core["stat_points"] = get_stat_points() + 3
		core["skill_points"] = get_skill_points() + 1
		did_level_up = true

	if did_level_up:
		_recalculate_derived_stats(true)
		level_changed.emit(get_level())
		_log_system("レベルが %d になった" % get_level())

	_after_data_changed()


# ----------------------------
# 派生値計算
# ----------------------------

func _recalculate_derived_stats(keep_current_values: bool = true) -> void:
	var current_hp: int = int(vitals.get("hp", 100))
	var current_mp: int = int(vitals.get("mp", 30))
	var current_stamina: int = int(vitals.get("stamina", 100))
	var current_fullness: int = int(vitals.get("fullness", 100))
	var current_fatigue: int = int(vitals.get("fatigue", 0))

	var new_max_hp: int = 100 + get_stat("vitality") * 10 + (get_level() - 1) * 5
	var new_max_mp: int = 30 + get_stat("intelligence") * 5
	var new_max_stamina: int = 100 + get_stat("agility") * 5
	var new_max_fullness: int = 100
	var new_max_fatigue: int = 100

	vitals["max_hp"] = new_max_hp
	vitals["max_mp"] = new_max_mp
	vitals["max_stamina"] = new_max_stamina
	vitals["max_fullness"] = new_max_fullness
	vitals["max_fatigue"] = new_max_fatigue

	if keep_current_values:
		vitals["hp"] = clamp(current_hp, 0, new_max_hp)
		vitals["mp"] = clamp(current_mp, 0, new_max_mp)
		vitals["stamina"] = clamp(current_stamina, 0, new_max_stamina)
		vitals["fullness"] = clamp(current_fullness, 0, new_max_fullness)
		vitals["fatigue"] = clamp(current_fatigue, 0, new_max_fatigue)
	else:
		vitals["hp"] = new_max_hp
		vitals["mp"] = new_max_mp
		vitals["stamina"] = new_max_stamina
		vitals["fullness"] = new_max_fullness
		vitals["fatigue"] = 0


func _load_skill_curves() -> void:
	_skill_exp_curves.clear()

	for skill_name in EXP_SKILL_SETTINGS.keys():
		var settings: Dictionary = EXP_SKILL_SETTINGS[skill_name]
		var curve_path: String = String(settings.get("curve_path", ""))
		if curve_path.is_empty():
			continue

		var curve: Curve = load(curve_path) as Curve
		if curve == null:
			push_warning("%s経験値Curveが見つからない: %s" % [_get_skill_display_name(String(skill_name)), curve_path])
			continue

		_skill_exp_curves[String(skill_name)] = curve


func _get_skill_required_exp(skill_name: String, level: int) -> int:
	if not _is_exp_skill(skill_name):
		return 0

	var min_level: int = _get_skill_min_level(skill_name)
	var max_level: int = get_skill_max_level(skill_name)
	if level >= max_level:
		return 0

	var safe_level: int = clamp(level, min_level, max_level)
	var t: float = 0.0
	if max_level > min_level:
		t = float(safe_level - min_level) / float(max_level - min_level)

	var base_exp: float = float(safe_level * 10)
	var curve_value: float = 1.0
	var curve: Curve = _skill_exp_curves.get(skill_name, null) as Curve
	if curve != null:
		curve_value = max(curve.sample(t), 1.0)

	return max(int(round(base_exp * curve_value)), 1)


func _emit_skill_progress_changed(skill_name: String) -> void:
	if not _is_exp_skill(skill_name):
		return

	skill_exp_changed.emit(
		skill_name,
		get_skill_exp(skill_name),
		get_skill_next_exp(skill_name),
		get_skill(skill_name),
		get_skill_max_level(skill_name)
	)


func _normalize_skill_data() -> void:
	for skill_name in EXP_SKILL_SETTINGS.keys():
		var normalized_name: String = String(skill_name)
		var min_level: int = _get_skill_min_level(normalized_name)
		var max_level: int = get_skill_max_level(normalized_name)
		var level: int = clamp(int(skills.get(normalized_name, min_level)), min_level, max_level)
		skills[normalized_name] = level

		var exp_value: int = max(int(skill_exps.get(normalized_name, 0)), 0)
		if level >= max_level:
			exp_value = 0
		skill_exps[normalized_name] = exp_value


func _is_exp_skill(skill_name: String) -> bool:
	return EXP_SKILL_SETTINGS.has(skill_name)


func _get_skill_min_level(skill_name: String) -> int:
	if not _is_exp_skill(skill_name):
		return 0
	return int(EXP_SKILL_SETTINGS[skill_name].get("min_level", 1))


func _get_skill_display_name(skill_name: String) -> String:
	if not _is_exp_skill(skill_name):
		return skill_name
	return String(EXP_SKILL_SETTINGS[skill_name].get("display_name", skill_name))


# ----------------------------
# 保存 / 読み込み
# ----------------------------

func save_data() -> void:
	var data: Dictionary = {
		"core": core,
		"stats": stats,
		"vitals": vitals,
		"skills": skills,
		"skill_exps": skill_exps
	}

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("プレイヤーステータスのセーブ失敗: %s" % SAVE_PATH)
		return

	file.store_string(JSON.stringify(data))


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_data()
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("プレイヤーステータスのロード失敗: %s" % SAVE_PATH)
		return

	var text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var err: int = json.parse(text)

	if err != OK:
		push_error("プレイヤーステータスJSON読み込み失敗")
		return

	var loaded: Dictionary = {}
	if typeof(json.data) == TYPE_DICTIONARY:
		loaded = json.data

	core = _merge_dictionary(DEFAULT_CORE, _get_nested_dict(loaded, "core"))
	stats = _merge_dictionary(DEFAULT_STATS, _get_nested_dict(loaded, "stats"))
	vitals = _merge_dictionary(DEFAULT_VITALS, _get_nested_dict(loaded, "vitals"))
	skills = _merge_dictionary(DEFAULT_SKILLS, _get_nested_dict(loaded, "skills"))
	skill_exps = _merge_dictionary(DEFAULT_SKILL_EXPS, _get_nested_dict(loaded, "skill_exps"))

	_normalize_skill_data()
	_recalculate_derived_stats(true)


func _get_nested_dict(source: Dictionary, key: String) -> Dictionary:
	if not source.has(key):
		return {}

	var value = source[key]
	if typeof(value) == TYPE_DICTIONARY:
		return value

	return {}


func _merge_dictionary(base_dict: Dictionary, loaded_dict: Dictionary) -> Dictionary:
	var merged: Dictionary = base_dict.duplicate(true)

	for key in loaded_dict.keys():
		merged[key] = loaded_dict[key]

	return merged


# ----------------------------
# 通知
# ----------------------------

func _after_data_changed() -> void:
	save_data()
	_emit_all_changed()


func _emit_all_changed() -> void:
	stats_changed.emit()
	hp_changed.emit(get_hp(), get_max_hp())
	mp_changed.emit(get_mp(), get_max_mp())
	stamina_changed.emit(get_stamina(), get_max_stamina())
	fullness_changed.emit(get_fullness(), get_max_fullness())
	fatigue_changed.emit(get_fatigue(), get_max_fatigue())
	level_changed.emit(get_level())

	for skill_name in skills.keys():
		skill_changed.emit(String(skill_name), int(skills[skill_name]))

	for skill_name in EXP_SKILL_SETTINGS.keys():
		_emit_skill_progress_changed(String(skill_name))


func _show_combat_indicator(amount: int, indicator_type: String) -> void:
	if amount == 0:
		return

	var manager: Node = get_node_or_null("/root/CombatIndicatorManager")
	if manager == null:
		return

	if manager.has_method("show_for_player"):
		manager.call("show_for_player", amount, indicator_type)


func _get_message_log() -> Node:
	return get_node_or_null("/root/MessageLog")


func _log_system(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node == null:
		return

	if log_node.has_method("add_system"):
		log_node.call("add_system", text)

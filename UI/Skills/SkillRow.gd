extends PanelContainer
class_name SkillRow

@onready var name_label: Label = $MarginContainer/VBoxContainer/TopHBox/NameLabel
@onready var points_label: Label = $MarginContainer/VBoxContainer/TopHBox/PointsLabel
@onready var level_label: Label = $MarginContainer/VBoxContainer/TopHBox/LevelLabel
@onready var exp_bar: ProgressBar = $MarginContainer/VBoxContainer/ExpBar
@onready var exp_label: Label = $MarginContainer/VBoxContainer/BottomHBox/ExpLabel
@onready var remain_label: Label = $MarginContainer/VBoxContainer/BottomHBox/RemainLabel

var _pending_data: Dictionary = {}


func _ready() -> void:
	_apply_pending_if_possible()


func setup(skill_key: String, display_name: String, level: int, max_level: int, current_exp: int, next_exp: int, skill_points: int = 0) -> void:
	_pending_data = {
		"skill_key": skill_key,
		"display_name": display_name,
		"level": level,
		"max_level": max_level,
		"current_exp": current_exp,
		"next_exp": next_exp,
		"skill_points": skill_points,
	}
	_apply_pending_if_possible()


func _apply_pending_if_possible() -> void:
	if not is_node_ready():
		return
	if _pending_data.is_empty():
		return

	var skill_key: String = str(_pending_data.get("skill_key", ""))
	var display_name: String = str(_pending_data.get("display_name", skill_key))
	var level: int = int(_pending_data.get("level", 0))
	var max_level: int = int(_pending_data.get("max_level", 0))
	var current_exp: int = int(_pending_data.get("current_exp", 0))
	var next_exp: int = int(_pending_data.get("next_exp", 1))
	var skill_points: int = int(_pending_data.get("skill_points", 0))

	var safe_level: int = max(level, 0)
	var safe_max_level: int = max(max_level, 0)
	var safe_current_exp: int = max(current_exp, 0)
	var safe_next_exp: int = max(next_exp, 1)
	var safe_skill_points: int = max(skill_points, 0)
	var is_max_level: bool = safe_max_level > 0 and safe_level >= safe_max_level
	var ratio: float = 1.0

	if not is_max_level:
		ratio = clamp(float(safe_current_exp) / float(safe_next_exp), 0.0, 1.0)

	name_label.text = display_name
	name_label.tooltip_text = "skill_key: %s" % skill_key
	points_label.text = "Pt %d" % safe_skill_points
	points_label.tooltip_text = "このスキル専用ポイント"

	if safe_max_level > 0:
		level_label.text = "Lv.%d / %d" % [safe_level, safe_max_level]
	else:
		level_label.text = "Lv.%d" % safe_level

	exp_bar.max_value = 100.0
	exp_bar.value = ratio * 100.0
	exp_bar.show_percentage = false

	if is_max_level:
		exp_label.text = "EXP MAX"
		remain_label.text = "専用Pt %d" % safe_skill_points
	else:
		var remain: int = max(safe_next_exp - safe_current_exp, 0)
		exp_label.text = "EXP %d / %d" % [safe_current_exp, safe_next_exp]
		remain_label.text = "専用Pt %d   次のレベルまで %d" % [safe_skill_points, remain]

extends Node2D
class_name CombatIndicator

@export var rise_distance: float = 36.0
@export var lifetime: float = 0.9
@export var drift_x_min: float = -10.0
@export var drift_x_max: float = 10.0
@export var pop_scale: float = 1.08
@export var start_scale: float = 0.78
@export var end_scale: float = 0.94
@export var font_size: int = 24
@export var outline_size: int = 4

@onready var label: Label = $Label

const KIND_NORMAL_DAMAGE := "normal_damage"
const KIND_DOT_DAMAGE := "dot_damage"
const KIND_HP_HEAL := "hp_heal"
const KIND_MP_HEAL := "mp_heal"
const KIND_MP_DAMAGE := "mp_damage"

const KIND_COLORS := {
	KIND_NORMAL_DAMAGE: Color("ffffff"),
	KIND_DOT_DAMAGE: Color("ff9f1a"),
	KIND_HP_HEAL: Color("53d769"),
	KIND_MP_HEAL: Color("4da6ff"),
	KIND_MP_DAMAGE: Color("b56cff"),
}


func setup(amount: int, kind: String, text_override: String = "") -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_color", KIND_COLORS.get(kind, Color.WHITE))
	label.text = _build_text(amount, kind, text_override)
	label.pivot_offset = label.size * 0.5

	modulate = Color(1, 1, 1, 1)
	scale = Vector2.ONE * start_scale
	rotation = 0.0

	_play_animation()


func _build_text(amount: int, kind: String, text_override: String) -> String:
	if not text_override.is_empty():
		return text_override

	var value: int = abs(amount)
	match kind:
		KIND_HP_HEAL:
			return "+%d" % value
		KIND_MP_HEAL:
			return "+%d MP" % value
		KIND_MP_DAMAGE:
			return "-%d MP" % value
		KIND_DOT_DAMAGE:
			return "-%d" % value
		_:
			return "-%d" % value


func _play_animation() -> void:
	var drift_x := randf_range(drift_x_min, drift_x_max)
	var end_position := position + Vector2(drift_x, -rise_distance)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position", end_position, lifetime).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, lifetime).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ONE * pop_scale, lifetime * 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var settle_tween := create_tween()
	settle_tween.tween_interval(lifetime * 0.18)
	settle_tween.tween_property(self, "scale", Vector2.ONE * end_scale, lifetime * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	settle_tween.finished.connect(queue_free)

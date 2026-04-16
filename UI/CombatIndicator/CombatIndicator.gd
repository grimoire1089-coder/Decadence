extends Node2D
class_name CombatIndicator

@export var rise_distance: float = 26.0
@export var lifetime: float = 0.65
@export var drift_x_min: float = -4.0
@export var drift_x_max: float = 4.0
@export var font_size: int = 24
@export var outline_size: int = 4
@export var start_scale: float = 0.92
@export var peak_scale: float = 1.08
@export var end_scale: float = 0.96

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

var _elapsed: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _target_position: Vector2 = Vector2.ZERO
var _text_kind: String = KIND_NORMAL_DAMAGE


func setup(amount: int, kind: String, text_override: String = "") -> void:
	_text_kind = kind
	top_level = true
	z_index = 5000

	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_color", KIND_COLORS.get(kind, Color.WHITE))
	label.text = _build_text(amount, kind, text_override)

	modulate = Color(1, 1, 1, 1)
	scale = Vector2.ONE * start_scale
	rotation = 0.0
	visible = true

	_start_position = global_position
	_target_position = _start_position + Vector2(randf_range(drift_x_min, drift_x_max), -rise_distance)
	_elapsed = 0.0
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	var t: float = 1.0
	if lifetime > 0.0:
		t = clampf(_elapsed / lifetime, 0.0, 1.0)

	global_position = _start_position.lerp(_target_position, _ease_out_cubic(t))
	modulate.a = 1.0 - t
	scale = Vector2.ONE * _compute_scale(t)

	if t >= 1.0:
		queue_free()


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


func _compute_scale(t: float) -> float:
	if t <= 0.18:
		var local_t: float = t / 0.18
		return lerpf(start_scale, peak_scale, _ease_out_back(local_t))
	var settle_t: float = inverse_lerp(0.18, 1.0, t)
	return lerpf(peak_scale, end_scale, _ease_out_cubic(settle_t))


func _ease_out_cubic(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


func _ease_out_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)

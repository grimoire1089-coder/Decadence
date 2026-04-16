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

const KIND_NORMAL_DAMAGE := "normal_damage"
const KIND_DOT_DAMAGE := "dot_damage"
const KIND_HP_HEAL := "hp_heal"
const KIND_MP_HEAL := "mp_heal"
const KIND_MP_DAMAGE := "mp_damage"
const INDICATOR_Z_INDEX := 5000

const KIND_COLORS := {
	KIND_NORMAL_DAMAGE: Color("ffffff"),
	KIND_DOT_DAMAGE: Color("ff9f1a"),
	KIND_HP_HEAL: Color("53d769"),
	KIND_MP_HEAL: Color("4da6ff"),
	KIND_MP_DAMAGE: Color("b56cff"),
}

@onready var label: Label = get_node_or_null("Label")

var _elapsed: float = 0.0
var _start_position: Vector2 = Vector2.ZERO
var _target_position: Vector2 = Vector2.ZERO
var _configured: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	z_index = _get_safe_indicator_z_index()
	_ensure_label()
	label.text = ""
	visible = false
	set_process(false)


func setup(amount: int, kind: String, text_override: String = "") -> void:
	_ensure_label()
	process_mode = Node.PROCESS_MODE_ALWAYS
	top_level = true
	z_index = _get_safe_indicator_z_index()

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
	_configured = true
	set_process(true)


func _process(delta: float) -> void:
	if not _configured:
		return

	_elapsed += delta
	var t: float = 1.0
	if lifetime > 0.0:
		t = clampf(_elapsed / lifetime, 0.0, 1.0)

	global_position = _start_position.lerp(_target_position, _ease_out_cubic(t))
	modulate.a = 1.0 - t
	scale = Vector2.ONE * _compute_scale(t)

	if t >= 1.0:
		queue_free()


func _ensure_label() -> void:
	if label != null:
		return
	label = get_node_or_null("Label")
	if label != null:
		return
	label = Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-36, -14)
	label.size = Vector2(72, 28)
	add_child(label)


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


func _get_safe_indicator_z_index() -> int:
	return clampi(INDICATOR_Z_INDEX, RenderingServer.CANVAS_ITEM_Z_MIN, RenderingServer.CANVAS_ITEM_Z_MAX)

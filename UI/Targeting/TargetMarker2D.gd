extends Node2D
class_name TargetMarker2D

@export var default_radius: float = 18.0
@export var line_width: float = 2.5
@export_range(8, 96, 1) var ring_segments: int = 32
@export var hostile_color: Color = Color(1.0, 0.35, 0.25, 0.95)
@export var friendly_color: Color = Color(0.25, 0.95, 0.95, 0.95)
@export var neutral_color: Color = Color(1.0, 0.85, 0.20, 0.95)
@export var default_world_offset: Vector2 = Vector2.ZERO

var _target: Node2D = null
var _ring: Line2D = null
var _last_radius: float = -1.0
var _last_color: Color = Color(-1, -1, -1, -1)


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 4096
	_ring = Line2D.new()
	_ring.name = "Ring"
	_ring.width = line_width
	_ring.antialiased = true
	_ring.closed = true
	_ring.default_color = neutral_color
	add_child(_ring)
	visible = false
	set_process(true)


func _process(_delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		visible = false
		return

	var marker_position: Vector2 = _get_target_marker_world_position(_target) + default_world_offset
	global_position = marker_position

	var radius: float = _get_target_ring_radius(_target)
	var color: Color = _get_target_color(_target)
	_redraw_ring_if_needed(radius, color)
	visible = true


func set_target(target: Node2D) -> void:
	_target = target
	if _target == null or not is_instance_valid(_target):
		visible = false
		return

	visible = true
	_last_radius = -1.0
	_last_color = Color(-1, -1, -1, -1)


func _redraw_ring_if_needed(radius: float, color: Color) -> void:
	radius = max(radius, 8.0)
	if _ring == null:
		return
	if is_equal_approx(radius, _last_radius) and color == _last_color:
		return

	_last_radius = radius
	_last_color = color
	_ring.default_color = color
	_ring.points = _build_circle_points(radius)


func _build_circle_points(radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = max(ring_segments, 8)
	for i in range(segments):
		var t: float = TAU * float(i) / float(segments)
		points.append(Vector2(cos(t), sin(t)) * radius)
	return points


func _get_target_marker_world_position(target: Node2D) -> Vector2:
	if target.has_method("get_target_marker_world_position"):
		var value: Variant = target.call("get_target_marker_world_position")
		if value is Vector2:
			return value
	return target.global_position


func _get_target_ring_radius(target: Node2D) -> float:
	if target.has_method("get_target_ring_radius"):
		var value: Variant = target.call("get_target_ring_radius")
		if value is float:
			return float(value)
		if value is int:
			return float(value)
	return default_radius


func _get_target_color(target: Node2D) -> Color:
	if target.is_in_group("hostile_target"):
		return hostile_color
	if target.is_in_group("friendly_target"):
		return friendly_color
	return neutral_color

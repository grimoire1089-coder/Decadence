extends Node

@export var day_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var night_tint: Color = Color(0.65, 0.72, 0.90, 1.0)
@export var tint_fade_time: float = 2.0

@onready var world_tint: CanvasModulate = $WorldTint

var _tint_tween: Tween = null


func _ready() -> void:
	if world_tint == null:
		push_error("WorldEnvironment: WorldTint が見つからない")
		return

	var period_changed_callable: Callable = Callable(self, "_on_period_changed")
	if not TimeManager.period_changed.is_connected(period_changed_callable):
		TimeManager.period_changed.connect(period_changed_callable)

	_apply_period_immediately(TimeManager.get_time_period())


func _on_period_changed(period: int) -> void:
	_change_tint(period)


func _apply_period_immediately(period: int) -> void:
	if _tint_tween != null and _tint_tween.is_valid():
		_tint_tween.kill()

	world_tint.color = _get_target_tint(period)


func _change_tint(period: int) -> void:
	if _tint_tween != null and _tint_tween.is_valid():
		_tint_tween.kill()

	_tint_tween = create_tween()
	_tint_tween.tween_property(
		world_tint,
		"color",
		_get_target_tint(period),
		tint_fade_time
	)


func _get_target_tint(period: int) -> Color:
	if period == TimeManager.TimePeriod.NIGHT:
		return night_tint
	return day_tint

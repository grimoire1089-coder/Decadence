extends CanvasLayer
class_name LoadingOverlay

@onready var blocker: ColorRect = $Blocker
@onready var center_container: CenterContainer = $Blocker/CenterContainer
@onready var status_label: Label = $Blocker/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $Blocker/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ProgressBar

var _fade_tween: Tween = null


func _ready() -> void:
	layer = 100
	visible = false

	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.offset_left = 0
	blocker.offset_top = 0
	blocker.offset_right = 0
	blocker.offset_bottom = 0
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.color = Color(0, 0, 0, 0.0)

	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.visible = false
	_set_panel_visible(false)


func _input(_event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()


func open(text: String = "読み込み中…", progress: float = -1.0) -> void:
	_stop_fade_tween()
	visible = true
	_set_blocker_alpha(0.72)
	_set_panel_visible(true)
	set_status(text)
	set_progress(progress)


func set_status(text: String) -> void:
	status_label.text = text


func set_progress(progress: float) -> void:
	if progress < 0.0:
		progress_bar.visible = false
		return

	progress_bar.visible = true
	progress_bar.value = clamp(progress, 0.0, 100.0)


func close() -> void:
	_stop_fade_tween()
	_set_blocker_alpha(0.0)
	_set_panel_visible(false)
	visible = false


func fade_out_to_black(duration: float = 0.18, target_alpha: float = 1.0) -> void:
	_stop_fade_tween()
	visible = true
	_set_panel_visible(false)
	progress_bar.visible = false
	await _tween_blocker_alpha(clamp(target_alpha, 0.0, 1.0), max(duration, 0.0))


func fade_in_from_black(duration: float = 0.18) -> void:
	_stop_fade_tween()
	visible = true
	_set_panel_visible(false)
	progress_bar.visible = false
	await _tween_blocker_alpha(0.0, max(duration, 0.0))
	visible = false


func _set_panel_visible(value: bool) -> void:
	center_container.visible = value


func _set_blocker_alpha(alpha: float) -> void:
	var color: Color = blocker.color
	color.a = alpha
	blocker.color = color


func _stop_fade_tween() -> void:
	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.kill()
	_fade_tween = null


func _tween_blocker_alpha(target_alpha: float, duration: float) -> void:
	if duration <= 0.0:
		_set_blocker_alpha(target_alpha)
		return

	_fade_tween = create_tween()
	_fade_tween.tween_property(blocker, "color:a", target_alpha, duration)
	await _fade_tween.finished
	_fade_tween = null

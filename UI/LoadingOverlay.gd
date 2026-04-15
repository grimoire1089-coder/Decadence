extends CanvasLayer
class_name LoadingOverlay

@onready var blocker: ColorRect = $Blocker
@onready var status_label: Label = $Blocker/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/StatusLabel
@onready var progress_bar: ProgressBar = $Blocker/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ProgressBar

func _ready() -> void:
	layer = 100
	visible = false

	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	blocker.offset_left = 0
	blocker.offset_top = 0
	blocker.offset_right = 0
	blocker.offset_bottom = 0
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.color = Color(0, 0, 0, 0.72)

	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.visible = false

func _input(event: InputEvent) -> void:
	if visible:
		get_viewport().set_input_as_handled()

func open(text: String = "読み込み中…", progress: float = -1.0) -> void:
	visible = true
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
	visible = false

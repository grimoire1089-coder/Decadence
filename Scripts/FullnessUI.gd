extends Control

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var fullness_bar: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/FullnessBar
@onready var value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/InfoRow/ValueLabel
@onready var state_label: Label = $PanelContainer/MarginContainer/VBoxContainer/InfoRow/StateLabel


func _ready() -> void:
	title_label.text = "満腹度"
	fullness_bar.show_percentage = false
	fullness_bar.min_value = 0.0
	fullness_bar.max_value = 100.0

	if PlayerStatsManager == null:
		visible = false
		return

	if not PlayerStatsManager.fullness_changed.is_connected(_on_fullness_changed):
		PlayerStatsManager.fullness_changed.connect(_on_fullness_changed)

	if not PlayerStatsManager.stats_changed.is_connected(_on_stats_changed):
		PlayerStatsManager.stats_changed.connect(_on_stats_changed)

	_refresh_all()


func _exit_tree() -> void:
	if PlayerStatsManager == null:
		return

	if PlayerStatsManager.fullness_changed.is_connected(_on_fullness_changed):
		PlayerStatsManager.fullness_changed.disconnect(_on_fullness_changed)

	if PlayerStatsManager.stats_changed.is_connected(_on_stats_changed):
		PlayerStatsManager.stats_changed.disconnect(_on_stats_changed)


func _on_fullness_changed(current_fullness: int, max_fullness: int) -> void:
	_apply_values(current_fullness, max_fullness)


func _on_stats_changed() -> void:
	_refresh_all()


func _refresh_all() -> void:
	var current_fullness: int = PlayerStatsManager.get_fullness()
	var max_fullness: int = PlayerStatsManager.get_max_fullness()
	_apply_values(current_fullness, max_fullness)


func _apply_values(current_fullness: int, max_fullness: int) -> void:
	var safe_max_fullness: int = max(max_fullness, 1)
	var clamped_fullness: int = clamp(current_fullness, 0, safe_max_fullness)

	fullness_bar.max_value = float(safe_max_fullness)
	fullness_bar.value = float(clamped_fullness)

	value_label.text = "%d / %d" % [clamped_fullness, safe_max_fullness]
	state_label.text = PlayerStatsManager.get_hunger_state_text()

	_apply_visuals(clamped_fullness, safe_max_fullness)


func _apply_visuals(current_fullness: int, max_fullness: int) -> void:
	var ratio: float = float(current_fullness) / float(max_fullness)

	if ratio <= 0.0:
		fullness_bar.modulate = Color(1.0, 0.55, 0.55, 1.0)
		state_label.modulate = Color(1.0, 0.55, 0.55, 1.0)
	elif ratio <= 0.3:
		fullness_bar.modulate = Color(1.0, 0.75, 0.45, 1.0)
		state_label.modulate = Color(1.0, 0.75, 0.45, 1.0)
	elif ratio >= 0.8:
		fullness_bar.modulate = Color(0.70, 1.0, 0.70, 1.0)
		state_label.modulate = Color(0.70, 1.0, 0.70, 1.0)
	else:
		fullness_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)
		state_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

	value_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

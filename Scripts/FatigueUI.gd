extends Control

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var fatigue_bar: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/FatigueBar
@onready var value_label: Label = $PanelContainer/MarginContainer/VBoxContainer/InfoRow/ValueLabel
@onready var state_label: Label = $PanelContainer/MarginContainer/VBoxContainer/InfoRow/StateLabel


func _ready() -> void:
	title_label.text = "疲労度"
	fatigue_bar.show_percentage = false
	fatigue_bar.min_value = 0.0
	fatigue_bar.max_value = 100.0

	if PlayerStatsManager == null:
		visible = false
		return

	if not PlayerStatsManager.fatigue_changed.is_connected(_on_fatigue_changed):
		PlayerStatsManager.fatigue_changed.connect(_on_fatigue_changed)

	if not PlayerStatsManager.stats_changed.is_connected(_on_stats_changed):
		PlayerStatsManager.stats_changed.connect(_on_stats_changed)

	_refresh_all()


func _exit_tree() -> void:
	if PlayerStatsManager == null:
		return

	if PlayerStatsManager.fatigue_changed.is_connected(_on_fatigue_changed):
		PlayerStatsManager.fatigue_changed.disconnect(_on_fatigue_changed)

	if PlayerStatsManager.stats_changed.is_connected(_on_stats_changed):
		PlayerStatsManager.stats_changed.disconnect(_on_stats_changed)


func _on_fatigue_changed(current_fatigue: int, max_fatigue: int) -> void:
	_apply_values(current_fatigue, max_fatigue)


func _on_stats_changed() -> void:
	_refresh_all()


func _refresh_all() -> void:
	var current_fatigue: int = PlayerStatsManager.get_fatigue()
	var max_fatigue: int = PlayerStatsManager.get_max_fatigue()
	_apply_values(current_fatigue, max_fatigue)


func _apply_values(current_fatigue: int, max_fatigue: int) -> void:
	var safe_max_fatigue: int = max(max_fatigue, 1)
	var clamped_fatigue: int = clamp(current_fatigue, 0, safe_max_fatigue)

	fatigue_bar.max_value = float(safe_max_fatigue)
	fatigue_bar.value = float(clamped_fatigue)

	value_label.text = "%d / %d" % [clamped_fatigue, safe_max_fatigue]
	state_label.text = PlayerStatsManager.get_fatigue_state_text()

	_apply_visuals(clamped_fatigue, safe_max_fatigue)


func _apply_visuals(current_fatigue: int, max_fatigue: int) -> void:
	var ratio: float = float(current_fatigue) / float(max_fatigue)

	if ratio >= 1.0:
		fatigue_bar.modulate = Color(1.0, 0.45, 0.45, 1.0)
		state_label.modulate = Color(1.0, 0.45, 0.45, 1.0)
	elif ratio >= 0.7:
		fatigue_bar.modulate = Color(1.0, 0.75, 0.45, 1.0)
		state_label.modulate = Color(1.0, 0.75, 0.45, 1.0)
	elif ratio <= 0.2:
		fatigue_bar.modulate = Color(0.70, 1.0, 0.70, 1.0)
		state_label.modulate = Color(0.70, 1.0, 0.70, 1.0)
	else:
		fatigue_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)
		state_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

	value_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

extends Control

@export var hp_label_text: String = "HP"
@export var mp_label_text: String = "MP"

@onready var hp_value_label: Label = %HPValue
@onready var mp_value_label: Label = %MPValue
@onready var hp_bar: ProgressBar = %HPBar
@onready var mp_bar: ProgressBar = %MPBar


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connect_stats_manager()
	_refresh_from_stats_manager()


func _connect_stats_manager() -> void:
	if PlayerStatsManager == null:
		return

	if not PlayerStatsManager.hp_changed.is_connected(_on_hp_changed):
		PlayerStatsManager.hp_changed.connect(_on_hp_changed)

	if not PlayerStatsManager.mp_changed.is_connected(_on_mp_changed):
		PlayerStatsManager.mp_changed.connect(_on_mp_changed)


func _refresh_from_stats_manager() -> void:
	if PlayerStatsManager == null:
		return

	set_values(
		PlayerStatsManager.get_hp(),
		PlayerStatsManager.get_max_hp(),
		PlayerStatsManager.get_mp(),
		PlayerStatsManager.get_max_mp()
	)


func _on_hp_changed(current: int, maximum: int) -> void:
	set_hp(current, maximum)


func _on_mp_changed(current: int, maximum: int) -> void:
	set_mp(current, maximum)


func set_hp(current: int, maximum: int) -> void:
	var safe_max: int = maxi(maximum, 1)
	hp_bar.max_value = safe_max
	hp_bar.value = clampi(current, 0, safe_max)
	hp_value_label.text = "%d / %d" % [current, maximum]


func set_mp(current: int, maximum: int) -> void:
	var safe_max: int = maxi(maximum, 1)
	mp_bar.max_value = safe_max
	mp_bar.value = clampi(current, 0, safe_max)
	mp_value_label.text = "%d / %d" % [current, maximum]


func set_values(hp_current: int, hp_maximum: int, mp_current: int, mp_maximum: int) -> void:
	set_hp(hp_current, hp_maximum)
	set_mp(mp_current, mp_maximum)

extends Label

func _ready() -> void:
	var time_manager := get_node("/root/TimeManager")
	time_manager.time_changed.connect(_on_time_changed)
	text = time_manager.get_time_text()

func _on_time_changed(_day: int, _hour: int, _minute: int) -> void:
	var time_manager := get_node("/root/TimeManager")
	text = time_manager.get_time_text()

extends Label

func _ready() -> void:
	update_text()
	if not CurrencyManager.credits_changed.is_connected(_on_credits_changed):
		CurrencyManager.credits_changed.connect(_on_credits_changed)


func _on_credits_changed(_value: int) -> void:
	update_text()


func update_text() -> void:
	text = "所持金: " + CurrencyManager.get_credits_text()

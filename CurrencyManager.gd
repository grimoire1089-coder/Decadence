extends Node

signal credits_changed(value: int)

const DEFAULT_CREDITS := 100

var credits: int = DEFAULT_CREDITS


func _ready() -> void:
	credits = max(credits, 0)
	credits_changed.emit(credits)


func add_credits(amount: int) -> void:
	if amount <= 0:
		return

	credits += amount
	credits_changed.emit(credits)


func can_spend(amount: int) -> bool:
	if amount < 0:
		return false
	return credits >= amount


func spend_credits(amount: int) -> bool:
	if amount <= 0:
		return false
	if credits < amount:
		return false

	credits -= amount
	credits_changed.emit(credits)
	return true


func set_credits(value: int) -> void:
	credits = max(value, 0)
	credits_changed.emit(credits)


func get_credits() -> int:
	return credits


func get_credits_text() -> String:
	return "%d Cr" % credits


func export_save_data() -> Dictionary:
	return {
		"credits": credits,
	}


func import_save_data(data: Dictionary) -> void:
	credits = max(int(data.get("credits", DEFAULT_CREDITS)), 0)
	credits_changed.emit(credits)

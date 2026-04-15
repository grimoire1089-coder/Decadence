extends Node

signal credits_changed(value: int)

const SAVE_PATH := "user://save_data.json"
const DEFAULT_CREDITS := 100

var credits: int = 0


func _ready() -> void:
	load_data()
	credits_changed.emit(credits)


func add_credits(amount: int) -> void:
	if amount <= 0:
		return

	credits += amount
	save_data()
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
	save_data()
	credits_changed.emit(credits)
	return true


func set_credits(value: int) -> void:
	credits = max(value, 0)
	save_data()
	credits_changed.emit(credits)


func get_credits() -> int:
	return credits


func get_credits_text() -> String:
	return "%d Cr" % credits


func save_data() -> void:
	var data := {
		"credits": credits
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("セーブ失敗: %s" % SAVE_PATH)
		return

	file.store_string(JSON.stringify(data))


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		credits = DEFAULT_CREDITS
		save_data()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("ロード失敗: %s" % SAVE_PATH)
		credits = DEFAULT_CREDITS
		return

	var text := file.get_as_text()
	var json := JSON.new()
	var err := json.parse(text)

	if err != OK:
		push_error("JSON読み込み失敗")
		credits = DEFAULT_CREDITS
		return

	var data = json.data
	if typeof(data) == TYPE_DICTIONARY and data.has("credits"):
		credits = max(int(data["credits"]), 0)
	else:
		credits = DEFAULT_CREDITS

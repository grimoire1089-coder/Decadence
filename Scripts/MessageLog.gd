extends Node

signal log_changed

const MAX_HISTORY: int = 100

const CATEGORY_COLORS := {
	"INFO": "#D8DEE9",
	"DEBUG": "#88C0D0",
	"SYSTEM": "#A3BE8C",
	"WARNING": "#EBCB8B",
	"ERROR": "#BF616A",
	"SHOP": "#B48EAD",
	"TIME": "#5E81AC"
}

var _messages: Array[Dictionary] = []

func add_message(message: String, category: String = "INFO") -> void:
	var time_text: String = Time.get_time_string_from_system()
	var entry := {
		"time": time_text,
		"category": category,
		"text": message
	}

	_messages.append(entry)

	while _messages.size() > MAX_HISTORY:
		_messages.pop_front()

	log_changed.emit()

func add_debug(message: String) -> void:
	add_message(message, "DEBUG")

func add_system(message: String) -> void:
	add_message(message, "SYSTEM")

func add_warning(message: String) -> void:
	add_message(message, "WARNING")

func add_error(message: String) -> void:
	add_message(message, "ERROR")

func add_shop(message: String) -> void:
	add_message(message, "SHOP")

func add_time(message: String) -> void:
	add_message(message, "TIME")

func get_messages() -> Array[Dictionary]:
	return _messages.duplicate(true)

func clear_messages() -> void:
	_messages.clear()
	log_changed.emit()

func get_category_color(category: String) -> String:
	if CATEGORY_COLORS.has(category):
		return CATEGORY_COLORS[category]
	return "#D8DEE9"

func escape_bbcode(text: String) -> String:
	# 公式ドキュメントの安全なやり方に寄せて、
	# 開きカッコを [lb] に置き換える
	return text.replace("[", "[lb]")

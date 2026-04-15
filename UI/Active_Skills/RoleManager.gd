extends Node

signal roles_changed(main_role: String, sub_role: String, is_pure: bool)

const SAVE_PATH: String = "user://role_settings.json"
const MAIN_ROLE_OPTIONS: PackedStringArray = ["tank", "attacker", "healer"]
const SUB_ROLE_OPTIONS: PackedStringArray = ["tank", "attacker", "healer", "trickster", "buffer", "debuffer"]
const ROLE_LABELS: Dictionary = {
	"tank": "タンク",
	"attacker": "アタッカー",
	"healer": "ヒーラー",
	"trickster": "トリックスター",
	"buffer": "バッファー",
	"debuffer": "デバッファー",
	"any": "制限なし"
}

var _main_role: String = "healer"
var _sub_role: String = "buffer"


func _ready() -> void:
	add_to_group("role_manager")
	load_data()
	_sanitize_roles(false)
	_emit_roles_changed()


func get_main_role() -> String:
	return _main_role


func get_sub_role() -> String:
	return _sub_role


func get_main_role_label() -> String:
	return get_role_label(_main_role)


func get_sub_role_label() -> String:
	return get_role_label(_sub_role)


func get_role_label(role_id: String) -> String:
	return String(ROLE_LABELS.get(role_id, role_id))


func get_main_role_options() -> PackedStringArray:
	return MAIN_ROLE_OPTIONS


func get_sub_role_options() -> PackedStringArray:
	return SUB_ROLE_OPTIONS


func set_main_role(role_id: String, save_immediately: bool = true) -> void:
	if not MAIN_ROLE_OPTIONS.has(role_id):
		return

	if _main_role == role_id:
		return

	_main_role = role_id
	_sanitize_roles(false)
	if save_immediately:
		save_data()
	_emit_roles_changed()


func set_sub_role(role_id: String, save_immediately: bool = true) -> void:
	if not SUB_ROLE_OPTIONS.has(role_id):
		return

	if _sub_role == role_id:
		return

	_sub_role = role_id
	_sanitize_roles(false)
	if save_immediately:
		save_data()
	_emit_roles_changed()


func set_roles(main_role_id: String, sub_role_id: String, save_immediately: bool = true) -> void:
	var changed: bool = false

	if MAIN_ROLE_OPTIONS.has(main_role_id) and _main_role != main_role_id:
		_main_role = main_role_id
		changed = true

	if SUB_ROLE_OPTIONS.has(sub_role_id) and _sub_role != sub_role_id:
		_sub_role = sub_role_id
		changed = true

	_sanitize_roles(false)

	if save_immediately:
		save_data()

	if changed:
		_emit_roles_changed()


func is_pure() -> bool:
	if not MAIN_ROLE_OPTIONS.has(_main_role):
		return false
	return _sub_role == _main_role


func get_specialization_text() -> String:
	if is_pure():
		return "%s・ピュア（特化）" % get_main_role_label()
	return "%s / %s" % [get_main_role_label(), get_sub_role_label()]


func can_use_skill(skill: Resource) -> Dictionary:
	if skill == null:
		return {"ok": false, "reason": "スキルデータがありません"}

	if not skill.has_method("get"):
		return {"ok": true, "reason": ""}

	var required_main_role: String = String(skill.get("required_main_role"))
	if required_main_role.is_empty():
		required_main_role = "any"

	var required_sub_role: String = String(skill.get("required_sub_role"))
	if required_sub_role.is_empty():
		required_sub_role = "any"

	var requires_pure_specialization: bool = bool(skill.get("requires_pure_specialization"))

	if required_main_role != "any" and _main_role != required_main_role:
		return {
			"ok": false,
			"reason": "このスキルは %s が必要です" % get_role_label(required_main_role)
		}

	if required_sub_role != "any" and _sub_role != required_sub_role:
		return {
			"ok": false,
			"reason": "このスキルはサブロール %s が必要です" % get_role_label(required_sub_role)
		}

	if requires_pure_specialization and not is_pure():
		if required_main_role != "any":
			return {
				"ok": false,
				"reason": "%sピュア（特化）でないと使えません" % get_role_label(required_main_role)
			}
		return {"ok": false, "reason": "ピュア（特化）でないと使えません"}

	return {"ok": true, "reason": ""}


func save_data() -> void:
	var payload: Dictionary = {
		"main_role": _main_role,
		"sub_role": _sub_role
	}

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify(payload, "\t"))
	file.close()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return

	var data: Dictionary = parsed as Dictionary
	_main_role = String(data.get("main_role", _main_role))
	_sub_role = String(data.get("sub_role", _sub_role))


func _sanitize_roles(save_if_fixed: bool) -> void:
	var changed: bool = false

	if not MAIN_ROLE_OPTIONS.has(_main_role):
		_main_role = "healer"
		changed = true

	if not SUB_ROLE_OPTIONS.has(_sub_role):
		_sub_role = "buffer"
		changed = true

	if changed and save_if_fixed:
		save_data()


func _emit_roles_changed() -> void:
	roles_changed.emit(_main_role, _sub_role, is_pure())

extends CanvasLayer
class_name RoleSelectUI

const MAIN_ROLE_OPTIONS: PackedStringArray = ["tank", "attacker", "healer"]
const SUB_ROLE_OPTIONS: PackedStringArray = ["tank", "attacker", "healer", "trickster", "buffer", "debuffer"]
const ROLE_LABELS: Dictionary = {
	"tank": "タンク",
	"attacker": "アタッカー",
	"healer": "ヒーラー",
	"trickster": "トリックスター",
	"buffer": "バッファー",
	"debuffer": "デバッファー"
}

@onready var _main_role_option: OptionButton = $RootMargin/Panel/MainVBox/MainRoleRow/MainRoleOption
@onready var _sub_role_option: OptionButton = $RootMargin/Panel/MainVBox/SubRoleRow/SubRoleOption
@onready var _current_label: Label = $RootMargin/Panel/MainVBox/CurrentRoleLabel
@onready var _specialization_label: Label = $RootMargin/Panel/MainVBox/SpecializationLabel
@onready var _close_button: Button = $RootMargin/Panel/MainVBox/ButtonRow/CloseButton

var _is_refreshing: bool = false


func _ready() -> void:
	add_to_group("skill_ui")
	layer = 20
	hide()
	_connect_ui()
	_populate_role_options()
	_refresh_from_manager()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close_menu()
		get_viewport().set_input_as_handled()


func toggle_menu() -> void:
	if visible:
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	_refresh_from_manager()
	show()


func close_menu() -> void:
	hide()


func _connect_ui() -> void:
	if not _main_role_option.item_selected.is_connected(_on_main_role_selected):
		_main_role_option.item_selected.connect(_on_main_role_selected)

	if not _sub_role_option.item_selected.is_connected(_on_sub_role_selected):
		_sub_role_option.item_selected.connect(_on_sub_role_selected)

	if not _close_button.pressed.is_connected(_on_close_pressed):
		_close_button.pressed.connect(_on_close_pressed)

	var role_manager: Node = _get_role_manager()
	if role_manager != null and role_manager.has_signal("roles_changed"):
		var callback := Callable(self, "_on_roles_changed")
		if not role_manager.is_connected("roles_changed", callback):
			role_manager.connect("roles_changed", callback)


func _populate_role_options() -> void:
	_is_refreshing = true
	_main_role_option.clear()
	_sub_role_option.clear()

	for role_id in MAIN_ROLE_OPTIONS:
		_main_role_option.add_item(_get_role_label(role_id))
		_main_role_option.set_item_metadata(_main_role_option.item_count - 1, role_id)

	for role_id in SUB_ROLE_OPTIONS:
		_sub_role_option.add_item(_get_role_label(role_id))
		_sub_role_option.set_item_metadata(_sub_role_option.item_count - 1, role_id)

	_is_refreshing = false


func _refresh_from_manager() -> void:
	var role_manager: Node = _get_role_manager()
	if role_manager == null:
		_update_summary_text("未設定", "RoleManager が見つかりません")
		return

	_is_refreshing = true
	_select_option_by_role_id(_main_role_option, String(role_manager.call("get_main_role")))
	_select_option_by_role_id(_sub_role_option, String(role_manager.call("get_sub_role")))
	_is_refreshing = false

	_update_labels_from_manager(role_manager)


func _update_labels_from_manager(role_manager: Node) -> void:
	var main_label: String = String(role_manager.call("get_main_role_label"))
	var sub_label: String = String(role_manager.call("get_sub_role_label"))
	var is_pure_role: bool = bool(role_manager.call("is_pure"))

	var current_text: String = "現在のロール: %s / %s" % [main_label, sub_label]
	var specialization_text: String = "状態: %s" % String(role_manager.call("get_specialization_text"))
	if is_pure_role:
		specialization_text += "\n※ 特化スキルを選択できます"
	else:
		specialization_text += "\n※ サブに同じメインロールを選ぶとピュア（特化）になります"

	_update_summary_text(current_text, specialization_text)


func _update_summary_text(current_text: String, specialization_text: String) -> void:
	_current_label.text = current_text
	_specialization_label.text = specialization_text


func _select_option_by_role_id(option_button: OptionButton, role_id: String) -> void:
	for index in option_button.item_count:
		if String(option_button.get_item_metadata(index)) == role_id:
			option_button.select(index)
			return


func _get_role_label(role_id: String) -> String:
	return String(ROLE_LABELS.get(role_id, role_id))


func _on_main_role_selected(index: int) -> void:
	if _is_refreshing:
		return

	var role_id: String = String(_main_role_option.get_item_metadata(index))
	var role_manager: Node = _get_role_manager()
	if role_manager != null and role_manager.has_method("set_main_role"):
		role_manager.call("set_main_role", role_id)
		_update_labels_from_manager(role_manager)


func _on_sub_role_selected(index: int) -> void:
	if _is_refreshing:
		return

	var role_id: String = String(_sub_role_option.get_item_metadata(index))
	var role_manager: Node = _get_role_manager()
	if role_manager != null and role_manager.has_method("set_sub_role"):
		role_manager.call("set_sub_role", role_id)
		_update_labels_from_manager(role_manager)


func _on_close_pressed() -> void:
	close_menu()


func _on_roles_changed(_main_role: String, _sub_role: String, _is_pure_role: bool) -> void:
	_refresh_from_manager()


func _get_role_manager() -> Node:
	return get_node_or_null("/root/RoleManager")

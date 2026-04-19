extends Control
class_name AutoAttackConfigDialog

const DEFAULT_MODIFIER_PATHS: PackedStringArray = [
	"res://UI/AutoAttack/Modifiers/AA_Physical_Melee.tres",
	"res://UI/AutoAttack/Modifiers/AA_Physical_Mid.tres",
	"res://UI/AutoAttack/Modifiers/AA_Physical_Long.tres",
	"res://UI/AutoAttack/Modifiers/AA_Magical_Melee.tres",
	"res://UI/AutoAttack/Modifiers/AA_Magical_Mid.tres",
	"res://UI/AutoAttack/Modifiers/AA_Magical_Long.tres"
]
const MODIFIER_SCAN_DIRS: PackedStringArray = [
	"res://UI/AutoAttack/Modifiers",
	"res://Data/AutoAttack/Modifiers"
]

@onready var title_label: Label = $CenterContainer/Panel/MarginContainer/RootVBox/HeaderLabel
@onready var status_label: Label = $CenterContainer/Panel/MarginContainer/RootVBox/StatusLabel
@onready var modifier_list: VBoxContainer = $CenterContainer/Panel/MarginContainer/RootVBox/BodySplit/LeftPanel/LeftMargin/ModifierScroll/ModifierList
@onready var icon_rect: TextureRect = $CenterContainer/Panel/MarginContainer/RootVBox/BodySplit/RightPanel/RightMargin/RightVBox/IconRect
@onready var name_label: Label = $CenterContainer/Panel/MarginContainer/RootVBox/BodySplit/RightPanel/RightMargin/RightVBox/NameLabel
@onready var summary_label: Label = $CenterContainer/Panel/MarginContainer/RootVBox/BodySplit/RightPanel/RightMargin/RightVBox/SummaryLabel
@onready var description_label: Label = $CenterContainer/Panel/MarginContainer/RootVBox/BodySplit/RightPanel/RightMargin/RightVBox/DescriptionLabel
@onready var close_button: Button = $CenterContainer/Panel/MarginContainer/RootVBox/ButtonRow/CloseButton
@onready var apply_button: Button = $CenterContainer/Panel/MarginContainer/RootVBox/ButtonRow/ApplyButton

var _controller: Node = null
var _pending_modifier: AutoAttackModifierData = null


func _ready() -> void:
	visible = false
	add_to_group("auto_attack_config_dialog")
	mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.text = "通常攻撃設定"
	close_button.pressed.connect(close_dialog)
	apply_button.pressed.connect(_on_apply_pressed)


func open_dialog(controller: Node = null) -> void:
	_controller = controller
	if _controller == null:
		_controller = get_tree().get_first_node_in_group("auto_attack_controller")
	visible = true
	_refresh()


func close_dialog() -> void:
	visible = false


func _refresh() -> void:
	for child in modifier_list.get_children():
		modifier_list.remove_child(child)
		child.queue_free()

	var modifiers: Array[AutoAttackModifierData] = _get_modifiers()
	if _controller != null and _controller.has_method("get_current_modifier"):
		var current_value: Variant = _controller.call("get_current_modifier")
		if current_value is AutoAttackModifierData and _pending_modifier == null:
			_pending_modifier = current_value as AutoAttackModifierData

	if _pending_modifier == null and not modifiers.is_empty():
		_pending_modifier = modifiers[0]

	var enabled_text: String = "OFF"
	if _controller != null and _controller.has_method("is_auto_attack_enabled"):
		enabled_text = "ON" if bool(_controller.call("is_auto_attack_enabled")) else "OFF"
	status_label.text = "現在の状態: %s" % enabled_text

	for modifier in modifiers:
		if modifier == null:
			continue
		var button: Button = Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 44)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = modifier.display_name
		if modifier == _pending_modifier:
			button.text += "  [選択中]"
		button.pressed.connect(_on_modifier_pressed.bind(modifier))
		modifier_list.add_child(button)

	_apply_preview(_pending_modifier)


func _apply_preview(modifier: AutoAttackModifierData) -> void:
	if modifier == null:
		icon_rect.texture = null
		name_label.text = "未選択"
		summary_label.text = ""
		description_label.text = ""
		apply_button.disabled = true
		return

	_pending_modifier = modifier
	icon_rect.texture = modifier.icon
	name_label.text = modifier.display_name
	summary_label.text = modifier.get_summary_text()
	description_label.text = modifier.description
	apply_button.disabled = _controller == null


func _on_modifier_pressed(modifier: AutoAttackModifierData) -> void:
	_pending_modifier = modifier
	_refresh()


func _on_apply_pressed() -> void:
	if _controller == null or _pending_modifier == null:
		return
	if _controller.has_method("set_current_modifier"):
		_controller.call("set_current_modifier", _pending_modifier)
	if _controller.has_method("get_current_modifier"):
		SkillHelpers.add_system_log("通常攻撃設定を %s に変更" % _pending_modifier.display_name)
	close_dialog()


func _get_modifiers() -> Array[AutoAttackModifierData]:
	var result: Array[AutoAttackModifierData] = []
	var seen: Dictionary = {}

	for path in DEFAULT_MODIFIER_PATHS:
		var modifier: AutoAttackModifierData = _load_modifier_from_path(path)
		if modifier == null:
			continue
		var key: String = modifier.resource_path if not modifier.resource_path.is_empty() else modifier.modifier_id
		if seen.has(key):
			continue
		seen[key] = true
		result.append(modifier)

	for dir_path in MODIFIER_SCAN_DIRS:
		for modifier in _scan_modifiers_in_directory(dir_path):
			if modifier == null:
				continue
			var key: String = modifier.resource_path if not modifier.resource_path.is_empty() else modifier.modifier_id
			if seen.has(key):
				continue
			seen[key] = true
			result.append(modifier)

	return result


func _load_modifier_from_path(path: String) -> AutoAttackModifierData:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	var loaded: Resource = ResourceLoader.load(path)
	if loaded is AutoAttackModifierData:
		return loaded as AutoAttackModifierData
	return null


func _scan_modifiers_in_directory(dir_path: String) -> Array[AutoAttackModifierData]:
	var found: Array[AutoAttackModifierData] = []
	if dir_path.is_empty() or not DirAccess.dir_exists_absolute(dir_path):
		return found

	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return found

	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break
		if dir.current_is_dir():
			continue
		if not file_name.ends_with(".tres"):
			continue

		var full_path: String = dir_path.path_join(file_name)
		var modifier: AutoAttackModifierData = _load_modifier_from_path(full_path)
		if modifier != null:
			found.append(modifier)
	dir.list_dir_end()

	return found

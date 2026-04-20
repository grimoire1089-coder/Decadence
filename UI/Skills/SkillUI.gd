extends Control
class_name SkillUI

const UI_LOCK_SOURCE: String = "スキル画面"
const TOGGLE_ACTION_NAME: String = "toggle_skill_ui"
const UI_MODAL_MANAGER_SCRIPT_NAME: String = "UIModalManager.gd"
const TIME_MANAGER_SCRIPT_NAME: String = "TimeManager.gd"
const ROLE_MANAGER_SCRIPT_NAME: String = "RoleManager.gd"
const SKILL_HOTBAR_SCRIPT_NAME: String = "SkillHotbarUI.gd"
const AUTO_ATTACK_CONTROLLER_SCRIPT_NAME: String = "AutoAttackController.gd"
const AUTO_ATTACK_CONFIG_DIALOG_SCENE_PATH: String = "res://UI/AutoAttack/AutoAttackConfigDialog.tscn"
const DEFAULT_ROLE_SKILL_PATHS: PackedStringArray = [
	"res://UI/Active_Skills/ReverseLightI_role_checked.tres",
	"res://UI/Active_Skills/ReverseLightI.tres",
	"res://Data/Skills/ReverseLightI_role_checked.tres",
	"res://Data/Skills/ReverseLightI.tres"
]
const ROLE_SKILL_SCAN_DIRS: PackedStringArray = [
	"res://UI/Active_Skills",
	"res://Data/Skills"
]

const SUPPORTED_SKILLS: Array[Dictionary] = [
	{"key": "farming", "label": "農業"},
	{"key": "cooking", "label": "料理"}
]

@export var skill_row_scene: PackedScene
@export var role_skill_resources: Array[Resource] = []

@onready var panel: Panel = $CenterContainer/Panel
@onready var title_label: Label = $CenterContainer/Panel/MarginContainer/RootVBox/HeaderHBox/TitleLabel
@onready var close_button: Button = $CenterContainer/Panel/MarginContainer/RootVBox/HeaderHBox/CloseButton
@onready var summary_label: Label = $CenterContainer/Panel/MarginContainer/RootVBox/SummaryLabel
@onready var skill_list: VBoxContainer = $CenterContainer/Panel/MarginContainer/RootVBox/BodySplit/LeftPanel/LeftMargin/LeftVBox/LifeSkillScroll/SkillList
@onready var hint_label: Label = $CenterContainer/Panel/MarginContainer/RootVBox/BodySplit/LeftPanel/LeftMargin/LeftVBox/HintLabel
@onready var content_vbox: VBoxContainer = $CenterContainer/Panel/MarginContainer/RootVBox/BodySplit/RightPanel/RightMargin/RightScroll/RightVBox

var _role_section: PanelContainer
var _role_status_label: Label
var _role_note_label: Label
var _main_role_option: OptionButton
var _sub_role_option: OptionButton
var _is_updating_role_controls: bool = false

var _active_skill_section: PanelContainer
var _active_skill_status_label: Label
var _active_skill_list: VBoxContainer
var _selected_skill_label: Label
var _open_select_page_button: Button
var _register_button: Button
var _clear_slot_button: Button

var _skill_select_overlay: ColorRect
var _skill_select_panel: PanelContainer
var _skill_select_list: VBoxContainer
var _skill_select_icon: TextureRect
var _skill_select_name_label: Label
var _skill_select_description_label: Label
var _skill_select_state_label: Label
var _skill_select_confirm_button: Button
var _skill_select_cancel_button: Button
var _skill_select_pending_skill: RoleSkillData = null

var _auto_attack_section: PanelContainer
var _auto_attack_status_label: Label
var _auto_attack_modifier_label: Label
var _auto_attack_open_button: Button
var _observed_auto_attack_controller: Node = null
var _auto_attack_config_dialog: Control = null

var _selected_role_skill: RoleSkillData = null
var _observed_hotbar: Node = null


func _ready() -> void:
	visible = false
	add_to_group("skill_ui")

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.text = "スキル"
	hint_label.text = "Esc / キャンセルで閉じる"

	close_button.pressed.connect(_on_close_pressed)
	_ensure_role_section()
	_ensure_active_skill_section()
	_ensure_auto_attack_section()
	_ensure_skill_select_overlay()
	_connect_stats_manager()
	_connect_role_manager()
	_bind_skill_hotbar()
	_bind_auto_attack_controller()
	call_deferred("_bind_skill_hotbar")
	call_deferred("_bind_auto_attack_controller")
	_refresh_all()


func _exit_tree() -> void:
	_disconnect_skill_hotbar()
	_disconnect_auto_attack_controller()
	_disconnect_role_manager()
	_disconnect_stats_manager()
	_release_ui_lock()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION_NAME):
		if visible:
			close()
		else:
			open_ui()
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open_ui() -> void:
	visible = true
	_bind_skill_hotbar()
	_bind_auto_attack_controller()
	_acquire_ui_lock()
	_refresh_all()


func close() -> void:
	_hide_skill_select_overlay()
	if _auto_attack_config_dialog != null and _auto_attack_config_dialog.has_method("close_dialog"):
		_auto_attack_config_dialog.call("close_dialog")
	_release_ui_lock()
	visible = false


func _connect_stats_manager() -> void:
	if PlayerStatsManager == null:
		return

	var point_changed_callable: Callable = Callable(self, "_on_skill_points_changed")
	if PlayerStatsManager.has_signal("skill_points_changed") and not PlayerStatsManager.skill_points_changed.is_connected(point_changed_callable):
		PlayerStatsManager.skill_points_changed.connect(point_changed_callable)

	var exp_changed_callable: Callable = Callable(self, "_on_skill_exp_changed")
	if not PlayerStatsManager.skill_exp_changed.is_connected(exp_changed_callable):
		PlayerStatsManager.skill_exp_changed.connect(exp_changed_callable)

	var stats_changed_callable: Callable = Callable(self, "_on_stats_changed")
	if not PlayerStatsManager.stats_changed.is_connected(stats_changed_callable):
		PlayerStatsManager.stats_changed.connect(stats_changed_callable)


func _disconnect_stats_manager() -> void:
	if PlayerStatsManager == null:
		return

	var point_changed_callable: Callable = Callable(self, "_on_skill_points_changed")
	if PlayerStatsManager.has_signal("skill_points_changed") and PlayerStatsManager.skill_points_changed.is_connected(point_changed_callable):
		PlayerStatsManager.skill_points_changed.disconnect(point_changed_callable)

	var exp_changed_callable: Callable = Callable(self, "_on_skill_exp_changed")
	if PlayerStatsManager.skill_exp_changed.is_connected(exp_changed_callable):
		PlayerStatsManager.skill_exp_changed.disconnect(exp_changed_callable)

	var stats_changed_callable: Callable = Callable(self, "_on_stats_changed")
	if PlayerStatsManager.stats_changed.is_connected(stats_changed_callable):
		PlayerStatsManager.stats_changed.disconnect(stats_changed_callable)


func _connect_role_manager() -> void:
	var role_manager: Node = _find_role_manager()
	if role_manager == null:
		_refresh_role_section()
		return

	var roles_changed_callable: Callable = Callable(self, "_on_roles_changed")
	if role_manager.has_signal("roles_changed") and not role_manager.is_connected("roles_changed", roles_changed_callable):
		role_manager.connect("roles_changed", roles_changed_callable)

	_refresh_role_section()


func _disconnect_role_manager() -> void:
	var role_manager: Node = _find_role_manager()
	if role_manager == null:
		return

	var roles_changed_callable: Callable = Callable(self, "_on_roles_changed")
	if role_manager.has_signal("roles_changed") and role_manager.is_connected("roles_changed", roles_changed_callable):
		role_manager.disconnect("roles_changed", roles_changed_callable)


func _bind_skill_hotbar() -> void:
	var hotbar: Node = _find_skill_hotbar()
	if hotbar == _observed_hotbar:
		return

	_disconnect_skill_hotbar()
	_observed_hotbar = hotbar
	if _observed_hotbar == null:
		return

	var slot_changed_callable: Callable = Callable(self, "_on_hotbar_active_slot_changed")
	if _observed_hotbar.has_signal("active_slot_changed") and not _observed_hotbar.is_connected("active_slot_changed", slot_changed_callable):
		_observed_hotbar.connect("active_slot_changed", slot_changed_callable)

	var assigned_callable: Callable = Callable(self, "_on_hotbar_slot_assignment_changed")
	if _observed_hotbar.has_signal("slot_skill_assigned") and not _observed_hotbar.is_connected("slot_skill_assigned", assigned_callable):
		_observed_hotbar.connect("slot_skill_assigned", assigned_callable)
	if _observed_hotbar.has_signal("slot_cleared") and not _observed_hotbar.is_connected("slot_cleared", assigned_callable):
		_observed_hotbar.connect("slot_cleared", assigned_callable)


func _disconnect_skill_hotbar() -> void:
	if _observed_hotbar == null:
		return

	var slot_changed_callable: Callable = Callable(self, "_on_hotbar_active_slot_changed")
	if _observed_hotbar.has_signal("active_slot_changed") and _observed_hotbar.is_connected("active_slot_changed", slot_changed_callable):
		_observed_hotbar.disconnect("active_slot_changed", slot_changed_callable)

	var assigned_callable: Callable = Callable(self, "_on_hotbar_slot_assignment_changed")
	if _observed_hotbar.has_signal("slot_skill_assigned") and _observed_hotbar.is_connected("slot_skill_assigned", assigned_callable):
		_observed_hotbar.disconnect("slot_skill_assigned", assigned_callable)
	if _observed_hotbar.has_signal("slot_cleared") and _observed_hotbar.is_connected("slot_cleared", assigned_callable):
		_observed_hotbar.disconnect("slot_cleared", assigned_callable)

	_observed_hotbar = null


func _bind_auto_attack_controller() -> void:
	var controller: Node = _find_auto_attack_controller()
	if controller == _observed_auto_attack_controller:
		return

	_disconnect_auto_attack_controller()
	_observed_auto_attack_controller = controller
	if _observed_auto_attack_controller == null:
		return

	var toggled_callable: Callable = Callable(self, "_on_auto_attack_toggled")
	if _observed_auto_attack_controller.has_signal("auto_attack_toggled") and not _observed_auto_attack_controller.is_connected("auto_attack_toggled", toggled_callable):
		_observed_auto_attack_controller.connect("auto_attack_toggled", toggled_callable)

	var modifier_callable: Callable = Callable(self, "_on_auto_attack_modifier_changed")
	if _observed_auto_attack_controller.has_signal("modifier_changed") and not _observed_auto_attack_controller.is_connected("modifier_changed", modifier_callable):
		_observed_auto_attack_controller.connect("modifier_changed", modifier_callable)

	_refresh_auto_attack_section()


func _disconnect_auto_attack_controller() -> void:
	if _observed_auto_attack_controller == null:
		return

	var toggled_callable: Callable = Callable(self, "_on_auto_attack_toggled")
	if _observed_auto_attack_controller.has_signal("auto_attack_toggled") and _observed_auto_attack_controller.is_connected("auto_attack_toggled", toggled_callable):
		_observed_auto_attack_controller.disconnect("auto_attack_toggled", toggled_callable)

	var modifier_callable: Callable = Callable(self, "_on_auto_attack_modifier_changed")
	if _observed_auto_attack_controller.has_signal("modifier_changed") and _observed_auto_attack_controller.is_connected("modifier_changed", modifier_callable):
		_observed_auto_attack_controller.disconnect("modifier_changed", modifier_callable)

	_observed_auto_attack_controller = null


func _on_skill_exp_changed(_skill_name: String, _current_exp: int, _next_exp: int, _level: int, _max_level: int) -> void:
	if visible:
		_refresh_all()


func _on_skill_points_changed(_skill_name: String, _points: int) -> void:
	if visible:
		_refresh_all()


func _on_stats_changed() -> void:
	if visible:
		_refresh_all()


func _on_roles_changed(_main_role: String, _sub_role: String, _is_pure: bool) -> void:
	_refresh_role_section()
	_refresh_active_skill_section()
	if visible:
		_refresh_all()


func _on_hotbar_active_slot_changed(_slot_index: int) -> void:
	_refresh_active_skill_section()


func _on_hotbar_slot_assignment_changed(_slot_index: int, _skill_id: String = "") -> void:
	_refresh_active_skill_section()


func _on_auto_attack_toggled(_enabled: bool) -> void:
	_refresh_auto_attack_section()


func _on_auto_attack_modifier_changed(_modifier) -> void:
	_refresh_auto_attack_section()


func _refresh_all() -> void:
	_refresh_role_section()
	_refresh_active_skill_section()
	_refresh_auto_attack_section()
	_clear_skill_rows()

	if PlayerStatsManager == null:
		summary_label.text = "PlayerStatsManager が見つからない"
		return

	var total_skill_points: int = PlayerStatsManager.get_skill_points()
	var shared_skill_points: int = 0
	if PlayerStatsManager.has_method("get_shared_skill_points"):
		shared_skill_points = PlayerStatsManager.get_shared_skill_points()

	summary_label.text = "プレイヤーLv.%d   未使用スキルpt合計 %d" % [
		PlayerStatsManager.get_level(),
		total_skill_points
	]
	if shared_skill_points > 0:
		summary_label.text += "  (共通pt %d)" % shared_skill_points

	var role_manager: Node = _find_role_manager()
	if role_manager != null and role_manager.has_method("get_specialization_text"):
		summary_label.text += "\n現在ロール: %s" % String(role_manager.call("get_specialization_text"))

	if skill_row_scene == null:
		summary_label.text += "\nskill_row_scene が未設定"
		return

	for i in range(SUPPORTED_SKILLS.size()):
		var skill_def: Dictionary = SUPPORTED_SKILLS[i]
		var skill_key: String = str(skill_def.get("key", ""))
		var display_name: String = str(skill_def.get("label", skill_key))
		var row: SkillRow = skill_row_scene.instantiate() as SkillRow
		if row == null:
			continue

		var level: int = PlayerStatsManager.get_skill(skill_key)
		var max_level: int = PlayerStatsManager.get_skill_max_level(skill_key)
		var current_exp: int = PlayerStatsManager.get_skill_exp(skill_key)
		var next_exp: int = PlayerStatsManager.get_skill_next_exp(skill_key)
		var skill_points: int = 0
		if PlayerStatsManager.has_method("get_skill_points"):
			skill_points = PlayerStatsManager.get_skill_points(skill_key)

		skill_list.add_child(row)
		row.setup(skill_key, display_name, level, max_level, current_exp, next_exp, skill_points)


func _refresh_role_section() -> void:
	_ensure_role_section()

	var role_manager: Node = _find_role_manager()
	if role_manager == null:
		_role_status_label.text = "ロール設定: RoleManager が見つかりません"
		_role_note_label.text = "AutoLoad に RoleManager を追加すると、ここでメイン / サブロールを選べます。"
		_main_role_option.disabled = true
		_sub_role_option.disabled = true
		return

	_main_role_option.disabled = false
	_sub_role_option.disabled = false

	var main_roles_variant: Variant = role_manager.call("get_main_role_options")
	var sub_roles_variant: Variant = role_manager.call("get_sub_role_options")
	var main_role: String = String(role_manager.call("get_main_role"))
	var sub_role: String = String(role_manager.call("get_sub_role"))
	var is_pure: bool = bool(role_manager.call("is_pure"))

	_populate_role_options(_main_role_option, main_roles_variant, role_manager)
	_populate_role_options(_sub_role_option, sub_roles_variant, role_manager)
	_select_role_option(_main_role_option, main_role)
	_select_role_option(_sub_role_option, sub_role)

	var main_label: String = main_role
	var sub_label: String = sub_role
	if role_manager.has_method("get_role_label"):
		main_label = String(role_manager.call("get_role_label", main_role))
		sub_label = String(role_manager.call("get_role_label", sub_role))

	if is_pure:
		_role_status_label.text = "現在のロール: %s・ピュア（特化）" % main_label
		_role_note_label.text = "メインロールと同じサブロールを選んでいるため、特化専用スキルを使用できます。"
	else:
		_role_status_label.text = "現在のロール: %s / %s" % [main_label, sub_label]
		_role_note_label.text = "メインと同じサブロールを選ぶとピュア（特化）になります。"


func _refresh_active_skill_section() -> void:
	_ensure_active_skill_section()
	_ensure_skill_select_overlay()
	_bind_skill_hotbar()

	var role_skills: Array[RoleSkillData] = _get_role_skills()
	var hotbar: Node = _observed_hotbar

	if role_skills.is_empty():
		_active_skill_status_label.text = "ロールスキルがまだありません。"
		_selected_skill_label.text = "登録候補: まだ選択していません"
		if _open_select_page_button != null:
			_open_select_page_button.disabled = true
		if _register_button != null:
			_register_button.disabled = true
		if _clear_slot_button != null:
			_clear_slot_button.disabled = true
		_hide_skill_select_overlay()
		return

	var current_slot_text: String = _get_hotbar_slot_text(hotbar)
	var current_skill_text: String = _get_hotbar_current_skill_text(hotbar)
	_active_skill_status_label.text = "選択中スロット: %s   現在登録: %s" % [current_slot_text, current_skill_text]

	if _selected_role_skill == null:
		_selected_skill_label.text = "登録候補: まだ選択していません"
	else:
		_selected_skill_label.text = "登録候補: %s" % _selected_role_skill.display_name

	if _open_select_page_button != null:
		_open_select_page_button.disabled = false
		_open_select_page_button.text = "ロールスキル選択ページを開く"

	if hotbar == null:
		_register_button.disabled = true
		_register_button.text = "ホットバーが見つかりません"
		_clear_slot_button.disabled = true
		return

	_register_button.disabled = _selected_role_skill == null
	_register_button.text = "選択中スロット(%s)に登録" % current_slot_text
	_clear_slot_button.disabled = _is_current_hotbar_slot_empty(hotbar)

	if _skill_select_overlay != null and _skill_select_overlay.visible:
		_refresh_skill_select_page()


func _refresh_auto_attack_section() -> void:
	_ensure_auto_attack_section()
	_bind_auto_attack_controller()

	if _observed_auto_attack_controller == null:
		_auto_attack_status_label.text = "オート通常攻撃: AutoAttackController が見つかりません"
		_auto_attack_modifier_label.text = "Robin.tscn などの戦闘キャラ側に AutoAttackController を追加してください。"
		_auto_attack_open_button.disabled = true
		return

	var enabled: bool = false
	if _observed_auto_attack_controller.has_method("is_auto_attack_enabled"):
		enabled = bool(_observed_auto_attack_controller.call("is_auto_attack_enabled"))

	var modifier_name: String = "未設定"
	var modifier_summary: String = ""
	if _observed_auto_attack_controller.has_method("get_current_modifier"):
		var modifier_value: Variant = _observed_auto_attack_controller.call("get_current_modifier")
		if modifier_value is AutoAttackModifierData:
			var modifier: AutoAttackModifierData = modifier_value as AutoAttackModifierData
			modifier_name = modifier.display_name
			modifier_summary = modifier.get_summary_text()

	_auto_attack_status_label.text = "オート通常攻撃: %s" % ("ON" if enabled else "OFF")
	_auto_attack_modifier_label.text = "現在設定: %s" % modifier_name
	if not modifier_summary.is_empty():
		_auto_attack_modifier_label.text += "\n" + modifier_summary

	_auto_attack_open_button.disabled = not ResourceLoader.exists(AUTO_ATTACK_CONFIG_DIALOG_SCENE_PATH)
	_auto_attack_open_button.text = "通常攻撃設定を開く"


func _build_role_skill_select_item(skill: RoleSkillData) -> Control:
	var row_button: Button = Button.new()
	row_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_button.text = skill.display_name
	row_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row_button.custom_minimum_size = Vector2(0, 48)
	row_button.pressed.connect(_on_role_skill_select_page_item_pressed.bind(skill))
	return row_button


func _open_skill_select_overlay() -> void:
	_ensure_skill_select_overlay()
	_skill_select_pending_skill = _selected_role_skill
	_refresh_skill_select_page()
	if _skill_select_overlay != null:
		_skill_select_overlay.visible = true


func _hide_skill_select_overlay() -> void:
	if _skill_select_overlay != null:
		_skill_select_overlay.visible = false
	_skill_select_pending_skill = null


func _refresh_skill_select_page() -> void:
	if _skill_select_overlay == null:
		return

	for child in _skill_select_list.get_children():
		_skill_select_list.remove_child(child)
		child.queue_free()

	var role_skills: Array[RoleSkillData] = _get_role_skills()
	if role_skills.is_empty():
		_skill_select_name_label.text = "ロールスキルなし"
		_skill_select_icon.texture = null
		_skill_select_description_label.text = "選択可能なロールスキルがありません。"
		_skill_select_state_label.text = ""
		_skill_select_confirm_button.disabled = true
		return

	var preview_skill: RoleSkillData = _skill_select_pending_skill
	if preview_skill == null:
		preview_skill = role_skills[0]

	for skill in role_skills:
		if skill == null:
			continue
		var item: Button = _build_role_skill_select_item(skill) as Button
		if skill == preview_skill:
			item.text += "  [選択中]"
		_skill_select_list.add_child(item)

	_apply_skill_select_preview(preview_skill)


func _apply_skill_select_preview(skill: RoleSkillData) -> void:
	if skill == null:
		_skill_select_name_label.text = "未選択"
		_skill_select_icon.texture = null
		_skill_select_description_label.text = ""
		_skill_select_state_label.text = ""
		_skill_select_confirm_button.disabled = true
		return

	_skill_select_pending_skill = skill
	_skill_select_name_label.text = skill.display_name
	_skill_select_icon.texture = skill.icon
	_skill_select_description_label.text = _build_role_skill_detail_text(skill)

	var role_manager: Node = _find_role_manager()
	var state_text: String = "現在のロールで使用可能"
	if role_manager != null and role_manager.has_method("can_use_skill"):
		var result: Variant = role_manager.call("can_use_skill", skill)
		if result is Dictionary and not bool(result.get("ok", false)):
			state_text = "現在のロールでは使用不可: %s" % String(result.get("reason", "条件未達成"))
	_skill_select_state_label.text = state_text
	_skill_select_confirm_button.disabled = false


func _on_role_skill_select_page_item_pressed(skill: RoleSkillData) -> void:
	_apply_skill_select_preview(skill)
	_refresh_skill_select_page()


func _on_skill_select_confirm_pressed() -> void:
	_selected_role_skill = _skill_select_pending_skill
	_hide_skill_select_overlay()
	_refresh_active_skill_section()


func _on_skill_select_cancel_pressed() -> void:
	_hide_skill_select_overlay()


func _ensure_skill_select_overlay() -> void:
	if _skill_select_overlay != null and is_instance_valid(_skill_select_overlay):
		return

	_skill_select_overlay = ColorRect.new()
	_skill_select_overlay.name = "RoleSkillSelectOverlay"
	_skill_select_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_skill_select_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_skill_select_overlay.color = Color(0.0, 0.0, 0.0, 0.62)
	_skill_select_overlay.visible = false
	add_child(_skill_select_overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_select_overlay.add_child(center)

	_skill_select_panel = PanelContainer.new()
	_skill_select_panel.custom_minimum_size = Vector2(980, 540)
	_skill_select_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_skill_select_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(_skill_select_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.04, 0.05, 0.07, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.20, 0.34, 0.48, 0.95)
	panel_style.corner_radius_top_left = 14
	panel_style.corner_radius_top_right = 14
	panel_style.corner_radius_bottom_left = 14
	panel_style.corner_radius_bottom_right = 14
	_skill_select_panel.add_theme_stylebox_override("panel", panel_style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_skill_select_panel.add_child(margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	var overlay_title_label: Label = Label.new()
	overlay_title_label.text = "ロールスキル選択"
	overlay_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title_label.add_theme_font_size_override("font_size", 24)
	root_vbox.add_child(overlay_title_label)

	var body_split: HSplitContainer = HSplitContainer.new()
	body_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_split.split_offset = 0
	root_vbox.add_child(body_split)

	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_split.add_child(left_panel)

	var left_style: StyleBoxFlat = StyleBoxFlat.new()
	left_style.bg_color = Color(0.08, 0.09, 0.11, 0.96)
	left_style.corner_radius_top_left = 10
	left_style.corner_radius_top_right = 10
	left_style.corner_radius_bottom_left = 10
	left_style.corner_radius_bottom_right = 10
	left_style.border_width_left = 1
	left_style.border_width_top = 1
	left_style.border_width_right = 1
	left_style.border_width_bottom = 1
	left_style.border_color = Color(0.17, 0.25, 0.35, 0.9)
	left_panel.add_theme_stylebox_override("panel", left_style)

	var left_margin: MarginContainer = MarginContainer.new()
	left_margin.add_theme_constant_override("margin_left", 14)
	left_margin.add_theme_constant_override("margin_top", 14)
	left_margin.add_theme_constant_override("margin_right", 14)
	left_margin.add_theme_constant_override("margin_bottom", 14)
	left_panel.add_child(left_margin)

	var left_vbox: VBoxContainer = VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 10)
	left_margin.add_child(left_vbox)

	var desc_title: Label = Label.new()
	desc_title.text = "スキル説明"
	desc_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_title.add_theme_font_size_override("font_size", 20)
	left_vbox.add_child(desc_title)

	_skill_select_description_label = Label.new()
	_skill_select_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_select_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(_skill_select_description_label)

	_skill_select_state_label = Label.new()
	_skill_select_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vbox.add_child(_skill_select_state_label)

	var right_panel: PanelContainer = PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_split.add_child(right_panel)
	right_panel.add_theme_stylebox_override("panel", left_style.duplicate())

	var right_margin: MarginContainer = MarginContainer.new()
	right_margin.add_theme_constant_override("margin_left", 14)
	right_margin.add_theme_constant_override("margin_top", 14)
	right_margin.add_theme_constant_override("margin_right", 14)
	right_margin.add_theme_constant_override("margin_bottom", 14)
	right_panel.add_child(right_margin)

	var right_vbox: VBoxContainer = VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	right_margin.add_child(right_vbox)

	var preview_title: Label = Label.new()
	preview_title.text = "スキル選択"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 20)
	right_vbox.add_child(preview_title)

	_skill_select_icon = TextureRect.new()
	_skill_select_icon.custom_minimum_size = Vector2(96, 96)
	_skill_select_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_skill_select_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_skill_select_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right_vbox.add_child(_skill_select_icon)

	_skill_select_name_label = Label.new()
	_skill_select_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_select_name_label.add_theme_font_size_override("font_size", 22)
	right_vbox.add_child(_skill_select_name_label)

	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_vbox.add_child(list_scroll)

	_skill_select_list = VBoxContainer.new()
	_skill_select_list.add_theme_constant_override("separation", 8)
	_skill_select_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(_skill_select_list)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 10)
	root_vbox.add_child(button_row)

	_skill_select_cancel_button = Button.new()
	_skill_select_cancel_button.text = "閉じる"
	_skill_select_cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_select_cancel_button.pressed.connect(_on_skill_select_cancel_pressed)
	button_row.add_child(_skill_select_cancel_button)

	_skill_select_confirm_button = Button.new()
	_skill_select_confirm_button.text = "このスキルを選択"
	_skill_select_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_select_confirm_button.pressed.connect(_on_skill_select_confirm_pressed)
	button_row.add_child(_skill_select_confirm_button)


func _build_role_skill_detail_text(skill: RoleSkillData) -> String:
	var cast_label: String = "即時詠唱"
	if skill.cast_time_seconds > 0.0:
		cast_label = "詠唱 %.1f秒" % skill.cast_time_seconds

	var cooldown_label: String = "CT %.1f秒" % skill.cooldown_seconds
	var range_label: String = ""
	if skill.range_meters > 0.0:
		range_label = "  射程 %.1fm" % skill.range_meters

	var role_label: String = skill.role_name
	if role_label.is_empty():
		role_label = "ロールスキル"

	return "%s / 消費MP %d / %s / %s%s\n%s" % [
		role_label,
		skill.mp_cost,
		cast_label,
		cooldown_label,
		range_label,
		skill.description
	]


func _get_role_skills() -> Array[RoleSkillData]:
	var result: Array[RoleSkillData] = []
	var seen_keys: Dictionary = {}

	for resource in role_skill_resources:
		var skill: RoleSkillData = _variant_to_role_skill(resource)
		if skill == null:
			continue
		var key: String = skill.resource_path
		if key.is_empty():
			key = skill.skill_id
		if seen_keys.has(key):
			continue
		seen_keys[key] = true
		result.append(skill)

	for path in DEFAULT_ROLE_SKILL_PATHS:
		var skill_from_path: RoleSkillData = _load_role_skill_from_path(path)
		if skill_from_path == null:
			continue
		var path_key: String = skill_from_path.resource_path
		if path_key.is_empty():
			path_key = skill_from_path.skill_id
		if seen_keys.has(path_key):
			continue
		seen_keys[path_key] = true
		result.append(skill_from_path)

	for dir_path in ROLE_SKILL_SCAN_DIRS:
		for skill in _scan_role_skills_in_directory(dir_path):
			if skill == null:
				continue
			var key: String = skill.resource_path
			if key.is_empty():
				key = skill.skill_id
			if seen_keys.has(key):
				continue
			seen_keys[key] = true
			result.append(skill)

	return result


func _variant_to_role_skill(value: Variant) -> RoleSkillData:
	if value == null:
		return null
	if value is RoleSkillData:
		return value as RoleSkillData
	if value is Resource:
		var resource: Resource = value as Resource
		if resource.get_script() != null and resource.has_method("get"):
			var skill_id_value: Variant = resource.get("skill_id")
			var display_name_value: Variant = resource.get("display_name")
			if skill_id_value != null or display_name_value != null:
				return resource as RoleSkillData
	return null


func _load_role_skill_from_path(path: String) -> RoleSkillData:
	if path.is_empty():
		return null
	if not ResourceLoader.exists(path):
		return null
	var loaded: Resource = ResourceLoader.load(path)
	return _variant_to_role_skill(loaded)


func _scan_role_skills_in_directory(dir_path: String) -> Array[RoleSkillData]:
	var found: Array[RoleSkillData] = []
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
		if not file_name.ends_with('.tres'):
			continue
		var full_path: String = dir_path.path_join(file_name)
		var loaded_skill: RoleSkillData = _load_role_skill_from_path(full_path)
		if loaded_skill == null:
			continue
		found.append(loaded_skill)
	dir.list_dir_end()
	return found


func _clear_skill_rows() -> void:
	for child in skill_list.get_children():
		skill_list.remove_child(child)
		child.queue_free()


func _on_main_role_selected(index: int) -> void:
	if _is_updating_role_controls:
		return

	var role_manager: Node = _find_role_manager()
	if role_manager == null:
		return

	var role_id: String = _get_option_role_id(_main_role_option, index)
	if role_id.is_empty():
		return

	role_manager.call("set_main_role", role_id)


func _on_sub_role_selected(index: int) -> void:
	if _is_updating_role_controls:
		return

	var role_manager: Node = _find_role_manager()
	if role_manager == null:
		return

	var role_id: String = _get_option_role_id(_sub_role_option, index)
	if role_id.is_empty():
		return

	role_manager.call("set_sub_role", role_id)


func _on_role_skill_selected(skill: RoleSkillData) -> void:
	_selected_role_skill = skill
	_refresh_active_skill_section()


func _on_register_selected_skill_pressed() -> void:
	var hotbar: Node = _observed_hotbar
	if hotbar == null or _selected_role_skill == null:
		return

	var slot_index: int = 0
	if hotbar.has_method("get_active_slot_index"):
		slot_index = int(hotbar.call("get_active_slot_index"))

	if hotbar.has_method("set_slot_skill_resource"):
		hotbar.call("set_slot_skill_resource", slot_index, _selected_role_skill)
	else:
		hotbar.call("set_slot_skill", slot_index, _selected_role_skill.skill_id, _selected_role_skill.display_name, _selected_role_skill.icon)

	_active_skill_status_label.text = "選択中スロット %s に %s を登録しました" % [_get_hotbar_slot_text(hotbar), _selected_role_skill.display_name]
	_refresh_active_skill_section()


func _on_clear_slot_pressed() -> void:
	var hotbar: Node = _observed_hotbar
	if hotbar == null:
		return

	var slot_index: int = 0
	if hotbar.has_method("get_active_slot_index"):
		slot_index = int(hotbar.call("get_active_slot_index"))

	if hotbar.has_method("clear_slot"):
		hotbar.call("clear_slot", slot_index)

	_refresh_active_skill_section()


func _on_open_auto_attack_config_pressed() -> void:
	_bind_auto_attack_controller()
	if _observed_auto_attack_controller == null:
		return
	if not ResourceLoader.exists(AUTO_ATTACK_CONFIG_DIALOG_SCENE_PATH):
		return

	if _auto_attack_config_dialog == null or not is_instance_valid(_auto_attack_config_dialog):
		var dialog_scene: PackedScene = load(AUTO_ATTACK_CONFIG_DIALOG_SCENE_PATH) as PackedScene
		if dialog_scene == null:
			return
		_auto_attack_config_dialog = dialog_scene.instantiate() as Control
		if _auto_attack_config_dialog == null:
			return
		add_child(_auto_attack_config_dialog)

	if _auto_attack_config_dialog.has_method("open_dialog"):
		_auto_attack_config_dialog.call("open_dialog", _observed_auto_attack_controller)


func _get_option_role_id(option_button: OptionButton, index: int) -> String:
	if option_button == null:
		return ""
	if index < 0 or index >= option_button.get_item_count():
		return ""
	return String(option_button.get_item_metadata(index))


func _populate_role_options(option_button: OptionButton, role_ids_variant: Variant, role_manager: Node) -> void:
	if option_button == null:
		return
	if not (role_ids_variant is PackedStringArray):
		return

	var role_ids: PackedStringArray = role_ids_variant as PackedStringArray
	var current_ids: Array[String] = []
	for i in range(option_button.get_item_count()):
		current_ids.append(String(option_button.get_item_metadata(i)))

	if current_ids.size() == role_ids.size():
		var same: bool = true
		for i in range(role_ids.size()):
			if current_ids[i] != role_ids[i]:
				same = false
				break
		if same:
			return

	_is_updating_role_controls = true
	option_button.clear()
	for role_id in role_ids:
		var label: String = String(role_id)
		if role_manager.has_method("get_role_label"):
			label = String(role_manager.call("get_role_label", role_id))
		option_button.add_item(label)
		option_button.set_item_metadata(option_button.get_item_count() - 1, String(role_id))
	_is_updating_role_controls = false


func _select_role_option(option_button: OptionButton, role_id: String) -> void:
	if option_button == null:
		return

	_is_updating_role_controls = true
	for i in range(option_button.get_item_count()):
		if String(option_button.get_item_metadata(i)) == role_id:
			option_button.select(i)
			break
	_is_updating_role_controls = false


func _ensure_role_section() -> void:
	if _role_section != null and is_instance_valid(_role_section):
		return

	_role_section = PanelContainer.new()
	_role_section.name = "RoleSection"
	_role_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_role_section.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header_label: Label = Label.new()
	header_label.text = "ロール設定"
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(header_label)

	_role_status_label = Label.new()
	_role_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_role_status_label)

	var main_row: HBoxContainer = HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 8)
	vbox.add_child(main_row)

	var main_label: Label = Label.new()
	main_label.text = "メインロール"
	main_label.custom_minimum_size = Vector2(120, 0)
	main_row.add_child(main_label)

	_main_role_option = OptionButton.new()
	_main_role_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_role_option.item_selected.connect(_on_main_role_selected)
	main_row.add_child(_main_role_option)

	var sub_row: HBoxContainer = HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 8)
	vbox.add_child(sub_row)

	var sub_label: Label = Label.new()
	sub_label.text = "サブロール"
	sub_label.custom_minimum_size = Vector2(120, 0)
	sub_row.add_child(sub_label)

	_sub_role_option = OptionButton.new()
	_sub_role_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_role_option.item_selected.connect(_on_sub_role_selected)
	sub_row.add_child(_sub_role_option)

	_role_note_label = Label.new()
	_role_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_role_note_label)

	content_vbox.add_child(_role_section)
	content_vbox.move_child(_role_section, 1)


func _ensure_active_skill_section() -> void:
	if _active_skill_section != null and is_instance_valid(_active_skill_section):
		return

	_active_skill_section = PanelContainer.new()
	_active_skill_section.name = "ActiveSkillSection"
	_active_skill_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_active_skill_section.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header_label: Label = Label.new()
	header_label.text = "ロールスキル登録"
	vbox.add_child(header_label)

	_active_skill_status_label = Label.new()
	_active_skill_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_active_skill_status_label)

	_selected_skill_label = Label.new()
	_selected_skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_selected_skill_label)

	_open_select_page_button = Button.new()
	_open_select_page_button.text = "ロールスキル選択ページを開く"
	_open_select_page_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_open_select_page_button.pressed.connect(_open_skill_select_overlay)
	vbox.add_child(_open_select_page_button)

	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	vbox.add_child(button_row)

	_register_button = Button.new()
	_register_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_register_button.text = "選択中スロットに登録"
	_register_button.pressed.connect(_on_register_selected_skill_pressed)
	button_row.add_child(_register_button)

	_clear_slot_button = Button.new()
	_clear_slot_button.text = "選択中スロットを解除"
	_clear_slot_button.pressed.connect(_on_clear_slot_pressed)
	button_row.add_child(_clear_slot_button)

	_active_skill_list = VBoxContainer.new()
	_active_skill_list.visible = false
	vbox.add_child(_active_skill_list)

	content_vbox.add_child(_active_skill_section)
	content_vbox.move_child(_active_skill_section, 2)


func _ensure_auto_attack_section() -> void:
	if _auto_attack_section != null and is_instance_valid(_auto_attack_section):
		return

	_auto_attack_section = PanelContainer.new()
	_auto_attack_section.name = "AutoAttackSection"
	_auto_attack_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	_auto_attack_section.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var header_label: Label = Label.new()
	header_label.text = "オート通常攻撃"
	vbox.add_child(header_label)

	_auto_attack_status_label = Label.new()
	_auto_attack_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_auto_attack_status_label)

	_auto_attack_modifier_label = Label.new()
	_auto_attack_modifier_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_auto_attack_modifier_label)

	_auto_attack_open_button = Button.new()
	_auto_attack_open_button.text = "通常攻撃設定を開く"
	_auto_attack_open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auto_attack_open_button.pressed.connect(_on_open_auto_attack_config_pressed)
	vbox.add_child(_auto_attack_open_button)

	content_vbox.add_child(_auto_attack_section)
	content_vbox.move_child(_auto_attack_section, 3)


func _get_hotbar_slot_text(hotbar: Node) -> String:
	if hotbar == null:
		return "未接続"

	var slot_index: int = 0
	if hotbar.has_method("get_active_slot_index"):
		slot_index = int(hotbar.call("get_active_slot_index"))

	return _slot_index_to_key_label(slot_index)


func _get_hotbar_current_skill_text(hotbar: Node) -> String:
	if hotbar == null:
		return "ホットバー未接続"

	var slot_index: int = 0
	if hotbar.has_method("get_active_slot_index"):
		slot_index = int(hotbar.call("get_active_slot_index"))

	var display_name: String = ""
	if hotbar.has_method("get_slot_skill_display_name"):
		display_name = String(hotbar.call("get_slot_skill_display_name", slot_index))
	elif hotbar.has_method("get_slot_skill_id"):
		display_name = String(hotbar.call("get_slot_skill_id", slot_index))

	if display_name.is_empty():
		return "空き"
	return display_name


func _is_current_hotbar_slot_empty(hotbar: Node) -> bool:
	if hotbar == null:
		return true

	var slot_index: int = 0
	if hotbar.has_method("get_active_slot_index"):
		slot_index = int(hotbar.call("get_active_slot_index"))

	var skill_id: String = ""
	if hotbar.has_method("get_slot_skill_id"):
		skill_id = String(hotbar.call("get_slot_skill_id", slot_index))
	return skill_id.is_empty()


func _slot_index_to_key_label(slot_index: int) -> String:
	match slot_index:
		0:
			return "1"
		1:
			return "2"
		2:
			return "3"
		3:
			return "4"
		4:
			return "5"
		5:
			return "6"
		6:
			return "7"
		7:
			return "8"
		8:
			return "9"
		9:
			return "0"
	return str(slot_index + 1)


func _on_close_pressed() -> void:
	close()


func _find_role_manager() -> Node:
	var by_path: Node = get_node_or_null("/root/RoleManager")
	if by_path != null:
		return by_path

	var by_group: Node = get_tree().get_first_node_in_group("role_manager")
	if by_group != null:
		return by_group

	for child in get_tree().root.get_children():
		var script_value: Variant = child.get_script()
		if script_value is Script:
			var script_ref: Script = script_value as Script
			if script_ref != null and script_ref.resource_path.get_file() == ROLE_MANAGER_SCRIPT_NAME:
				return child

	return null


func _find_skill_hotbar() -> Node:
	var direct_paths: Array[NodePath] = [
		NodePath("/root/Main/UI/SkillHotbarUI"),
		NodePath("/root/Main/UI/SkillHotbarUI"),
		NodePath("/root/SkillHotbarUI"),
		NodePath("UI/SkillHotbarUI"),
		NodePath("../UI/SkillHotbarUI")
	]
	for path in direct_paths:
		var direct: Node = get_node_or_null(path)
		if direct != null:
			return direct

	var by_group: Node = get_tree().get_first_node_in_group("skill_hotbar_ui")
	if by_group != null:
		return by_group

	var root: Node = get_tree().root
	var found_by_name: Node = root.find_child("SkillHotbarUI", true, false)
	if found_by_name != null:
		return found_by_name

	return _find_node_by_script_file(root, SKILL_HOTBAR_SCRIPT_NAME)


func _find_auto_attack_controller() -> Node:
	var by_group: Node = get_tree().get_first_node_in_group("auto_attack_controller")
	if by_group != null:
		return by_group

	var root: Node = get_tree().root
	var by_name: Node = root.find_child("AutoAttackController", true, false)
	if by_name != null:
		return by_name

	return _find_node_by_script_file(root, AUTO_ATTACK_CONTROLLER_SCRIPT_NAME)


func _find_node_by_script_file(root: Node, file_name: String) -> Node:
	if root == null:
		return null

	var stack: Array = [root]
	while not stack.is_empty():
		var current_obj: Variant = stack.pop_back()
		var current: Node = current_obj as Node
		if current == null:
			continue

		var script_value: Variant = current.get_script()
		if script_value is Script:
			var script_ref: Script = script_value as Script
			if script_ref != null and script_ref.resource_path.get_file() == file_name:
				return current

		for child_obj in current.get_children():
			var child: Node = child_obj as Node
			if child != null:
				stack.append(child)

	return null


func _find_ui_modal_manager() -> Node:
	var by_path: Node = get_node_or_null("/root/UIModalManager")
	if by_path != null:
		return by_path

	var by_group: Node = get_tree().get_first_node_in_group("ui_modal_manager")
	if by_group != null:
		return by_group

	for child in get_tree().root.get_children():
		var script_value: Variant = child.get_script()
		if script_value is Script:
			var script_ref: Script = script_value as Script
			if script_ref != null and script_ref.resource_path.get_file() == UI_MODAL_MANAGER_SCRIPT_NAME:
				return child

	return null


func _find_time_manager() -> Node:
	var by_path: Node = get_node_or_null("/root/TimeManager")
	if by_path != null:
		return by_path

	var by_group: Node = get_tree().get_first_node_in_group("time_manager")
	if by_group != null:
		return by_group

	for child in get_tree().root.get_children():
		var script_value: Variant = child.get_script()
		if script_value is Script:
			var script_ref: Script = script_value as Script
			if script_ref != null and script_ref.resource_path.get_file() == TIME_MANAGER_SCRIPT_NAME:
				return child

	return null


func _acquire_ui_lock() -> void:
	var ui_modal_manager: Node = _find_ui_modal_manager()
	if ui_modal_manager != null and ui_modal_manager.has_method("acquire_lock"):
		ui_modal_manager.call("acquire_lock", UI_LOCK_SOURCE, true, true)
		return

	var time_manager: Node = _find_time_manager()
	if time_manager == null:
		return

	var pause_source: String = "UI:" + UI_LOCK_SOURCE
	if time_manager.has_method("request_pause"):
		time_manager.call("request_pause", pause_source)
	elif time_manager.has_method("pause_time"):
		time_manager.call("pause_time", pause_source)


func _release_ui_lock() -> void:
	var ui_modal_manager: Node = _find_ui_modal_manager()
	if ui_modal_manager != null and ui_modal_manager.has_method("release_lock"):
		ui_modal_manager.call("release_lock", UI_LOCK_SOURCE)
		return

	var time_manager: Node = _find_time_manager()
	if time_manager == null:
		return

	var pause_source: String = "UI:" + UI_LOCK_SOURCE
	if time_manager.has_method("release_pause"):
		time_manager.call("release_pause", pause_source)
	elif time_manager.has_method("resume_time"):
		time_manager.call("resume_time", pause_source)

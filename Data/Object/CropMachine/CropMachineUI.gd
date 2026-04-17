extends Control
class_name CropMachineUI

const UI_LOCK_SOURCE: String = "栽培機UI"
const UI_MODAL_MANAGER_SCRIPT_NAME: String = "UIModalManager.gd"
const TIME_MANAGER_SCRIPT_NAME: String = "TimeManager.gd"
const FARMING_SKILL_NAME: String = "farming"
const DEFAULT_FARMING_EXP_PER_HARVEST_CYCLE: int = 1

const ROOT_DIMMER_COLOR: Color = Color(0.0, 0.0, 0.0, 0.45)
const MAIN_PANEL_SIZE: Vector2 = Vector2(1000, 760)
const MAIN_PANEL_BG: Color = Color(0.05, 0.08, 0.12, 0.94)
const MAIN_PANEL_BORDER: Color = Color(0.30, 0.75, 1.0, 0.70)
const PANEL_CORNER_RADIUS: int = 16

const SLOT_SELECTED_BORDER_COLOR: Color = Color("ffd700")
const SLOT_SELECTED_BORDER_WIDTH: int = 5
const SLOT_NORMAL_BORDER_WIDTH: int = 2
const SLOT_CORNER_RADIUS: int = 10
const SLOT_BG_NORMAL: Color = Color("2a2a2a")
const SLOT_BG_HOVER: Color = Color("353535")
const SLOT_BG_SELECTED: Color = Color("3a3320")
const SLOT_BG_SELECTED_HOVER: Color = Color("4a4024")
const SLOT_BORDER_NORMAL: Color = Color("666666")
const SLOT_BORDER_HOVER: Color = Color("8a8a8a")
const SLOT_ICON_SIZE: int = 36
const SLOT_ICON_TOP_OFFSET: int = 8
const SLOT_CONTENT_TOP_WITH_ICON: int = 48
const SLOT_BUTTON_WIDTH: int = 160
const SLOT_BUTTON_HEIGHT: int = 118
const SLOT_COLUMNS_PER_PAGE: int = 3
const SLOT_ROWS_PER_PAGE: int = 2
const SLOTS_PER_PAGE: int = SLOT_COLUMNS_PER_PAGE * SLOT_ROWS_PER_PAGE
const GRID_H_SEPARATION: int = 12
const GRID_V_SEPARATION: int = 12
const SLOT_UPGRADE_BUTTON_HEIGHT: int = 28
const SLOT_UPGRADE_BUTTON_TEXT: String = "強化"
const SLOT_CELL_SEPARATION: int = 6
const UPGRADE_DIALOG_SIZE: Vector2 = Vector2(420, 320)
const RECIPE_SELECTOR_DIALOG_SIZE: Vector2 = Vector2(760, 540)
const RECIPE_SELECTOR_DIALOG_SCENE_PATH: String = "res://Data/Object/CropMachine/CropRecipeSelectorDialog.tscn"

var current_machine: CropMachine = null
var current_player: Node = null
var selected_slot_index: int = -1
var selected_recipe_key: String = ""
var pending_cancel_slot_index: int = -1
var pending_cancel_preview: Dictionary = {}
var current_page_index: int = 0
var dimmer: ColorRect = null

@onready var panel: Panel = $Panel
@onready var root_vbox: VBoxContainer = $Panel/VBoxContainer
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var grid: GridContainer = $Panel/VBoxContainer/GridContainer
@onready var recipe_option: OptionButton = $Panel/VBoxContainer/RecipeOptionButton
@onready var plant_count_spinbox: SpinBox = $Panel/VBoxContainer/PlantCountHBox/PlantCountSpinBox
@onready var action_button_row: HBoxContainer = $Panel/VBoxContainer/HBoxContainer
@onready var plant_button: Button = $Panel/VBoxContainer/HBoxContainer/PlantButton
@onready var harvest_button: Button = $Panel/VBoxContainer/HBoxContainer/HarvestButton
@onready var cancel_button: Button = $Panel/VBoxContainer/HBoxContainer/CancelButton
@onready var info_label: Label = $Panel/VBoxContainer/InfoLabel
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton
@onready var cancel_confirm_dialog: ConfirmationDialog = $CancelConfirmDialog

var unlock_slot_button: Button = null
var unlock_slot_button_row: HBoxContainer = null
var page_navigation_row: HBoxContainer = null
var prev_page_button: Button = null
var next_page_button: Button = null
var page_label: Label = null
var close_button_spacer: Control = null
var slot_upgrade_dialog: AcceptDialog = null
var slot_upgrade_title_label: Label = null
var slot_upgrade_info_label: Label = null
var slot_upgrade_slot_index: int = -1
var recipe_selector_row: HBoxContainer = null
var recipe_selector_summary_label: Label = null
var recipe_selector_button: Button = null
var recipe_selector_dialog: CropRecipeSelectorDialog = null
var slot_grid_module: CropMachineSlotGridModule = null


func _ready() -> void:
	visible = false
	add_to_group("crop_machine_ui")

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_slot_grid_module()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_root_layout()
	_setup_dimmer()
	_setup_main_panel()
	_setup_content_layout()

	plant_count_spinbox.min_value = 1
	plant_count_spinbox.max_value = 999
	plant_count_spinbox.step = 1
	plant_count_spinbox.value = 1
	plant_count_spinbox.rounded = true

	plant_button.pressed.connect(_on_plant_pressed)
	harvest_button.pressed.connect(_on_harvest_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	close_button.pressed.connect(_on_close_pressed)
	plant_count_spinbox.value_changed.connect(_on_plant_count_changed)
	cancel_confirm_dialog.confirmed.connect(_on_cancel_confirmed)
	grid.columns = SLOT_COLUMNS_PER_PAGE
	_ensure_page_controls()
	_ensure_unlock_slot_button_row()
	_ensure_unlock_slot_button()
	_ensure_recipe_selector_row()
	_ensure_recipe_selector_dialog()
	_ensure_bottom_spacer()
	_ensure_slot_upgrade_dialog()

	if not resized.is_connected(_on_ui_resized):
		resized.connect(_on_ui_resized)


func _exit_tree() -> void:
	_release_ui_lock()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if cancel_confirm_dialog.visible:
			cancel_confirm_dialog.hide()
			pending_cancel_slot_index = -1
			pending_cancel_preview.clear()
			return
		if recipe_selector_dialog != null and recipe_selector_dialog.visible:
			recipe_selector_dialog.hide()
			return
		close()


func _setup_root_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	z_index = 400


func _setup_dimmer() -> void:
	var existing: ColorRect = get_node_or_null("Dimmer") as ColorRect
	if existing != null:
		dimmer = existing
	else:
		dimmer = ColorRect.new()
		dimmer.name = "Dimmer"
		add_child(dimmer)
		move_child(dimmer, 0)

	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.offset_left = 0
	dimmer.offset_top = 0
	dimmer.offset_right = 0
	dimmer.offset_bottom = 0
	dimmer.color = ROOT_DIMMER_COLOR
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	dimmer.z_index = -1


func _setup_main_panel() -> void:
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -MAIN_PANEL_SIZE.x * 0.5
	panel.offset_top = -MAIN_PANEL_SIZE.y * 0.5
	panel.offset_right = MAIN_PANEL_SIZE.x * 0.5
	panel.offset_bottom = MAIN_PANEL_SIZE.y * 0.5
	panel.size = MAIN_PANEL_SIZE
	panel.custom_minimum_size = MAIN_PANEL_SIZE
	panel.z_index = 1

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = MAIN_PANEL_BG
	style.border_color = MAIN_PANEL_BORDER
	style.corner_radius_top_left = PANEL_CORNER_RADIUS
	style.corner_radius_top_right = PANEL_CORNER_RADIUS
	style.corner_radius_bottom_right = PANEL_CORNER_RADIUS
	style.corner_radius_bottom_left = PANEL_CORNER_RADIUS
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", style)


func _setup_content_layout() -> void:
	root_vbox.anchor_left = 0
	root_vbox.anchor_top = 0
	root_vbox.anchor_right = 1
	root_vbox.anchor_bottom = 1
	root_vbox.offset_left = 24
	root_vbox.offset_top = 20
	root_vbox.offset_right = -24
	root_vbox.offset_bottom = -20
	root_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	root_vbox.add_theme_constant_override("separation", 10)

	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(0, 48)
	close_button.custom_minimum_size = Vector2(0, 40)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button.size_flags_vertical = Control.SIZE_SHRINK_END

	grid.columns = SLOT_COLUMNS_PER_PAGE
	grid.add_theme_constant_override("h_separation", GRID_H_SEPARATION)
	grid.add_theme_constant_override("v_separation", GRID_V_SEPARATION)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.custom_minimum_size = Vector2(
		SLOT_BUTTON_WIDTH * SLOT_COLUMNS_PER_PAGE + GRID_H_SEPARATION * max(SLOT_COLUMNS_PER_PAGE - 1, 0),
		_get_slot_cell_height() * SLOT_ROWS_PER_PAGE + GRID_V_SEPARATION * max(SLOT_ROWS_PER_PAGE - 1, 0)
	)

	plant_count_spinbox.custom_minimum_size = Vector2(0, 40)
	plant_count_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_option.visible = false
	recipe_option.custom_minimum_size = Vector2(0, 0)
	plant_button.custom_minimum_size = Vector2(0, 40)
	harvest_button.custom_minimum_size = Vector2(0, 40)
	cancel_button.custom_minimum_size = Vector2(0, 40)
	action_button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _on_ui_resized() -> void:
	_setup_main_panel()


func _ensure_page_controls() -> void:
	if root_vbox == null:
		return

	var existing_row: Node = root_vbox.get_node_or_null("PageNavigation")
	if existing_row is HBoxContainer:
		page_navigation_row = existing_row as HBoxContainer
	else:
		page_navigation_row = HBoxContainer.new()
		page_navigation_row.name = "PageNavigation"
		page_navigation_row.alignment = BoxContainer.ALIGNMENT_CENTER
		page_navigation_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var insert_index: int = action_button_row.get_index()
		root_vbox.add_child(page_navigation_row)
		root_vbox.move_child(page_navigation_row, insert_index)

	var existing_prev: Node = page_navigation_row.get_node_or_null("PrevPageButton")
	if existing_prev is Button:
		prev_page_button = existing_prev as Button
	else:
		prev_page_button = Button.new()
		prev_page_button.name = "PrevPageButton"
		prev_page_button.text = "← 前へ"
		page_navigation_row.add_child(prev_page_button)

	var existing_label: Node = page_navigation_row.get_node_or_null("PageLabel")
	if existing_label is Label:
		page_label = existing_label as Label
	else:
		page_label = Label.new()
		page_label.name = "PageLabel"
		page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_navigation_row.add_child(page_label)

	var existing_next: Node = page_navigation_row.get_node_or_null("NextPageButton")
	if existing_next is Button:
		next_page_button = existing_next as Button
	else:
		next_page_button = Button.new()
		next_page_button.name = "NextPageButton"
		next_page_button.text = "次へ →"
		page_navigation_row.add_child(next_page_button)

	if not prev_page_button.pressed.is_connected(_on_prev_page_pressed):
		prev_page_button.pressed.connect(_on_prev_page_pressed)
	if not next_page_button.pressed.is_connected(_on_next_page_pressed):
		next_page_button.pressed.connect(_on_next_page_pressed)


func _ensure_unlock_slot_button_row() -> void:
	if root_vbox == null or action_button_row == null:
		return

	var existing_row: Node = root_vbox.get_node_or_null("UnlockSlotButtonRow")
	if existing_row is HBoxContainer:
		unlock_slot_button_row = existing_row as HBoxContainer
	else:
		unlock_slot_button_row = HBoxContainer.new()
		unlock_slot_button_row.name = "UnlockSlotButtonRow"
		unlock_slot_button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unlock_slot_button_row.alignment = BoxContainer.ALIGNMENT_END
		root_vbox.add_child(unlock_slot_button_row)

	var target_index: int = action_button_row.get_index() + 1
	if unlock_slot_button_row.get_index() != target_index:
		root_vbox.move_child(unlock_slot_button_row, target_index)


func _ensure_unlock_slot_button() -> void:
	if unlock_slot_button_row == null:
		return

	var existing: Node = unlock_slot_button_row.get_node_or_null("UnlockSlotButton")
	if existing is Button:
		unlock_slot_button = existing as Button
	else:
		unlock_slot_button = Button.new()
		unlock_slot_button.name = "UnlockSlotButton"
		unlock_slot_button.text = "スロット解放"
		unlock_slot_button.custom_minimum_size = Vector2(0, 40)
		unlock_slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		unlock_slot_button_row.add_child(unlock_slot_button)

	if not unlock_slot_button.pressed.is_connected(_on_unlock_slot_pressed):
		unlock_slot_button.pressed.connect(_on_unlock_slot_pressed)

func _ensure_recipe_selector_row() -> void:
	if root_vbox == null or recipe_option == null:
		return

	var existing_row: Node = root_vbox.get_node_or_null("RecipeSelectorRow")
	if existing_row is HBoxContainer:
		recipe_selector_row = existing_row as HBoxContainer
	else:
		recipe_selector_row = HBoxContainer.new()
		recipe_selector_row.name = "RecipeSelectorRow"
		recipe_selector_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_selector_row.add_theme_constant_override("separation", 12)
		root_vbox.add_child(recipe_selector_row)

	var target_index: int = recipe_option.get_index()
	if recipe_selector_row.get_index() != target_index:
		root_vbox.move_child(recipe_selector_row, target_index)

	var existing_label: Node = recipe_selector_row.get_node_or_null("RecipeSelectorSummaryLabel")
	if existing_label is Label:
		recipe_selector_summary_label = existing_label as Label
	else:
		recipe_selector_summary_label = Label.new()
		recipe_selector_summary_label.name = "RecipeSelectorSummaryLabel"
		recipe_selector_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_selector_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		recipe_selector_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		recipe_selector_row.add_child(recipe_selector_summary_label)

	var existing_button: Node = recipe_selector_row.get_node_or_null("RecipeSelectorButton")
	if existing_button is Button:
		recipe_selector_button = existing_button as Button
	else:
		recipe_selector_button = Button.new()
		recipe_selector_button.name = "RecipeSelectorButton"
		recipe_selector_button.text = "変更"
		recipe_selector_button.custom_minimum_size = Vector2(140, 40)
		recipe_selector_row.add_child(recipe_selector_button)

	if not recipe_selector_button.pressed.is_connected(_on_open_recipe_selector_pressed):
		recipe_selector_button.pressed.connect(_on_open_recipe_selector_pressed)

	_update_recipe_selector_summary()


func _ensure_recipe_selector_dialog() -> void:
	var existing_dialog: Node = get_node_or_null("RecipeSelectorDialog")
	if existing_dialog is CropRecipeSelectorDialog:
		recipe_selector_dialog = existing_dialog as CropRecipeSelectorDialog
	else:
		if existing_dialog != null:
			existing_dialog.queue_free()

		var dialog_scene: PackedScene = load(RECIPE_SELECTOR_DIALOG_SCENE_PATH) as PackedScene
		if dialog_scene == null:
			push_warning("CropRecipeSelectorDialog.tscn が見つからない: %s" % RECIPE_SELECTOR_DIALOG_SCENE_PATH)
			return

		recipe_selector_dialog = dialog_scene.instantiate() as CropRecipeSelectorDialog
		if recipe_selector_dialog == null:
			return

		recipe_selector_dialog.name = "RecipeSelectorDialog"
		add_child(recipe_selector_dialog)

	if not recipe_selector_dialog.recipe_selected.is_connected(_on_recipe_selector_recipe_selected):
		recipe_selector_dialog.recipe_selected.connect(_on_recipe_selector_recipe_selected)


func _ensure_bottom_spacer() -> void:
	if root_vbox == null or close_button == null:
		return

	var existing: Node = root_vbox.get_node_or_null("CloseButtonSpacer")
	if existing is Control:
		close_button_spacer = existing as Control
	else:
		close_button_spacer = Control.new()
		close_button_spacer.name = "CloseButtonSpacer"
		close_button_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		close_button_spacer.custom_minimum_size = Vector2(0, 0)
		root_vbox.add_child(close_button_spacer)

	var close_index: int = close_button.get_index()
	if close_button_spacer.get_index() != close_index - 1:
		root_vbox.move_child(close_button_spacer, close_index)


func _ensure_slot_upgrade_dialog() -> void:
	var existing_dialog: Node = get_node_or_null("SlotUpgradeDialog")
	if existing_dialog is AcceptDialog:
		slot_upgrade_dialog = existing_dialog as AcceptDialog
	else:
		slot_upgrade_dialog = AcceptDialog.new()
		slot_upgrade_dialog.name = "SlotUpgradeDialog"
		slot_upgrade_dialog.title = "スロット強化"
		add_child(slot_upgrade_dialog)

	slot_upgrade_dialog.exclusive = true
	slot_upgrade_dialog.dialog_hide_on_ok = true
	slot_upgrade_dialog.min_size = UPGRADE_DIALOG_SIZE
	slot_upgrade_dialog.size = UPGRADE_DIALOG_SIZE
	if slot_upgrade_dialog.get_ok_button() != null:
		slot_upgrade_dialog.get_ok_button().text = "閉じる"

	var body: VBoxContainer = slot_upgrade_dialog.get_node_or_null("Body") as VBoxContainer
	if body == null:
		for child in slot_upgrade_dialog.get_children():
			if child is Control and child != slot_upgrade_dialog.get_ok_button():
				child.queue_free()

		body = VBoxContainer.new()
		body.name = "Body"
		body.set_anchors_preset(Control.PRESET_FULL_RECT)
		body.offset_left = 16
		body.offset_top = 16
		body.offset_right = -16
		body.offset_bottom = -52
		body.add_theme_constant_override("separation", 10)
		slot_upgrade_dialog.add_child(body)

		slot_upgrade_title_label = Label.new()
		slot_upgrade_title_label.name = "UpgradeTitleLabel"
		slot_upgrade_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_upgrade_title_label.add_theme_font_size_override("font_size", 20)
		body.add_child(slot_upgrade_title_label)

		slot_upgrade_info_label = Label.new()
		slot_upgrade_info_label.name = "UpgradeInfoLabel"
		slot_upgrade_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot_upgrade_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(slot_upgrade_info_label)

		var placeholder_header: Label = Label.new()
		placeholder_header.text = "強化項目"
		body.add_child(placeholder_header)

		for feature_name in ["成長速度", "収穫量", "品質補正"]:
			var row: HBoxContainer = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			body.add_child(row)

			var name_label: Label = Label.new()
			name_label.text = feature_name
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)

			var state_button: Button = Button.new()
			state_button.text = "準備中"
			state_button.disabled = true
			state_button.custom_minimum_size = Vector2(120, 32)
			row.add_child(state_button)
	else:
		slot_upgrade_title_label = body.get_node_or_null("UpgradeTitleLabel") as Label
		slot_upgrade_info_label = body.get_node_or_null("UpgradeInfoLabel") as Label


func _ensure_slot_grid_module() -> void:
	if slot_grid_module != null:
		return
	slot_grid_module = CropMachineSlotGridModule.new()
	slot_grid_module.setup(self)


func _get_slot_cell_height() -> int:
	if slot_grid_module != null:
		return slot_grid_module.get_slot_cell_height()
	return SLOT_BUTTON_HEIGHT + SLOT_CELL_SEPARATION + SLOT_UPGRADE_BUTTON_HEIGHT


func open_machine(machine: CropMachine, player: Node) -> void:
	current_machine = machine
	current_player = player
	pending_cancel_slot_index = -1
	pending_cancel_preview.clear()

	if current_machine != null and current_machine.slots.size() > 0:
		selected_slot_index = clamp(selected_slot_index, 0, current_machine.slots.size() - 1)
		if selected_slot_index < 0:
			selected_slot_index = 0
	else:
		selected_slot_index = -1

	if slot_grid_module != null:
		slot_grid_module.sync_page_to_selected_slot()
	visible = true
	move_to_front()
	_acquire_ui_lock()
	refresh()


func close() -> void:
	_release_ui_lock()
	visible = false
	current_machine = null
	current_player = null
	selected_slot_index = -1
	selected_recipe_key = ""
	current_page_index = 0
	pending_cancel_slot_index = -1
	pending_cancel_preview.clear()
	cancel_confirm_dialog.hide()
	if recipe_selector_dialog != null:
		recipe_selector_dialog.reset_selector_state()
	info_label.text = ""
	_update_recipe_selector_summary()


func refresh() -> void:
	if current_machine == null:
		return

	grid.columns = SLOT_COLUMNS_PER_PAGE
	title_label.text = "%s  (%d / %d スロット)" % [
		current_machine.machine_name,
		current_machine.get_unlocked_slot_count(),
		current_machine.get_max_slot_count()
	]
	_refresh_recipe_options()

	if slot_grid_module != null:
		slot_grid_module.refresh_slot_grid()
	else:
		_update_selected_slot_info()
		_update_action_buttons()


func _format_slot_text_for_ui(slot_text: String) -> String:
	if slot_grid_module != null:
		return slot_grid_module.format_slot_text_for_ui(slot_text)
	return slot_text


func _make_slot_stylebox(is_selected: bool, is_hover: bool, has_icon: bool = false) -> StyleBoxFlat:
	if slot_grid_module != null:
		return slot_grid_module.make_slot_stylebox(is_selected, is_hover, has_icon)

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = SLOT_CORNER_RADIUS
	style.corner_radius_top_right = SLOT_CORNER_RADIUS
	style.corner_radius_bottom_right = SLOT_CORNER_RADIUS
	style.corner_radius_bottom_left = SLOT_CORNER_RADIUS
	style.content_margin_left = 12
	style.content_margin_top = SLOT_CONTENT_TOP_WITH_ICON if has_icon else 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	return style


func _add_slot_icon(button: Button, icon_texture: Texture2D) -> void:
	if slot_grid_module != null:
		slot_grid_module.add_slot_icon(button, icon_texture)


func _get_total_pages(total_slots: int) -> int:
	if slot_grid_module != null:
		return slot_grid_module.get_total_pages(total_slots)
	if total_slots <= 0:
		return 1
	return int(ceil(float(total_slots) / float(SLOTS_PER_PAGE)))


func _sync_page_to_selected_slot(total_slots: int = -1) -> void:
	if slot_grid_module != null:
		slot_grid_module.sync_page_to_selected_slot(total_slots)


func _select_first_slot_on_current_page() -> void:
	if slot_grid_module != null:
		slot_grid_module.select_first_slot_on_current_page()


func _update_page_controls(total_slots: int) -> void:
	if slot_grid_module != null:
		slot_grid_module.update_page_controls(total_slots)


func _on_prev_page_pressed() -> void:
	if slot_grid_module != null:
		slot_grid_module.on_prev_page_pressed()


func _on_next_page_pressed() -> void:
	if slot_grid_module != null:
		slot_grid_module.on_next_page_pressed()


func _refresh_recipe_options() -> void:
	var previous_key: String = selected_recipe_key
	var first_valid_key: String = ""
	var has_previous_key: bool = false

	if current_machine != null:
		for recipe in current_machine.available_recipes:
			if recipe == null or not recipe.is_valid_recipe():
				continue

			var recipe_key: String = _get_recipe_key(recipe)
			if first_valid_key.is_empty():
				first_valid_key = recipe_key
			if recipe_key == previous_key:
				has_previous_key = true

	selected_recipe_key = previous_key if has_previous_key else first_valid_key
	_update_recipe_selector_summary()
	_refresh_recipe_selector_dialog()


func _build_recipe_option_text(recipe: CropRecipe) -> String:
	var seed_name: String = "種"
	if recipe.seed_item != null:
		if not recipe.seed_item.item_name.is_empty():
			seed_name = recipe.seed_item.item_name
		else:
			seed_name = str(recipe.seed_item.id)
	return "%s（種: %s / %d分 / 収穫%d個 / EXP+%d）" % [recipe.get_display_name(), seed_name, recipe.grow_minutes, recipe.harvest_amount, _get_recipe_farming_exp_per_cycle(recipe)]


func _get_recipe_key(recipe: CropRecipe) -> String:
	if recipe == null:
		return ""
	if not recipe.resource_path.is_empty():
		return recipe.resource_path
	if not str(recipe.id).is_empty():
		return str(recipe.id)
	return recipe.get_display_name()


func _find_recipe_by_key(recipe_key: String) -> CropRecipe:
	if current_machine == null or recipe_key.is_empty():
		return null

	for recipe in current_machine.available_recipes:
		if recipe == null or not recipe.is_valid_recipe():
			continue
		if _get_recipe_key(recipe) == recipe_key:
			return recipe

	return null


func _set_selected_recipe_by_key(recipe_key: String) -> void:
	var recipe: CropRecipe = _find_recipe_by_key(recipe_key)
	selected_recipe_key = _get_recipe_key(recipe) if recipe != null else ""

	_update_recipe_selector_summary()
	_refresh_recipe_selector_dialog()
	if visible:
		_update_selected_slot_info()
		_update_action_buttons()


func _update_recipe_selector_summary() -> void:
	if recipe_selector_summary_label == null:
		return

	var recipe: CropRecipe = _get_selected_recipe()
	if recipe == null:
		recipe_selector_summary_label.text = "植え付ける作物: 未選択"
		if recipe_selector_button != null:
			recipe_selector_button.disabled = current_machine == null or current_machine.available_recipes.is_empty()
		return

	recipe_selector_summary_label.text = "植え付ける作物: %s" % _build_recipe_option_text(recipe)
	if recipe_selector_button != null:
		recipe_selector_button.disabled = false


func _on_open_recipe_selector_pressed() -> void:
	_open_recipe_selector_dialog()


func _open_recipe_selector_dialog() -> void:
	if recipe_selector_dialog == null or current_machine == null:
		return

	_refresh_recipe_selector_dialog()
	recipe_selector_dialog.open_selector()


func _refresh_recipe_selector_dialog() -> void:
	if recipe_selector_dialog == null:
		return

	var recipes: Array = []
	if current_machine != null:
		recipes = current_machine.available_recipes

	recipe_selector_dialog.configure_selector(
		recipes,
		selected_recipe_key,
		Callable(self, "_get_player_item_count"),
		Callable(self, "_get_recipe_farming_exp_per_cycle")
	)


func _on_recipe_selector_recipe_selected(recipe_key: String) -> void:
	_set_selected_recipe_by_key(recipe_key)


func _get_player_item_count(item_data: ItemData) -> int:
	if item_data == null:
		return -1

	var targets: Array[Node] = _collect_item_count_targets()
	var method_names: Array[String] = [
		"get_item_count_by_data",
		"get_item_count",
		"get_inventory_item_count",
		"get_item_quantity",
		"count_item_in_inventory",
		"get_total_item_count"
	]

	var best_result: int = -1
	for target in targets:
		for method_name in method_names:
			var result: int = _call_item_count_method(target, method_name, item_data)
			if result > 0:
				return result
			if result == 0:
				best_result = 0

	return best_result


func _collect_item_count_targets() -> Array[Node]:
	var targets: Array[Node] = []
	_append_item_count_target(targets, current_player)

	if current_player != null:
		for property_name in ["inventory_ui", "inventory", "inventory_manager"]:
			var value: Variant = current_player.get(property_name)
			if value is Node:
				_append_item_count_target(targets, value as Node)

	var inventory_ui: Node = get_tree().get_first_node_in_group("inventory_ui")
	_append_item_count_target(targets, inventory_ui)

	return targets


func _append_item_count_target(targets: Array[Node], target: Node) -> void:
	if target == null:
		return
	if targets.has(target):
		return
	targets.append(target)


func _call_item_count_method(target: Node, method_name: String, item_data: ItemData) -> int:
	if target == null or item_data == null:
		return -1
	if not target.has_method(method_name):
		return -1

	var attempts: Array = []
	match method_name:
		"get_item_count_by_data":
			attempts.append(item_data)
		"get_item_count", "get_inventory_item_count", "get_item_quantity", "count_item_in_inventory", "get_total_item_count":
			if not str(item_data.id).is_empty():
				attempts.append(StringName(item_data.id))
			if not item_data.resource_path.is_empty():
				attempts.append(item_data.resource_path)
			if not item_data.item_name.is_empty():
				attempts.append(item_data.item_name)
		_:
			attempts.append(item_data)
			if not str(item_data.id).is_empty():
				attempts.append(StringName(item_data.id))
			if not item_data.resource_path.is_empty():
				attempts.append(item_data.resource_path)
			if not item_data.item_name.is_empty():
				attempts.append(item_data.item_name)

	var best_numeric_result: int = -1
	for arg in attempts:
		var value: Variant = target.call(method_name, arg)
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			best_numeric_result = max(best_numeric_result, max(int(value), 0))
			if int(value) > 0:
				return int(value)

	return best_numeric_result


func _update_selected_slot_info() -> void:
	if current_machine == null:
		info_label.text = ""
		return
	if selected_slot_index < 0:
		info_label.text = "スロット未選択"
		return

	var recipe: CropRecipe = _get_selected_recipe()
	var plant_count: int = int(plant_count_spinbox.value)

	if current_machine.is_slot_empty(selected_slot_index):
		if recipe == null:
			info_label.text = "空きスロット。植え付けレシピを選んでくれ。"
		else:
			info_label.text = "空きスロット。%sを %d 回連続で植え付けできる。" % [recipe.get_display_name(), plant_count]
		return

	var display_name: String = current_machine.get_slot_display_name(selected_slot_index)
	var queued_count: int = current_machine.get_slot_queued_count(selected_slot_index)
	var ready_count: int = current_machine.get_slot_ready_count(selected_slot_index)
	var harvest_total: int = ready_count * current_machine.get_slot_harvest_amount(selected_slot_index)
	var base_text: String = ""
	if queued_count > 0:
		base_text = "%s：進行中 %d 回 / 収穫待ち %d 回（今取ると %d 個、キャンセルで未完了の種 %d 個返却）" % [display_name, queued_count, ready_count, harvest_total, queued_count]
	else:
		base_text = "%s：収穫待ち %d 回（今取ると %d 個）" % [display_name, ready_count, harvest_total]

	if recipe == null:
		info_label.text = base_text
		return

	if current_machine.can_stack_recipe(selected_slot_index, recipe):
		info_label.text = "%s\n同じ作物なので %d 回分を追加投入できる。" % [base_text, plant_count]
	else:
		info_label.text = "%s\n使用中スロットには同じ作物だけ追加投入できる。" % [base_text]


func _update_action_buttons() -> void:
	var can_plant: bool = false
	var can_harvest: bool = false
	var can_cancel: bool = false
	plant_button.text = "植え付け"

	if current_machine != null and selected_slot_index >= 0:
		var recipe: CropRecipe = _get_selected_recipe()
		can_harvest = current_machine.is_slot_ready(selected_slot_index)
		can_cancel = not current_machine.is_slot_empty(selected_slot_index)

		if recipe != null and current_machine.can_plant_recipe_in_slot(selected_slot_index, recipe):
			can_plant = true
			if not current_machine.is_slot_empty(selected_slot_index):
				plant_button.text = "追加投入"

	plant_button.disabled = not can_plant
	harvest_button.disabled = not can_harvest
	cancel_button.disabled = not can_cancel

	if unlock_slot_button != null:
		if current_machine == null:
			unlock_slot_button.text = "スロット解放"
			unlock_slot_button.disabled = true
		elif not current_machine.can_unlock_slot():
			unlock_slot_button.text = "最大まで解放済み"
			unlock_slot_button.disabled = true
		else:
			var unlock_cost: int = current_machine.get_next_slot_unlock_cost()
			unlock_slot_button.text = "スロット解放 (%d Cr)" % unlock_cost
			unlock_slot_button.disabled = current_player == null or not _can_player_spend_credits(unlock_cost)


func _get_selected_recipe() -> CropRecipe:
	if current_machine == null:
		return null

	if not selected_recipe_key.is_empty():
		var selected_recipe: CropRecipe = _find_recipe_by_key(selected_recipe_key)
		if selected_recipe != null:
			return selected_recipe

	for recipe in current_machine.available_recipes:
		if recipe != null and recipe.is_valid_recipe():
			return recipe

	return null


func _on_slot_pressed(index: int) -> void:
	if slot_grid_module != null:
		slot_grid_module.on_slot_pressed(index)
		return
	selected_slot_index = index
	refresh()


func _on_plant_count_changed(_value: float) -> void:
	if visible:
		_update_selected_slot_info()
		_update_action_buttons()



func _on_plant_pressed() -> void:
	if current_machine == null or current_player == null or selected_slot_index < 0:
		return

	var recipe: CropRecipe = _get_selected_recipe()
	if recipe == null:
		info_label.text = "植え付けレシピがない"
		return
	if recipe.seed_item == null:
		info_label.text = "種アイテムが未設定"
		return
	if not current_machine.can_plant_recipe_in_slot(selected_slot_index, recipe):
		info_label.text = "使用中スロットには同じ作物だけ追加投入できる"
		return

	var plant_count: int = max(int(plant_count_spinbox.value), 1)
	var removed_ok: bool = bool(current_player.call("remove_item_from_inventory", recipe.seed_item, plant_count))
	if not removed_ok:
		info_label.text = "必要な種が %d 個 足りない" % plant_count
		return

	var was_empty: bool = current_machine.is_slot_empty(selected_slot_index)
	var planted: bool = current_machine.plant_slot(selected_slot_index, recipe, plant_count)
	if not planted:
		current_player.call("add_item_to_inventory", recipe.seed_item, plant_count)
		info_label.text = "植え付けできなかった"
		return

	if was_empty:
		info_label.text = "%sを %d 回分 セットした" % [recipe.get_display_name(), plant_count]
		_log_system("%sのスロット%dに%sを %d 回分 セットした" % [current_machine.machine_name, selected_slot_index + 1, recipe.get_display_name(), plant_count])
	else:
		info_label.text = "%sを %d 回分 追加投入した" % [recipe.get_display_name(), plant_count]
		_log_system("%sのスロット%dに%sを %d 回分 追加投入した" % [current_machine.machine_name, selected_slot_index + 1, recipe.get_display_name(), plant_count])
	refresh()


func _build_item_quality_text(item_data: ItemData) -> String:
	if item_data == null:
		return "品質0 / ☆☆☆☆☆"
	return "品質%d / %s" % [item_data.get_quality(), item_data.get_rank_stars()]


func _on_harvest_pressed() -> void:
	if current_machine == null or current_player == null or selected_slot_index < 0:
		return

	var before_name: String = current_machine.get_slot_display_name(selected_slot_index)
	var result: Dictionary = current_machine.harvest_slot(selected_slot_index)
	if not bool(result.get("success", false)):
		info_label.text = "まだ収穫できない"
		return

	var item_data: ItemData = result.get("item_data", null) as ItemData
	var amount: int = int(result.get("amount", 0))
	var ready_cycles: int = int(result.get("ready_cycles", 0))
	if item_data == null or amount <= 0 or ready_cycles <= 0:
		info_label.text = "収穫データが不正"
		return

	var add_ok: bool = bool(current_player.call("add_item_to_inventory", item_data, amount))
	if not add_ok:
		info_label.text = "インベントリに入れられない"
		return

	_grant_farming_harvest_exp_for_slot(selected_slot_index, ready_cycles)

	var quality_text: String = _build_item_quality_text(item_data)
	info_label.text = "%sを %d 回分 収穫して %d 個受け取った（%s）" % [before_name, ready_cycles, amount, quality_text]
	_log_system("%sのスロット%dから%sを %d 回分収穫して %d 個受け取った（%s）" % [current_machine.machine_name, selected_slot_index + 1, before_name, ready_cycles, amount, quality_text])
	refresh()


func _on_cancel_pressed() -> void:
	if current_machine == null or current_player == null or selected_slot_index < 0:
		return

	var preview: Dictionary = current_machine.get_slot_cancel_preview(selected_slot_index)
	if not bool(preview.get("success", false)):
		info_label.text = "キャンセルできる栽培がない"
		return

	pending_cancel_slot_index = selected_slot_index
	pending_cancel_preview = preview
	cancel_confirm_dialog.dialog_text = _build_cancel_confirm_text(preview)
	cancel_confirm_dialog.popup_centered()


func _build_cancel_confirm_text(preview: Dictionary) -> String:
	var display_name: String = str(preview.get("display_name", "作物"))
	var ready_cycles: int = int(preview.get("ready_cycles", 0))
	var ready_amount: int = int(preview.get("ready_amount", 0))
	var return_seed_count: int = int(preview.get("return_seed_count", 0))
	var lines: PackedStringArray = []
	lines.append("%s の栽培をキャンセルする。" % display_name)
	if ready_cycles > 0 and ready_amount > 0:
		var ready_quality: int = int(preview.get("ready_quality", 0))
		var ready_rank: int = int(preview.get("ready_rank", 0))
		var star_text: String = "☆☆☆☆☆"
		if ready_rank > 0:
			star_text = ""
			for i in range(ready_rank):
				star_text += "★"
			for i in range(5 - ready_rank):
				star_text += "☆"
		lines.append("完了分: %d 回分 → 収穫物 %d 個を受け取る（品質%d / %s）" % [ready_cycles, ready_amount, ready_quality, star_text])
	if return_seed_count > 0:
		lines.append("未完了分: %d 回分 → 種 %d 個が戻る" % [return_seed_count, return_seed_count])
	lines.append("本当にキャンセルしていいか？")
	return "\n".join(lines)


func _on_cancel_confirmed() -> void:
	if current_machine == null or current_player == null or pending_cancel_slot_index < 0:
		return

	var target_slot_index: int = pending_cancel_slot_index
	var preview: Dictionary = pending_cancel_preview.duplicate(true)
	pending_cancel_slot_index = -1
	pending_cancel_preview.clear()
	if not bool(preview.get("success", false)):
		info_label.text = "キャンセルできなかった"
		refresh()
		return

	var ready_item_data: ItemData = preview.get("ready_item_data", null) as ItemData
	var ready_amount: int = int(preview.get("ready_amount", 0))
	var ready_cycles: int = int(preview.get("ready_cycles", 0))
	var seed_item_data: ItemData = preview.get("seed_item_data", null) as ItemData
	var return_seed_count: int = int(preview.get("return_seed_count", 0))
	var display_name: String = str(preview.get("display_name", "作物"))
	var ready_quality_text: String = _build_item_quality_text(ready_item_data)

	if ready_amount > 0 and ready_item_data != null:
		var add_harvest_ok: bool = bool(current_player.call("add_item_to_inventory", ready_item_data, ready_amount))
		if not add_harvest_ok:
			info_label.text = "完了分の収穫物をインベントリに入れられない"
			refresh()
			return

	if return_seed_count > 0 and seed_item_data != null:
		var add_seed_ok: bool = bool(current_player.call("add_item_to_inventory", seed_item_data, return_seed_count))
		if not add_seed_ok:
			if ready_amount > 0 and ready_item_data != null:
				current_player.call("remove_item_from_inventory", ready_item_data, ready_amount)
			info_label.text = "未完了分の種をインベントリに戻せない"
			refresh()
			return

	if ready_cycles > 0 and ready_amount > 0:
		_grant_farming_harvest_exp_for_slot(target_slot_index, ready_cycles)

	current_machine.clear_slot(target_slot_index)

	var parts: PackedStringArray = []
	if ready_cycles > 0 and ready_amount > 0:
		parts.append("完了分 %d 回分を収穫して %d 個受け取った（%s）" % [ready_cycles, ready_amount, ready_quality_text])
	if return_seed_count > 0:
		parts.append("未完了分の種 %d 個を戻した" % return_seed_count)
	if parts.is_empty():
		parts.append("キャンセルした")

	info_label.text = "%sをキャンセルした。%s" % [display_name, "、".join(parts)]
	_log_system("%sのスロット%dの%sをキャンセルした。%s" % [current_machine.machine_name, target_slot_index + 1, display_name, "、".join(parts)])
	refresh()


func _get_player_credits() -> int:
	if current_player == null:
		return 0
	if current_player.has_method("get_credits"):
		return int(current_player.call("get_credits"))
	if current_player.has_method("getCredit"):
		return int(current_player.call("getCredit"))
	return 0


func _can_player_spend_credits(amount: int) -> bool:
	if amount <= 0:
		return true
	if current_player == null:
		return false
	if current_player.has_method("can_spend_credits"):
		return bool(current_player.call("can_spend_credits", amount))
	if current_player.has_method("get_credits"):
		return int(current_player.call("get_credits")) >= amount
	if current_player.has_method("getCredit"):
		return int(current_player.call("getCredit")) >= amount
	return false


func _spend_player_credits(amount: int) -> bool:
	if amount <= 0:
		return true
	if current_player == null:
		return false
	if current_player.has_method("spend_credits"):
		return bool(current_player.call("spend_credits", amount))
	if current_player.has_method("spendCredit"):
		return bool(current_player.call("spendCredit", amount))
	return false


func _refund_player_credits(amount: int) -> void:
	if amount <= 0:
		return
	if current_player == null:
		return
	if current_player.has_method("add_credits"):
		current_player.call("add_credits", amount)
	elif current_player.has_method("addCredit"):
		current_player.call("addCredit", amount)


func _on_unlock_slot_pressed() -> void:
	if current_machine == null or current_player == null:
		return
	if not current_machine.can_unlock_slot():
		info_label.text = "これ以上スロットを増やせない"
		_update_action_buttons()
		return

	var unlock_cost: int = current_machine.get_next_slot_unlock_cost()
	var next_slot_number: int = current_machine.get_unlocked_slot_count() + 1
	if not _can_player_spend_credits(unlock_cost):
		info_label.text = "クレジットが足りない（必要: %d Cr / 所持: %d Cr）" % [unlock_cost, _get_player_credits()]
		_update_action_buttons()
		return

	if not _spend_player_credits(unlock_cost):
		info_label.text = "クレジットの支払いに失敗した"
		_update_action_buttons()
		return

	var unlocked: bool = current_machine.unlock_slot()
	if not unlocked:
		_refund_player_credits(unlock_cost)
		info_label.text = "スロット解放に失敗した"
		_update_action_buttons()
		return

	selected_slot_index = current_machine.get_unlocked_slot_count() - 1
	info_label.text = "スロット%dを解放した（-%d Cr）" % [next_slot_number, unlock_cost]
	_log_system("%sのスロット%dを %d Cr で解放した" % [current_machine.machine_name, next_slot_number, unlock_cost])
	refresh()


func _on_open_slot_upgrade_pressed(slot_index: int) -> void:
	if current_machine == null or slot_upgrade_dialog == null:
		return
	if slot_index < 0 or slot_index >= current_machine.slots.size():
		return

	slot_upgrade_slot_index = slot_index
	var display_name: String = current_machine.get_slot_display_name(slot_index)
	if display_name.is_empty():
		display_name = "空きスロット"

	if slot_upgrade_title_label != null:
		slot_upgrade_title_label.text = "スロット%d 強化" % [slot_index + 1]

	if slot_upgrade_info_label != null:
		var lines: PackedStringArray = []
		lines.append("対象: スロット%d" % [slot_index + 1])
		lines.append("状態: %s" % display_name)
		if current_machine.is_slot_empty(slot_index):
			lines.append("現在は空きスロット。")
		else:
			lines.append("進行中: %d 回" % current_machine.get_slot_queued_count(slot_index))
			lines.append("収穫待ち: %d 回" % current_machine.get_slot_ready_count(slot_index))
		lines.append("")
		lines.append("この画面に各スロット専用の強化項目を追加できる。")
		lines.append("強化効果と価格ルールは次の段階で接続可能。")
		slot_upgrade_info_label.text = "\n".join(lines)

	slot_upgrade_dialog.popup_centered()


func _on_close_pressed() -> void:
	close()


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


func _get_player_stats_manager() -> Node:
	return get_node_or_null("/root/PlayerStatsManager")


func _get_recipe_farming_exp_per_cycle(recipe: CropRecipe) -> int:
	if recipe == null:
		return DEFAULT_FARMING_EXP_PER_HARVEST_CYCLE
	return max(int(recipe.farming_exp_per_harvest_cycle), 0)


func _find_recipe_for_slot(slot_index: int) -> CropRecipe:
	if current_machine == null:
		return null
	if slot_index < 0 or slot_index >= current_machine.slots.size():
		return null

	var slot: Dictionary = current_machine.slots[slot_index]
	var slot_recipe_key: String = str(slot.get("recipe_key", ""))
	var slot_display_name: String = str(slot.get("display_name", ""))

	for recipe in current_machine.available_recipes:
		if recipe == null:
			continue
		if _get_recipe_key(recipe) == slot_recipe_key:
			return recipe

	for recipe in current_machine.available_recipes:
		if recipe == null:
			continue
		if recipe.get_display_name() == slot_display_name:
			return recipe

	return null


func _grant_farming_harvest_exp_for_slot(slot_index: int, harvest_cycles: int) -> void:
	if harvest_cycles <= 0:
		return

	var stats_manager: Node = _get_player_stats_manager()
	if stats_manager == null:
		return
	if not stats_manager.has_method("gain_skill_exp"):
		return

	var recipe: CropRecipe = _find_recipe_for_slot(slot_index)
	var exp_per_cycle: int = _get_recipe_farming_exp_per_cycle(recipe)
	var exp_gain: int = harvest_cycles * exp_per_cycle
	if exp_gain <= 0:
		return

	stats_manager.call("gain_skill_exp", FARMING_SKILL_NAME, exp_gain)
	_log_system("農業経験値 +%d" % exp_gain)


func _get_message_log() -> Node:
	return get_node_or_null("/root/MessageLog")


func _log_system(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_system"):
		log_node.call("add_system", text)

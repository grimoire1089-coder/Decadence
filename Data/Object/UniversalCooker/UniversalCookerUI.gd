extends Control
class_name UniversalCookerUI

const UI_LOCK_SOURCE: String = "万能調理器UI"
const UI_MODAL_MANAGER_SCRIPT_NAME: String = "UIModalManager.gd"
const TIME_MANAGER_SCRIPT_NAME: String = "TimeManager.gd"
const COOKING_SKILL_NAME: String = "cooking"
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
const PANEL_TARGET_WIDTH: float = 960.0
const PANEL_TARGET_HEIGHT: float = 800.0
const PANEL_MIN_VIEWPORT_MARGIN: float = 40.0
const PANEL_MIN_HEIGHT: float = 760.0
const GRID_RESERVED_ROWS: int = 2
const INGREDIENT_SLOT_WIDTH: int = 180
const INGREDIENT_SLOT_HEIGHT: int = 92
const INGREDIENT_GRID_RESERVED_ROWS: int = 2


var current_machine: UniversalCooker = null
var current_player: Node = null
var selected_slot_index: int = -1
var selected_recipe_key: String = ""
var pending_discard_slot_index: int = -1
var pending_discard_preview: Dictionary = {}
var prepared_assignments: Array[Dictionary] = []
var prepared_context_slot_index: int = -1
var prepared_context_recipe_key: String = ""
var prepared_context_craft_count: int = 0

@onready var panel: Panel = get_node_or_null("Panel") as Panel
@onready var root_vbox: VBoxContainer = get_node_or_null("Panel/VBoxContainer") as VBoxContainer
@onready var title_label: Label = get_node_or_null("Panel/VBoxContainer/TitleLabel") as Label
@onready var slots_center: CenterContainer = get_node_or_null("Panel/VBoxContainer/SlotsCenter") as CenterContainer
@onready var grid: GridContainer = (get_node_or_null("Panel/VBoxContainer/SlotsCenter/GridContainer") as GridContainer) if has_node("Panel/VBoxContainer/SlotsCenter/GridContainer") else (get_node_or_null("Panel/VBoxContainer/GridContainer") as GridContainer)
@onready var ingredient_section: VBoxContainer = get_node_or_null("Panel/VBoxContainer/IngredientSection") as VBoxContainer
@onready var ingredient_label: Label = (get_node_or_null("Panel/VBoxContainer/IngredientSection/IngredientLabel") as Label) if has_node("Panel/VBoxContainer/IngredientSection/IngredientLabel") else (get_node_or_null("Panel/VBoxContainer/IngredientSection/IngredientTitleLabel") as Label)
@onready var ingredient_center: CenterContainer = get_node_or_null("Panel/VBoxContainer/IngredientSection/IngredientCenter") as CenterContainer
@onready var recipe_option: OptionButton = get_node_or_null("Panel/VBoxContainer/RecipeOptionButton") as OptionButton
@onready var craft_count_spinbox: SpinBox = get_node_or_null("Panel/VBoxContainer/CraftCountHBox/CraftCountSpinBox") as SpinBox
@onready var start_button: Button = get_node_or_null("Panel/VBoxContainer/HBoxContainer/StartButton") as Button
@onready var collect_button: Button = get_node_or_null("Panel/VBoxContainer/HBoxContainer/CollectButton") as Button
@onready var discard_button: Button = get_node_or_null("Panel/VBoxContainer/HBoxContainer/DiscardButton") as Button
@onready var info_label: Label = get_node_or_null("Panel/VBoxContainer/InfoLabel") as Label
@onready var close_button: Button = get_node_or_null("Panel/VBoxContainer/CloseButton") as Button
@onready var discard_confirm_dialog: ConfirmationDialog = get_node_or_null("DiscardConfirmDialog") as ConfirmationDialog
@onready var ingredient_slots_center: CenterContainer = get_node_or_null("Panel/VBoxContainer/IngredientSection/IngredientSlotsCenter") as CenterContainer
@onready var ingredient_slots_container: HBoxContainer = get_node_or_null("Panel/VBoxContainer/IngredientSection/IngredientSlotsCenter/IngredientSlotsContainer") as HBoxContainer


func _ready() -> void:
	visible = false
	add_to_group("universal_cooker_ui")

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_root_resized)
	call_deferred("_apply_panel_layout")
	if craft_count_spinbox != null:
		craft_count_spinbox.min_value = 1
		craft_count_spinbox.max_value = 999
		craft_count_spinbox.step = 1
		craft_count_spinbox.value = 1
		craft_count_spinbox.rounded = true

	if start_button != null:
		start_button.pressed.connect(_on_start_pressed)
	if collect_button != null:
		collect_button.pressed.connect(_on_collect_pressed)
	if discard_button != null:
		discard_button.pressed.connect(_on_discard_pressed)
	if close_button != null:
		close_button.pressed.connect(_on_close_pressed)
	if craft_count_spinbox != null:
		craft_count_spinbox.value_changed.connect(_on_craft_count_changed)
	if recipe_option != null:
		recipe_option.item_selected.connect(_on_recipe_selected)
	if discard_confirm_dialog != null:
		discard_confirm_dialog.confirmed.connect(_on_discard_confirmed)




func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		call_deferred("_apply_panel_layout")


func _on_root_resized() -> void:
	_apply_panel_layout()


func _apply_panel_layout() -> void:
	if panel == null or grid == null:
		return

	var viewport_size: Vector2 = get_viewport_rect().size
	var max_width: float = max(900.0, viewport_size.x - PANEL_MIN_VIEWPORT_MARGIN * 2.0)
	var max_height: float = max(PANEL_MIN_HEIGHT, viewport_size.y - PANEL_MIN_VIEWPORT_MARGIN * 2.0)
	var panel_width: float = min(PANEL_TARGET_WIDTH, max_width)
	var panel_height: float = min(PANEL_TARGET_HEIGHT, max_height)

	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.offset_left = -panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_bottom = panel_height * 0.5

	if title_label != null:
		title_label.custom_minimum_size = Vector2(0, 30)

	if close_button != null:
		close_button.custom_minimum_size = Vector2(0, 42)

	if root_vbox != null:
		root_vbox.add_theme_constant_override("separation", 8)

	var row_gap: int = 12

	if grid != null:
		grid.custom_minimum_size.y = 128 * GRID_RESERVED_ROWS + row_gap * max(GRID_RESERVED_ROWS - 1, 0)

	if ingredient_slots_center != null:
		ingredient_slots_center.custom_minimum_size = Vector2(0, max(128.0, float(INGREDIENT_SLOT_HEIGHT)))


func _exit_tree() -> void:
	_release_ui_lock()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if discard_confirm_dialog != null and discard_confirm_dialog.visible:
			discard_confirm_dialog.hide()
			pending_discard_slot_index = -1
			pending_discard_preview.clear()
			return
		close()


func open_machine(machine: UniversalCooker, player: Node) -> void:
	current_machine = machine
	current_player = player
	pending_discard_slot_index = -1
	pending_discard_preview.clear()

	if current_machine != null and current_machine.slots.size() > 0:
		selected_slot_index = clamp(selected_slot_index, 0, current_machine.slots.size() - 1)
		if selected_slot_index < 0:
			selected_slot_index = 0
	else:
		selected_slot_index = -1

	visible = true
	_acquire_ui_lock()
	refresh()


func close() -> void:
	_release_ui_lock()
	visible = false
	current_machine = null
	current_player = null
	selected_slot_index = -1
	selected_recipe_key = ""
	pending_discard_slot_index = -1
	pending_discard_preview.clear()
	prepared_assignments.clear()
	prepared_context_slot_index = -1
	prepared_context_recipe_key = ""
	prepared_context_craft_count = 0
	if discard_confirm_dialog != null:
		discard_confirm_dialog.hide()
	if info_label != null:
		info_label.text = ""


func refresh() -> void:
	if current_machine == null:
		return

	title_label.text = "%s Lv.%d" % [current_machine.machine_name, current_machine.cooker_level]
	_refresh_recipe_options()

	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	var total_slots: int = current_machine.slots.size()
	if total_slots <= 0:
		selected_slot_index = -1
		if info_label != null:
			info_label.text = "スロットがない"
		_update_action_buttons()
		return

	selected_slot_index = clamp(selected_slot_index, 0, total_slots - 1)

	for i in range(total_slots):
		var is_selected: bool = i == selected_slot_index
		var button: Button = Button.new()
		var result_item: ItemData = current_machine.get_slot_result_item(i)
		var slot_icon: Texture2D = null
		var has_icon: bool = false

		if result_item != null and result_item.icon != null:
			slot_icon = result_item.icon
			has_icon = true

		button.custom_minimum_size = Vector2(180, 128)
		button.mouse_filter = Control.MOUSE_FILTER_STOP

		var slot_text: String = current_machine.get_slot_status_text(i)
		if has_icon:
			button.text = slot_text
		else:
			button.text = "[%d]\n%s" % [i + 1, slot_text]

		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_stylebox_override("normal", _make_slot_stylebox(is_selected, false, has_icon))
		button.add_theme_stylebox_override("hover", _make_slot_stylebox(is_selected, true, has_icon))
		button.add_theme_stylebox_override("pressed", _make_slot_stylebox(is_selected, true, has_icon))
		button.add_theme_stylebox_override("focus", _make_slot_stylebox(is_selected, true, has_icon))
		button.add_theme_stylebox_override("disabled", _make_slot_stylebox(is_selected, false, has_icon))

		if is_selected:
			button.add_theme_color_override("font_color", Color.WHITE)
			button.add_theme_color_override("font_hover_color", Color.WHITE)
			button.add_theme_color_override("font_pressed_color", Color.WHITE)
			button.add_theme_color_override("font_focus_color", Color.WHITE)

		if slot_icon != null:
			_add_slot_icon(button, slot_icon)

		button.pressed.connect(_on_slot_pressed.bind(i))
		grid.add_child(button)

	_refresh_ingredient_slots()
	_update_selected_slot_info()
	_update_action_buttons()


func _make_slot_stylebox(is_selected: bool, is_hover: bool, has_icon: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = SLOT_CORNER_RADIUS
	style.corner_radius_top_right = SLOT_CORNER_RADIUS
	style.corner_radius_bottom_right = SLOT_CORNER_RADIUS
	style.corner_radius_bottom_left = SLOT_CORNER_RADIUS
	style.content_margin_left = 12
	style.content_margin_top = SLOT_CONTENT_TOP_WITH_ICON if has_icon else 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10

	if is_selected:
		style.bg_color = SLOT_BG_SELECTED_HOVER if is_hover else SLOT_BG_SELECTED
		style.border_color = SLOT_SELECTED_BORDER_COLOR
		style.border_width_left = SLOT_SELECTED_BORDER_WIDTH
		style.border_width_top = SLOT_SELECTED_BORDER_WIDTH
		style.border_width_right = SLOT_SELECTED_BORDER_WIDTH
		style.border_width_bottom = SLOT_SELECTED_BORDER_WIDTH
	else:
		style.bg_color = SLOT_BG_HOVER if is_hover else SLOT_BG_NORMAL
		style.border_color = SLOT_BORDER_HOVER if is_hover else SLOT_BORDER_NORMAL
		style.border_width_left = SLOT_NORMAL_BORDER_WIDTH
		style.border_width_top = SLOT_NORMAL_BORDER_WIDTH
		style.border_width_right = SLOT_NORMAL_BORDER_WIDTH
		style.border_width_bottom = SLOT_NORMAL_BORDER_WIDTH

	return style


func _add_slot_icon(button: Button, icon_texture: Texture2D) -> void:
	if button == null or icon_texture == null:
		return

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = icon_texture
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.z_index = 1
	icon_rect.anchor_left = 0.5
	icon_rect.anchor_right = 0.5
	icon_rect.anchor_top = 0.0
	icon_rect.anchor_bottom = 0.0
	icon_rect.offset_left = -SLOT_ICON_SIZE * 0.5
	icon_rect.offset_top = SLOT_ICON_TOP_OFFSET
	icon_rect.offset_right = SLOT_ICON_SIZE * 0.5
	icon_rect.offset_bottom = SLOT_ICON_TOP_OFFSET + SLOT_ICON_SIZE
	button.add_child(icon_rect)


func _refresh_recipe_options() -> void:
	var previous_key: String = selected_recipe_key
	if previous_key.is_empty():
		previous_key = _get_recipe_key(_get_selected_recipe())

	if recipe_option == null:
		selected_recipe_key = ""
		return

	recipe_option.clear()
	selected_recipe_key = ""

	if current_machine == null:
		return

	var selected_index: int = -1
	for recipe in current_machine.available_recipes:
		if recipe == null or not recipe.is_valid_recipe():
			continue
		if not recipe.can_use_station(current_machine.station_flags):
			continue
		if current_machine.cooker_level < int(recipe.required_upgrade_level):
			continue

		var display_name: String = _build_recipe_option_text(recipe)
		var item_index: int = recipe_option.item_count
		recipe_option.add_item(display_name)
		recipe_option.set_item_metadata(item_index, recipe)

		var recipe_key: String = _get_recipe_key(recipe)
		if selected_index < 0 and recipe_key == previous_key:
			selected_index = item_index

	if recipe_option.item_count <= 0:
		return

	if selected_index < 0:
		selected_index = 0

	recipe_option.select(selected_index)
	selected_recipe_key = _get_recipe_key(_get_selected_recipe())


func _build_recipe_option_text(recipe: CookingRecipe) -> String:
	return "%s（%d分 / 完成%d個 / EXP+%d）" % [recipe.get_display_name(), recipe.cook_minutes, recipe.result_count, recipe.cooking_exp]


func _get_recipe_key(recipe: CookingRecipe) -> String:
	if recipe == null:
		return ""
	if not recipe.resource_path.is_empty():
		return recipe.resource_path
	if not str(recipe.id).is_empty():
		return str(recipe.id)
	return recipe.get_display_name()


func _refresh_ingredient_slots() -> void:
	if ingredient_slots_container != null:
		for child in ingredient_slots_container.get_children():
			ingredient_slots_container.remove_child(child)
			child.queue_free()

	var recipe: CookingRecipe = _get_selected_recipe()
	if current_machine == null or selected_slot_index < 0 or recipe == null:
		if ingredient_label != null:
			ingredient_label.text = "材料投入"
		if ingredient_section != null:
			ingredient_section.visible = false
		prepared_assignments.clear()
		prepared_context_slot_index = -1
		prepared_context_recipe_key = ""
		prepared_context_craft_count = 0
		return

	if ingredient_section != null:
		ingredient_section.visible = true
	_sync_prepared_assignments()

	var craft_count: int = max(int(craft_count_spinbox.value), 1)
	if ingredient_label != null:
		ingredient_label.text = "材料投入（必要種類 %d / 調理回数 %d）" % [prepared_assignments.size(), craft_count]

	for assignment_index in range(prepared_assignments.size()):
		var assignment: Dictionary = prepared_assignments[assignment_index]
		var ingredient_index: int = int(assignment.get("ingredient_index", assignment_index))
		var ingredient = recipe.ingredients[ingredient_index]
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(INGREDIENT_SLOT_WIDTH, INGREDIENT_SLOT_HEIGHT)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.tooltip_text = "左クリック: 選択中アイテムを投入 / 右クリック: 解除"

		var need_total: int = max(recipe.get_ingredient_count_at(ingredient_index), 0) * craft_count
		var assigned_item: ItemData = assignment.get("item_data", null) as ItemData
		var display_lines: PackedStringArray = PackedStringArray()
		display_lines.append("%s" % ingredient.get_display_name())
		display_lines.append("必要数: x%d" % need_total)

		var icon_texture: Texture2D = null
		var has_icon: bool = false
		var is_valid_assignment: bool = false
		if assigned_item != null:
			is_valid_assignment = _is_assignment_fulfilled(assignment_index)
			display_lines.append("投入: %s" % assigned_item.item_name)
			display_lines.append("状態: %s" % ("準備OK" if is_valid_assignment else "不足 / 不一致"))
			if assigned_item.icon != null:
				icon_texture = assigned_item.icon
				has_icon = true
		else:
			display_lines.append("未投入")
			if ingredient.specific_item != null and ingredient.specific_item.icon != null:
				icon_texture = ingredient.specific_item.icon
				has_icon = true

		button.text = "\n".join(display_lines)
		button.add_theme_stylebox_override("normal", _make_slot_stylebox(is_valid_assignment, false, has_icon))
		button.add_theme_stylebox_override("hover", _make_slot_stylebox(is_valid_assignment, true, has_icon))
		button.add_theme_stylebox_override("pressed", _make_slot_stylebox(is_valid_assignment, true, has_icon))
		button.add_theme_stylebox_override("focus", _make_slot_stylebox(is_valid_assignment, true, has_icon))
		button.add_theme_stylebox_override("disabled", _make_slot_stylebox(is_valid_assignment, false, has_icon))

		if is_valid_assignment:
			button.add_theme_color_override("font_color", Color.WHITE)
			button.add_theme_color_override("font_hover_color", Color.WHITE)
			button.add_theme_color_override("font_pressed_color", Color.WHITE)
			button.add_theme_color_override("font_focus_color", Color.WHITE)

		if icon_texture != null:
			_add_slot_icon(button, icon_texture)

		button.gui_input.connect(_on_ingredient_slot_gui_input.bind(assignment_index))
		if ingredient_slots_container != null:
			ingredient_slots_container.add_child(button)


func _sync_prepared_assignments() -> void:
	var recipe: CookingRecipe = _get_selected_recipe()
	if current_machine == null or selected_slot_index < 0 or recipe == null:
		prepared_assignments.clear()
		prepared_context_slot_index = -1
		prepared_context_recipe_key = ""
		prepared_context_craft_count = 0
		return

	var new_recipe_key: String = _get_recipe_key(recipe)
	var new_craft_count: int = max(int(craft_count_spinbox.value), 1)
	var preserved: Dictionary = {}
	if prepared_context_slot_index == selected_slot_index and prepared_context_recipe_key == new_recipe_key:
		for entry in prepared_assignments:
			preserved[int(entry.get("ingredient_index", 0))] = entry.get("item_data", null)

	prepared_assignments.clear()
	for ingredient_index in range(recipe.ingredients.size()):
		var ingredient = recipe.ingredients[ingredient_index]
		if ingredient == null or not ingredient.consume_on_cook:
			continue
		var preserved_item: ItemData = preserved.get(ingredient_index, null) as ItemData
		if preserved_item != null and not ingredient.matches_item(preserved_item):
			preserved_item = null
		prepared_assignments.append({
			"ingredient_index": ingredient_index,
			"item_data": preserved_item
		})

	prepared_context_slot_index = selected_slot_index
	prepared_context_recipe_key = new_recipe_key
	prepared_context_craft_count = new_craft_count


func _on_ingredient_slot_gui_input(event: InputEvent, assignment_index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return

	if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_clear_prepared_assignment(assignment_index)
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	var selected_item: ItemData = _get_selected_inventory_item()
	if selected_item == null:
		_clear_prepared_assignment(assignment_index)
		return

	_assign_selected_inventory_item_to_ingredient_slot(assignment_index, selected_item)


func _assign_selected_inventory_item_to_ingredient_slot(assignment_index: int, item_data: ItemData) -> void:
	var recipe: CookingRecipe = _get_selected_recipe()
	if recipe == null:
		return
	if assignment_index < 0 or assignment_index >= prepared_assignments.size():
		return
	if item_data == null:
		return

	var ingredient_index: int = int(prepared_assignments[assignment_index].get("ingredient_index", assignment_index))
	var ingredient = recipe.ingredients[ingredient_index]
	if ingredient == null:
		return
	if not ingredient.matches_item(item_data):
		info_label.text = "%s には %s を入れられない" % [ingredient.get_display_name(), item_data.item_name]
		_refresh_ingredient_slots()
		_update_action_buttons()
		return

	prepared_assignments[assignment_index]["item_data"] = item_data
	_refresh_ingredient_slots()
	_update_selected_slot_info()
	_update_action_buttons()


func _clear_prepared_assignment(assignment_index: int) -> void:
	if assignment_index < 0 or assignment_index >= prepared_assignments.size():
		return
	prepared_assignments[assignment_index]["item_data"] = null
	_refresh_ingredient_slots()
	_update_selected_slot_info()
	_update_action_buttons()


func _get_selected_inventory_item() -> ItemData:
	var inventory_ui: Node = _get_inventory_ui()
	if inventory_ui != null and inventory_ui.has_method("get_selected_item_data"):
		return inventory_ui.call("get_selected_item_data") as ItemData
	if current_player != null:
		return current_player.get("selected_item_data") as ItemData
	return null


func _get_inventory_ui() -> Node:
	return get_tree().get_first_node_in_group("inventory_ui")


func _get_item_signature(item_data: ItemData) -> String:
	if item_data == null:
		return ""
	var key: String = str(item_data.id)
	if key.is_empty():
		key = item_data.resource_path
	return "%s|q=%d|r=%d" % [key, item_data.get_quality(), item_data.get_rank()]


func _get_inventory_count_exact(item_data: ItemData) -> int:
	var inventory_ui: Node = _get_inventory_ui()
	if inventory_ui == null or item_data == null:
		return 0
	if inventory_ui.has_method("get_item_count_by_data"):
		return int(inventory_ui.call("get_item_count_by_data", item_data))
	return 0


func _is_assignment_fulfilled(assignment_index: int) -> bool:
	var plan: Dictionary = _build_prepared_plan_for_selected_recipe()
	if not bool(plan.get("success", false)):
		return false
	var prepared_entries: Array = plan.get("prepared_entries", [])
	for entry in prepared_entries:
		if int(entry.get("assignment_index", -1)) == assignment_index:
			return true
	return false


func _build_prepared_plan_for_selected_recipe() -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"message": "材料投入スロットを埋めてくれ",
		"prepared_entries": []
	}

	var recipe: CookingRecipe = _get_selected_recipe()
	if recipe == null:
		result["message"] = "料理レシピがない"
		return result

	_sync_prepared_assignments()
	var craft_count: int = max(int(craft_count_spinbox.value), 1)
	var requested_by_signature: Dictionary = {}
	var prepared_entries: Array[Dictionary] = []

	for assignment_index in range(prepared_assignments.size()):
		var assignment: Dictionary = prepared_assignments[assignment_index]
		var ingredient_index: int = int(assignment.get("ingredient_index", assignment_index))
		var ingredient = recipe.ingredients[ingredient_index]
		if ingredient == null or not ingredient.consume_on_cook:
			continue

		var need_total: int = max(recipe.get_ingredient_count_at(ingredient_index), 0) * craft_count
		if need_total <= 0:
			continue

		var item_data: ItemData = assignment.get("item_data", null) as ItemData
		if item_data == null:
			result["message"] = "%s が未投入" % ingredient.get_display_name()
			return result
		if not ingredient.matches_item(item_data):
			result["message"] = "%s に合わない材料が入っている" % ingredient.get_display_name()
			return result

		var signature: String = _get_item_signature(item_data)
		requested_by_signature[signature] = int(requested_by_signature.get(signature, 0)) + need_total
		prepared_entries.append({
			"assignment_index": assignment_index,
			"ingredient_index": ingredient_index,
			"item_data": item_data,
			"count": need_total
		})

	for entry in prepared_entries:
		var item_data: ItemData = entry.get("item_data", null) as ItemData
		var signature: String = _get_item_signature(item_data)
		var requested_count: int = int(requested_by_signature.get(signature, 0))
		var available_count: int = _get_inventory_count_exact(item_data)
		if available_count < requested_count:
			result["message"] = "%s が %d 個 足りない" % [item_data.item_name, requested_count - available_count]
			return result

	result["success"] = true
	result["message"] = "OK"
	result["prepared_entries"] = prepared_entries
	return result


func _update_selected_slot_info() -> void:
	if current_machine == null:
		info_label.text = ""
		return
	if selected_slot_index < 0:
		info_label.text = "スロット未選択"
		return

	var recipe: CookingRecipe = _get_selected_recipe()
	var craft_count: int = int(craft_count_spinbox.value)

	if current_machine.is_slot_empty(selected_slot_index):
		if recipe == null:
			info_label.text = "空きスロット。料理レシピを選んでくれ。"
		else:
			var prepared_plan: Dictionary = _build_prepared_plan_for_selected_recipe()
			var prep_text: String = "材料投入待ち"
			if bool(prepared_plan.get("success", false)):
				prep_text = "材料準備OK。調理開始できる。"
			else:
				prep_text = str(prepared_plan.get("message", "材料投入待ち"))
			info_label.text = "空きスロット。%sを %d 回連続で調理できる。\n必要食材: %s\n%s" % [recipe.get_display_name(), craft_count, recipe.get_ingredients_summary_text(), prep_text]
		return

	var display_name: String = current_machine.get_slot_display_name(selected_slot_index)
	var queued_count: int = current_machine.get_slot_queued_count(selected_slot_index)
	var ready_count: int = current_machine.get_slot_ready_count(selected_slot_index)
	var collect_total: int = ready_count * current_machine.get_slot_result_count(selected_slot_index)
	var quality_text: String = _build_quality_text(current_machine.get_slot_output_quality(selected_slot_index), current_machine.get_slot_output_rank(selected_slot_index))
	var base_text: String = ""
	if queued_count > 0:
		base_text = "%s：進行中 %d 回 / 完成待ち %d 回（今取ると %d 個、%s）" % [display_name, queued_count, ready_count, collect_total, quality_text]
	else:
		base_text = "%s：完成待ち %d 回（今取ると %d 個、%s）" % [display_name, ready_count, collect_total, quality_text]

	if recipe == null:
		info_label.text = base_text
		return

	if current_machine.can_stack_recipe(selected_slot_index, recipe):
		info_label.text = "%s\n同じ料理なら %d 回分を追加投入できる。" % [base_text, craft_count]
	else:
		info_label.text = "%s\n使用中スロットには同じ料理だけ追加投入できる。" % [base_text]


func _update_action_buttons() -> void:
	var can_start: bool = false
	var can_collect: bool = false
	var can_discard: bool = false
	if start_button != null:
		start_button.text = "調理開始"

	if current_machine != null and selected_slot_index >= 0:
		var recipe: CookingRecipe = _get_selected_recipe()
		can_collect = current_machine.is_slot_ready(selected_slot_index)
		can_discard = not current_machine.is_slot_empty(selected_slot_index)

		if recipe != null and current_machine.can_start_recipe_in_slot(selected_slot_index, recipe):
			var prepared_plan: Dictionary = _build_prepared_plan_for_selected_recipe()
			can_start = bool(prepared_plan.get("success", false))
			if not current_machine.is_slot_empty(selected_slot_index):
				if start_button != null:
					start_button.text = "追加投入"

	if start_button != null:
		start_button.disabled = not can_start
	if collect_button != null:
		collect_button.disabled = not can_collect
	if discard_button != null:
		discard_button.disabled = not can_discard


func _get_selected_recipe() -> CookingRecipe:
	if current_machine == null or recipe_option == null or recipe_option.item_count <= 0:
		return null

	var option_index: int = recipe_option.selected
	if option_index < 0:
		option_index = 0

	var meta: Variant = recipe_option.get_item_metadata(option_index)
	if meta is CookingRecipe:
		return meta as CookingRecipe
	return null


func _build_quality_text(quality_value: int, rank_value: int) -> String:
	var stars: String = ""
	var clamped_rank: int = clamp(rank_value, 0, 5)
	for i in range(clamped_rank):
		stars += "★"
	for i in range(5 - clamped_rank):
		stars += "☆"
	return "品質%d / %s" % [quality_value, stars]


func _on_slot_pressed(index: int) -> void:
	selected_slot_index = index
	refresh()


func _on_craft_count_changed(_value: float) -> void:
	if visible:
		_refresh_ingredient_slots()
		_update_selected_slot_info()
		_update_action_buttons()


func _on_recipe_selected(index: int) -> void:
	if index < 0 or index >= recipe_option.item_count:
		selected_recipe_key = ""
	else:
		selected_recipe_key = _get_recipe_key(_get_selected_recipe())
	if visible:
		_refresh_ingredient_slots()
		_update_selected_slot_info()
		_update_action_buttons()


func _on_start_pressed() -> void:
	if current_machine == null or current_player == null or selected_slot_index < 0:
		return

	var recipe: CookingRecipe = _get_selected_recipe()
	if recipe == null:
		info_label.text = "料理レシピがない"
		return

	var craft_count: int = max(int(craft_count_spinbox.value), 1)
	var prepared_plan: Dictionary = _build_prepared_plan_for_selected_recipe()
	if not bool(prepared_plan.get("success", false)):
		info_label.text = str(prepared_plan.get("message", "材料投入スロットを埋めてくれ"))
		_refresh_ingredient_slots()
		_update_action_buttons()
		return

	var was_empty: bool = current_machine.is_slot_empty(selected_slot_index)
	var result: Dictionary = current_machine.start_recipe_with_prepared_ingredients(selected_slot_index, recipe, craft_count, current_player, prepared_plan.get("prepared_entries", []))
	if not bool(result.get("success", false)):
		info_label.text = str(result.get("message", "調理を開始できなかった"))
		_refresh_ingredient_slots()
		_update_action_buttons()
		return

	if current_player.has_method("add_fatigue_for_action"):
		current_player.call("add_fatigue_for_action", "cook", float(craft_count), false)

	info_label.text = str(result.get("message", "調理を開始した"))
	prepared_assignments.clear()
	prepared_context_slot_index = -1
	prepared_context_recipe_key = ""
	prepared_context_craft_count = 0
	if was_empty:
		_log_system("%sのスロット%dに%sを %d 回分 セットした" % [current_machine.machine_name, selected_slot_index + 1, recipe.get_display_name(), craft_count])
	else:
		_log_system("%sのスロット%dに%sを %d 回分 追加投入した" % [current_machine.machine_name, selected_slot_index + 1, recipe.get_display_name(), craft_count])
	refresh()


func _on_collect_pressed() -> void:
	if current_machine == null or current_player == null or selected_slot_index < 0:
		return

	var before_name: String = current_machine.get_slot_display_name(selected_slot_index)
	var result: Dictionary = current_machine.collect_slot(selected_slot_index)
	if not bool(result.get("success", false)):
		info_label.text = "まだ受け取れない"
		return

	var item_data: ItemData = result.get("item_data", null) as ItemData
	var amount: int = int(result.get("amount", 0))
	var ready_cycles: int = int(result.get("ready_cycles", 0))
	if item_data == null or amount <= 0 or ready_cycles <= 0:
		info_label.text = "完成データが不正"
		return

	var add_ok: bool = bool(current_player.call("add_item_to_inventory", item_data, amount))
	if not add_ok:
		info_label.text = "インベントリに入れられない"
		return

	_grant_cooking_exp(int(result.get("cooking_exp", 0)))
	var quality_text: String = _build_quality_text(item_data.get_quality(), item_data.get_rank())
	info_label.text = "%sを %d 回分 受け取って %d 個獲得した（%s）" % [before_name, ready_cycles, amount, quality_text]
	_log_system("%sのスロット%dから%sを %d 回分受け取って %d 個獲得した（%s）" % [current_machine.machine_name, selected_slot_index + 1, before_name, ready_cycles, amount, quality_text])
	refresh()


func _on_discard_pressed() -> void:
	if current_machine == null or selected_slot_index < 0:
		return

	var preview: Dictionary = current_machine.get_slot_discard_preview(selected_slot_index)
	if not bool(preview.get("success", false)):
		info_label.text = "破棄できる料理がない"
		return

	pending_discard_slot_index = selected_slot_index
	pending_discard_preview = preview
	if discard_confirm_dialog != null:
		discard_confirm_dialog.dialog_text = _build_discard_confirm_text(preview)
		discard_confirm_dialog.popup_centered()


func _build_discard_confirm_text(preview: Dictionary) -> String:
	var display_name: String = str(preview.get("display_name", "料理"))
	var ready_cycles: int = int(preview.get("ready_cycles", 0))
	var ready_amount: int = int(preview.get("ready_amount", 0))
	var queued_count: int = int(preview.get("queued_count", 0))
	var lines: PackedStringArray = []
	lines.append("%s を破棄する。" % display_name)
	if ready_cycles > 0 and ready_amount > 0:
		lines.append("完成待ち: %d 回分 → %d 個ぶんが消える" % [ready_cycles, ready_amount])
	if queued_count > 0:
		lines.append("進行中: %d 回分 → 材料返却なしで消える" % queued_count)
	lines.append("本当に破棄していいか？")
	return "\n".join(lines)


func _on_discard_confirmed() -> void:
	if current_machine == null or pending_discard_slot_index < 0:
		return

	var target_slot_index: int = pending_discard_slot_index
	var preview: Dictionary = pending_discard_preview.duplicate(true)
	pending_discard_slot_index = -1
	pending_discard_preview.clear()
	if not bool(preview.get("success", false)):
		info_label.text = "破棄できなかった"
		refresh()
		return

	var display_name: String = str(preview.get("display_name", "料理"))
	var ready_cycles: int = int(preview.get("ready_cycles", 0))
	var queued_count: int = int(preview.get("queued_count", 0))
	current_machine.discard_slot(target_slot_index)

	info_label.text = "%sを破棄した（完成待ち %d 回分 / 進行中 %d 回分）" % [display_name, ready_cycles, queued_count]
	_log_system("%sのスロット%dの%sを破棄した（完成待ち %d 回分 / 進行中 %d 回分）" % [current_machine.machine_name, target_slot_index + 1, display_name, ready_cycles, queued_count])
	refresh()


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


func _grant_cooking_exp(exp_gain: int) -> void:
	if exp_gain <= 0:
		return

	var stats_manager: Node = _get_player_stats_manager()
	if stats_manager == null:
		return
	if not stats_manager.has_method("gain_skill_exp"):
		return

	stats_manager.call("gain_skill_exp", COOKING_SKILL_NAME, exp_gain)
	_log_system("料理経験値 +%d" % exp_gain)


func _get_message_log() -> Node:
	return get_node_or_null("/root/MessageLog")


func _log_system(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_system"):
		log_node.call("add_system", text)

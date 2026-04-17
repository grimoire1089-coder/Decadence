extends Control
class_name CropRecipeSelectorDialog

signal recipe_selected(recipe_key: String)

const DIALOG_SIZE: Vector2i = Vector2i(820, 560)
const DIALOG_MIN_MARGIN: int = 64
const PANEL_CORNER_RADIUS: int = 16
const ROOT_DIMMER_COLOR: Color = Color(0.0, 0.0, 0.0, 0.38)
const PANEL_BG: Color = Color(0.05, 0.08, 0.12, 0.98)
const PANEL_BORDER: Color = Color(0.30, 0.75, 1.0, 0.72)
const SUB_PANEL_BG: Color = Color(0.09, 0.12, 0.17, 0.96)
const SUB_PANEL_BORDER: Color = Color(0.22, 0.42, 0.58, 0.95)
const TEXT_COLOR: Color = Color(0.93, 0.96, 1.0, 1.0)
const MUTED_TEXT_COLOR: Color = Color(0.72, 0.80, 0.90, 1.0)
const BUTTON_BG: Color = Color(0.11, 0.16, 0.23, 1.0)
const BUTTON_BG_HOVER: Color = Color(0.15, 0.22, 0.31, 1.0)
const BUTTON_BG_PRESSED: Color = Color(0.09, 0.13, 0.18, 1.0)
const BUTTON_DISABLED_BG: Color = Color(0.12, 0.12, 0.12, 0.85)
const SEARCH_BG: Color = Color(0.08, 0.10, 0.14, 1.0)
const SELECT_BG: Color = Color(0.18, 0.29, 0.38, 1.0)
const SELECT_BG_FOCUS: Color = Color(0.23, 0.39, 0.53, 1.0)

@onready var dimmer: ColorRect = $Dimmer
@onready var center_container: CenterContainer = $CenterContainer
@onready var content_panel: PanelContainer = $CenterContainer/ContentPanel
@onready var body: VBoxContainer = $CenterContainer/ContentPanel/Margin/Body
@onready var title_label: Label = $CenterContainer/ContentPanel/Margin/Body/HeaderRow/TitleLabel
@onready var top_close_button: Button = $CenterContainer/ContentPanel/Margin/Body/HeaderRow/CloseButton
@onready var search_input: LineEdit = $CenterContainer/ContentPanel/Margin/Body/RecipeSearchInput
@onready var body_split: HSplitContainer = $CenterContainer/ContentPanel/Margin/Body/BodySplit
@onready var left_box: VBoxContainer = $CenterContainer/ContentPanel/Margin/Body/BodySplit/LeftBox
@onready var result_list: ItemList = $CenterContainer/ContentPanel/Margin/Body/BodySplit/LeftBox/RecipeResultList
@onready var empty_label: Label = $CenterContainer/ContentPanel/Margin/Body/BodySplit/LeftBox/RecipeEmptyLabel
@onready var detail_panel: PanelContainer = $CenterContainer/ContentPanel/Margin/Body/BodySplit/RightPanel
@onready var detail_label: Label = $CenterContainer/ContentPanel/Margin/Body/BodySplit/RightPanel/RightBox/RecipeDetailLabel
@onready var select_button: Button = $CenterContainer/ContentPanel/Margin/Body/ActionRow/SelectButton
@onready var close_action_button: Button = $CenterContainer/ContentPanel/Margin/Body/ActionRow/CloseButton
@onready var action_row: HBoxContainer = $CenterContainer/ContentPanel/Margin/Body/ActionRow

var _selected_recipe_key: String = ""
var _entries: Array = []
var _item_count_resolver: Callable = Callable()
var _exp_resolver: Callable = Callable()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200
	hide()

	if not search_input.text_changed.is_connected(_on_search_text_changed):
		search_input.text_changed.connect(_on_search_text_changed)
	if not result_list.item_selected.is_connected(_on_result_list_item_selected):
		result_list.item_selected.connect(_on_result_list_item_selected)
	if not result_list.item_activated.is_connected(_on_result_list_item_activated):
		result_list.item_activated.connect(_on_result_list_item_activated)
	if not top_close_button.pressed.is_connected(_on_top_close_pressed):
		top_close_button.pressed.connect(_on_top_close_pressed)
	if not select_button.pressed.is_connected(_on_select_pressed):
		select_button.pressed.connect(_on_select_pressed)
	if not close_action_button.pressed.is_connected(_on_close_action_pressed):
		close_action_button.pressed.connect(_on_close_action_pressed)

	_apply_visual_style()
	_fit_dialog_to_viewport()
	_update_detail_text()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_fit_dialog_to_viewport()


func configure_selector(recipes: Array, selected_recipe_key: String, item_count_resolver: Callable, exp_resolver: Callable) -> void:
	_selected_recipe_key = selected_recipe_key
	_item_count_resolver = item_count_resolver
	_exp_resolver = exp_resolver
	_rebuild_entries(recipes)
	_apply_filter(search_input.text)


func open_selector() -> void:
	_fit_dialog_to_viewport()
	show()
	call_deferred("_finalize_open_selector")


func _finalize_open_selector() -> void:
	if not visible:
		return
	_fit_dialog_to_viewport()
	search_input.grab_focus()
	search_input.select_all()


func _fit_dialog_to_viewport() -> void:
	if content_panel == null:
		return
	var viewport_rect: Rect2 = get_viewport_rect()
	var available_width: float = max(640.0, viewport_rect.size.x - float(DIALOG_MIN_MARGIN))
	var available_height: float = max(380.0, viewport_rect.size.y - float(DIALOG_MIN_MARGIN))
	var target_width: float = min(float(DIALOG_SIZE.x), available_width)
	var target_height: float = min(float(DIALOG_SIZE.y), available_height)
	content_panel.custom_minimum_size = Vector2(target_width, target_height)
	content_panel.size = Vector2(target_width, target_height)


func reset_selector_state() -> void:
	hide()
	_entries.clear()
	_selected_recipe_key = ""
	if search_input != null:
		search_input.text = ""
	if result_list != null:
		result_list.clear()
	_update_detail_text()


func _apply_visual_style() -> void:
	dimmer.color = ROOT_DIMMER_COLOR

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = PANEL_BORDER
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = PANEL_CORNER_RADIUS
	panel_style.corner_radius_top_right = PANEL_CORNER_RADIUS
	panel_style.corner_radius_bottom_right = PANEL_CORNER_RADIUS
	panel_style.corner_radius_bottom_left = PANEL_CORNER_RADIUS
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 12
	content_panel.add_theme_stylebox_override("panel", panel_style)

	var sub_panel_style: StyleBoxFlat = StyleBoxFlat.new()
	sub_panel_style.bg_color = SUB_PANEL_BG
	sub_panel_style.border_color = SUB_PANEL_BORDER
	sub_panel_style.border_width_left = 1
	sub_panel_style.border_width_top = 1
	sub_panel_style.border_width_right = 1
	sub_panel_style.border_width_bottom = 1
	sub_panel_style.corner_radius_top_left = 10
	sub_panel_style.corner_radius_top_right = 10
	sub_panel_style.corner_radius_bottom_right = 10
	sub_panel_style.corner_radius_bottom_left = 10

	var input_style: StyleBoxFlat = sub_panel_style.duplicate()
	input_style.content_margin_left = 12
	input_style.content_margin_right = 12
	input_style.content_margin_top = 10
	input_style.content_margin_bottom = 10
	input_style.bg_color = SEARCH_BG

	var input_focus_style: StyleBoxFlat = input_style.duplicate()
	input_focus_style.border_color = PANEL_BORDER
	input_focus_style.border_width_left = 2
	input_focus_style.border_width_top = 2
	input_focus_style.border_width_right = 2
	input_focus_style.border_width_bottom = 2

	search_input.add_theme_stylebox_override("normal", input_style)
	search_input.add_theme_stylebox_override("focus", input_focus_style)
	search_input.add_theme_stylebox_override("read_only", input_style)
	search_input.add_theme_color_override("font_color", TEXT_COLOR)
	search_input.add_theme_color_override("font_placeholder_color", MUTED_TEXT_COLOR)
	search_input.add_theme_color_override("caret_color", TEXT_COLOR)
	search_input.add_theme_font_size_override("font_size", 18)

	result_list.add_theme_stylebox_override("panel", sub_panel_style)
	result_list.add_theme_color_override("font_color", TEXT_COLOR)
	result_list.add_theme_color_override("font_selected_color", TEXT_COLOR)
	result_list.add_theme_color_override("guide_color", Color(0, 0, 0, 0))
	result_list.add_theme_color_override("selection_fill", SELECT_BG)
	result_list.add_theme_color_override("selection_fill_disabled", SELECT_BG)
	result_list.add_theme_color_override("selection_fill_focus", SELECT_BG_FOCUS)
	result_list.add_theme_constant_override("h_separation", 8)
	result_list.add_theme_constant_override("v_separation", 8)
	result_list.fixed_column_width = 0
	result_list.icon_mode = ItemList.ICON_MODE_TOP
	result_list.same_column_width = true

	detail_panel.add_theme_stylebox_override("panel", sub_panel_style)
	left_box.add_theme_constant_override("separation", 8)
	body.add_theme_constant_override("separation", 12)
	body_split.split_offset = 520
	action_row.custom_minimum_size = Vector2(0, 52)

	title_label.text = "植え付ける作物を選択"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", TEXT_COLOR)

	for label_path in [
		"CenterContainer/ContentPanel/Margin/Body/BodySplit/LeftBox/ListHeader",
		"CenterContainer/ContentPanel/Margin/Body/BodySplit/RightPanel/RightBox/DetailHeader"
	]:
		var header_label: Label = get_node_or_null(label_path) as Label
		if header_label != null:
			header_label.add_theme_font_size_override("font_size", 18)
			header_label.add_theme_color_override("font_color", TEXT_COLOR)

	empty_label.add_theme_color_override("font_color", MUTED_TEXT_COLOR)
	empty_label.add_theme_font_size_override("font_size", 18)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	detail_label.add_theme_color_override("font_color", TEXT_COLOR)
	detail_label.add_theme_font_size_override("font_size", 18)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_apply_button_style(select_button, false)
	_apply_button_style(close_action_button, false)
	_apply_button_style(top_close_button, true)


func _apply_button_style(button: Button, compact: bool) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(44, 40) if compact else Vector2(140, 42)
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", TEXT_COLOR)
	button.add_theme_color_override("font_pressed_color", TEXT_COLOR)
	button.add_theme_color_override("font_disabled_color", MUTED_TEXT_COLOR)

	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = BUTTON_BG
	normal_style.border_color = PANEL_BORDER
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_right = 10
	normal_style.corner_radius_bottom_left = 10
	normal_style.content_margin_left = 12
	normal_style.content_margin_top = 8
	normal_style.content_margin_right = 12
	normal_style.content_margin_bottom = 8

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = BUTTON_BG_HOVER

	var pressed_style: StyleBoxFlat = normal_style.duplicate()
	pressed_style.bg_color = BUTTON_BG_PRESSED

	var disabled_style: StyleBoxFlat = normal_style.duplicate()
	disabled_style.bg_color = BUTTON_DISABLED_BG
	disabled_style.border_color = Color(0.30, 0.30, 0.30, 0.85)

	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("disabled", disabled_style)


func _rebuild_entries(recipes: Array) -> void:
	_entries.clear()
	var has_known_seed_counts: bool = false
	var all_entries: Array = []

	for recipe in recipes:
		if recipe == null or not recipe.is_valid_recipe():
			continue

		var seed_name: String = _get_seed_name(recipe)
		var seed_count: int = _resolve_item_count(recipe.seed_item)
		var has_seed_count: bool = seed_count >= 0
		if has_seed_count:
			has_known_seed_counts = true

		var entry: Dictionary = {
			"recipe": recipe,
			"key": _get_recipe_key(recipe),
			"seed_name": seed_name,
			"seed_count": seed_count,
			"has_seed_count": has_seed_count,
			"list_text": _build_item_text(recipe, seed_name, seed_count, has_seed_count),
			"detail_text": _build_detail_text(recipe, seed_name, seed_count, has_seed_count),
			"search_text": (recipe.get_display_name() + " " + seed_name).to_lower()
		}
		all_entries.append(entry)

	if has_known_seed_counts:
		for entry in all_entries:
			if bool(entry.get("has_seed_count", false)) and int(entry.get("seed_count", 0)) <= 0:
				continue
			_entries.append(entry)
	else:
		_entries = all_entries


func _get_seed_name(recipe: CropRecipe) -> String:
	if recipe == null or recipe.seed_item == null:
		return "種"
	if not recipe.seed_item.item_name.is_empty():
		return recipe.seed_item.item_name
	return str(recipe.seed_item.id)


func _build_item_text(recipe: CropRecipe, seed_name: String, seed_count: int, has_seed_count: bool) -> String:
	var seed_count_text: String = "所持数不明"
	if has_seed_count:
		seed_count_text = "所持 %d" % seed_count
	return "%s  [%s / %s / %d分 / 収穫%d]" % [recipe.get_display_name(), seed_name, seed_count_text, recipe.grow_minutes, recipe.harvest_amount]


func _build_detail_text(recipe: CropRecipe, seed_name: String, seed_count: int, has_seed_count: bool) -> String:
	var lines: PackedStringArray = []
	lines.append("作物: %s" % recipe.get_display_name())
	lines.append("種: %s" % seed_name)
	if has_seed_count:
		lines.append("所持している種: %d 個" % seed_count)
	else:
		lines.append("所持している種: 取得できない")
	lines.append("成長時間: %d 分" % recipe.grow_minutes)
	lines.append("収穫量: %d 個" % recipe.harvest_amount)
	lines.append("獲得EXP: %d" % _resolve_recipe_exp(recipe))
	return "\n".join(lines)


func _apply_filter(filter_text: String) -> void:
	result_list.clear()
	var normalized_filter: String = filter_text.strip_edges().to_lower()
	var filtered_entries: Array = []

	for entry in _entries:
		var search_text: String = str(entry.get("search_text", "")).to_lower()
		if not normalized_filter.is_empty() and not search_text.contains(normalized_filter):
			continue
		filtered_entries.append(entry)

	for entry in filtered_entries:
		var item_index: int = result_list.item_count
		result_list.add_item(str(entry.get("list_text", "")))
		result_list.set_item_metadata(item_index, entry.get("key", ""))

	empty_label.visible = filtered_entries.is_empty()
	result_list.visible = not filtered_entries.is_empty()

	var select_index: int = -1
	for i in range(result_list.item_count):
		if str(result_list.get_item_metadata(i)) == _selected_recipe_key:
			select_index = i
			break

	if select_index < 0 and result_list.item_count > 0:
		select_index = 0

	if select_index >= 0:
		result_list.select(select_index)

	_update_detail_text()
	select_button.disabled = result_list.item_count <= 0


func _update_detail_text() -> void:
	if result_list == null or result_list.item_count <= 0:
		detail_label.text = "選択できる種がない。インベントリに種を入れるとここに出る。"
		return

	var selected_items: PackedInt32Array = result_list.get_selected_items()
	if selected_items.is_empty():
		detail_label.text = "作物を選択すると詳細が出る。"
		return

	var recipe_key: String = str(result_list.get_item_metadata(selected_items[0]))
	for entry in _entries:
		if str(entry.get("key", "")) == recipe_key:
			detail_label.text = str(entry.get("detail_text", ""))
			return

	detail_label.text = "詳細を取得できなかった。"


func _emit_selected_recipe() -> void:
	if result_list == null:
		return

	var selected_items: PackedInt32Array = result_list.get_selected_items()
	if selected_items.is_empty():
		return

	_selected_recipe_key = str(result_list.get_item_metadata(selected_items[0]))
	recipe_selected.emit(_selected_recipe_key)


func _resolve_item_count(item_data: ItemData) -> int:
	if item_data == null:
		return -1
	if not _item_count_resolver.is_valid():
		return -1

	var value: Variant = _item_count_resolver.call(item_data)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return max(int(value), 0)
	return -1


func _resolve_recipe_exp(recipe: CropRecipe) -> int:
	if recipe == null:
		return 0
	if not _exp_resolver.is_valid():
		return 0

	var value: Variant = _exp_resolver.call(recipe)
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return int(value)
	return 0


func _get_recipe_key(recipe: CropRecipe) -> String:
	if recipe == null:
		return ""
	if not recipe.resource_path.is_empty():
		return recipe.resource_path
	if not str(recipe.id).is_empty():
		return str(recipe.id)
	return recipe.get_display_name()


func _on_search_text_changed(new_text: String) -> void:
	_apply_filter(new_text)


func _on_result_list_item_selected(_index: int) -> void:
	_update_detail_text()


func _on_result_list_item_activated(_index: int) -> void:
	_emit_selected_recipe()
	hide()


func _on_select_pressed() -> void:
	_emit_selected_recipe()
	hide()


func _on_top_close_pressed() -> void:
	hide()


func _on_close_action_pressed() -> void:
	hide()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		hide()
		accept_event()

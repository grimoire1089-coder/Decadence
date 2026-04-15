extends Control
class_name VendingMachineUI

const UI_LOCK_SOURCE: String = "自販機UI"
const UI_MODAL_MANAGER_SCRIPT_NAME: String = "UIModalManager.gd"
const TIME_MANAGER_SCRIPT_NAME: String = "TimeManager.gd"

const ROOT_DIMMER_COLOR: Color = Color(0.0, 0.0, 0.0, 0.45)
const MAIN_PANEL_SIZE: Vector2 = Vector2(1000, 620)
const MAIN_PANEL_BG: Color = Color(0.05, 0.08, 0.12, 0.94)
const MAIN_PANEL_BORDER: Color = Color(0.30, 0.75, 1.0, 0.70)
const PANEL_CORNER_RADIUS: int = 16
const SLOT_SELECTED_BORDER_COLOR: Color = Color("ffd700")
const SLOT_SELECTED_BORDER_WIDTH: int = 4
const SLOT_NORMAL_BORDER_WIDTH: int = 2
const SLOT_CORNER_RADIUS: int = 10
const SLOT_BG_NORMAL: Color = Color(0.18, 0.20, 0.24, 0.92)
const SLOT_BG_HOVER: Color = Color(0.22, 0.24, 0.28, 0.96)
const SLOT_BG_SELECTED: Color = Color(0.30, 0.25, 0.10, 0.96)
const SLOT_BG_SELECTED_HOVER: Color = Color(0.36, 0.30, 0.12, 0.98)
const SLOT_BORDER_NORMAL: Color = Color(0.45, 0.48, 0.52, 0.90)
const SLOT_BORDER_HOVER: Color = Color(0.62, 0.66, 0.72, 0.95)

var current_machine: VendingMachine = null
var current_player: Node = null
var selected_slot_index: int = -1
var inventory_was_open_before_machine: bool = false
var dimmer: ColorRect = null

@onready var panel: Panel = $Panel
@onready var vbox: VBoxContainer = $Panel/VBoxContainer
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var money_label: Label = $Panel/VBoxContainer/MoneyLabel
@onready var earnings_label: Label = $Panel/VBoxContainer/EarningsLabel
@onready var grid: GridContainer = $Panel/VBoxContainer/GridContainer
@onready var price_spinbox: SpinBox = $Panel/VBoxContainer/PriceSpinBox
@onready var stock_one_button: Button = $Panel/VBoxContainer/HBoxContainer/StockOneButton
@onready var take_back_one_button: Button = $Panel/VBoxContainer/HBoxContainer/TakeBackOneButton
@onready var set_price_button: Button = $Panel/VBoxContainer/HBoxContainer/SetPriceButton
@onready var collect_button: Button = $Panel/VBoxContainer/HBoxContainer/CollectButton
@onready var info_label: Label = $Panel/VBoxContainer/InfoLabel
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton


func _ready() -> void:
	visible = false
	add_to_group("vending_ui")

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_root_layout()
	_setup_dimmer()
	_setup_main_panel()
	_setup_content_layout()

	price_spinbox.min_value = 0
	price_spinbox.max_value = 999999
	price_spinbox.step = 1
	price_spinbox.value = 10

	stock_one_button.pressed.connect(_on_stock_one_pressed)
	take_back_one_button.pressed.connect(_on_take_back_one_pressed)
	set_price_button.pressed.connect(_on_set_price_pressed)
	collect_button.pressed.connect(_on_collect_pressed)
	close_button.pressed.connect(_on_close_pressed)
	if not resized.is_connected(_on_ui_resized):
		resized.connect(_on_ui_resized)

	if CurrencyManager != null:
		if not CurrencyManager.credits_changed.is_connected(_on_credits_changed):
			CurrencyManager.credits_changed.connect(_on_credits_changed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _exit_tree() -> void:
	_release_ui_lock()


func open_machine(machine: VendingMachine, player: Node) -> void:
	current_machine = machine
	current_player = player

	if machine != null and machine.slots.size() > 0:
		selected_slot_index = clamp(selected_slot_index, 0, machine.slots.size() - 1)
		if selected_slot_index < 0:
			selected_slot_index = 0
	else:
		selected_slot_index = -1

	inventory_was_open_before_machine = _is_inventory_ui_visible()
	_ensure_inventory_ui_visible()

	visible = true
	move_to_front()
	_acquire_ui_lock()
	refresh()
	
	var inventory_ui: Control = get_tree().get_first_node_in_group("inventory_ui") as Control
	if inventory_ui != null:
		inventory_ui.move_to_front()
	
	_acquire_ui_lock()
	refresh()


func close() -> void:
	visible = false

	if not inventory_was_open_before_machine:
		_hide_inventory_ui()

	_release_ui_lock()

	current_machine = null
	current_player = null
	selected_slot_index = -1
	inventory_was_open_before_machine = false
	info_label.text = ""


func refresh() -> void:
	if current_machine == null or current_player == null:
		return

	title_label.text = current_machine.machine_name
	money_label.text = "所持金: %d Cr" % _get_player_credits(current_player)
	earnings_label.text = "売上: %d Cr" % current_machine.earnings

	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	var total_slots: int = current_machine.slots.size()

	if total_slots <= 0:
		selected_slot_index = -1
		info_label.text = "スロットがない"
		return

	selected_slot_index = clamp(selected_slot_index, 0, total_slots - 1)

	for i in range(total_slots):
		var slot: VendingSlot = current_machine.slots[i]
		var button: Button = Button.new()
		var is_selected: bool = i == selected_slot_index
		button.custom_minimum_size = Vector2(170, 230)
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.clip_contents = true
		button.text = ""
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_stylebox_override("normal", _make_slot_stylebox(is_selected, false))
		button.add_theme_stylebox_override("hover", _make_slot_stylebox(is_selected, true))
		button.add_theme_stylebox_override("pressed", _make_slot_stylebox(is_selected, true))
		button.add_theme_stylebox_override("focus", _make_slot_stylebox(is_selected, true))
		button.add_theme_stylebox_override("disabled", _make_slot_stylebox(is_selected, false))

		_populate_slot_button(button, slot, i, is_selected)

		button.pressed.connect(_on_slot_pressed.bind(i))
		grid.add_child(button)

	if selected_slot_index >= 0 and selected_slot_index < total_slots:
		var selected_slot: VendingSlot = current_machine.slots[selected_slot_index]
		if not selected_slot.is_empty():
			price_spinbox.value = selected_slot.price
		else:
			var selected_item_data: Resource = _get_player_selected_item_data(current_player)
			var recommended_price: int = _get_adjusted_sell_price(selected_item_data)
			if recommended_price > 0:
				price_spinbox.value = recommended_price


func _populate_slot_button(button: Button, slot: VendingSlot, slot_index: int, is_selected: bool) -> void:
	var content: VBoxContainer = VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8
	content.offset_top = 8
	content.offset_right = -8
	content.offset_bottom = -8
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4)
	button.add_child(content)

	var text_color: Color = Color.WHITE if is_selected else Color(0.95, 0.97, 1.0)

	if slot.is_empty():
		content.add_child(_make_slot_line_label("[%d]" % [slot_index + 1], true, 18, text_color))
		content.add_child(_make_slot_line_label("空", true, 16, text_color))
		return

	content.add_child(_make_slot_line_label(_get_item_name(slot.item_data), true, 16, text_color))

	var icon_rect: TextureRect = _make_slot_icon(slot.item_data)
	if icon_rect != null:
		content.add_child(icon_rect)

	content.add_child(_make_slot_line_label("品質: %d" % _get_item_quality_value(slot.item_data), true, 14, text_color))
	content.add_child(_make_slot_line_label("ランク: %s" % _get_item_rank_text(slot.item_data), true, 14, text_color))
	content.add_child(_make_slot_line_label("在庫: %d個" % slot.amount, true, 14, text_color))
	content.add_child(_make_slot_line_label("価格: %d Cr" % slot.price, true, 14, text_color))


func _make_slot_line_label(text: String, centered: bool, font_size: int, text_color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color)
	return label


func _make_slot_icon(item_data: Resource) -> TextureRect:
	var item: ItemData = item_data as ItemData
	if item == null or item.icon == null:
		return null

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = item.icon
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.size = Vector2(64, 64)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return icon_rect


func _get_item_quality_value(item_data: Resource) -> int:
	var item: ItemData = item_data as ItemData
	if item == null:
		return 0
	return item.get_quality()


func _get_item_rank_text(item_data: Resource) -> String:
	var item: ItemData = item_data as ItemData
	if item == null:
		return "-"
	return item.get_rank_stars()


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
	vbox.anchor_left = 0
	vbox.anchor_top = 0
	vbox.anchor_right = 1
	vbox.anchor_bottom = 1
	vbox.offset_left = 24
	vbox.offset_top = 20
	vbox.offset_right = -24
	vbox.offset_bottom = -20
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.add_theme_constant_override("separation", 10)

	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	earnings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(0, 32)
	close_button.custom_minimum_size = Vector2(0, 40)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.custom_minimum_size = Vector2(898, 230) # 170 * 5 + 12 * 4

	price_spinbox.custom_minimum_size = Vector2(0, 40)
	price_spinbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stock_one_button.custom_minimum_size = Vector2(0, 40)
	take_back_one_button.custom_minimum_size = Vector2(0, 40)
	set_price_button.custom_minimum_size = Vector2(0, 40)
	collect_button.custom_minimum_size = Vector2(0, 40)


func _on_ui_resized() -> void:
	_setup_main_panel()


func _make_slot_stylebox(is_selected: bool, is_hover: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = SLOT_CORNER_RADIUS
	style.corner_radius_top_right = SLOT_CORNER_RADIUS
	style.corner_radius_bottom_right = SLOT_CORNER_RADIUS
	style.corner_radius_bottom_left = SLOT_CORNER_RADIUS
	style.content_margin_left = 12
	style.content_margin_top = 10
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


func _on_slot_pressed(index: int) -> void:
	selected_slot_index = index
	refresh()


func _on_stock_one_pressed() -> void:
	if current_machine == null or current_player == null:
		return

	if selected_slot_index < 0:
		return

	var selected_item_data: Resource = _get_player_selected_item_data(current_player)
	if selected_item_data == null:
		info_label.text = "先にインベントリで商品を選んでくれ"
		_log_error("アイテムデータが見つからない")
		return

	var sell_price: int = int(price_spinbox.value)
	if current_machine.slots[selected_slot_index].is_empty():
		var recommended_price: int = _get_adjusted_sell_price(selected_item_data)
		if recommended_price > 0 and sell_price <= 0:
			sell_price = recommended_price
			price_spinbox.value = sell_price

	var removed_variant: Variant = current_player.call("remove_item_from_inventory", selected_item_data, 1)
	var removed: bool = bool(removed_variant)
	if not removed:
		info_label.text = "在庫が足りない"
		return

	var stocked: bool = current_machine.stock_item(selected_slot_index, selected_item_data, 1, sell_price)
	if not stocked:
		current_player.call("add_item_to_inventory", selected_item_data, 1)
		info_label.text = "そのスロットには別の商品が入ってる"
		return

	info_label.text = "1個補充した"
	_log_shop("%sを %d Cr で販売した" % [_get_item_display_name(selected_item_data), sell_price])
	refresh()


func _on_take_back_one_pressed() -> void:
	if current_machine == null or current_player == null:
		return

	if selected_slot_index < 0:
		return

	var old_price: int = current_machine.peek_slot_price(selected_slot_index)
	var result: Dictionary = current_machine.take_back_item(selected_slot_index, 1)

	var success: bool = bool(result.get("success", false))
	if not success:
		info_label.text = "取り出せない"
		return

	var returned_item: Resource = result.get("item_data", null) as Resource
	var returned_amount: int = int(result.get("amount", 0))

	if returned_item == null or returned_amount <= 0:
		info_label.text = "取り出しデータが不正"
		return

	var add_result_variant: Variant = current_player.call("add_item_to_inventory", returned_item, returned_amount)
	var ok: bool = bool(add_result_variant)
	if not ok:
		current_machine.stock_item(selected_slot_index, returned_item, returned_amount, old_price)
		info_label.text = "インベントリに戻せない"
		return

	info_label.text = "1個取り戻した"
	refresh()


func _on_set_price_pressed() -> void:
	if current_machine == null:
		return

	if selected_slot_index < 0:
		return

	current_machine.set_slot_price(selected_slot_index, int(price_spinbox.value))
	info_label.text = "価格を更新した"
	refresh()


func _on_collect_pressed() -> void:
	if current_machine == null or current_player == null:
		return

	var before: int = current_machine.earnings
	if before <= 0:
		info_label.text = "回収できる売上がない"
		refresh()
		return

	if current_player.has_method("add_credits"):
		current_player.call("add_credits", before)
		current_machine.earnings = 0
		if current_machine.has_method("save_data"):
			current_machine.call("save_data")
		_log_shop("売上 %d Cr を回収した" % before)
		info_label.text = "売上を回収した"
	else:
		info_label.text = "プレイヤーに add_credits がない"
		_log_error("Player に add_credits がない")

	refresh()


func _on_close_pressed() -> void:
	close()


func _on_credits_changed(_value: int) -> void:
	if visible:
		refresh()


func _get_player_credits(player: Node) -> int:
	if player == null:
		return 0

	if player.has_method("get_credits"):
		return int(player.call("get_credits"))

	if CurrencyManager != null and CurrencyManager.has_method("get_credits"):
		return int(CurrencyManager.get_credits())

	return int(player.get("credits"))


func _get_player_selected_item_data(player: Node) -> Resource:
	return player.get("selected_item_data") as Resource


func _get_item_name(item_data: Resource) -> String:
	if item_data == null:
		return "不明"

	var item_name_value: Variant = item_data.get("item_name")
	if item_name_value != null:
		return str(item_name_value)

	var name_value: Variant = item_data.get("name")
	if name_value != null:
		return str(name_value)

	return item_data.resource_name


func _get_item_quality_text(item_data: Resource) -> String:
	var item: ItemData = item_data as ItemData
	if item == null:
		return ""

	return "品質 %d / %s" % [item.get_quality(), item.get_rank_stars()]


func _get_item_display_name(item_data: Resource) -> String:
	var base_name: String = _get_item_name(item_data)
	var quality_text: String = _get_item_quality_text(item_data)

	if quality_text.is_empty():
		return base_name

	return "%s（%s）" % [base_name, quality_text]


func _get_rank_sell_multiplier(rank: int) -> float:
	match clamp(rank, 0, 5):
		1:
			return 1.1
		2:
			return 1.5
		3:
			return 2.0
		4:
			return 3.0
		5:
			return 5.0
		_:
			return 1.0


func _get_adjusted_sell_price(item_data: Resource) -> int:
	var item: ItemData = item_data as ItemData
	if item == null:
		return 0

	var base_price: int = max(int(item.price), 0)
	var quality_bonus: int = int(item.get_quality() / 5)
	var multiplied_price: float = float(base_price + quality_bonus) * _get_rank_sell_multiplier(item.get_rank())
	return max(int(round(multiplied_price)), 0)


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


func _get_inventory_ui() -> Control:
	return get_tree().get_first_node_in_group("inventory_ui") as Control


func _is_inventory_ui_visible() -> bool:
	var inventory_ui: Control = _get_inventory_ui()
	if inventory_ui == null:
		return false
	return inventory_ui.visible


func _ensure_inventory_ui_visible() -> void:
	var inventory_ui: Control = _get_inventory_ui()
	if inventory_ui == null:
		_log_error("InventoryUI が見つからない")
		return

	if inventory_ui.visible:
		return

	inventory_ui.visible = true

	if inventory_ui.has_method("refresh"):
		inventory_ui.call("refresh")


func _hide_inventory_ui() -> void:
	var inventory_ui: Control = _get_inventory_ui()
	if inventory_ui == null:
		return

	inventory_ui.visible = false

	if inventory_ui.has_method("clear_selection"):
		inventory_ui.call("clear_selection")


func _get_message_log() -> Node:
	return get_node_or_null("/root/MessageLog")


func _log_shop(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_message"):
		log_node.call("add_message", text, "SHOP")


func _log_error(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_error"):
		log_node.call("add_error", text)

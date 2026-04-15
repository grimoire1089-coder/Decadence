extends Control
class_name ShopDeliveryBoxUI

const UI_LOCK_SOURCE: String = "ShopDeliveryBoxUI"
const UI_MODAL_MANAGER_SCRIPT_NAME: String = "UIModalManager.gd"
const TIME_MANAGER_SCRIPT_NAME: String = "TimeManager.gd"

const ROOT_DIMMER_COLOR: Color = Color(0.0, 0.0, 0.0, 0.45)
const MAIN_PANEL_BG: Color = Color(0.05, 0.08, 0.12, 0.97)
const MAIN_PANEL_BORDER: Color = Color(0.30, 0.75, 1.0, 0.70)
const PANEL_CORNER_RADIUS: int = 18
const MAIN_PANEL_SIZE: Vector2 = Vector2(1340, 760)
const CARD_NORMAL_BG: Color = Color(0.11, 0.14, 0.18, 0.96)
const CARD_HOVER_BG: Color = Color(0.15, 0.18, 0.24, 0.98)
const CARD_SELECTED_BORDER: Color = Color(1.0, 0.84, 0.0, 1.0)
const CARD_NORMAL_BORDER: Color = Color(0.36, 0.48, 0.62, 0.85)

var current_box: ShopDeliveryBox = null
var current_player: Node = null
var selected_shop_index: int = -1
var selected_product_index: int = -1
var selected_delivery_index: int = -1
var dimmer: ColorRect = null

@onready var panel: Panel = $Panel
@onready var vbox: VBoxContainer = $Panel/VBoxContainer
@onready var title_label: Label = $Panel/VBoxContainer/HeaderRow/HeaderTextBox/TitleLabel
@onready var selected_store_label: Label = $Panel/VBoxContainer/HeaderRow/HeaderTextBox/SelectedStoreLabel
@onready var store_description_label: Label = $Panel/VBoxContainer/HeaderRow/HeaderTextBox/StoreDescriptionLabel
@onready var credits_label: Label = $Panel/VBoxContainer/HeaderRow/HeaderTextBox/CreditsLabel
@onready var pending_label: Label = $Panel/VBoxContainer/HeaderRow/HeaderTextBox/PendingLabel
@onready var close_button: Button = $Panel/VBoxContainer/HeaderRow/CloseButton
@onready var store_list: VBoxContainer = $Panel/VBoxContainer/ContentRow/StoreColumn/StoreScroll/StoreList
@onready var shop_grid: GridContainer = $Panel/VBoxContainer/ContentRow/ShopColumn/ShopScroll/ShopGrid
@onready var delivery_grid: GridContainer = $Panel/VBoxContainer/ContentRow/DeliveryColumn/DeliveryScroll/DeliveryGrid
@onready var order_one_button: Button = $Panel/VBoxContainer/ActionRow/OrderOneButton
@onready var receive_one_button: Button = $Panel/VBoxContainer/ActionRow/ReceiveOneButton
@onready var receive_all_button: Button = $Panel/VBoxContainer/ActionRow/ReceiveAllButton
@onready var info_label: Label = $Panel/VBoxContainer/InfoLabel


func _ready() -> void:
	visible = false
	add_to_group("shop_delivery_ui")
	add_to_group("shop_ui")

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	_setup_root_layout()
	_setup_dimmer()
	_setup_main_panel()
	_setup_content_layout()

	order_one_button.pressed.connect(_on_order_one_pressed)
	receive_one_button.pressed.connect(_on_receive_one_pressed)
	receive_all_button.pressed.connect(_on_receive_all_pressed)
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


func open_box(box: ShopDeliveryBox, player: Node) -> void:
	current_box = box
	current_player = player
	selected_shop_index = box.get_default_shop_index()
	selected_product_index = 0
	selected_delivery_index = 0

	visible = true
	move_to_front()
	_acquire_ui_lock()
	refresh()


func close() -> void:
	visible = false
	_release_ui_lock()

	current_box = null
	current_player = null
	selected_shop_index = -1
	selected_product_index = -1
	selected_delivery_index = -1
	info_label.text = ""


func refresh() -> void:
	if current_box == null:
		return

	title_label.text = current_box.get_object_display_name()
	selected_store_label.text = "選択中店舗: %s" % current_box.get_store_name(selected_shop_index)
	store_description_label.text = current_box.get_shop_description(selected_shop_index)
	credits_label.text = "所持金: %d Cr" % _get_player_credits(current_player)
	pending_label.text = "配送中: %d個 / 受け取り待ち: %d種類" % [
		current_box.get_pending_order_count(),
		current_box.get_delivery_entries().size()
	]

	_rebuild_store_list()
	_rebuild_shop_grid()
	_rebuild_delivery_grid()
	_update_button_state()


func _rebuild_store_list() -> void:
	for child in store_list.get_children():
		store_list.remove_child(child)
		child.queue_free()

	if current_box == null:
		return

	var shop_count: int = current_box.get_shop_count()
	if shop_count <= 0:
		var empty_label: Label = Label.new()
		empty_label.text = "店舗が登録されていない"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(220, 64)
		store_list.add_child(empty_label)
		selected_shop_index = -1
		return

	selected_shop_index = clamp(selected_shop_index, 0, shop_count - 1)

	for i in range(shop_count):
		var button: Button = _make_store_button(i == selected_shop_index)
		var root: VBoxContainer = _make_store_button_content(button)
		root.add_child(_make_center_label(current_box.get_store_name(i), 15, true))

		var description: String = current_box.get_shop_description(i)
		if not description.is_empty():
			root.add_child(_make_center_label(description, 12, false))

		button.pressed.connect(_on_store_pressed.bind(i))
		store_list.add_child(button)


func _rebuild_shop_grid() -> void:
	for child in shop_grid.get_children():
		shop_grid.remove_child(child)
		child.queue_free()

	if current_box == null or selected_shop_index < 0:
		selected_product_index = -1
		return

	var products: Array[ShopProduct] = current_box.get_products(selected_shop_index)
	if products.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "商品が登録されていない"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(420, 64)
		shop_grid.add_child(empty_label)
		selected_product_index = -1
		return

	selected_product_index = clamp(selected_product_index, 0, products.size() - 1)

	for i in range(products.size()):
		var product: ShopProduct = products[i]
		var button: Button = _make_card_button(i == selected_product_index)
		_populate_product_button(button, product)
		button.pressed.connect(_on_product_pressed.bind(i))
		shop_grid.add_child(button)


func _rebuild_delivery_grid() -> void:
	for child in delivery_grid.get_children():
		delivery_grid.remove_child(child)
		child.queue_free()

	if current_box == null:
		return

	var entries: Array[Dictionary] = current_box.get_delivery_entries()
	if entries.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "受け取り待ちの商品はない"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.custom_minimum_size = Vector2(420, 64)
		delivery_grid.add_child(empty_label)
		selected_delivery_index = -1
		return

	selected_delivery_index = clamp(selected_delivery_index, 0, entries.size() - 1)

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var button: Button = _make_card_button(i == selected_delivery_index)
		_populate_delivery_button(button, entry)
		button.pressed.connect(_on_delivery_pressed.bind(i))
		delivery_grid.add_child(button)


func _populate_product_button(button: Button, product: ShopProduct) -> void:
	var root: VBoxContainer = _make_card_content(button)
	var item_data: ItemData = product.get_item_data()

	root.add_child(_make_center_label(product.get_display_name(), 16, true))

	var icon_rect: TextureRect = _make_icon(item_data)
	if icon_rect != null:
		root.add_child(icon_rect)

	root.add_child(_make_center_label("価格: %d Cr" % product.get_unit_price(), 14, false))
	root.add_child(_make_center_label("購入数: %d個" % max(product.amount_per_purchase, 1), 14, false))

	if item_data != null:
		root.add_child(_make_center_label("品質: %d" % item_data.get_quality(), 13, false))
		root.add_child(_make_center_label("ランク: %s" % item_data.get_rank_stars(), 13, false))


func _populate_delivery_button(button: Button, entry: Dictionary) -> void:
	var root: VBoxContainer = _make_card_content(button)
	var item_data: ItemData = entry.get("item_data", null) as ItemData
	var count: int = int(entry.get("count", 0))

	root.add_child(_make_center_label(_get_item_name(item_data), 16, true))

	var icon_rect: TextureRect = _make_icon(item_data)
	if icon_rect != null:
		root.add_child(icon_rect)

	root.add_child(_make_center_label("個数: %d個" % count, 14, false))

	if item_data != null:
		root.add_child(_make_center_label("品質: %d" % item_data.get_quality(), 13, false))
		root.add_child(_make_center_label("ランク: %s" % item_data.get_rank_stars(), 13, false))


func _make_store_button(selected: bool) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(220, 74)
	button.text = ""
	button.clip_contents = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_stylebox_override("normal", _make_store_stylebox(selected, false))
	button.add_theme_stylebox_override("hover", _make_store_stylebox(selected, true))
	button.add_theme_stylebox_override("pressed", _make_store_stylebox(selected, true))
	button.add_theme_stylebox_override("focus", _make_store_stylebox(selected, true))
	return button


func _make_store_button_content(button: Button) -> VBoxContainer:
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10
	root.offset_top = 8
	root.offset_right = -10
	root.offset_bottom = -8
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 3)
	button.add_child(root)
	return root


func _make_card_button(selected: bool) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(220, 250)
	button.text = ""
	button.clip_contents = true
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	button.add_theme_stylebox_override("normal", _make_card_stylebox(selected, false))
	button.add_theme_stylebox_override("hover", _make_card_stylebox(selected, true))
	button.add_theme_stylebox_override("pressed", _make_card_stylebox(selected, true))
	button.add_theme_stylebox_override("focus", _make_card_stylebox(selected, true))
	return button


func _make_card_content(button: Button) -> VBoxContainer:
	var root: VBoxContainer = VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 10
	root.offset_top = 10
	root.offset_right = -10
	root.offset_bottom = -10
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 4)
	button.add_child(root)
	return root


func _make_center_label(text: String, font_size: int, strong: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE if strong else Color(0.90, 0.94, 1.0))
	return label


func _make_icon(item_data: ItemData) -> TextureRect:
	if item_data == null or item_data.icon == null:
		return null

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = item_data.icon
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.custom_minimum_size = Vector2(80, 80)
	icon_rect.size = Vector2(80, 80)
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon_rect


func _make_store_stylebox(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_HOVER_BG if hovered else CARD_NORMAL_BG
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = CARD_SELECTED_BORDER if selected else CARD_NORMAL_BORDER
	return style


func _make_card_stylebox(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_HOVER_BG if hovered else CARD_NORMAL_BG
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = CARD_SELECTED_BORDER if selected else CARD_NORMAL_BORDER
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 8
	return style


func _update_button_state() -> void:
	var can_order: bool = current_box != null and selected_shop_index >= 0 and selected_product_index >= 0
	var can_receive_one: bool = current_box != null and selected_delivery_index >= 0 and current_box.get_delivery_entries().size() > 0
	var can_receive_all: bool = current_box != null and not current_box.get_delivery_entries().is_empty()

	order_one_button.disabled = not can_order
	receive_one_button.disabled = not can_receive_one
	receive_all_button.disabled = not can_receive_all


func _on_store_pressed(index: int) -> void:
	selected_shop_index = index
	selected_product_index = 0
	refresh()


func _on_product_pressed(index: int) -> void:
	selected_product_index = index
	refresh()


func _on_delivery_pressed(index: int) -> void:
	selected_delivery_index = index
	refresh()


func _on_order_one_pressed() -> void:
	if current_box == null or current_player == null or selected_product_index < 0:
		return

	var result: Dictionary = current_box.place_order(current_player, selected_product_index, 1, selected_shop_index)
	info_label.text = str(result.get("message", ""))
	refresh()


func _on_receive_one_pressed() -> void:
	if current_box == null or current_player == null or selected_delivery_index < 0:
		return

	var result: Dictionary = current_box.claim_delivery_entry(current_player, selected_delivery_index, 1)
	info_label.text = str(result.get("message", ""))
	refresh()


func _on_receive_all_pressed() -> void:
	if current_box == null or current_player == null:
		return

	var result: Dictionary = current_box.claim_all_delivery(current_player)
	info_label.text = str(result.get("message", ""))
	refresh()


func _on_close_pressed() -> void:
	close()


func _on_credits_changed(_value: int) -> void:
	if visible:
		refresh()


func _on_ui_resized() -> void:
	_apply_centered_panel_layout()


func _get_item_name(item_data: ItemData) -> String:
	if item_data == null:
		return "不明"
	if not item_data.item_name.is_empty():
		return item_data.item_name
	if not str(item_data.id).is_empty():
		return str(item_data.id)
	return "不明"


func _setup_root_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0
	z_index = 420


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
	_apply_centered_panel_layout()

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


func _apply_centered_panel_layout() -> void:
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


func _setup_content_layout() -> void:
	vbox.add_theme_constant_override("separation", 14)
	store_list.add_theme_constant_override("separation", 8)
	shop_grid.columns = 2
	delivery_grid.columns = 2

	store_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _get_player_credits(player: Node) -> int:
	if player == null:
		return 0

	if player.has_method("get_credits"):
		return int(player.call("get_credits"))

	return 0


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

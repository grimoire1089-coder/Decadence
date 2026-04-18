extends PanelContainer
class_name InventoryTooltip

@onready var margin_container: MarginContainer = $MarginContainer
@onready var vbox: VBoxContainer = $MarginContainer/VBoxContainer
@onready var name_label: Label = $MarginContainer/VBoxContainer/ItemNameLabel
@onready var icon_rect: TextureRect = $MarginContainer/VBoxContainer/IconBox/IconRect
@onready var count_label: Label = $MarginContainer/VBoxContainer/CountLabel
@onready var quality_label: Label = $MarginContainer/VBoxContainer/QualityLabel
@onready var rank_label: Label = $MarginContainer/VBoxContainer/RankLabel
@onready var buy_price_label: Label = get_node_or_null("MarginContainer/VBoxContainer/BuyPriceLabel")
@onready var sell_price_label: Label = $MarginContainer/VBoxContainer/SellPriceLabel
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var label_chip_flow: HFlowContainer = $MarginContainer/VBoxContainer/LabelChipFlow

const TOOLTIP_BG: Color = Color(0.08, 0.10, 0.14, 0.96)
const TOOLTIP_BORDER: Color = Color(0.30, 0.75, 1.0, 0.70)
const TOOLTIP_RADIUS: int = 16

const CHIP_TEXT_COLOR: Color = Color(0.95, 0.98, 1.0, 1.0)
const CHIP_BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.14)

const CHIP_BG_TAG: Color = Color(0.17, 0.42, 0.75, 0.95)
const CHIP_BG_TRAIT: Color = Color(0.52, 0.25, 0.72, 0.95)
const CHIP_BG_OTHER: Color = Color(0.28, 0.32, 0.38, 0.95)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_apply_tooltip_theme()
	hide_tooltip()


func show_item(item_data: ItemData, count: int = 0) -> void:
	if item_data == null:
		hide_tooltip()
		return

	visible = true

	name_label.text = item_data.item_name
	icon_rect.texture = item_data.icon
	count_label.text = "所持数: %d" % count
	quality_label.text = "品質: %d" % item_data.get_quality()
	rank_label.text = "ランク: %s" % item_data.get_rank_stars()
	if buy_price_label != null:
		buy_price_label.visible = false
	sell_price_label.text = "売値: %d Cr" % item_data.get_sell_price()
	description_label.text = item_data.description

	_rebuild_label_chips(item_data)

	update_minimum_size()
	reset_size()
	queue_redraw()
	show()


func hide_tooltip() -> void:
	visible = false


func _apply_tooltip_theme() -> void:
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = TOOLTIP_BG
	panel_style.border_color = TOOLTIP_BORDER
	panel_style.corner_radius_top_left = TOOLTIP_RADIUS
	panel_style.corner_radius_top_right = TOOLTIP_RADIUS
	panel_style.corner_radius_bottom_right = TOOLTIP_RADIUS
	panel_style.corner_radius_bottom_left = TOOLTIP_RADIUS
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	panel_style.shadow_size = 12
	add_theme_stylebox_override("panel", panel_style)

	if margin_container != null:
		margin_container.add_theme_constant_override("margin_left", 16)
		margin_container.add_theme_constant_override("margin_top", 16)
		margin_container.add_theme_constant_override("margin_right", 16)
		margin_container.add_theme_constant_override("margin_bottom", 16)

	if vbox != null:
		vbox.add_theme_constant_override("separation", 8)

	if name_label != null:
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if count_label != null:
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if quality_label != null:
		quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if rank_label != null:
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if buy_price_label != null:
		buy_price_label.visible = false
	if sell_price_label != null:
		sell_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if description_label != null:
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.size_flags_horizontal = Control.SIZE_FILL
		description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	if label_chip_flow != null:
		label_chip_flow.size_flags_horizontal = Control.SIZE_FILL
		label_chip_flow.add_theme_constant_override("h_separation", 8)
		label_chip_flow.add_theme_constant_override("v_separation", 8)


func _rebuild_label_chips(item_data: ItemData) -> void:
	if label_chip_flow == null:
		return

	for child in label_chip_flow.get_children():
		child.queue_free()

	if item_data == null:
		return

	var labels: Array = item_data.get_valid_labels()
	for label_obj in labels:
		var label_res: ItemTag = label_obj as ItemTag
		if label_res == null:
			continue
		label_chip_flow.add_child(_create_label_chip(label_res))

	label_chip_flow.queue_sort()


func _create_label_chip(label_res: ItemTag) -> Control:
	var chip_panel: PanelContainer = PanelContainer.new()
	chip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	chip_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var chip_style: StyleBoxFlat = StyleBoxFlat.new()
	chip_style.bg_color = _get_chip_color(label_res)
	chip_style.border_color = CHIP_BORDER_COLOR
	chip_style.corner_radius_top_left = 12
	chip_style.corner_radius_top_right = 12
	chip_style.corner_radius_bottom_right = 12
	chip_style.corner_radius_bottom_left = 12
	chip_style.border_width_left = 1
	chip_style.border_width_top = 1
	chip_style.border_width_right = 1
	chip_style.border_width_bottom = 1
	chip_style.content_margin_left = 10
	chip_style.content_margin_right = 10
	chip_style.content_margin_top = 5
	chip_style.content_margin_bottom = 5
	chip_panel.add_theme_stylebox_override("panel", chip_style)

	var text_label: Label = Label.new()
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.text = label_res.get_display_name()
	text_label.add_theme_color_override("font_color", CHIP_TEXT_COLOR)
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip_panel.add_child(text_label)

	return chip_panel


func _get_chip_color(label_res: ItemTag) -> Color:
	if label_res == null:
		return CHIP_BG_OTHER

	match String(label_res.category):
		"tag":
			return CHIP_BG_TAG
		"trait":
			return CHIP_BG_TRAIT
		_:
			return CHIP_BG_OTHER

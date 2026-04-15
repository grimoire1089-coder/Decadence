extends Panel

@onready var icon_rect: TextureRect = $TextureRect
@onready var count_label: Label = $CountLabel

var is_selected: bool = false
var normal_style: StyleBoxFlat
var selected_style: StyleBoxFlat
var current_item_data: ItemData = null

func _ready() -> void:
	top_level = false
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2(72, 72)
	custom_minimum_size = Vector2(72, 72)
	mouse_filter = Control.MOUSE_FILTER_STOP
	icon_rect.top_level = false
	icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_left = 8.0
	icon_rect.offset_top = 8.0
	icon_rect.offset_right = -8.0
	icon_rect.offset_bottom = -8.0
	icon_rect.visible = true
	icon_rect.modulate = Color.WHITE
	icon_rect.self_modulate = Color.WHITE
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	count_label.top_level = false
	count_label.anchor_left = 0.0
	count_label.anchor_top = 1.0
	count_label.anchor_right = 1.0
	count_label.anchor_bottom = 1.0
	count_label.offset_left = 4.0
	count_label.offset_top = -22.0
	count_label.offset_right = -4.0
	count_label.offset_bottom = -4.0
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.visible = true
	count_label.modulate = Color.WHITE
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_styles()
	_apply_style()

func _build_styles() -> void:
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.12, 0.12, 0.12, 0.90)
	normal_style.border_color = Color(0.35, 0.35, 0.35, 1.0)
	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.content_margin_left = 2
	normal_style.content_margin_top = 2
	normal_style.content_margin_right = 2
	normal_style.content_margin_bottom = 2

	selected_style = normal_style.duplicate()
	selected_style.bg_color = Color(0.18, 0.18, 0.18, 0.95)
	selected_style.border_color = Color(1.0, 0.85, 0.20, 1.0)
	selected_style.border_width_left = 3
	selected_style.border_width_top = 3
	selected_style.border_width_right = 3
	selected_style.border_width_bottom = 3

func set_selected(value: bool) -> void:
	is_selected = value
	_apply_style()

func set_entry(entry: InventoryEntry) -> void:
	if entry == null or entry.item_data == null:
		current_item_data = null
		icon_rect.texture = null
		count_label.text = ""
		icon_rect.visible = false
		set_selected(false)
		return

	current_item_data = entry.item_data
	icon_rect.texture = entry.item_data.icon
	icon_rect.visible = icon_rect.texture != null

	if entry.count > 1:
		count_label.text = str(entry.count)
	else:
		count_label.text = "1"

func has_item_data(item_data: ItemData) -> bool:
	return current_item_data != null and current_item_data == item_data

func _apply_style() -> void:
	if is_selected:
		add_theme_stylebox_override("panel", selected_style)
	else:
		add_theme_stylebox_override("panel", normal_style)

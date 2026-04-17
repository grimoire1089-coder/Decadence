extends RefCounted
class_name CropMachineSlotGridModule

var ui: CropMachineUI = null


func setup(owner_ui: CropMachineUI) -> void:
	ui = owner_ui


func get_slot_cell_height() -> int:
	if ui == null:
		return 0
	return ui.SLOT_BUTTON_HEIGHT + ui.SLOT_CELL_SEPARATION + ui.SLOT_UPGRADE_BUTTON_HEIGHT


func refresh_slot_grid() -> void:
	if ui == null or ui.current_machine == null:
		return

	ui.grid.columns = ui.SLOT_COLUMNS_PER_PAGE
	_clear_grid()

	var total_slots: int = ui.current_machine.slots.size()
	if total_slots <= 0:
		ui.selected_slot_index = -1
		ui.current_page_index = 0
		ui.info_label.text = "スロットがない"
		update_page_controls(0)
		ui._update_action_buttons()
		return

	ui.selected_slot_index = clamp(ui.selected_slot_index, 0, total_slots - 1)
	sync_page_to_selected_slot(total_slots)

	var start_index: int = ui.current_page_index * ui.SLOTS_PER_PAGE
	var end_index: int = min(start_index + ui.SLOTS_PER_PAGE, total_slots)

	for i in range(start_index, end_index):
		var is_selected: bool = i == ui.selected_slot_index
		var slot_cell: VBoxContainer = VBoxContainer.new()
		slot_cell.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_cell.add_theme_constant_override("separation", ui.SLOT_CELL_SEPARATION)
		slot_cell.custom_minimum_size = Vector2(ui.SLOT_BUTTON_WIDTH, get_slot_cell_height())
		slot_cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		var button: Button = Button.new()
		var harvest_item: ItemData = ui.current_machine.get_slot_harvest_item(i)
		var slot_icon: Texture2D = null
		var has_icon: bool = false

		if harvest_item != null and harvest_item.icon != null:
			slot_icon = harvest_item.icon
			has_icon = true

		button.custom_minimum_size = Vector2(ui.SLOT_BUTTON_WIDTH, ui.SLOT_BUTTON_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.clip_contents = true

		var slot_text: String = format_slot_text_for_ui(ui.current_machine.get_slot_status_text(i))
		if has_icon:
			button.text = slot_text
		else:
			button.text = "[%d]\n%s" % [i + 1, slot_text]

		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_stylebox_override("normal", make_slot_stylebox(is_selected, false, has_icon))
		button.add_theme_stylebox_override("hover", make_slot_stylebox(is_selected, true, has_icon))
		button.add_theme_stylebox_override("pressed", make_slot_stylebox(is_selected, true, has_icon))
		button.add_theme_stylebox_override("focus", make_slot_stylebox(is_selected, true, has_icon))
		button.add_theme_stylebox_override("disabled", make_slot_stylebox(is_selected, false, has_icon))

		if is_selected:
			button.add_theme_color_override("font_color", Color.WHITE)
			button.add_theme_color_override("font_hover_color", Color.WHITE)
			button.add_theme_color_override("font_pressed_color", Color.WHITE)
			button.add_theme_color_override("font_focus_color", Color.WHITE)

		if slot_icon != null:
			add_slot_icon(button, slot_icon)

		button.pressed.connect(Callable(self, "on_slot_pressed").bind(i))
		slot_cell.add_child(button)

		var upgrade_button: Button = Button.new()
		upgrade_button.text = ui.SLOT_UPGRADE_BUTTON_TEXT
		upgrade_button.custom_minimum_size = Vector2(ui.SLOT_BUTTON_WIDTH, ui.SLOT_UPGRADE_BUTTON_HEIGHT)
		upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upgrade_button.pressed.connect(Callable(ui, "_on_open_slot_upgrade_pressed").bind(i))
		slot_cell.add_child(upgrade_button)

		ui.grid.add_child(slot_cell)

	for _dummy_index in range(end_index - start_index, ui.SLOTS_PER_PAGE):
		var placeholder: Control = Control.new()
		placeholder.custom_minimum_size = Vector2(ui.SLOT_BUTTON_WIDTH, get_slot_cell_height())
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.grid.add_child(placeholder)

	update_page_controls(total_slots)
	ui._update_selected_slot_info()
	ui._update_action_buttons()


func format_slot_text_for_ui(slot_text: String) -> String:
	if slot_text.is_empty():
		return slot_text

	var lines: PackedStringArray = slot_text.split("\n")
	for i in range(lines.size()):
		var line: String = lines[i]
		if line.contains("現在:") and line.contains("%"):
			var parts: PackedStringArray = line.split(" / ")
			if parts.size() > 0:
				lines[i] = parts[0]
	return "\n".join(lines)


func make_slot_stylebox(is_selected: bool, is_hover: bool, has_icon: bool = false) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = ui.SLOT_CORNER_RADIUS
	style.corner_radius_top_right = ui.SLOT_CORNER_RADIUS
	style.corner_radius_bottom_right = ui.SLOT_CORNER_RADIUS
	style.corner_radius_bottom_left = ui.SLOT_CORNER_RADIUS
	style.content_margin_left = 12
	style.content_margin_top = ui.SLOT_CONTENT_TOP_WITH_ICON if has_icon else 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10

	if is_selected:
		style.bg_color = ui.SLOT_BG_SELECTED_HOVER if is_hover else ui.SLOT_BG_SELECTED
		style.border_color = ui.SLOT_SELECTED_BORDER_COLOR
		style.border_width_left = ui.SLOT_SELECTED_BORDER_WIDTH
		style.border_width_top = ui.SLOT_SELECTED_BORDER_WIDTH
		style.border_width_right = ui.SLOT_SELECTED_BORDER_WIDTH
		style.border_width_bottom = ui.SLOT_SELECTED_BORDER_WIDTH
	else:
		style.bg_color = ui.SLOT_BG_HOVER if is_hover else ui.SLOT_BG_NORMAL
		style.border_color = ui.SLOT_BORDER_HOVER if is_hover else ui.SLOT_BORDER_NORMAL
		style.border_width_left = ui.SLOT_NORMAL_BORDER_WIDTH
		style.border_width_top = ui.SLOT_NORMAL_BORDER_WIDTH
		style.border_width_right = ui.SLOT_NORMAL_BORDER_WIDTH
		style.border_width_bottom = ui.SLOT_NORMAL_BORDER_WIDTH

	return style


func add_slot_icon(button: Button, icon_texture: Texture2D) -> void:
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

	icon_rect.offset_left = -ui.SLOT_ICON_SIZE * 0.5
	icon_rect.offset_top = ui.SLOT_ICON_TOP_OFFSET
	icon_rect.offset_right = ui.SLOT_ICON_SIZE * 0.5
	icon_rect.offset_bottom = ui.SLOT_ICON_TOP_OFFSET + ui.SLOT_ICON_SIZE

	button.add_child(icon_rect)


func get_total_pages(total_slots: int) -> int:
	if total_slots <= 0:
		return 1
	return int(ceil(float(total_slots) / float(ui.SLOTS_PER_PAGE)))


func sync_page_to_selected_slot(total_slots: int = -1) -> void:
	if ui == null:
		return
	if ui.current_machine == null:
		ui.current_page_index = 0
		return

	if total_slots < 0:
		total_slots = ui.current_machine.slots.size()

	var total_pages: int = get_total_pages(total_slots)
	ui.current_page_index = clamp(ui.current_page_index, 0, max(total_pages - 1, 0))

	if ui.selected_slot_index < 0 or ui.selected_slot_index >= total_slots:
		return

	var selected_page: int = int(ui.selected_slot_index / ui.SLOTS_PER_PAGE)
	ui.current_page_index = clamp(selected_page, 0, max(total_pages - 1, 0))


func select_first_slot_on_current_page() -> void:
	if ui == null:
		return
	if ui.current_machine == null:
		ui.selected_slot_index = -1
		return

	var total_slots: int = ui.current_machine.slots.size()
	if total_slots <= 0:
		ui.selected_slot_index = -1
		return

	var start_index: int = ui.current_page_index * ui.SLOTS_PER_PAGE
	ui.selected_slot_index = clamp(start_index, 0, total_slots - 1)


func update_page_controls(total_slots: int) -> void:
	if ui == null or ui.page_navigation_row == null:
		return

	var total_pages: int = get_total_pages(total_slots)
	var has_multiple_pages: bool = total_pages > 1
	ui.page_navigation_row.visible = has_multiple_pages

	if ui.page_label != null:
		ui.page_label.text = "ページ %d / %d" % [ui.current_page_index + 1, total_pages]

	if ui.prev_page_button != null:
		ui.prev_page_button.disabled = not has_multiple_pages or ui.current_page_index <= 0

	if ui.next_page_button != null:
		ui.next_page_button.disabled = not has_multiple_pages or ui.current_page_index >= total_pages - 1


func on_prev_page_pressed() -> void:
	if ui == null or ui.current_machine == null:
		return
	if ui.current_page_index <= 0:
		return

	ui.current_page_index -= 1
	select_first_slot_on_current_page()
	ui.refresh()


func on_next_page_pressed() -> void:
	if ui == null or ui.current_machine == null:
		return

	var total_pages: int = get_total_pages(ui.current_machine.slots.size())
	if ui.current_page_index >= total_pages - 1:
		return

	ui.current_page_index += 1
	select_first_slot_on_current_page()
	ui.refresh()


func on_slot_pressed(index: int) -> void:
	if ui == null:
		return
	ui.selected_slot_index = index
	ui.refresh()


func _clear_grid() -> void:
	if ui == null or ui.grid == null:
		return
	for child in ui.grid.get_children():
		ui.grid.remove_child(child)
		child.queue_free()

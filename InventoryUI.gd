extends Control

@export var slot_scene: PackedScene
@export var item_db: Array = []
@export var item_data_folders: PackedStringArray = ["res://Data/Items/Item_defs"]

@onready var panel: Control = $Panel
@onready var grid: GridContainer = $Panel/ScrollContainer/GridContainer
@onready var tooltip: Control = $InventoryTooltip

var items: Array = []
var item_map: Dictionary = {}
var selected_item_data: ItemData = null
@export var persistent_id: String = "inventory_ui"
@export var add_debug_start_items: bool = false
var _boot_initialized: bool = false

const PANEL_BG: Color = Color(0.05, 0.08, 0.12, 0.94)
const PANEL_BORDER: Color = Color(0.30, 0.75, 1.0, 0.70)
const PANEL_RADIUS: int = 16

const TOOLTIP_TOP_MARGIN := 16
const GRID_COLUMNS := 5
const GRID_ROWS := 4
const MIN_VISIBLE_SLOTS := GRID_COLUMNS * GRID_ROWS
const SLOT_SIZE := 72

func _ready() -> void:
	add_to_group("inventory_ui")
	add_to_group("save_persistent")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Panel.mouse_filter = Control.MOUSE_FILTER_STOP

	z_index = 300
	panel.z_index = 301
	tooltip.z_index = 302

	grid.columns = GRID_COLUMNS
	_apply_inventory_theme()
	_update_grid_size()
	_hide_tooltip_immediately()
	boot_initialize()


func boot_initialize() -> void:
	if _boot_initialized:
		return
	_boot_initialized = true
	grid.columns = GRID_COLUMNS
	_update_grid_size()
	_load_items_from_folders()
	_rebuild_item_map()
	if add_debug_start_items:
		add_item_by_id("apple", 1)
		add_item_by_id("avocado", 1)
		add_item_by_id("lemon", 1)
		add_item_by_id("mangosteen", 1)
		add_item_by_id("orange", 1)
		add_item_by_id("peach", 1)
		add_item_by_id("seed_potato", 100)
		add_item_by_id("seed_wheat", 100)
	refresh()


func get_persistent_save_id() -> String:
	return persistent_id.strip_edges()


func export_save_data() -> Dictionary:
	var entries: Array = []
	for entry_obj in items:
		var entry: InventoryEntry = entry_obj as InventoryEntry
		if entry == null or entry.item_data == null:
			continue
		entries.append({
			"item_id": String(entry.item_data.id),
			"count": entry.count,
		})
	return {
		"entries": entries,
		"selected_item_id": "" if selected_item_data == null else String(selected_item_data.id),
	}


func import_save_data(data: Dictionary) -> void:
	boot_initialize()
	items.clear()
	selected_item_data = null

	var entries: Array = data.get("entries", []) as Array
	for row_obj in entries:
		if typeof(row_obj) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_obj as Dictionary
		var item_id: String = String(row.get("item_id", "")).strip_edges()
		var count: int = int(row.get("count", 0))
		if item_id.is_empty() or count <= 0:
			continue
		var item_data: ItemData = item_map.get(item_id, null) as ItemData
		if item_data == null:
			continue
		items.append(InventoryEntry.new(item_data, count))

	var selected_id: String = String(data.get("selected_item_id", "")).strip_edges()
	if not selected_id.is_empty():
		selected_item_data = item_map.get(selected_id, null) as ItemData

	refresh()


func _load_items_from_folders() -> void:
	var loaded_by_id: Dictionary = {}

	for item in item_db:
		if item == null:
			continue
		loaded_by_id[item.id] = item

	for folder_path in item_data_folders:
		_load_item_data_from_folder_recursive(folder_path, loaded_by_id)

func _load_item_data_from_folder_recursive(folder_path: String, loaded_by_id: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(folder_path)
	if dir == null:
		push_warning("アイテムフォルダを開けない: " + folder_path)
		return

	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name == "":
			break

		if file_name.begins_with("."):
			continue

		var full_path: String = folder_path.path_join(file_name)

		if dir.current_is_dir():
			_load_item_data_from_folder_recursive(full_path, loaded_by_id)
			continue

		if not file_name.ends_with(".tres"):
			continue

		var res: Resource = load(full_path)
		if res is ItemData:
			var item_data: ItemData = res as ItemData
			if item_data != null and str(item_data.id) != "":
				loaded_by_id[item_data.id] = item_data

	dir.list_dir_end()

	item_db.clear()
	for value in loaded_by_id.values():
		item_db.append(value)


func _update_grid_size() -> void:
	if grid == null:
		return

	var h_sep: int = grid.get_theme_constant("h_separation")
	var v_sep: int = grid.get_theme_constant("v_separation")
	var width: int = SLOT_SIZE * GRID_COLUMNS + h_sep * max(GRID_COLUMNS - 1, 0)
	var height: int = SLOT_SIZE * GRID_ROWS + v_sep * max(GRID_ROWS - 1, 0)
	grid.custom_minimum_size = Vector2(width, height)

func _rebuild_item_map() -> void:
	item_map.clear()

	for item in item_db:
		if item == null:
			continue
		item_map[item.id] = item

func refresh() -> void:
	grid.columns = GRID_COLUMNS
	_update_grid_size()

	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	var selection_exists := false

	for entry_obj in items:
		var entry: InventoryEntry = entry_obj
		var slot: Control = slot_scene.instantiate() as Control
		if slot == null:
			push_error("slot_scene のルートが Control / Panel じゃない")
			_log_error("slot_scene のルートが Control / Panel じゃない")
			continue

		slot.top_level = false
		slot.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		slot.position = Vector2.ZERO
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)

		grid.add_child(slot)

		if slot.has_method("set_entry"):
			slot.call("set_entry", entry)
		else:
			push_error("slot に set_entry() がない")
			_log_error("slot に set_entry() がない")

		if slot.has_method("set_selected"):
			var is_selected := selected_item_data != null and entry.item_data == selected_item_data
			slot.call("set_selected", is_selected)
			if is_selected:
				selection_exists = true

		slot.gui_input.connect(_on_slot_gui_input.bind(entry.item_data))

	var visible_slot_count: int = int(max(items.size(), MIN_VISIBLE_SLOTS))
	var remainder: int = visible_slot_count % GRID_COLUMNS
	if remainder != 0:
		visible_slot_count += GRID_COLUMNS - remainder

	var empty_slot_count: int = int(max(visible_slot_count - items.size(), 0))
	for i in range(empty_slot_count):
		var empty_slot: Control = slot_scene.instantiate() as Control
		if empty_slot == null:
			push_error("slot_scene のルートが Control / Panel じゃない")
			_log_error("slot_scene のルートが Control / Panel じゃない")
			continue

		empty_slot.top_level = false
		empty_slot.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		empty_slot.position = Vector2.ZERO
		empty_slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		empty_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

		grid.add_child(empty_slot)

		if empty_slot.has_method("set_entry"):
			empty_slot.call("set_entry", null)
		if empty_slot.has_method("set_selected"):
			empty_slot.call("set_selected", false)

	if selected_item_data != null and not selection_exists:
		selected_item_data = null

	_sync_player_selected_item()
	_update_tooltip_for_selection()

func _can_stack_item(entry_item: ItemData, incoming_item: ItemData) -> bool:
	if entry_item == null or incoming_item == null:
		return false

	var entry_id: String = str(entry_item.id)
	var incoming_id: String = str(incoming_item.id)
	if not entry_id.is_empty() or not incoming_id.is_empty():
		if entry_id != incoming_id:
			return false
	else:
		var entry_path: String = String(entry_item.resource_path)
		var incoming_path: String = String(incoming_item.resource_path)
		if entry_path != incoming_path and entry_item != incoming_item:
			return false

	if entry_item.get_quality() != incoming_item.get_quality():
		return false
	if entry_item.get_rank() != incoming_item.get_rank():
		return false
	return true


func add_item(item_data: ItemData, amount: int = 1) -> bool:
	if item_data == null:
		push_error("add_item: item_data が null")
		_log_error("アイテムデータが見つからない")
		return false

	for entry_obj in items:
		var entry: InventoryEntry = entry_obj
		if _can_stack_item(entry.item_data, item_data):
			entry.count += amount
			refresh()
			return true

	items.append(InventoryEntry.new(item_data, amount))
	refresh()
	return true

func add_item_by_id(item_id: StringName, amount: int = 1) -> bool:
	if not item_map.has(item_id):
		push_error("item_id が見つからない: " + str(item_id))
		_log_error("アイテムデータが見つからない")
		return false

	return add_item(item_map[item_id], amount)

func remove_item(item_data: ItemData, amount: int = 1) -> bool:
	if item_data == null:
		_log_error("アイテムデータが見つからない")
		return false

	if amount <= 0:
		return false

	for i in range(items.size()):
		var entry: InventoryEntry = items[i]
		if _can_stack_item(entry.item_data, item_data):
			if entry.count < amount:
				return false

			entry.count -= amount

			if entry.count <= 0:
				items.remove_at(i)
				if selected_item_data == item_data:
					selected_item_data = null

			refresh()
			return true

	return false

func remove_item_by_id(item_id: StringName, amount: int = 1) -> bool:
	if not item_map.has(item_id):
		push_error("remove_item_by_id: item_id が見つからない: " + str(item_id))
		_log_error("アイテムデータが見つからない")
		return false
	if amount <= 0:
		return false
	if get_item_count(item_id) < amount:
		return false

	var remaining: int = amount
	var index: int = 0
	while index < items.size() and remaining > 0:
		var entry: InventoryEntry = items[index]
		if entry.item_data != null and entry.item_data.id == item_id:
			var remove_count: int = min(entry.count, remaining)
			entry.count -= remove_count
			remaining -= remove_count

			if entry.count <= 0:
				if selected_item_data == entry.item_data:
					selected_item_data = null
				items.remove_at(index)
				continue

		index += 1

	refresh()
	return remaining <= 0

func has_item(item_id: StringName) -> bool:
	if not item_map.has(item_id):
		return false

	for entry_obj in items:
		var entry: InventoryEntry = entry_obj
		if entry.item_data != null and entry.item_data.id == item_id:
			return true

	return false

func get_item_count(item_id: StringName) -> int:
	if not item_map.has(item_id):
		return 0

	var total_count: int = 0
	for entry_obj in items:
		var entry: InventoryEntry = entry_obj
		if entry.item_data != null and entry.item_data.id == item_id:
			total_count += entry.count

	return total_count

func get_item_count_by_data(item_data: ItemData) -> int:
	if item_data == null:
		return 0

	for entry_obj in items:
		var entry: InventoryEntry = entry_obj
		if _can_stack_item(entry.item_data, item_data):
			return entry.count

	return 0


func get_highest_quality_item_by_id(item_id: StringName) -> ItemData:
	var best_item: ItemData = null
	for entry_obj in items:
		var entry: InventoryEntry = entry_obj
		if entry.item_data == null or entry.item_data.id != item_id:
			continue
		if _is_better_quality_item(entry.item_data, best_item):
			best_item = entry.item_data
	return best_item


func remove_highest_quality_items_by_id(item_id: StringName, amount: int = 1) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"removed_entries": [],
		"representative_item_data": null,
		"seed_quality": 0
	}

	if amount <= 0:
		return result
	if get_item_count(item_id) < amount:
		return result

	var candidates: Array[InventoryEntry] = []
	for entry_obj in items:
		var entry: InventoryEntry = entry_obj
		if entry.item_data != null and entry.item_data.id == item_id:
			candidates.append(entry)

	if candidates.is_empty():
		return result

	candidates.sort_custom(_sort_inventory_entries_by_quality_desc)

	var remaining: int = amount
	var removed_entries: Array = []
	var representative_item_data: ItemData = candidates[0].item_data

	for entry in candidates:
		if remaining <= 0:
			break
		if entry == null or entry.item_data == null or entry.count <= 0:
			continue

		var remove_count: int = min(entry.count, remaining)
		if remove_count <= 0:
			continue

		removed_entries.append({
			"item_data": entry.item_data,
			"count": remove_count
		})

		entry.count -= remove_count
		remaining -= remove_count

		if entry.count <= 0:
			if selected_item_data == entry.item_data:
				selected_item_data = null
			items.erase(entry)

	if remaining > 0:
		restore_removed_item_entries(removed_entries)
		return result

	refresh()

	result["success"] = true
	result["removed_entries"] = removed_entries
	result["representative_item_data"] = representative_item_data
	if representative_item_data != null:
		result["seed_quality"] = max(representative_item_data.get_quality(), 0)
	return result


func restore_removed_item_entries(removed_entries: Array) -> void:
	for removed_entry in removed_entries:
		if typeof(removed_entry) != TYPE_DICTIONARY:
			continue
		var item_data: ItemData = removed_entry.get("item_data", null) as ItemData
		var count: int = max(int(removed_entry.get("count", 0)), 0)
		if item_data == null or count <= 0:
			continue
		add_item(item_data, count)


func _sort_inventory_entries_by_quality_desc(a: InventoryEntry, b: InventoryEntry) -> bool:
	var a_item: ItemData = null if a == null else a.item_data
	var b_item: ItemData = null if b == null else b.item_data
	if a_item == null:
		return false
	if b_item == null:
		return true
	if a_item.get_quality() != b_item.get_quality():
		return a_item.get_quality() > b_item.get_quality()
	if a_item.get_rank() != b_item.get_rank():
		return a_item.get_rank() > b_item.get_rank()
	return String(a_item.resource_path) < String(b_item.resource_path)


func _is_better_quality_item(candidate: ItemData, current_best: ItemData) -> bool:
	if candidate == null:
		return false
	if current_best == null:
		return true
	if candidate.get_quality() != current_best.get_quality():
		return candidate.get_quality() > current_best.get_quality()
	if candidate.get_rank() != current_best.get_rank():
		return candidate.get_rank() > current_best.get_rank()
	return String(candidate.resource_path) < String(current_best.resource_path)

func get_selected_item_data() -> ItemData:
	return selected_item_data

func clear_selection() -> void:
	selected_item_data = null
	_update_selected_slot_visuals()
	_sync_player_selected_item()
	_update_tooltip_for_selection()

func _on_slot_gui_input(event: InputEvent, item_data: ItemData) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event == null:
		return

	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		selected_item_data = item_data
		_update_selected_slot_visuals()

		var count: int = get_item_count_by_data(item_data)
		var player: Node = get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("set_selected_item"):
			player.call("set_selected_item", item_data, count)

		_update_tooltip_for_selection()

func _update_selected_slot_visuals() -> void:
	for child in grid.get_children():
		if not child.has_method("set_selected"):
			continue

		var is_selected := false
		if selected_item_data != null:
			if child.has_method("has_item_data"):
				is_selected = child.call("has_item_data", selected_item_data)

		child.call("set_selected", is_selected)

func _sync_player_selected_item() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		_update_tooltip_for_selection()
		return

	var player_selected_item = player.get("selected_item_data")

	if selected_item_data == null and player_selected_item != null:
		var player_item: ItemData = player_selected_item as ItemData
		if player_item != null and get_item_count_by_data(player_item) > 0:
			selected_item_data = player_item

	if selected_item_data == null:
		if player_selected_item != null and player.has_method("clear_selected_item"):
			player.call("clear_selected_item")
		_update_tooltip_for_selection()
		return

	var remaining: int = get_item_count_by_data(selected_item_data)
	if remaining <= 0:
		selected_item_data = null
		if player.has_method("clear_selected_item"):
			player.call("clear_selected_item")
	else:
		if player.has_method("set_selected_item"):
			player.call("set_selected_item", selected_item_data, remaining)

	_update_tooltip_for_selection()

func _update_tooltip_for_selection() -> void:
	if tooltip == null:
		return

	if not is_visible_in_tree():
		_hide_tooltip_immediately()
		return

	if selected_item_data == null:
		_hide_tooltip_immediately()
		return

	var count := get_item_count_by_data(selected_item_data)
	if count <= 0:
		_hide_tooltip_immediately()
		return

	if tooltip.has_method("show_item"):
		tooltip.call("show_item", selected_item_data, count)
	else:
		tooltip.visible = true

	_call_reposition_tooltip()

func _call_reposition_tooltip() -> void:
	if tooltip == null or panel == null:
		return

	call_deferred("_reposition_tooltip_top")

func _reposition_tooltip_left_of_panel() -> void:
	if tooltip == null or panel == null:
		return

	var margin := 16.0
	var tooltip_size: Vector2 = tooltip.size
	if tooltip_size.x <= 0.0 or tooltip_size.y <= 0.0:
		tooltip_size = tooltip.get_combined_minimum_size()

	var x := panel.position.x - tooltip_size.x - margin
	var y := panel.position.y

	if x < 0.0:
		x = panel.position.x + panel.size.x + margin

	tooltip.position = Vector2(x, y)

func _hide_tooltip_immediately() -> void:
	if tooltip == null:
		return

	if tooltip.has_method("hide_tooltip"):
		tooltip.call("hide_tooltip")
	else:
		tooltip.visible = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			_update_tooltip_for_selection()
		else:
			_hide_tooltip_immediately()
	elif what == NOTIFICATION_RESIZED:
		if tooltip != null and tooltip.visible:
			_call_reposition_tooltip()

func _apply_inventory_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_color = PANEL_BORDER
	panel_style.corner_radius_top_left = PANEL_RADIUS
	panel_style.corner_radius_top_right = PANEL_RADIUS
	panel_style.corner_radius_bottom_right = PANEL_RADIUS
	panel_style.corner_radius_bottom_left = PANEL_RADIUS
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 12
	panel.add_theme_stylebox_override("panel", panel_style)

	grid.columns = GRID_COLUMNS
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)

func _reposition_tooltip_top() -> void:
	if tooltip == null or panel == null:
		return
	if not tooltip.visible:
		return

	var margin: float = TOOLTIP_TOP_MARGIN
	var target_width: float = panel.size.x

	tooltip.custom_minimum_size = Vector2(target_width, 0.0)
	tooltip.update_minimum_size()

	tooltip.reset_size()

	if tooltip is Container:
		var tooltip_container: Container = tooltip
		tooltip_container.queue_sort()

	await get_tree().process_frame

	var tooltip_size: Vector2 = tooltip.get_combined_minimum_size()
	if tooltip_size.x < target_width:
		tooltip_size.x = target_width
	if tooltip_size.y <= 0.0:
		tooltip_size.y = 1.0

	tooltip.size = tooltip_size

	var x: float = panel.position.x
	var y: float = panel.position.y - tooltip_size.y - margin
	tooltip.position = Vector2(x, y)

func _get_message_log() -> Node:
	return get_node_or_null("/root/MessageLog")

func _log_error(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_error"):
		log_node.call("add_error", text)

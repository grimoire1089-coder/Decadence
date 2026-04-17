extends StaticBody2D
class_name CropMachine

@export var machine_name: String = "栽培機"
@export var interact_action_text: String = "開く"
@export var interact_prompt_offset: Vector2 = Vector2(0, -56)
@export_range(1, 240) var slot_count: int = 1
@export_range(1, 240) var max_slot_count: int = 240
@export_range(0, 999999999) var slot_unlock_cost_base: int = 100
@export_range(1.0, 100.0, 0.1) var slot_unlock_cost_multiplier: float = 1.5
@export var available_recipes: Array[CropRecipe] = []
@export_dir var recipe_folder_path: String = "res://Data/Crop_Recipe"
@export var include_subfolders: bool = false

var slots: Array[Dictionary] = []
var _last_total_minutes: int = -1
var _save_module: CropMachineSaveModule = CropMachineSaveModule.new()
var _growth_module: CropMachineGrowthModule = CropMachineGrowthModule.new()
var _recipe_repository: CropMachineRecipeRepository = CropMachineRecipeRepository.new()

@onready var interact_area: Area2D = $InteractArea


func _ready() -> void:
	max_slot_count = max(max_slot_count, slot_count)
	slot_count = clamp(slot_count, 1, max_slot_count)
	_init_slots()
	_reload_available_recipes()
	load_data()
	_connect_interact_area()
	_connect_time_manager()
	_sync_last_total_minutes()


func _exit_tree() -> void:
	_disconnect_time_manager()


func _init_slots() -> void:
	slots.clear()
	for _i in range(slot_count):
		slots.append(_make_empty_slot())


func _resize_slots_to_count(new_count: int) -> void:
	var clamped_count: int = clamp(new_count, 1, max_slot_count)
	if clamped_count < slots.size():
		slots.resize(clamped_count)
	else:
		while slots.size() < clamped_count:
			slots.append(_make_empty_slot())
	slot_count = clamped_count


func _make_empty_slot() -> Dictionary:
	return {
		"seed_item_path": "",
		"harvest_item_path": "",
		"display_name": "",
		"total_minutes": 0,
		"remaining_minutes": 0,
		"harvest_amount": 0,
		"queued_count": 0,
		"ready_count": 0,
		"recipe_key": ""
	}


func _reload_available_recipes() -> void:
	_get_recipe_repository().reload_available_recipes(self)


func _append_unique_recipe(target: Array[CropRecipe], seen: Dictionary, recipe: CropRecipe) -> bool:
	return _get_recipe_repository().append_unique_recipe(target, seen, recipe)


func _get_recipe_unique_key(recipe: CropRecipe) -> String:
	return _get_recipe_repository().get_recipe_unique_key(recipe)


func _load_recipes_from_folder(folder_path: String, recursive: bool) -> Array[CropRecipe]:
	return _get_recipe_repository().load_recipes_from_folder(self, folder_path, recursive)


func _collect_recipes_in_folder(folder_path: String, recursive: bool, out_results: Array[CropRecipe]) -> void:
	_get_recipe_repository().collect_recipes_in_folder(self, folder_path, recursive, out_results)


func _connect_interact_area() -> void:
	if interact_area == null:
		return

	if not interact_area.body_entered.is_connected(_on_body_entered):
		interact_area.body_entered.connect(_on_body_entered)

	if not interact_area.body_exited.is_connected(_on_body_exited):
		interact_area.body_exited.connect(_on_body_exited)


func _connect_time_manager() -> void:
	_get_growth_module().connect_time_manager(self)


func _disconnect_time_manager() -> void:
	_get_growth_module().disconnect_time_manager(self)


func _sync_last_total_minutes() -> void:
	_get_growth_module().sync_last_total_minutes(self)


func _to_total_minutes(day: int, hour: int, minute: int) -> int:
	return _get_growth_module().to_total_minutes(day, hour, minute)


func _on_time_changed(day: int, hour: int, minute: int) -> void:
	_get_growth_module().handle_time_changed(self, day, hour, minute)


func _advance_growth(delta_minutes: int) -> void:
	_get_growth_module().advance_growth(self, delta_minutes)


func get_interact_action_text() -> String:
	return interact_action_text


func get_interact_prompt_offset() -> Vector2:
	return interact_prompt_offset


func interact(player: Node) -> void:
	var ui: Node = get_tree().get_first_node_in_group("crop_machine_ui")
	if ui != null and ui.has_method("open_machine"):
		ui.call("open_machine", self, player)


func can_stack_recipe(slot_index: int, recipe: CropRecipe) -> bool:
	if not _is_valid_slot_index(slot_index):
		return false
	if recipe == null or not recipe.is_valid_recipe():
		return false
	if is_slot_empty(slot_index):
		return false

	var slot: Dictionary = slots[slot_index]
	var slot_seed_path: String = str(slot.get("seed_item_path", ""))
	var slot_harvest_path: String = str(slot.get("harvest_item_path", ""))
	var slot_total_minutes: int = int(slot.get("total_minutes", 0))
	var slot_harvest_amount: int = int(slot.get("harvest_amount", 0))
	var slot_recipe_key: String = str(slot.get("recipe_key", ""))
	var recipe_key: String = _get_recipe_unique_key(recipe)

	if not slot_recipe_key.is_empty() and not recipe_key.is_empty():
		return slot_recipe_key == recipe_key

	return slot_seed_path == recipe.seed_item.resource_path \
		and slot_harvest_path == recipe.harvest_item.resource_path \
		and slot_total_minutes == max(recipe.grow_minutes, 1) \
		and slot_harvest_amount == max(recipe.harvest_amount, 1)


func can_plant_recipe_in_slot(slot_index: int, recipe: CropRecipe) -> bool:
	if not _is_valid_slot_index(slot_index):
		return false
	if recipe == null or not recipe.is_valid_recipe():
		return false
	if is_slot_empty(slot_index):
		return true
	return can_stack_recipe(slot_index, recipe)


func plant_slot(slot_index: int, recipe: CropRecipe, plant_count: int = 1) -> bool:
	if not _is_valid_slot_index(slot_index):
		return false
	if recipe == null or not recipe.is_valid_recipe():
		return false
	if plant_count <= 0:
		return false
	if not can_plant_recipe_in_slot(slot_index, recipe):
		return false

	if is_slot_empty(slot_index):
		var new_slot: Dictionary = _make_empty_slot()
		new_slot["seed_item_path"] = recipe.seed_item.resource_path
		new_slot["harvest_item_path"] = recipe.harvest_item.resource_path
		new_slot["display_name"] = recipe.get_display_name()
		new_slot["total_minutes"] = max(recipe.grow_minutes, 1)
		new_slot["remaining_minutes"] = max(recipe.grow_minutes, 1)
		new_slot["harvest_amount"] = max(recipe.harvest_amount, 1)
		new_slot["queued_count"] = plant_count
		new_slot["ready_count"] = 0
		new_slot["recipe_key"] = _get_recipe_unique_key(recipe)
		slots[slot_index] = new_slot
	else:
		var slot: Dictionary = slots[slot_index]
		slot["queued_count"] = max(int(slot.get("queued_count", 0)), 0) + plant_count
		if int(slot.get("remaining_minutes", 0)) <= 0:
			slot["remaining_minutes"] = max(int(slot.get("total_minutes", 0)), 1)
		if str(slot.get("recipe_key", "")).is_empty():
			slot["recipe_key"] = _get_recipe_unique_key(recipe)
		slots[slot_index] = slot

	save_data()
	_refresh_open_ui()
	return true


func _get_player_stats_manager() -> Node:
	return get_node_or_null("/root/PlayerStatsManager")


func _get_farming_quality_bonus() -> float:
	var stats_manager: Node = _get_player_stats_manager()
	if stats_manager != null and stats_manager.has_method("get_farming_quality_bonus"):
		return clamp(float(stats_manager.call("get_farming_quality_bonus")), 0.0, 1.0)
	return 0.0


func _get_harvest_quality_value() -> int:
	return clamp(int(round(_get_farming_quality_bonus() * 100.0)), 0, 100)


func _get_harvest_rank_from_quality(quality_value: int) -> int:
	if quality_value <= 0:
		return 0
	return clamp(int(ceil(float(quality_value) / 20.0)), 0, 5)


func _build_quality_harvest_item(base_item: ItemData) -> ItemData:
	if base_item == null:
		return null

	var harvested_item: ItemData = base_item.duplicate(true) as ItemData
	if harvested_item == null:
		harvested_item = base_item

	var quality_value: int = _get_harvest_quality_value()
	harvested_item.quality = quality_value
	harvested_item.rank = _get_harvest_rank_from_quality(quality_value)
	return harvested_item


func harvest_slot(slot_index: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"item_data": null,
		"amount": 0,
		"ready_cycles": 0,
		"quality": 0,
		"rank": 0
	}

	if not _is_valid_slot_index(slot_index):
		return result
	if is_slot_empty(slot_index):
		return result

	var ready_cycles: int = get_slot_ready_count(slot_index)
	if ready_cycles <= 0:
		return result

	var harvest_item: ItemData = get_slot_harvest_item(slot_index)
	if harvest_item == null:
		_log_error("収穫アイテムが読み込めない")
		return result

	var per_cycle_amount: int = max(int(slots[slot_index].get("harvest_amount", 0)), 0)
	if per_cycle_amount <= 0:
		return result

	var total_amount: int = ready_cycles * per_cycle_amount
	var harvested_item: ItemData = _build_quality_harvest_item(harvest_item)
	if harvested_item == null:
		return result

	result["success"] = true
	result["item_data"] = harvested_item
	result["amount"] = total_amount
	result["ready_cycles"] = ready_cycles
	result["quality"] = harvested_item.get_quality()
	result["rank"] = harvested_item.get_rank()

	var slot: Dictionary = slots[slot_index]
	slot["ready_count"] = 0
	if max(int(slot.get("queued_count", 0)), 0) <= 0:
		slots[slot_index] = _make_empty_slot()
	else:
		slots[slot_index] = slot

	save_data()
	_refresh_open_ui()
	return result


func get_slot_cancel_preview(slot_index: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"display_name": "",
		"ready_item_data": null,
		"ready_amount": 0,
		"ready_cycles": 0,
		"ready_quality": 0,
		"ready_rank": 0,
		"seed_item_data": null,
		"return_seed_count": 0
	}

	if not _is_valid_slot_index(slot_index):
		return result
	if is_slot_empty(slot_index):
		return result

	var ready_cycles: int = get_slot_ready_count(slot_index)
	var queued_count: int = get_slot_queued_count(slot_index)
	var harvest_amount_per_cycle: int = get_slot_harvest_amount(slot_index)
	var harvest_item: ItemData = get_slot_harvest_item(slot_index)
	var seed_item: ItemData = get_slot_seed_item(slot_index)
	var ready_item: ItemData = null
	if ready_cycles > 0 and harvest_item != null:
		ready_item = _build_quality_harvest_item(harvest_item)

	result["success"] = ready_cycles > 0 or queued_count > 0
	result["display_name"] = get_slot_display_name(slot_index)
	result["ready_item_data"] = ready_item
	result["ready_amount"] = ready_cycles * harvest_amount_per_cycle
	result["ready_cycles"] = ready_cycles
	if ready_item != null:
		result["ready_quality"] = ready_item.get_quality()
		result["ready_rank"] = ready_item.get_rank()
	result["seed_item_data"] = seed_item
	result["return_seed_count"] = queued_count
	return result


func cancel_slot(slot_index: int) -> Dictionary:
	var result: Dictionary = get_slot_cancel_preview(slot_index)
	if not bool(result.get("success", false)):
		return result

	slots[slot_index] = _make_empty_slot()
	save_data()
	_refresh_open_ui()
	return result


func clear_slot(slot_index: int) -> void:
	if not _is_valid_slot_index(slot_index):
		return

	slots[slot_index] = _make_empty_slot()
	save_data()
	_refresh_open_ui()


func get_unlocked_slot_count() -> int:
	return slot_count


func get_max_slot_count() -> int:
	return max_slot_count


func can_unlock_slot() -> bool:
	return slot_count < max_slot_count


func get_next_slot_unlock_cost() -> int:
	if not can_unlock_slot():
		return 0

	var multiplier_step: int = max(slot_count - 1, 0)
	var scaled_cost: float = float(slot_unlock_cost_base) * pow(slot_unlock_cost_multiplier, float(multiplier_step))
	return max(int(round(scaled_cost)), 0)


func unlock_slot() -> bool:
	if not can_unlock_slot():
		return false

	_resize_slots_to_count(slot_count + 1)
	save_data()
	_log_system("%sのスロット%dを解放した" % [machine_name, slot_count])
	_refresh_open_ui()
	return true


func is_slot_empty(slot_index: int) -> bool:
	if not _is_valid_slot_index(slot_index):
		return true

	var slot: Dictionary = slots[slot_index]
	var harvest_item_path: String = str(slot.get("harvest_item_path", ""))
	var queued_count: int = max(int(slot.get("queued_count", 0)), 0)
	var ready_count: int = max(int(slot.get("ready_count", 0)), 0)
	return harvest_item_path.is_empty() or (queued_count <= 0 and ready_count <= 0)


func is_slot_ready(slot_index: int) -> bool:
	if not _is_valid_slot_index(slot_index):
		return false
	if is_slot_empty(slot_index):
		return false
	return get_slot_ready_count(slot_index) > 0


func has_slot_active_growth(slot_index: int) -> bool:
	if not _is_valid_slot_index(slot_index):
		return false
	if is_slot_empty(slot_index):
		return false
	return get_slot_queued_count(slot_index) > 0


func get_slot_display_name(slot_index: int) -> String:
	if not _is_valid_slot_index(slot_index):
		return "-"
	if is_slot_empty(slot_index):
		return "空"
	return get_slot_display_name_from_slot(slots[slot_index])


func get_slot_display_name_from_slot(slot: Dictionary) -> String:
	var display_name: String = str(slot.get("display_name", ""))
	if not display_name.is_empty():
		return display_name

	var harvest_item_path: String = str(slot.get("harvest_item_path", ""))
	if not harvest_item_path.is_empty():
		var harvest_item: ItemData = load(harvest_item_path) as ItemData
		if harvest_item != null:
			if not harvest_item.item_name.is_empty():
				return harvest_item.item_name
			return str(harvest_item.id)

	return "作物"


func get_slot_remaining_minutes(slot_index: int) -> int:
	if not _is_valid_slot_index(slot_index):
		return 0
	if is_slot_empty(slot_index):
		return 0
	if not has_slot_active_growth(slot_index):
		return 0
	return max(int(slots[slot_index].get("remaining_minutes", 0)), 0)


func get_slot_total_minutes(slot_index: int) -> int:
	if not _is_valid_slot_index(slot_index):
		return 0
	if is_slot_empty(slot_index):
		return 0
	return max(int(slots[slot_index].get("total_minutes", 0)), 0)


func get_slot_progress_ratio(slot_index: int) -> float:
	if not _is_valid_slot_index(slot_index):
		return 0.0
	if is_slot_empty(slot_index):
		return 0.0
	if not has_slot_active_growth(slot_index):
		return 1.0

	var total_minutes: int = get_slot_total_minutes(slot_index)
	if total_minutes <= 0:
		return 0.0

	var remaining_minutes: int = get_slot_remaining_minutes(slot_index)
	var grown_minutes: int = total_minutes - remaining_minutes
	return clamp(float(grown_minutes) / float(total_minutes), 0.0, 1.0)


func get_slot_status_text(slot_index: int) -> String:
	if not _is_valid_slot_index(slot_index):
		return "無効"
	if is_slot_empty(slot_index):
		return "空きスロット"

	var display_name: String = get_slot_display_name(slot_index)
	var ready_count: int = get_slot_ready_count(slot_index)
	var queued_count: int = get_slot_queued_count(slot_index)
	if queued_count <= 0 and ready_count > 0:
		return "%s\n収穫待ち: %d回分" % [display_name, ready_count]

	var remaining_minutes: int = get_slot_remaining_minutes(slot_index)
	var progress_percent: int = int(round(get_slot_progress_ratio(slot_index) * 100.0))
	return "%s\n進行中: %d回 / 収穫待ち: %d回\n現在: 残り%d分 / %d%%" % [display_name, queued_count, ready_count, remaining_minutes, progress_percent]


func get_slot_harvest_amount(slot_index: int) -> int:
	if not _is_valid_slot_index(slot_index):
		return 0
	if is_slot_empty(slot_index):
		return 0
	return max(int(slots[slot_index].get("harvest_amount", 0)), 0)


func get_slot_ready_count(slot_index: int) -> int:
	if not _is_valid_slot_index(slot_index):
		return 0
	if is_slot_empty(slot_index):
		return 0
	return max(int(slots[slot_index].get("ready_count", 0)), 0)


func get_slot_queued_count(slot_index: int) -> int:
	if not _is_valid_slot_index(slot_index):
		return 0
	if is_slot_empty(slot_index):
		return 0
	return max(int(slots[slot_index].get("queued_count", 0)), 0)


func get_slot_seed_item(slot_index: int) -> ItemData:
	if not _is_valid_slot_index(slot_index):
		return null
	if is_slot_empty(slot_index):
		return null

	var path: String = str(slots[slot_index].get("seed_item_path", ""))
	if path.is_empty():
		return null
	return load(path) as ItemData


func get_slot_harvest_item(slot_index: int) -> ItemData:
	if not _is_valid_slot_index(slot_index):
		return null
	if is_slot_empty(slot_index):
		return null

	var path: String = str(slots[slot_index].get("harvest_item_path", ""))
	if path.is_empty():
		return null
	return load(path) as ItemData


func _is_valid_slot_index(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slots.size()


func _get_save_module() -> CropMachineSaveModule:
	if _save_module == null:
		_save_module = CropMachineSaveModule.new()
	return _save_module


func _get_growth_module() -> CropMachineGrowthModule:
	if _growth_module == null:
		_growth_module = CropMachineGrowthModule.new()
	return _growth_module


func _get_recipe_repository() -> CropMachineRecipeRepository:
	if _recipe_repository == null:
		_recipe_repository = CropMachineRecipeRepository.new()
	return _recipe_repository


func get_save_key() -> String:
	return _get_save_module().get_machine_save_key(self)


func _get_save_path() -> String:
	return _get_save_module().get_save_path(self)


func get_save_payload() -> Dictionary:
	return _get_save_module().build_save_payload(self)


func apply_save_payload(data: Dictionary) -> void:
	_get_save_module().apply_save_payload(self, data)


func save_data() -> void:
	_get_save_module().save_machine(self)


func load_data() -> void:
	_get_save_module().load_machine(self)


func _refresh_open_ui() -> void:
	var ui: Node = get_tree().get_first_node_in_group("crop_machine_ui")
	if ui != null and bool(ui.get("visible")) and ui.has_method("refresh"):
		ui.call("refresh")


func _get_time_manager() -> Node:
	return get_node_or_null("/root/TimeManager")


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("register_interactable"):
		body.register_interactable(self)
		_log_debug("プレイヤーが栽培機の範囲に入った")


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("unregister_interactable"):
		body.unregister_interactable(self)


func _get_message_log() -> Node:
	return get_node_or_null("/root/MessageLog")


func _log_debug(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_debug"):
		log_node.call("add_debug", text)


func _log_system(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_system"):
		log_node.call("add_system", text)


func _log_error(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_error"):
		log_node.call("add_error", text)

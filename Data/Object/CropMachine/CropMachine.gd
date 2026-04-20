extends StaticBody2D
class_name CropMachine

@export var machine_name: String = "栽培機"
@export var interact_action_text: String = "開く"
@export var interact_prompt_offset: Vector2 = Vector2(0, -56)
@export_range(1, 240) var slot_count: int = 1
@export_range(1, 240) var max_slot_count: int = 240
@export_range(0, 999999999) var slot_unlock_cost_base: int = 100
@export_range(1.0, 100.0, 0.1) var slot_unlock_cost_multiplier: float = 1.5
@export var available_recipes: Array = []
@export_dir var recipe_folder_path: String = "res://Data/Crop_Recipe"
@export var include_subfolders: bool = false

var slots: Array[Dictionary] = []
var _last_total_minutes: int = -1
var _save_module: CropMachineSaveModule = CropMachineSaveModule.new()
var _growth_module: CropMachineGrowthModule = CropMachineGrowthModule.new()
var _recipe_repository: CropMachineRecipeRepository = CropMachineRecipeRepository.new()
var _slot_logic_module: CropMachineSlotLogicModule = CropMachineSlotLogicModule.new()
var _harvest_quality_module: CropMachineHarvestQualityModule = CropMachineHarvestQualityModule.new()

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


func _make_empty_slot(slot_quality_bonus: int = 0) -> Dictionary:
	return {
		"seed_item_path": "",
		"harvest_item_path": "",
		"display_name": "",
		"total_minutes": 0,
		"remaining_minutes": 0,
		"harvest_amount": 0,
		"queued_count": 0,
		"ready_count": 0,
		"recipe_key": "",
		"seed_quality": 0,
		"slot_quality_bonus": max(slot_quality_bonus, 0)
	}


func _reload_available_recipes() -> void:
	_get_recipe_repository().reload_available_recipes(self)


func _append_unique_recipe(target: Array, seen: Dictionary, recipe: CropRecipe) -> bool:
	return _get_recipe_repository().append_unique_recipe(target, seen, recipe)


func _get_recipe_unique_key(recipe: CropRecipe) -> String:
	return _get_recipe_repository().get_recipe_unique_key(recipe)


func _load_recipes_from_folder(folder_path: String, recursive: bool) -> Array:
	return _get_recipe_repository().load_recipes_from_folder(self, folder_path, recursive)


func _collect_recipes_in_folder(folder_path: String, recursive: bool, out_results: Array) -> void:
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


func get_last_total_minutes() -> int:
	return _last_total_minutes


func set_last_total_minutes(value: int) -> void:
	_last_total_minutes = value


func get_interact_action_text() -> String:
	return interact_action_text


func get_interact_prompt_offset() -> Vector2:
	return interact_prompt_offset


func interact(player: Node) -> void:
	var ui: Node = get_tree().get_first_node_in_group("crop_machine_ui")
	if ui != null and ui.has_method("open_machine"):
		ui.call("open_machine", self, player)


func can_stack_recipe(slot_index: int, recipe: CropRecipe) -> bool:
	return _get_slot_logic_module().can_stack_recipe(self, slot_index, recipe)


func can_plant_recipe_in_slot(slot_index: int, recipe: CropRecipe) -> bool:
	return _get_slot_logic_module().can_plant_recipe_in_slot(self, slot_index, recipe)


func plant_slot(slot_index: int, recipe: CropRecipe, plant_count: int = 1, seed_item_data: ItemData = null) -> bool:
	return _get_slot_logic_module().plant_slot(self, slot_index, recipe, plant_count, seed_item_data)



func _get_player_stats_manager() -> Node:
	return _get_harvest_quality_module().get_player_stats_manager(self)


func _get_farming_quality_bonus() -> float:
	return _get_harvest_quality_module().get_farming_quality_bonus(self)


func _get_harvest_quality_value(slot_index: int = -1) -> int:
	return _get_harvest_quality_module().get_harvest_quality_value(self, slot_index)


func _get_harvest_rank_from_quality(quality_value: int) -> int:
	return _get_harvest_quality_module().get_harvest_rank_from_quality(self, quality_value)


func _build_quality_harvest_item(base_item: ItemData, slot_index: int = -1) -> ItemData:
	return _get_harvest_quality_module().build_quality_harvest_item(self, base_item, slot_index)


func harvest_slot(slot_index: int) -> Dictionary:
	return _get_slot_logic_module().harvest_slot(self, slot_index)


func get_slot_cancel_preview(slot_index: int) -> Dictionary:
	return _get_slot_logic_module().get_slot_cancel_preview(self, slot_index)


func cancel_slot(slot_index: int) -> Dictionary:
	return _get_slot_logic_module().cancel_slot(self, slot_index)


func clear_slot(slot_index: int) -> void:
	_get_slot_logic_module().clear_slot(self, slot_index)


func get_unlocked_slot_count() -> int:
	return _get_slot_logic_module().get_unlocked_slot_count(self)


func get_max_slot_count() -> int:
	return _get_slot_logic_module().get_max_slot_count(self)


func can_unlock_slot() -> bool:
	return _get_slot_logic_module().can_unlock_slot(self)


func get_next_slot_unlock_cost() -> int:
	return _get_slot_logic_module().get_next_slot_unlock_cost(self)


func unlock_slot() -> bool:
	return _get_slot_logic_module().unlock_slot(self)


func is_slot_empty(slot_index: int) -> bool:
	return _get_slot_logic_module().is_slot_empty(self, slot_index)


func is_slot_ready(slot_index: int) -> bool:
	return _get_slot_logic_module().is_slot_ready(self, slot_index)


func has_slot_active_growth(slot_index: int) -> bool:
	return _get_slot_logic_module().has_slot_active_growth(self, slot_index)


func get_slot_display_name(slot_index: int) -> String:
	return _get_slot_logic_module().get_slot_display_name(self, slot_index)


func get_slot_display_name_from_slot(slot: Dictionary) -> String:
	return _get_slot_logic_module().get_slot_display_name_from_slot(self, slot)


func get_slot_remaining_minutes(slot_index: int) -> int:
	return _get_slot_logic_module().get_slot_remaining_minutes(self, slot_index)


func get_slot_total_minutes(slot_index: int) -> int:
	return _get_slot_logic_module().get_slot_total_minutes(self, slot_index)


func get_slot_progress_ratio(slot_index: int) -> float:
	return _get_slot_logic_module().get_slot_progress_ratio(self, slot_index)


func get_slot_status_text(slot_index: int) -> String:
	return _get_slot_logic_module().get_slot_status_text(self, slot_index)


func get_slot_harvest_amount(slot_index: int) -> int:
	return _get_slot_logic_module().get_slot_harvest_amount(self, slot_index)


func get_slot_ready_count(slot_index: int) -> int:
	return _get_slot_logic_module().get_slot_ready_count(self, slot_index)


func get_slot_queued_count(slot_index: int) -> int:
	return _get_slot_logic_module().get_slot_queued_count(self, slot_index)


func get_slot_seed_item(slot_index: int) -> ItemData:
	return _get_slot_logic_module().get_slot_seed_item(self, slot_index)


func get_slot_seed_quality(slot_index: int) -> int:
	return _get_slot_logic_module().get_slot_seed_quality(self, slot_index)


func get_slot_quality_bonus(slot_index: int) -> int:
	return _get_slot_logic_module().get_slot_quality_bonus(self, slot_index)


func set_slot_quality_bonus(slot_index: int, quality_bonus: int) -> void:
	_get_slot_logic_module().set_slot_quality_bonus(self, slot_index, quality_bonus)


func get_slot_harvest_item(slot_index: int) -> ItemData:
	return _get_slot_logic_module().get_slot_harvest_item(self, slot_index)


func _is_valid_slot_index(slot_index: int) -> bool:
	return _get_slot_logic_module().is_valid_slot_index(self, slot_index)


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


func _get_slot_logic_module() -> CropMachineSlotLogicModule:
	if _slot_logic_module == null:
		_slot_logic_module = CropMachineSlotLogicModule.new()
	return _slot_logic_module


func _get_harvest_quality_module() -> CropMachineHarvestQualityModule:
	if _harvest_quality_module == null:
		_harvest_quality_module = CropMachineHarvestQualityModule.new()
	return _harvest_quality_module


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

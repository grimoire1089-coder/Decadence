extends RefCounted
class_name CropMachineSlotLogicModule


func can_stack_recipe(machine: CropMachine, slot_index: int, recipe: CropRecipe) -> bool:
	if machine == null:
		return false
	if not is_valid_slot_index(machine, slot_index):
		return false
	if recipe == null or not recipe.is_valid_recipe():
		return false
	if is_slot_empty(machine, slot_index):
		return false

	var slot: Dictionary = machine.slots[slot_index]
	var slot_seed_path: String = str(slot.get("seed_item_path", ""))
	var slot_harvest_path: String = str(slot.get("harvest_item_path", ""))
	var slot_total_minutes: int = int(slot.get("total_minutes", 0))
	var slot_harvest_amount: int = int(slot.get("harvest_amount", 0))
	var slot_recipe_key: String = str(slot.get("recipe_key", ""))
	var recipe_key: String = machine._get_recipe_unique_key(recipe)

	if not slot_recipe_key.is_empty() and not recipe_key.is_empty():
		return slot_recipe_key == recipe_key

	return slot_seed_path == recipe.seed_item.resource_path \
		and slot_harvest_path == recipe.harvest_item.resource_path \
		and slot_total_minutes == max(recipe.grow_minutes, 1) \
		and slot_harvest_amount == max(recipe.harvest_amount, 1)


func can_plant_recipe_in_slot(machine: CropMachine, slot_index: int, recipe: CropRecipe) -> bool:
	if machine == null:
		return false
	if not is_valid_slot_index(machine, slot_index):
		return false
	if recipe == null or not recipe.is_valid_recipe():
		return false
	if is_slot_empty(machine, slot_index):
		return true
	return can_stack_recipe(machine, slot_index, recipe)


func plant_slot(machine: CropMachine, slot_index: int, recipe: CropRecipe, plant_count: int = 1, seed_item_data: ItemData = null) -> bool:
	if machine == null:
		return false
	if not is_valid_slot_index(machine, slot_index):
		return false
	if recipe == null or not recipe.is_valid_recipe():
		return false
	if plant_count <= 0:
		return false
	if not can_plant_recipe_in_slot(machine, slot_index, recipe):
		return false

	var incoming_seed_quality: int = _resolve_seed_quality(recipe, seed_item_data)
	if is_slot_empty(machine, slot_index):
		var existing_slot: Dictionary = machine.slots[slot_index]
		var preserved_slot_quality_bonus: int = _get_slot_quality_bonus_from_slot(existing_slot)
		var new_slot: Dictionary = machine._make_empty_slot(preserved_slot_quality_bonus)
		new_slot["seed_item_path"] = recipe.seed_item.resource_path
		new_slot["harvest_item_path"] = recipe.harvest_item.resource_path
		new_slot["display_name"] = recipe.get_display_name()
		new_slot["total_minutes"] = max(recipe.grow_minutes, 1)
		new_slot["remaining_minutes"] = max(recipe.grow_minutes, 1)
		new_slot["harvest_amount"] = max(recipe.harvest_amount, 1)
		new_slot["queued_count"] = plant_count
		new_slot["ready_count"] = 0
		new_slot["recipe_key"] = machine._get_recipe_unique_key(recipe)
		new_slot["seed_quality"] = incoming_seed_quality
		machine.slots[slot_index] = new_slot
	else:
		var slot: Dictionary = machine.slots[slot_index]
		slot["queued_count"] = max(int(slot.get("queued_count", 0)), 0) + plant_count
		if int(slot.get("remaining_minutes", 0)) <= 0:
			slot["remaining_minutes"] = max(int(slot.get("total_minutes", 0)), 1)
		if str(slot.get("recipe_key", "")).is_empty():
			slot["recipe_key"] = machine._get_recipe_unique_key(recipe)
		machine.slots[slot_index] = slot

	machine.save_data()
	machine._refresh_open_ui()
	return true


func harvest_slot(machine: CropMachine, slot_index: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"item_data": null,
		"amount": 0,
		"ready_cycles": 0,
		"quality": 0,
		"rank": 0
	}

	if machine == null:
		return result
	if not is_valid_slot_index(machine, slot_index):
		return result
	if is_slot_empty(machine, slot_index):
		return result

	var ready_cycles: int = get_slot_ready_count(machine, slot_index)
	if ready_cycles <= 0:
		return result

	var harvest_item: ItemData = get_slot_harvest_item(machine, slot_index)
	if harvest_item == null:
		machine._log_error("収穫アイテムが読み込めない")
		return result

	var per_cycle_amount: int = max(int(machine.slots[slot_index].get("harvest_amount", 0)), 0)
	if per_cycle_amount <= 0:
		return result

	var total_amount: int = ready_cycles * per_cycle_amount
	var harvested_item: ItemData = machine._build_quality_harvest_item(harvest_item, slot_index)
	if harvested_item == null:
		return result

	result["success"] = true
	result["item_data"] = harvested_item
	result["amount"] = total_amount
	result["ready_cycles"] = ready_cycles
	result["quality"] = harvested_item.get_quality()
	result["rank"] = harvested_item.get_rank()

	var slot: Dictionary = machine.slots[slot_index]
	slot["ready_count"] = 0
	if max(int(slot.get("queued_count", 0)), 0) <= 0:
		machine.slots[slot_index] = _make_empty_slot_preserving_bonus(machine, slot)
	else:
		machine.slots[slot_index] = slot

	machine.save_data()
	machine._refresh_open_ui()
	return result


func get_slot_cancel_preview(machine: CropMachine, slot_index: int) -> Dictionary:
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

	if machine == null:
		return result
	if not is_valid_slot_index(machine, slot_index):
		return result
	if is_slot_empty(machine, slot_index):
		return result

	var ready_cycles: int = get_slot_ready_count(machine, slot_index)
	var queued_count: int = get_slot_queued_count(machine, slot_index)
	var harvest_amount_per_cycle: int = get_slot_harvest_amount(machine, slot_index)
	var harvest_item: ItemData = get_slot_harvest_item(machine, slot_index)
	var seed_item: ItemData = get_slot_seed_item(machine, slot_index)
	var ready_item: ItemData = null
	if ready_cycles > 0 and harvest_item != null:
		ready_item = machine._build_quality_harvest_item(harvest_item, slot_index)

	result["success"] = ready_cycles > 0 or queued_count > 0
	result["display_name"] = get_slot_display_name(machine, slot_index)
	result["ready_item_data"] = ready_item
	result["ready_amount"] = ready_cycles * harvest_amount_per_cycle
	result["ready_cycles"] = ready_cycles
	if ready_item != null:
		result["ready_quality"] = ready_item.get_quality()
		result["ready_rank"] = ready_item.get_rank()
	result["seed_item_data"] = seed_item
	result["return_seed_count"] = queued_count
	return result


func cancel_slot(machine: CropMachine, slot_index: int) -> Dictionary:
	if machine == null:
		return {"success": false}

	var result: Dictionary = get_slot_cancel_preview(machine, slot_index)
	if not bool(result.get("success", false)):
		return result

	var current_slot: Dictionary = machine.slots[slot_index]
	machine.slots[slot_index] = _make_empty_slot_preserving_bonus(machine, current_slot)
	machine.save_data()
	machine._refresh_open_ui()
	return result


func clear_slot(machine: CropMachine, slot_index: int) -> void:
	if machine == null:
		return
	if not is_valid_slot_index(machine, slot_index):
		return

	var current_slot: Dictionary = machine.slots[slot_index]
	machine.slots[slot_index] = _make_empty_slot_preserving_bonus(machine, current_slot)
	machine.save_data()
	machine._refresh_open_ui()


func get_unlocked_slot_count(machine: CropMachine) -> int:
	if machine == null:
		return 0
	return machine.slot_count


func get_max_slot_count(machine: CropMachine) -> int:
	if machine == null:
		return 0
	return machine.max_slot_count


func can_unlock_slot(machine: CropMachine) -> bool:
	if machine == null:
		return false
	return machine.slot_count < machine.max_slot_count


func get_next_slot_unlock_cost(machine: CropMachine) -> int:
	if machine == null:
		return 0
	if not can_unlock_slot(machine):
		return 0

	var multiplier_step: int = max(machine.slot_count - 1, 0)
	var scaled_cost: float = float(machine.slot_unlock_cost_base) * pow(machine.slot_unlock_cost_multiplier, float(multiplier_step))
	return max(int(round(scaled_cost)), 0)


func unlock_slot(machine: CropMachine) -> bool:
	if machine == null:
		return false
	if not can_unlock_slot(machine):
		return false

	machine._resize_slots_to_count(machine.slot_count + 1)
	machine.save_data()
	machine._log_system("%sのスロット%dを解放した" % [machine.machine_name, machine.slot_count])
	machine._refresh_open_ui()
	return true


func is_slot_empty(machine: CropMachine, slot_index: int) -> bool:
	if machine == null:
		return true
	if not is_valid_slot_index(machine, slot_index):
		return true

	var slot: Dictionary = machine.slots[slot_index]
	var harvest_item_path: String = str(slot.get("harvest_item_path", ""))
	var queued_count: int = max(int(slot.get("queued_count", 0)), 0)
	var ready_count: int = max(int(slot.get("ready_count", 0)), 0)
	return harvest_item_path.is_empty() or (queued_count <= 0 and ready_count <= 0)


func is_slot_ready(machine: CropMachine, slot_index: int) -> bool:
	if machine == null:
		return false
	if not is_valid_slot_index(machine, slot_index):
		return false
	if is_slot_empty(machine, slot_index):
		return false
	return get_slot_ready_count(machine, slot_index) > 0


func has_slot_active_growth(machine: CropMachine, slot_index: int) -> bool:
	if machine == null:
		return false
	if not is_valid_slot_index(machine, slot_index):
		return false
	if is_slot_empty(machine, slot_index):
		return false
	return get_slot_queued_count(machine, slot_index) > 0


func get_slot_display_name(machine: CropMachine, slot_index: int) -> String:
	if machine == null:
		return "-"
	if not is_valid_slot_index(machine, slot_index):
		return "-"
	if is_slot_empty(machine, slot_index):
		return "空"
	return get_slot_display_name_from_slot(machine, machine.slots[slot_index])


func get_slot_display_name_from_slot(machine: CropMachine, slot: Dictionary) -> String:
	if machine == null:
		return "作物"

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


func get_slot_remaining_minutes(machine: CropMachine, slot_index: int) -> int:
	if machine == null:
		return 0
	if not is_valid_slot_index(machine, slot_index):
		return 0
	if is_slot_empty(machine, slot_index):
		return 0
	if not has_slot_active_growth(machine, slot_index):
		return 0
	return max(int(machine.slots[slot_index].get("remaining_minutes", 0)), 0)


func get_slot_total_minutes(machine: CropMachine, slot_index: int) -> int:
	if machine == null:
		return 0
	if not is_valid_slot_index(machine, slot_index):
		return 0
	if is_slot_empty(machine, slot_index):
		return 0
	return max(int(machine.slots[slot_index].get("total_minutes", 0)), 0)


func get_slot_progress_ratio(machine: CropMachine, slot_index: int) -> float:
	if machine == null:
		return 0.0
	if not is_valid_slot_index(machine, slot_index):
		return 0.0
	if is_slot_empty(machine, slot_index):
		return 0.0
	if not has_slot_active_growth(machine, slot_index):
		return 1.0

	var total_minutes: int = get_slot_total_minutes(machine, slot_index)
	if total_minutes <= 0:
		return 0.0

	var remaining_minutes: int = get_slot_remaining_minutes(machine, slot_index)
	var grown_minutes: int = total_minutes - remaining_minutes
	return clamp(float(grown_minutes) / float(total_minutes), 0.0, 1.0)


func get_slot_status_text(machine: CropMachine, slot_index: int) -> String:
	if machine == null:
		return "無効"
	if not is_valid_slot_index(machine, slot_index):
		return "無効"
	if is_slot_empty(machine, slot_index):
		return "空きスロット"

	var display_name: String = get_slot_display_name(machine, slot_index)
	var ready_count: int = get_slot_ready_count(machine, slot_index)
	var queued_count: int = get_slot_queued_count(machine, slot_index)
	if queued_count <= 0 and ready_count > 0:
		return "%s\n収穫待ち: %d回分" % [display_name, ready_count]

	var remaining_minutes: int = get_slot_remaining_minutes(machine, slot_index)
	var progress_percent: int = int(round(get_slot_progress_ratio(machine, slot_index) * 100.0))
	return "%s\n進行中: %d回 / 収穫待ち: %d回\n現在: 残り%d分 / %d%%" % [display_name, queued_count, ready_count, remaining_minutes, progress_percent]


func get_slot_harvest_amount(machine: CropMachine, slot_index: int) -> int:
	if machine == null:
		return 0
	if not is_valid_slot_index(machine, slot_index):
		return 0
	if is_slot_empty(machine, slot_index):
		return 0
	return max(int(machine.slots[slot_index].get("harvest_amount", 0)), 0)


func get_slot_ready_count(machine: CropMachine, slot_index: int) -> int:
	if machine == null:
		return 0
	if not is_valid_slot_index(machine, slot_index):
		return 0
	if is_slot_empty(machine, slot_index):
		return 0
	return max(int(machine.slots[slot_index].get("ready_count", 0)), 0)


func get_slot_queued_count(machine: CropMachine, slot_index: int) -> int:
	if machine == null:
		return 0
	if not is_valid_slot_index(machine, slot_index):
		return 0
	if is_slot_empty(machine, slot_index):
		return 0
	return max(int(machine.slots[slot_index].get("queued_count", 0)), 0)


func get_slot_seed_item(machine: CropMachine, slot_index: int) -> ItemData:
	if machine == null:
		return null
	if not is_valid_slot_index(machine, slot_index):
		return null
	if is_slot_empty(machine, slot_index):
		return null

	var path: String = str(machine.slots[slot_index].get("seed_item_path", ""))
	if path.is_empty():
		return null

	var base_item: ItemData = load(path) as ItemData
	if base_item == null:
		return null

	var seed_item: ItemData = base_item.duplicate(true) as ItemData
	if seed_item == null:
		seed_item = base_item
	seed_item.quality = get_slot_seed_quality(machine, slot_index)
	return seed_item


func get_slot_seed_quality(machine: CropMachine, slot_index: int) -> int:
	if machine == null:
		return 0
	if not is_valid_slot_index(machine, slot_index):
		return 0
	return max(int(machine.slots[slot_index].get("seed_quality", 0)), 0)


func get_slot_quality_bonus(machine: CropMachine, slot_index: int) -> int:
	if machine == null:
		return 0
	if not is_valid_slot_index(machine, slot_index):
		return 0
	return max(int(machine.slots[slot_index].get("slot_quality_bonus", 0)), 0)


func set_slot_quality_bonus(machine: CropMachine, slot_index: int, quality_bonus: int) -> void:
	if machine == null:
		return
	if not is_valid_slot_index(machine, slot_index):
		return

	var slot: Dictionary = machine.slots[slot_index]
	slot["slot_quality_bonus"] = max(quality_bonus, 0)
	machine.slots[slot_index] = slot
	machine.save_data()
	machine._refresh_open_ui()


func get_slot_harvest_item(machine: CropMachine, slot_index: int) -> ItemData:
	if machine == null:
		return null
	if not is_valid_slot_index(machine, slot_index):
		return null
	if is_slot_empty(machine, slot_index):
		return null

	var path: String = str(machine.slots[slot_index].get("harvest_item_path", ""))
	if path.is_empty():
		return null
	return load(path) as ItemData


func is_valid_slot_index(machine: CropMachine, slot_index: int) -> bool:
	if machine == null:
		return false
	return slot_index >= 0 and slot_index < machine.slots.size()


func _resolve_seed_quality(recipe: CropRecipe, seed_item_data: ItemData) -> int:
	if seed_item_data != null:
		return max(seed_item_data.get_quality(), 0)
	if recipe != null and recipe.seed_item != null:
		return max(recipe.seed_item.get_quality(), 0)
	return 0


func _get_slot_quality_bonus_from_slot(slot: Dictionary) -> int:
	return max(int(slot.get("slot_quality_bonus", 0)), 0)


func _make_empty_slot_preserving_bonus(machine: CropMachine, slot: Dictionary) -> Dictionary:
	var preserved_slot_quality_bonus: int = _get_slot_quality_bonus_from_slot(slot)
	return machine._make_empty_slot(preserved_slot_quality_bonus)

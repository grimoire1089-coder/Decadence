extends RefCounted
class_name CropMachineHarvestQualityModule

const FARMING_SKILL_NAME: String = "farming"
const DEFAULT_FARMING_MAX_LEVEL: int = 300


func get_player_stats_manager(machine: CropMachine) -> Node:
	if machine == null:
		return null
	return machine.get_node_or_null("/root/PlayerStatsManager")


func get_farming_quality_bonus(machine: CropMachine) -> float:
	var max_level: int = max(_get_farming_skill_max_level(machine), 1)
	return clamp(float(get_farming_level_bonus(machine)) / float(max_level), 0.0, 1.0)


func get_farming_level_bonus(machine: CropMachine) -> int:
	var stats_manager: Node = get_player_stats_manager(machine)
	if stats_manager == null:
		return 0

	if stats_manager.has_method("get_farming_quality_level_bonus"):
		return max(int(stats_manager.call("get_farming_quality_level_bonus")), 0)
	if stats_manager.has_method("get_skill"):
		return max(int(stats_manager.call("get_skill", FARMING_SKILL_NAME)), 0)
	if stats_manager.has_method("get_farming_quality_bonus"):
		var max_level: int = max(_get_farming_skill_max_level(machine), 1)
		return clamp(int(round(float(stats_manager.call("get_farming_quality_bonus")) * float(max_level))), 0, max_level)
	return 0


func get_farming_quality_passive_flat_bonus(machine: CropMachine) -> int:
	var stats_manager: Node = get_player_stats_manager(machine)
	if stats_manager == null:
		return 0

	for method_name in [
		"get_farming_quality_passive_flat_bonus",
		"get_farming_passive_quality_flat_bonus",
		"get_farming_quality_flat_bonus"
	]:
		if stats_manager.has_method(method_name):
			return max(int(stats_manager.call(method_name)), 0)

	return 0


func get_farming_quality_passive_multiplier(machine: CropMachine) -> float:
	var stats_manager: Node = get_player_stats_manager(machine)
	if stats_manager == null:
		return 1.0

	for method_name in [
		"get_farming_quality_passive_multiplier",
		"get_farming_passive_quality_multiplier",
		"get_farming_quality_multiplier"
	]:
		if stats_manager.has_method(method_name):
			return max(float(stats_manager.call(method_name)), 0.0)

	return 1.0


func get_seed_quality_bonus(machine: CropMachine, slot_index: int = -1) -> int:
	if machine == null:
		return 0
	if slot_index < 0 or slot_index >= machine.slots.size():
		return 0
	return max(int(machine.slots[slot_index].get("seed_quality", 0)), 0)


func get_slot_quality_bonus(machine: CropMachine, slot_index: int = -1) -> int:
	if machine == null:
		return 0
	if slot_index < 0 or slot_index >= machine.slots.size():
		return 0
	return max(int(machine.slots[slot_index].get("slot_quality_bonus", 0)), 0)


func get_harvest_quality_components(machine: CropMachine, slot_index: int = -1) -> Dictionary:
	var farming_level_bonus: int = get_farming_level_bonus(machine)
	var seed_quality_bonus: int = get_seed_quality_bonus(machine, slot_index)
	var slot_quality_bonus_value: int = get_slot_quality_bonus(machine, slot_index)
	var passive_flat_bonus: int = get_farming_quality_passive_flat_bonus(machine)
	var passive_multiplier: float = get_farming_quality_passive_multiplier(machine)

	return {
		"farming_level_bonus": farming_level_bonus,
		"seed_quality_bonus": seed_quality_bonus,
		"slot_quality_bonus": slot_quality_bonus_value,
		"passive_flat_bonus": passive_flat_bonus,
		"passive_multiplier": passive_multiplier
	}


func get_harvest_quality_value(machine: CropMachine, slot_index: int = -1) -> int:
	var components: Dictionary = get_harvest_quality_components(machine, slot_index)
	var base_quality: int = int(components.get("farming_level_bonus", 0)) \
		+ int(components.get("seed_quality_bonus", 0)) \
		+ int(components.get("slot_quality_bonus", 0)) \
		+ int(components.get("passive_flat_bonus", 0))
	var multiplier: float = max(float(components.get("passive_multiplier", 1.0)), 0.0)
	return max(int(round(float(base_quality) * multiplier)), 0)


func get_harvest_rank_from_quality(_machine: CropMachine, _quality_value: int) -> int:
	return 0


func build_quality_harvest_item(machine: CropMachine, base_item: ItemData, slot_index: int = -1) -> ItemData:
	if base_item == null:
		return null

	var harvested_item: ItemData = base_item.duplicate(true) as ItemData
	if harvested_item == null:
		harvested_item = base_item

	var quality_value: int = get_harvest_quality_value(machine, slot_index)
	harvested_item.quality = quality_value
	harvested_item.rank = max(harvested_item.get_rank(), 0)
	return harvested_item


func _get_farming_skill_max_level(machine: CropMachine) -> int:
	var stats_manager: Node = get_player_stats_manager(machine)
	if stats_manager != null and stats_manager.has_method("get_skill_max_level"):
		return max(int(stats_manager.call("get_skill_max_level", FARMING_SKILL_NAME)), 1)
	return DEFAULT_FARMING_MAX_LEVEL

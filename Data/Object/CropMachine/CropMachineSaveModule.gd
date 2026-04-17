extends RefCounted
class_name CropMachineSaveModule

const SAVE_PATH_PREFIX: String = "user://crop_machine_"


func get_machine_save_key(machine: CropMachine) -> String:
	if machine == null:
		return "default"

	var unique_name: String = str(machine.name)
	if unique_name.is_empty():
		unique_name = machine.machine_name
	if unique_name.is_empty():
		unique_name = "default"
	return unique_name


func get_save_path(machine: CropMachine) -> String:
	return SAVE_PATH_PREFIX + get_machine_save_key(machine) + ".json"


func build_save_payload(machine: CropMachine) -> Dictionary:
	if machine == null:
		return {}

	return {
		"slot_count": machine.slot_count,
		"slots": machine.slots.duplicate(true)
	}


func save_machine(machine: CropMachine) -> bool:
	if machine == null:
		return false

	var save_path: String = get_save_path(machine)
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("栽培機セーブ失敗: %s" % save_path)
		return false

	file.store_string(JSON.stringify(build_save_payload(machine)))
	return true


func load_machine(machine: CropMachine) -> bool:
	if machine == null:
		return false

	var save_path: String = get_save_path(machine)
	if not FileAccess.file_exists(save_path):
		return false

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("栽培機ロード失敗: %s" % save_path)
		return false

	var text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("栽培機JSON読み込み失敗: %s" % save_path)
		return false

	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return false

	apply_save_payload(machine, data)
	return true


func apply_save_payload(machine: CropMachine, data: Dictionary) -> void:
	if machine == null:
		return

	var saved_slot_count: int = clamp(int(data.get("slot_count", machine.slot_count)), 1, machine.max_slot_count)
	if saved_slot_count != machine.slot_count:
		machine._resize_slots_to_count(saved_slot_count)

	var loaded_slots_variant: Variant = data.get("slots", [])
	if typeof(loaded_slots_variant) != TYPE_ARRAY:
		return

	var loaded_slots: Array = loaded_slots_variant
	var count: int = min(machine.slot_count, loaded_slots.size())
	for i in range(count):
		var slot_variant: Variant = loaded_slots[i]
		if typeof(slot_variant) != TYPE_DICTIONARY:
			continue

		machine.slots[i] = _deserialize_slot(machine, slot_variant)


func _deserialize_slot(machine: CropMachine, incoming: Dictionary) -> Dictionary:
	var slot_quality_bonus: int = max(int(incoming.get("slot_quality_bonus", 0)), 0)
	var slot: Dictionary = machine._make_empty_slot(slot_quality_bonus)
	slot["seed_item_path"] = str(incoming.get("seed_item_path", ""))
	slot["harvest_item_path"] = str(incoming.get("harvest_item_path", ""))
	slot["display_name"] = str(incoming.get("display_name", ""))
	slot["total_minutes"] = max(int(incoming.get("total_minutes", 0)), 0)
	slot["harvest_amount"] = max(int(incoming.get("harvest_amount", 0)), 0)
	slot["recipe_key"] = str(incoming.get("recipe_key", ""))
	slot["seed_quality"] = max(int(incoming.get("seed_quality", 0)), 0)

	if incoming.has("queued_count") or incoming.has("ready_count"):
		slot["remaining_minutes"] = max(int(incoming.get("remaining_minutes", 0)), 0)
		slot["queued_count"] = max(int(incoming.get("queued_count", 0)), 0)
		slot["ready_count"] = max(int(incoming.get("ready_count", 0)), 0)
	else:
		var old_ready: bool = bool(incoming.get("ready", false))
		if old_ready:
			slot["remaining_minutes"] = 0
			slot["queued_count"] = 0
			slot["ready_count"] = 1
		else:
			slot["remaining_minutes"] = max(int(incoming.get("remaining_minutes", 0)), 0)
			if not str(slot.get("harvest_item_path", "")).is_empty():
				slot["queued_count"] = 1
			else:
				slot["queued_count"] = 0
			slot["ready_count"] = 0

	if max(int(slot.get("queued_count", 0)), 0) <= 0 and max(int(slot.get("ready_count", 0)), 0) <= 0:
		return machine._make_empty_slot(slot_quality_bonus)

	return slot

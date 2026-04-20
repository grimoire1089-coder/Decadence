extends RefCounted
class_name CropMachineGrowthModule


func connect_time_manager(machine: CropMachine) -> void:
	if machine == null:
		return

	var time_manager: Node = machine._get_time_manager()
	if time_manager == null:
		return

	var callable: Callable = Callable(machine, "_on_time_changed")
	if time_manager.has_signal("time_changed") and not time_manager.is_connected("time_changed", callable):
		time_manager.connect("time_changed", callable)


func disconnect_time_manager(machine: CropMachine) -> void:
	if machine == null:
		return

	var time_manager: Node = machine._get_time_manager()
	if time_manager == null:
		return

	var callable: Callable = Callable(machine, "_on_time_changed")
	if time_manager.has_signal("time_changed") and time_manager.is_connected("time_changed", callable):
		time_manager.disconnect("time_changed", callable)


func sync_last_total_minutes(machine: CropMachine) -> void:
	if machine == null:
		return

	var time_manager: Node = machine._get_time_manager()
	if time_manager == null:
		machine.set_last_total_minutes(-1)
		return

	var current_day: int = int(time_manager.get("day"))
	var current_hour: int = int(time_manager.get("hour"))
	var current_minute: int = int(time_manager.get("minute"))
	machine.set_last_total_minutes(to_total_minutes(current_day, current_hour, current_minute))


func to_total_minutes(day: int, hour: int, minute: int) -> int:
	return ((max(day, 1) - 1) * 24 * 60) + (clamp(hour, 0, 23) * 60) + clamp(minute, 0, 59)


func handle_time_changed(machine: CropMachine, day: int, hour: int, minute: int) -> void:
	if machine == null:
		return

	var new_total: int = to_total_minutes(day, hour, minute)
	if machine.get_last_total_minutes() < 0:
		machine.set_last_total_minutes(new_total)
		return

	var delta_minutes: int = new_total - machine.get_last_total_minutes()
	machine.set_last_total_minutes(new_total)
	if delta_minutes <= 0:
		return

	advance_growth(machine, delta_minutes)


func advance_growth(machine: CropMachine, delta_minutes: int) -> void:
	if machine == null or delta_minutes <= 0:
		return

	var changed: bool = false

	for i in range(machine.slots.size()):
		if machine.is_slot_empty(i):
			continue

		var slot_before: Dictionary = machine.slots[i].duplicate(true)
		var slot: Dictionary = machine.slots[i]
		var ready_before: int = max(int(slot.get("ready_count", 0)), 0)
		var delta_left: int = delta_minutes

		while delta_left > 0 and max(int(slot.get("queued_count", 0)), 0) > 0:
			var current_remaining: int = max(int(slot.get("remaining_minutes", 0)), 0)
			if current_remaining <= 0:
				current_remaining = max(int(slot.get("total_minutes", 0)), 1)
				slot["remaining_minutes"] = current_remaining

			if delta_left >= current_remaining:
				delta_left -= current_remaining
				slot["ready_count"] = max(int(slot.get("ready_count", 0)), 0) + 1
				slot["queued_count"] = max(int(slot.get("queued_count", 0)), 0) - 1

				if max(int(slot.get("queued_count", 0)), 0) > 0:
					slot["remaining_minutes"] = max(int(slot.get("total_minutes", 0)), 1)
				else:
					slot["remaining_minutes"] = 0
			else:
				slot["remaining_minutes"] = current_remaining - delta_left
				delta_left = 0

		var ready_after: int = max(int(slot.get("ready_count", 0)), 0)
		if ready_after > ready_before:
			var added_ready: int = ready_after - ready_before
			machine._log_system("%sのスロット%dで%sが %d 回分 収穫待ちになった" % [machine.machine_name, i + 1, machine.get_slot_display_name_from_slot(slot), added_ready])

		if slot != slot_before:
			machine.slots[i] = slot
			changed = true

	if changed:
		machine.save_data()
		machine._refresh_open_ui()

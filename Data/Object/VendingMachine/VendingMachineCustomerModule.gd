extends RefCounted
class_name VendingMachineCustomerModule

var machine: VendingMachine = null


func setup(owner_machine: VendingMachine) -> void:
	machine = owner_machine


func sync_customer_timer_pause_state() -> void:
	if machine == null or machine.customer_timer == null:
		return

	var should_pause: bool = machine.is_customer_timer_paused_by_ui() or not is_customer_simulation_authority()
	if machine.customer_timer.paused != should_pause:
		machine.customer_timer.paused = should_pause


func on_customer_timer_timeout() -> void:
	if machine == null:
		return

	if machine.is_customer_timer_paused_by_ui():
		sync_customer_timer_pause_state()
		return

	if not is_customer_simulation_authority():
		sync_customer_timer_pause_state()
		return

	simulate_customer_purchase()


func simulate_customer_purchase() -> void:
	if machine == null:
		return

	var candidates: Array[int] = []

	for i in range(machine.slots.size()):
		if not machine.slots[i].is_empty():
			candidates.append(i)

	if candidates.is_empty():
		return

	var chosen_index: int = candidates[randi() % candidates.size()]
	var slot = machine.slots[chosen_index]

	slot.amount -= 1
	machine.earnings += slot.price

	if slot.amount <= 0:
		slot.clear()

	machine.save_data()
	machine._notify_state_changed()


func is_customer_simulation_authority() -> bool:
	if machine == null:
		return true

	var current_scene: Node = machine.get_tree().current_scene
	if current_scene == null:
		return true

	if current_scene.has_method("_is_network_online") and bool(current_scene.call("_is_network_online")):
		if current_scene.has_method("_can_accept_network_gameplay_requests"):
			return bool(current_scene.call("_can_accept_network_gameplay_requests"))
		return false

	return true

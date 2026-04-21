extends RefCounted
class_name PlayerSupportController

var owner: CharacterBody2D = null


func setup(owner_node: CharacterBody2D) -> void:
	owner = owner_node


func get_stat_value(stat_name: String) -> int:
	if PlayerStatsManager == null:
		return 0
	return PlayerStatsManager.get_stat(stat_name)


func get_skill_value(skill_name: String) -> int:
	if PlayerStatsManager == null:
		return 0
	return PlayerStatsManager.get_skill(skill_name)


func add_fatigue_for_action(action_name: String, multiplier: float = 1.0, write_log: bool = false) -> int:
	if PlayerStatsManager == null:
		return 0

	var added_amount: int = PlayerStatsManager.apply_fatigue_for_action(action_name, multiplier)

	if write_log and added_amount > 0:
		_log_system("行動疲労: %s（疲労度 +%d）" % [action_name, added_amount])

	return added_amount


func set_selected_item(item_data: Resource, amount: int) -> void:
	if owner == null:
		return
	owner.selected_item_data = item_data
	owner.selected_item_amount = amount


func clear_selected_item() -> void:
	if owner == null:
		return
	owner.selected_item_data = null
	owner.selected_item_amount = 0


func try_consume_selected_item() -> bool:
	if owner == null:
		return false

	var item_data: ItemData = owner.selected_item_data as ItemData
	if item_data == null:
		return false

	if not item_data.can_eat():
		_log_warning("このアイテムは食べられない")
		return false

	if not remove_item_from_inventory(item_data, 1):
		return false

	var fullness_amount: int = item_data.get_fullness_restore()
	var fatigue_amount: int = item_data.get_fatigue_restore()

	if PlayerStatsManager != null:
		if fullness_amount > 0:
			PlayerStatsManager.restore_fullness(fullness_amount)
		if fatigue_amount > 0:
			PlayerStatsManager.recover_fatigue(fatigue_amount)

	var item_name_text: String = item_data.item_name
	if item_name_text.is_empty():
		item_name_text = str(item_data.id)

	var parts: Array[String] = []
	if fullness_amount > 0:
		parts.append("満腹度 +%d" % fullness_amount)
	if fatigue_amount > 0:
		parts.append("疲労度 -%d" % fatigue_amount)

	if parts.is_empty():
		_log_system("%sを食べた" % item_name_text)
	else:
		_log_system("%sを食べた（%s）" % [item_name_text, " / ".join(parts)])

	return true


func add_item_to_inventory(item_data: Resource, amount: int) -> bool:
	var inventory_ui: Node = _get_inventory_ui()
	if inventory_ui == null:
		_log_error("InventoryUI が見つからない")
		return false

	if inventory_ui.has_method("add_item"):
		return bool(inventory_ui.call("add_item", item_data, amount))

	_log_error("InventoryUI に add_item() がない")
	return false


func remove_item_from_inventory(item_data: Resource, amount: int) -> bool:
	var inventory_ui: Node = _get_inventory_ui()
	if inventory_ui == null:
		_log_error("InventoryUI が見つからない")
		return false

	if inventory_ui.has_method("remove_item"):
		return bool(inventory_ui.call("remove_item", item_data, amount))

	_log_error("InventoryUI に remove_item() がない")
	return false


func get_inventory_count(item_data: Resource) -> int:
	var inventory_ui: Node = _get_inventory_ui()
	if inventory_ui == null:
		return 0

	if inventory_ui.has_method("get_item_count"):
		return int(inventory_ui.call("get_item_count", item_data))

	return 0


func add_credits(amount: int) -> void:
	if amount <= 0:
		return

	if CurrencyManager != null and CurrencyManager.has_method("add_credits"):
		CurrencyManager.add_credits(amount)
		_log_system("%d Cr を獲得した" % amount)
		return

	_log_error("CurrencyManager に add_credits() がない")


func get_credits() -> int:
	if CurrencyManager != null and CurrencyManager.has_method("get_credits"):
		return int(CurrencyManager.get_credits())
	return 0


func can_spend_credits(amount: int) -> bool:
	if amount < 0:
		return false
	if CurrencyManager != null and CurrencyManager.has_method("can_spend"):
		return bool(CurrencyManager.can_spend(amount))
	return false


func spend_credits(amount: int) -> bool:
	if amount <= 0:
		return false

	if CurrencyManager != null and CurrencyManager.has_method("spend_credits"):
		return bool(CurrencyManager.spend_credits(amount))

	_log_error("CurrencyManager に spend_credits() がない")
	return false


func get_inventory_ui() -> Node:
	return _get_inventory_ui()


func get_message_log() -> Node:
	return _get_message_log()


func log_system(text: String) -> void:
	_log_system(text)


func log_warning(text: String) -> void:
	_log_warning(text)


func log_error(text: String) -> void:
	_log_error(text)


func _get_inventory_ui() -> Node:
	if owner == null:
		return null
	return owner.get_tree().get_first_node_in_group("inventory_ui") as Node


func _get_message_log() -> Node:
	if owner == null:
		return null
	return owner.get_node_or_null("/root/MessageLog")


func _log_system(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node == null:
		return
	if log_node.has_method("add_system"):
		log_node.call("add_system", text)
	elif log_node.has_method("add_message"):
		log_node.call("add_message", text, "SYSTEM")


func _log_warning(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node == null:
		return
	if log_node.has_method("add_warning"):
		log_node.call("add_warning", text)
	elif log_node.has_method("add_message"):
		log_node.call("add_message", text, "WARN")


func _log_error(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node == null:
		return
	if log_node.has_method("add_error"):
		log_node.call("add_error", text)
	elif log_node.has_method("add_message"):
		log_node.call("add_message", text, "ERROR")

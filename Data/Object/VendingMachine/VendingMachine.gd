extends StaticBody2D
class_name VendingMachine

const SAVE_PATH_PREFIX: String = "user://vending_machine_"

@export var machine_name: String = "委託自販機"
@export var interact_action_text: String = "開く"
@export var interact_prompt_offset: Vector2 = Vector2(0, -56)
@export var slot_count: int = 5
@export var item_data_folders: PackedStringArray = ["res://Data/Items/Item_defs"]

var slots: Array = []
var earnings: int = 0

@onready var interact_area: Area2D = $InteractArea
@onready var customer_timer: Timer = $CustomerTimer


func _ready() -> void:
	add_to_group("customer_timer_targets")

	_init_slots()
	load_data()

	if interact_area != null:
		interact_area.body_entered.connect(_on_body_entered)
		interact_area.body_exited.connect(_on_body_exited)

	if customer_timer != null:
		customer_timer.timeout.connect(_on_customer_timer_timeout)
		customer_timer.start()
		customer_timer.paused = false


func _init_slots() -> void:
	slots.clear()
	for _i in range(slot_count):
		slots.append(VendingSlot.new())


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("register_interactable"):
		body.register_interactable(self)
		_log_debug("プレイヤーが自販機の範囲に入った")


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("unregister_interactable"):
		body.unregister_interactable(self)


func get_interact_action_text() -> String:
	return interact_action_text


func get_interact_prompt_offset() -> Vector2:
	return interact_prompt_offset


func interact(player: Node) -> void:
	var ui: Node = get_tree().get_first_node_in_group("vending_ui")
	if ui != null and ui.has_method("open_machine"):
		ui.call("open_machine", self, player)


func stock_item(slot_index: int, item_data: Resource, amount: int, _price: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	if item_data == null or amount <= 0:
		return false

	var slot = slots[slot_index]
	var sell_price: int = _get_item_sell_price(item_data)

	if slot.is_empty():
		slot.item_data = item_data
		slot.amount = amount
		slot.price = sell_price
		save_data()
		return true

	if _can_stack_item(slot.item_data, item_data):
		slot.amount += amount
		slot.price = sell_price
		save_data()
		return true

	return false


func take_back_item(slot_index: int, amount: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"item_data": null,
		"amount": 0
	}

	if slot_index < 0 or slot_index >= slots.size():
		return result

	var slot = slots[slot_index]
	if slot.is_empty():
		return result

	var take_amount: int = mini(amount, slot.amount)
	result["success"] = true
	result["item_data"] = slot.item_data
	result["amount"] = take_amount

	slot.amount -= take_amount
	if slot.amount <= 0:
		slot.clear()

	save_data()
	return result


func set_slot_price(slot_index: int, _new_price: int) -> void:
	if slot_index < 0 or slot_index >= slots.size():
		return

	var slot = slots[slot_index]
	if slot.is_empty():
		return

	slot.price = _get_item_sell_price(slot.item_data)
	save_data()


func peek_slot_price(slot_index: int) -> int:
	if slot_index < 0 or slot_index >= slots.size():
		return 10

	var slot = slots[slot_index]
	if slot == null or slot.is_empty():
		return 10

	return slot.price


func collect_earnings(player: Node) -> int:
	if player == null:
		return 0

	var amount: int = earnings
	if amount <= 0:
		return 0

	if player.has_method("add_credits"):
		player.call("add_credits", amount)
		earnings = 0
		save_data()
		return amount

	return 0


func set_paused_by_ui(value: bool) -> void:
	if customer_timer == null:
		return
	customer_timer.paused = value


func pause_customer_timer() -> void:
	set_paused_by_ui(true)


func resume_customer_timer() -> void:
	set_paused_by_ui(false)


func is_customer_timer_paused() -> bool:
	if customer_timer == null:
		return false
	return customer_timer.paused


func _on_customer_timer_timeout() -> void:
	_simulate_customer_purchase()


func _simulate_customer_purchase() -> void:
	var candidates: Array[int] = []

	for i in range(slots.size()):
		if not slots[i].is_empty():
			candidates.append(i)

	if candidates.is_empty():
		return

	var chosen_index: int = candidates[randi() % candidates.size()]
	var slot = slots[chosen_index]

	slot.amount -= 1
	earnings += slot.price

	if slot.amount <= 0:
		slot.clear()

	save_data()

	var ui: Node = get_tree().get_first_node_in_group("vending_ui")
	if ui != null and ui.visible and ui.has_method("refresh"):
		ui.call("refresh")


func _can_stack_item(left_item: Resource, right_item: Resource) -> bool:
	var left_data: ItemData = left_item as ItemData
	var right_data: ItemData = right_item as ItemData

	if left_data == null or right_data == null:
		return left_item == right_item

	var left_id: String = str(left_data.id)
	var right_id: String = str(right_data.id)

	if not left_id.is_empty() or not right_id.is_empty():
		if left_id != right_id:
			return false
	else:
		var left_path: String = _get_item_source_path(left_data)
		var right_path: String = _get_item_source_path(right_data)
		if left_path != right_path and left_data != right_data:
			return false

	if left_data.get_quality() != right_data.get_quality():
		return false
	if left_data.get_rank() != right_data.get_rank():
		return false

	return true


func _get_item_source_path(item_data: Resource) -> String:
	if item_data == null:
		return ""

	if item_data.has_meta("source_item_path"):
		var meta_path: String = str(item_data.get_meta("source_item_path"))
		if not meta_path.is_empty():
			return meta_path

	var resource_path_text: String = String(item_data.resource_path)
	if not resource_path_text.is_empty():
		return resource_path_text

	return ""


func _load_item_by_id(item_id: String) -> ItemData:
	if item_id.is_empty():
		return null

	for folder_path in item_data_folders:
		var dir: DirAccess = DirAccess.open(folder_path)
		if dir == null:
			continue

		dir.list_dir_begin()
		while true:
			var file_name: String = dir.get_next()
			if file_name.is_empty():
				break

			if dir.current_is_dir():
				continue
			if not file_name.ends_with(".tres") and not file_name.ends_with(".res"):
				continue

			var full_path: String = folder_path.path_join(file_name)
			var res: Resource = load(full_path)
			var item_data: ItemData = res as ItemData
			if item_data == null:
				continue
			if str(item_data.id) == item_id:
				dir.list_dir_end()
				return item_data

		dir.list_dir_end()

	return null


func _build_item_from_saved_data(item_path: String, item_id: String, quality: int, rank: int) -> Resource:
	var base_item: ItemData = null

	if not item_path.is_empty():
		base_item = load(item_path) as ItemData

	if base_item == null and not item_id.is_empty():
		base_item = _load_item_by_id(item_id)

	if base_item == null:
		return null

	if quality == 0 and rank == 0:
		return base_item

	var duplicated_item: ItemData = base_item.duplicate(true) as ItemData
	if duplicated_item == null:
		duplicated_item = base_item

	duplicated_item.quality = clamp(quality, 0, 999999999)
	duplicated_item.rank = clamp(rank, 0, 5)
	duplicated_item.set_meta("source_item_path", _get_item_source_path(base_item))
	duplicated_item.set_meta("source_item_id", str(base_item.id))
	return duplicated_item


func _get_item_name(item_data: Resource) -> String:
	if item_data == null:
		return "不明"
	if "item_name" in item_data:
		return str(item_data.item_name)
	if "name" in item_data:
		return str(item_data.name)
	return item_data.resource_name


func _get_item_sell_price(item_data: Resource) -> int:
	var item: ItemData = item_data as ItemData
	if item == null:
		return 0

	if item.has_method("get_sell_price"):
		return maxi(int(item.get_sell_price()), 0)

	return maxi(int(item.price), 0)


func _get_save_path() -> String:
	var unique_name: String = str(name)
	if unique_name.is_empty():
		unique_name = machine_name
	if unique_name.is_empty():
		unique_name = "default"
	return SAVE_PATH_PREFIX + unique_name + ".json"


func save_data() -> void:
	var slots_data: Array = []
	for slot in slots:
		var item_path: String = ""
		var item_id: String = ""
		var quality: int = 0
		var rank: int = 0

		var item_data: ItemData = slot.item_data as ItemData
		if item_data != null:
			item_path = _get_item_source_path(item_data)
			item_id = str(item_data.id)
			quality = item_data.get_quality()
			rank = item_data.get_rank()

		slots_data.append({
			"item_path": item_path,
			"item_id": item_id,
			"quality": quality,
			"rank": rank,
			"amount": int(slot.amount),
			"price": int(slot.price)
		})

	var data: Dictionary = {
		"earnings": earnings,
		"slots": slots_data
	}

	var file: FileAccess = FileAccess.open(_get_save_path(), FileAccess.WRITE)
	if file == null:
		push_error("自販機セーブ失敗: %s" % _get_save_path())
		return

	file.store_string(JSON.stringify(data))


func load_data() -> void:
	var save_path: String = _get_save_path()
	if not FileAccess.file_exists(save_path):
		return

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("自販機ロード失敗: %s" % save_path)
		return

	var text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("自販機JSON読み込み失敗: %s" % save_path)
		return

	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return

	earnings = maxi(int(data.get("earnings", 0)), 0)

	var loaded_slots: Variant = data.get("slots", [])
	if typeof(loaded_slots) != TYPE_ARRAY:
		return

	var loaded_slots_array: Array = loaded_slots
	var count: int = mini(slots.size(), loaded_slots_array.size())
	for i in range(count):
		var slot_data: Variant = loaded_slots_array[i]
		if typeof(slot_data) != TYPE_DICTIONARY:
			continue

		var slot = slots[i]
		slot.clear()

		var item_path: String = str(slot_data.get("item_path", ""))
		var item_id: String = str(slot_data.get("item_id", ""))
		var quality: int = maxi(int(slot_data.get("quality", 0)), 0)
		var rank: int = clamp(int(slot_data.get("rank", 0)), 0, 5)
		var amount: int = maxi(int(slot_data.get("amount", 0)), 0)

		if amount <= 0:
			continue

		var item_data: Resource = _build_item_from_saved_data(item_path, item_id, quality, rank)
		if item_data == null:
			continue

		slot.item_data = item_data
		slot.amount = amount
		slot.price = _get_item_sell_price(item_data)


func _get_player_credits(player: Node) -> int:
	if player == null:
		return 0

	if player.has_method("get_credits"):
		return int(player.call("get_credits"))

	return int(player.get("credits"))


func _get_message_log() -> Node:
	return get_node_or_null("/root/MessageLog")


func _log_debug(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_debug"):
		log_node.call("add_debug", text)

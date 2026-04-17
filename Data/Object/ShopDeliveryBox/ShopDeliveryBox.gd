extends StaticBody2D
class_name ShopDeliveryBox

const SAVE_PATH_PREFIX: String = "user://shop_delivery_box_"

@export var object_name: String = "ショップ宅配ボックス"
@export var shop_data: ShopData
@export var shops: Array = []
@export var default_shop_index: int = 0
@export var delivery_seconds: float = 1.0
@export var delivery_tick_interval: float = 0.1
@export var item_data_folders: PackedStringArray = ["res://Data/Items/Item_defs"]

var pending_orders: Array[Dictionary] = []
var delivery_entries: Array[Dictionary] = []

@onready var interact_area: Area2D = $InteractArea
@onready var delivery_tick_timer: Timer = $DeliveryTickTimer


func _ready() -> void:
	add_to_group("customer_timer_targets")
	load_data()

	if interact_area != null:
		if not interact_area.body_entered.is_connected(_on_body_entered):
			interact_area.body_entered.connect(_on_body_entered)
		if not interact_area.body_exited.is_connected(_on_body_exited):
			interact_area.body_exited.connect(_on_body_exited)

	if delivery_tick_timer != null:
		delivery_tick_timer.wait_time = max(delivery_tick_interval, 0.05)
		delivery_tick_timer.one_shot = false
		delivery_tick_timer.autostart = false
		if not delivery_tick_timer.timeout.is_connected(_on_delivery_tick_timer_timeout):
			delivery_tick_timer.timeout.connect(_on_delivery_tick_timer_timeout)

	_update_timer_state()


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("register_interactable"):
		body.register_interactable(self)
		_log_debug("プレイヤーがショップ宅配ボックスの範囲に入った")


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("unregister_interactable"):
		body.unregister_interactable(self)


func interact(player: Node) -> void:
	var ui: Node = get_tree().get_first_node_in_group("shop_delivery_ui")
	if ui != null and ui.has_method("open_box"):
		ui.call("open_box", self, player)


func get_object_display_name() -> String:
	if not object_name.is_empty():
		return object_name

	var available_shops: Array = _get_available_shops()
	if available_shops.size() == 1:
		return available_shops[0].get_store_name()

	return "ショップ宅配ボックス"


func get_shop_count() -> int:
	return _get_available_shops().size()


func get_default_shop_index() -> int:
	var count: int = get_shop_count()
	if count <= 0:
		return -1
	return clamp(default_shop_index, 0, count - 1)


func get_store_name(shop_index: int = -1) -> String:
	var shop: ShopData = _resolve_shop(shop_index)
	if shop != null and not shop.get_store_name().is_empty():
		return shop.get_store_name()

	if shop_index < 0:
		var available_shops: Array = _get_available_shops()
		if available_shops.size() == 1:
			return available_shops[0].get_store_name()

	return get_object_display_name()


func get_shop_description(shop_index: int = -1) -> String:
	var shop: ShopData = _resolve_shop(shop_index)
	if shop == null:
		return ""
	return String(shop.description)


func get_products(shop_index: int = -1) -> Array:
	var shop: ShopData = _resolve_shop(shop_index)
	if shop == null:
		var empty_products: Array = []
		return empty_products
	return shop.get_products()


func get_product(product_index: int, shop_index: int = -1) -> ShopProduct:
	var shop: ShopData = _resolve_shop(shop_index)
	if shop == null:
		return null
	return shop.get_product(product_index)


func get_pending_order_count() -> int:
	var total: int = 0
	for order in pending_orders:
		total += int(order.get("count", 0))
	return total


func get_delivery_entries() -> Array[Dictionary]:
	return delivery_entries


func place_order(player: Node, product_index: int, order_count: int = 1, shop_index: int = -1) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"message": "",
		"total_price": 0,
		"item_count": 0
	}

	if player == null:
		result["message"] = "プレイヤーが見つからない"
		return result

	if order_count <= 0:
		result["message"] = "注文数が不正"
		return result

	var product: ShopProduct = get_product(product_index, shop_index)
	if product == null:
		result["message"] = "商品が見つからない"
		return result

	var item_data: ItemData = product.get_item_data()
	if item_data == null:
		result["message"] = "アイテムデータが設定されていない"
		return result

	var total_item_count: int = max(product.amount_per_purchase, 1) * order_count
	var total_price: int = product.get_total_price(order_count)
	result["total_price"] = total_price
	result["item_count"] = total_item_count

	if total_price <= 0:
		result["message"] = "価格が不正"
		return result

	if player.has_method("can_spend_credits"):
		if not bool(player.call("can_spend_credits", total_price)):
			result["message"] = "クレジットが足りない"
			return result

	if not player.has_method("spend_credits"):
		result["message"] = "プレイヤーに spend_credits() がない"
		return result

	if not bool(player.call("spend_credits", total_price)):
		result["message"] = "購入に失敗した"
		return result

	pending_orders.append({
		"item_data": item_data,
		"count": total_item_count,
		"remaining_seconds": max(delivery_seconds, 0.01),
		"unit_price": product.get_unit_price()
	})

	_update_timer_state()
	save_data()
	_refresh_ui_if_open()

	var item_name_text: String = _get_item_name(item_data)
	var store_name_text: String = get_store_name(shop_index)
	result["success"] = true
	result["message"] = "%s で %s を %d個 注文した" % [store_name_text, item_name_text, total_item_count]
	_log_shop("%s で %s を %d個 注文した（%d Cr）" % [store_name_text, item_name_text, total_item_count, total_price])

	return result


func claim_delivery_entry(player: Node, entry_index: int, amount: int = 1) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"message": "",
		"claimed_count": 0
	}

	if player == null:
		result["message"] = "プレイヤーが見つからない"
		return result

	if entry_index < 0 or entry_index >= delivery_entries.size():
		result["message"] = "受け取り対象が無効"
		return result

	var entry: Dictionary = delivery_entries[entry_index]
	var item_data: ItemData = entry.get("item_data", null) as ItemData
	if item_data == null:
		result["message"] = "アイテムデータが壊れている"
		return result

	var current_count: int = int(entry.get("count", 0))
	if current_count <= 0:
		result["message"] = "受け取り在庫が空"
		return result

	var claim_count: int = mini(max(amount, 1), current_count)

	if not player.has_method("add_item_to_inventory"):
		result["message"] = "プレイヤーに add_item_to_inventory() がない"
		return result

	if not bool(player.call("add_item_to_inventory", item_data, claim_count)):
		result["message"] = "インベントリに追加できない"
		return result

	current_count -= claim_count
	if current_count <= 0:
		delivery_entries.remove_at(entry_index)
	else:
		entry["count"] = current_count
		delivery_entries[entry_index] = entry

	save_data()
	_refresh_ui_if_open()

	var item_name_text: String = _get_item_name(item_data)
	result["success"] = true
	result["claimed_count"] = claim_count
	result["message"] = "%s を %d個 受け取った" % [item_name_text, claim_count]
	_log_shop("%s から %s を %d個 受け取った" % [get_object_display_name(), item_name_text, claim_count])

	return result


func claim_all_delivery(player: Node) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"message": "",
		"claimed_total": 0
	}

	if player == null:
		result["message"] = "プレイヤーが見つからない"
		return result

	if delivery_entries.is_empty():
		result["message"] = "受け取りできる商品がない"
		return result

	var claimed_total: int = 0
	var index: int = delivery_entries.size() - 1
	while index >= 0:
		var entry: Dictionary = delivery_entries[index]
		var item_data: ItemData = entry.get("item_data", null) as ItemData
		var count: int = int(entry.get("count", 0))

		if item_data != null and count > 0:
			if player.has_method("add_item_to_inventory"):
				if bool(player.call("add_item_to_inventory", item_data, count)):
					claimed_total += count
					delivery_entries.remove_at(index)

		index -= 1

	if claimed_total <= 0:
		result["message"] = "インベントリに追加できなかった"
		return result

	save_data()
	_refresh_ui_if_open()

	result["success"] = true
	result["claimed_total"] = claimed_total
	result["message"] = "%d個 をまとめて受け取った" % claimed_total
	_log_shop("%s から %d個 をまとめて受け取った" % [get_object_display_name(), claimed_total])

	return result


func set_paused_by_ui(value: bool) -> void:
	if delivery_tick_timer == null:
		return
	delivery_tick_timer.paused = value


func pause_customer_timer() -> void:
	set_paused_by_ui(true)


func resume_customer_timer() -> void:
	set_paused_by_ui(false)


func is_customer_timer_paused() -> bool:
	if delivery_tick_timer == null:
		return false
	return delivery_tick_timer.paused


func _on_delivery_tick_timer_timeout() -> void:
	if pending_orders.is_empty():
		_update_timer_state()
		return

	var changed: bool = false
	var step: float = max(delivery_tick_timer.wait_time, 0.01)

	for i in range(pending_orders.size() - 1, -1, -1):
		var order: Dictionary = pending_orders[i]
		var remaining_seconds: float = float(order.get("remaining_seconds", 0.0))
		remaining_seconds -= step
		order["remaining_seconds"] = remaining_seconds

		if remaining_seconds <= 0.0:
			var item_data: ItemData = order.get("item_data", null) as ItemData
			var count: int = int(order.get("count", 0))
			if item_data != null and count > 0:
				_add_delivery_item(item_data, count)
				_log_shop("%s に %s が %d個 届いた" % [get_object_display_name(), _get_item_name(item_data), count])

			pending_orders.remove_at(i)
			changed = true
		else:
			pending_orders[i] = order

	if changed:
		save_data()
		_refresh_ui_if_open()

	_update_timer_state()


func _add_delivery_item(item_data: ItemData, amount: int) -> void:
	if item_data == null or amount <= 0:
		return

	for i in range(delivery_entries.size()):
		var entry: Dictionary = delivery_entries[i]
		var entry_item: ItemData = entry.get("item_data", null) as ItemData
		if _can_stack_item(entry_item, item_data):
			entry["count"] = int(entry.get("count", 0)) + amount
			delivery_entries[i] = entry
			return

	delivery_entries.append({
		"item_data": item_data,
		"count": amount
	})


func _update_timer_state() -> void:
	if delivery_tick_timer == null:
		return

	if pending_orders.is_empty():
		delivery_tick_timer.stop()
	else:
		if delivery_tick_timer.is_stopped():
			delivery_tick_timer.start()


func _refresh_ui_if_open() -> void:
	var ui: Node = get_tree().get_first_node_in_group("shop_delivery_ui")
	if ui != null and ui.visible and ui.has_method("refresh"):
		ui.call("refresh")


func _get_available_shops() -> Array:
	var result: Array = []

	for entry_variant in shops:
		var entry: ShopData = entry_variant as ShopData
		if entry != null:
			result.append(entry)

	if result.is_empty() and shop_data != null:
		result.append(shop_data)

	return result


func _resolve_shop(shop_index: int = -1) -> ShopData:
	var available_shops: Array = _get_available_shops()
	if available_shops.is_empty():
		return null

	if shop_index < 0:
		shop_index = clamp(default_shop_index, 0, available_shops.size() - 1)

	if shop_index < 0 or shop_index >= available_shops.size():
		return null

	return available_shops[shop_index] as ShopData


func _can_stack_item(left_item: ItemData, right_item: ItemData) -> bool:
	if left_item == null or right_item == null:
		return false

	var left_id: String = str(left_item.id)
	var right_id: String = str(right_item.id)

	if not left_id.is_empty() or not right_id.is_empty():
		if left_id != right_id:
			return false
	else:
		var left_path: String = _get_item_source_path(left_item)
		var right_path: String = _get_item_source_path(right_item)
		if left_path != right_path and left_item != right_item:
			return false

	if left_item.get_quality() != right_item.get_quality():
		return false
	if left_item.get_rank() != right_item.get_rank():
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


func _build_item_from_saved_data(item_path: String, item_id: String, quality: int, rank: int) -> ItemData:
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


func _serialize_item_entry(item_data: ItemData, count: int) -> Dictionary:
	var item_path: String = ""
	var item_id: String = ""
	var quality: int = 0
	var rank: int = 0

	if item_data != null:
		item_path = _get_item_source_path(item_data)
		item_id = str(item_data.id)
		quality = item_data.get_quality()
		rank = item_data.get_rank()

	return {
		"item_path": item_path,
		"item_id": item_id,
		"quality": quality,
		"rank": rank,
		"count": count
	}


func _serialize_pending_order(order: Dictionary) -> Dictionary:
	var item_data: ItemData = order.get("item_data", null) as ItemData
	var base_data: Dictionary = _serialize_item_entry(item_data, int(order.get("count", 0)))
	base_data["remaining_seconds"] = float(order.get("remaining_seconds", 0.0))
	base_data["unit_price"] = int(order.get("unit_price", 0))
	return base_data


func _get_item_name(item_data: Resource) -> String:
	if item_data == null:
		return "不明"
	if "item_name" in item_data:
		return str(item_data.item_name)
	if "name" in item_data:
		return str(item_data.name)
	return item_data.resource_name


func _get_save_path() -> String:
	var unique_name: String = str(name)
	if unique_name.is_empty():
		unique_name = object_name
	if unique_name.is_empty():
		unique_name = "default"
	return SAVE_PATH_PREFIX + unique_name + ".json"


func save_data() -> void:
	var pending_data: Array = []
	for order in pending_orders:
		pending_data.append(_serialize_pending_order(order))

	var delivery_data: Array = []
	for entry in delivery_entries:
		var item_data: ItemData = entry.get("item_data", null) as ItemData
		var count: int = int(entry.get("count", 0))
		delivery_data.append(_serialize_item_entry(item_data, count))

	var data: Dictionary = {
		"pending_orders": pending_data,
		"delivery_entries": delivery_data
	}

	var file: FileAccess = FileAccess.open(_get_save_path(), FileAccess.WRITE)
	if file == null:
		push_error("ショップ宅配ボックスのセーブ失敗: %s" % _get_save_path())
		return

	file.store_string(JSON.stringify(data))


func load_data() -> void:
	pending_orders.clear()
	delivery_entries.clear()

	var save_path: String = _get_save_path()
	if not FileAccess.file_exists(save_path):
		return

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_error("ショップ宅配ボックスのロード失敗: %s" % save_path)
		return

	var text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		push_error("ショップ宅配ボックスJSON読み込み失敗: %s" % save_path)
		return

	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return

	var pending_data: Variant = data.get("pending_orders", [])
	if typeof(pending_data) == TYPE_ARRAY:
		for row in pending_data:
			if typeof(row) != TYPE_DICTIONARY:
				continue

			var item_path: String = str(row.get("item_path", ""))
			var item_id: String = str(row.get("item_id", ""))
			var quality: int = maxi(int(row.get("quality", 0)), 0)
			var rank: int = clamp(int(row.get("rank", 0)), 0, 5)
			var count: int = maxi(int(row.get("count", 0)), 0)
			var remaining_seconds: float = max(float(row.get("remaining_seconds", 0.0)), 0.0)
			var unit_price: int = maxi(int(row.get("unit_price", 0)), 0)

			if count <= 0:
				continue

			var item_data: ItemData = _build_item_from_saved_data(item_path, item_id, quality, rank)
			if item_data == null:
				continue

			pending_orders.append({
				"item_data": item_data,
				"count": count,
				"remaining_seconds": remaining_seconds,
				"unit_price": unit_price
			})

	var delivery_data: Variant = data.get("delivery_entries", [])
	if typeof(delivery_data) == TYPE_ARRAY:
		for row in delivery_data:
			if typeof(row) != TYPE_DICTIONARY:
				continue

			var item_path: String = str(row.get("item_path", ""))
			var item_id: String = str(row.get("item_id", ""))
			var quality: int = maxi(int(row.get("quality", 0)), 0)
			var rank: int = clamp(int(row.get("rank", 0)), 0, 5)
			var count: int = maxi(int(row.get("count", 0)), 0)

			if count <= 0:
				continue

			var item_data: ItemData = _build_item_from_saved_data(item_path, item_id, quality, rank)
			if item_data == null:
				continue

			delivery_entries.append({
				"item_data": item_data,
				"count": count
			})


func _get_message_log() -> Node:
	return get_node_or_null("/root/MessageLog")


func _log_debug(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_debug"):
		log_node.call("add_debug", text)


func _log_shop(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node != null and log_node.has_method("add_shop"):
		log_node.call("add_shop", text)
	elif log_node != null and log_node.has_method("add_message"):
		log_node.call("add_message", text, "SHOP")

extends Resource
class_name ShopProduct

@export var item_data: ItemData
@export_range(1, 999999) var amount_per_purchase: int = 1
@export_range(0, 999999999) var price_override: int = 0


func get_item_data() -> ItemData:
	return item_data


func get_unit_price() -> int:
	if price_override > 0:
		return price_override
	if item_data == null:
		return 0
	return item_data.get_buy_price()


func get_total_price(order_count: int = 1) -> int:
	var safe_order_count: int = max(order_count, 1)
	return get_unit_price() * max(amount_per_purchase, 1) * safe_order_count


func get_display_name() -> String:
	if item_data == null:
		return "不明な商品"

	if not item_data.item_name.is_empty():
		return item_data.item_name

	if not str(item_data.id).is_empty():
		return str(item_data.id)

	return "不明な商品"

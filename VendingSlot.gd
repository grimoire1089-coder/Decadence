extends RefCounted
class_name VendingSlot

var item_data: Resource = null
var amount: int = 0
var price: int = 10

func is_empty() -> bool:
	return item_data == null or amount <= 0

func clear() -> void:
	item_data = null
	amount = 0
	price = 10

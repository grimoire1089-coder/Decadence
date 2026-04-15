extends RefCounted
class_name InventoryEntry

var item_data: ItemData
var count: int

func _init(_item_data: ItemData, _count: int) -> void:
	item_data = _item_data
	count = _count

extends Resource
class_name ShopData

@export var store_name: String = "ショップ"
@export_multiline var description: String = ""
@export var products: Array = []


func get_store_name() -> String:
	if not store_name.is_empty():
		return store_name
	return "ショップ"


func get_products() -> Array:
	return products


func get_product(index: int) -> ShopProduct:
	if index < 0 or index >= products.size():
		return null
	return products[index] as ShopProduct

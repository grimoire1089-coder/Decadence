extends CanvasLayer

@onready var inventory_ui = $InventoryUI

func _ready() -> void:
	if inventory_ui == null:
		push_error("CanvasLayer の子に InventoryUI がない")
		return

	inventory_ui.visible = false
	print("InventoryToggle ready")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle"):
		print("inventory action pressed")
		inventory_ui.visible = !inventory_ui.visible
		print("inventory_ui.visible =", inventory_ui.visible)

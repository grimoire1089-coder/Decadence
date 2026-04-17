extends Node2D

@onready var player: Node = get_node_or_null("Player")
@onready var loading_overlay: Node = get_node_or_null("UI/LoadingOverlay")
@onready var inventory_ui = $UI/InventoryUI

func _ready() -> void:
	call_deferred("_boot_game")


func _boot_game() -> void:
	player.set_input_locked(true)
	loading_overlay.open("読み込み中…", 0)
	await get_tree().process_frame

	loading_overlay.set_status("インベントリデータを読み込み中…")
	loading_overlay.set_progress(30)
	inventory_ui.boot_initialize()
	await get_tree().process_frame

	loading_overlay.set_status("完了")
	loading_overlay.set_progress(100)
	await get_tree().create_timer(0.15).timeout

	loading_overlay.close()
	await get_tree().process_frame
	_resume_time_manager()
	player.set_input_locked(false)


func _resume_time_manager() -> void:
	var time_manager: Node = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return

	if time_manager.has_method("start_time"):
		time_manager.call("start_time")
		return

	if time_manager.has_method("set_time_running"):
		time_manager.call("set_time_running", true)
		return

	for property_info in time_manager.get_property_list():
		if String(property_info.get("name", "")) == "is_running":
			time_manager.set("is_running", true)
			return


func _set_player_input_locked(value: bool) -> void:
	if player != null and player.has_method("set_input_locked"):
		player.call("set_input_locked", value)


func _open_loading_overlay(text: String, progress: float = -1.0) -> void:
	if loading_overlay != null and loading_overlay.has_method("open"):
		loading_overlay.call("open", text, progress)


func _update_loading_overlay(text: String, progress: float = -1.0) -> void:
	if loading_overlay == null:
		return

	if loading_overlay.has_method("set_status"):
		loading_overlay.call("set_status", text)

	if loading_overlay.has_method("set_progress"):
		loading_overlay.call("set_progress", progress)


func _close_loading_overlay() -> void:
	if loading_overlay != null and loading_overlay.has_method("close"):
		loading_overlay.call("close")


func _load_item_defs() -> void:
	# 例:
	# ItemDatabase.load_all()
	pass


func _load_recipe_defs() -> void:
	# 例:
	# RecipeDatabase.load_all()
	pass


func _init_shop_data() -> void:
	# 例:
	# ShopManager.setup()
	pass


func _init_crop_data() -> void:
	# 例:
	# CropManager.setup()
	pass


func _build_ui() -> void:
	# 例:
	# var main_ui: Node = get_node_or_null("UI/MainUI")
	# if main_ui != null and main_ui.has_method("refresh_all"):
	# 	main_ui.call("refresh_all")
	pass

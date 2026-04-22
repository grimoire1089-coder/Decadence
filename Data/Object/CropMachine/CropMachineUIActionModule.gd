
extends RefCounted
class_name CropMachineUIActionModule

var ui: CropMachineUI = null


func setup(owner_ui: CropMachineUI) -> void:
	ui = owner_ui


func on_plant_pressed() -> void:
	if ui == null or ui.current_machine == null or ui.current_player == null or ui.selected_slot_index < 0:
		return

	var recipe: CropRecipe = ui._get_selected_recipe()
	if recipe == null:
		ui.info_label.text = "植え付けレシピがない"
		return
	if recipe.seed_item == null:
		ui.info_label.text = "種アイテムが未設定"
		return
	if not ui.current_machine.can_plant_recipe_in_slot(ui.selected_slot_index, recipe):
		ui.info_label.text = "使用中スロットには同じ作物だけ追加投入できる"
		return

	var plant_count: int = ui._get_effective_plant_count()
	var removed_seed_result: Dictionary = remove_seed_items_for_planting(recipe.seed_item, plant_count)
	if not bool(removed_seed_result.get("success", false)):
		ui.info_label.text = "必要な種が %d 個 足りない" % plant_count
		return

	var representative_seed_item: ItemData = removed_seed_result.get("representative_item_data", null) as ItemData
	if representative_seed_item == null:
		representative_seed_item = recipe.seed_item

	if can_route_crop_actions_through_world():
		var seed_item_payload: Dictionary = {}
		if ui.current_machine.has_method("build_network_item_payload"):
			seed_item_payload = ui.current_machine.call("build_network_item_payload", representative_seed_item) as Dictionary

		ui._pending_network_plant_request = {
			"removed_entries": removed_seed_result.get("removed_entries", []).duplicate(true),
			"slot_index": ui.selected_slot_index,
			"plant_count": plant_count,
			"recipe_key": ui._get_recipe_key(recipe),
		}

		ui.info_label.text = "植え付け要求を送信した"
		request_networked_crop_action({
			"interaction_kind": "crop_machine_plant",
			"machine_path": str(ui.current_machine.get_path()),
			"request_peer_id": get_request_peer_id(ui.current_player),
			"slot_index": ui.selected_slot_index,
			"plant_count": plant_count,
			"recipe_key": ui._get_recipe_key(recipe),
			"seed_item_payload": seed_item_payload,
			"removed_entries_payload": build_removed_entries_payload(removed_seed_result.get("removed_entries", [])),
		})
		ui.refresh()
		return

	var was_empty: bool = ui.current_machine.is_slot_empty(ui.selected_slot_index)
	var planted: bool = ui.current_machine.plant_slot(ui.selected_slot_index, recipe, plant_count, representative_seed_item)
	if not planted:
		restore_removed_seed_entries(removed_seed_result.get("removed_entries", []))
		ui.info_label.text = "植え付けできなかった"
		return

	if was_empty:
		ui.info_label.text = "%sを %d 回分 セットした" % [recipe.get_display_name(), plant_count]
		ui._log_system("%sのスロット%dに%sを %d 回分 セットした" % [ui.current_machine.machine_name, ui.selected_slot_index + 1, recipe.get_display_name(), plant_count])
	else:
		ui.info_label.text = "%sを %d 回分 追加投入した" % [recipe.get_display_name(), plant_count]
		ui._log_system("%sのスロット%dに%sを %d 回分 追加投入した" % [ui.current_machine.machine_name, ui.selected_slot_index + 1, recipe.get_display_name(), plant_count])
	ui.refresh()


func on_harvest_pressed() -> void:
	if ui == null or ui.current_machine == null or ui.current_player == null or ui.selected_slot_index < 0:
		return

	var before_name: String = ui.current_machine.get_slot_display_name(ui.selected_slot_index)
	var result: Dictionary = ui.current_machine.harvest_slot(ui.selected_slot_index)
	if not bool(result.get("success", false)):
		ui.info_label.text = "まだ収穫できない"
		return

	var item_data: ItemData = result.get("item_data", null) as ItemData
	var amount: int = int(result.get("amount", 0))
	var ready_cycles: int = int(result.get("ready_cycles", 0))
	if item_data == null or amount <= 0 or ready_cycles <= 0:
		ui.info_label.text = "収穫データが不正"
		return

	var add_ok: bool = bool(ui.current_player.call("add_item_to_inventory", item_data, amount))
	if not add_ok:
		ui.info_label.text = "インベントリに入れられない"
		return

	ui._grant_farming_harvest_exp_for_slot(ui.selected_slot_index, ready_cycles)

	var quality_text: String = build_item_quality_text(item_data)
	ui.info_label.text = "%sを %d 回分 収穫して %d 個受け取った（%s）" % [before_name, ready_cycles, amount, quality_text]
	ui._log_system("%sのスロット%dから%sを %d 回分収穫して %d 個受け取った（%s）" % [ui.current_machine.machine_name, ui.selected_slot_index + 1, before_name, ready_cycles, amount, quality_text])
	ui.refresh()


func on_cancel_pressed() -> void:
	if ui == null or ui.current_machine == null or ui.current_player == null or ui.selected_slot_index < 0:
		return

	var preview: Dictionary = ui.current_machine.get_slot_cancel_preview(ui.selected_slot_index)
	if not bool(preview.get("success", false)):
		ui.info_label.text = "キャンセルできる栽培がない"
		return

	ui.pending_cancel_slot_index = ui.selected_slot_index
	ui.pending_cancel_preview = preview
	ui.cancel_confirm_dialog.dialog_text = build_cancel_confirm_text(preview)
	ui.cancel_confirm_dialog.popup_centered()


func build_cancel_confirm_text(preview: Dictionary) -> String:
	var display_name: String = str(preview.get("display_name", "作物"))
	var ready_cycles: int = int(preview.get("ready_cycles", 0))
	var ready_amount: int = int(preview.get("ready_amount", 0))
	var return_seed_count: int = int(preview.get("return_seed_count", 0))
	var lines: PackedStringArray = []
	lines.append("%s の栽培をキャンセルする。" % display_name)
	if ready_cycles > 0 and ready_amount > 0:
		var ready_quality: int = int(preview.get("ready_quality", 0))
		var ready_rank: int = int(preview.get("ready_rank", 0))
		var star_text: String = "☆☆☆☆☆"
		if ready_rank > 0:
			star_text = ""
			for i in range(ready_rank):
				star_text += "★"
			for i in range(5 - ready_rank):
				star_text += "☆"
		lines.append("完了分: %d 回分 → 収穫物 %d 個を受け取る（品質%d / %s）" % [ready_cycles, ready_amount, ready_quality, star_text])
	if return_seed_count > 0:
		lines.append("未完了分: %d 回分 → 種 %d 個が戻る" % [return_seed_count, return_seed_count])
	lines.append("本当にキャンセルしていいか？")
	return "\n".join(lines)


func on_cancel_confirmed() -> void:
	if ui == null or ui.current_machine == null or ui.current_player == null or ui.pending_cancel_slot_index < 0:
		return

	var target_slot_index: int = ui.pending_cancel_slot_index
	var preview: Dictionary = ui.pending_cancel_preview.duplicate(true)
	ui.pending_cancel_slot_index = -1
	ui.pending_cancel_preview.clear()
	if not bool(preview.get("success", false)):
		ui.info_label.text = "キャンセルできなかった"
		ui.refresh()
		return

	var ready_item_data: ItemData = preview.get("ready_item_data", null) as ItemData
	var ready_amount: int = int(preview.get("ready_amount", 0))
	var ready_cycles: int = int(preview.get("ready_cycles", 0))
	var seed_item_data: ItemData = preview.get("seed_item_data", null) as ItemData
	var return_seed_count: int = int(preview.get("return_seed_count", 0))
	var display_name: String = str(preview.get("display_name", "作物"))
	var ready_quality_text: String = build_item_quality_text(ready_item_data)

	if ready_amount > 0 and ready_item_data != null:
		var add_harvest_ok: bool = bool(ui.current_player.call("add_item_to_inventory", ready_item_data, ready_amount))
		if not add_harvest_ok:
			ui.info_label.text = "完了分の収穫物をインベントリに入れられない"
			ui.refresh()
			return

	if return_seed_count > 0 and seed_item_data != null:
		var add_seed_ok: bool = bool(ui.current_player.call("add_item_to_inventory", seed_item_data, return_seed_count))
		if not add_seed_ok:
			if ready_amount > 0 and ready_item_data != null:
				ui.current_player.call("remove_item_from_inventory", ready_item_data, ready_amount)
			ui.info_label.text = "未完了分の種をインベントリに戻せない"
			ui.refresh()
			return

	if ready_cycles > 0 and ready_amount > 0:
		ui._grant_farming_harvest_exp_for_slot(target_slot_index, ready_cycles)

	ui.current_machine.clear_slot(target_slot_index)

	var parts: PackedStringArray = []
	if ready_cycles > 0 and ready_amount > 0:
		parts.append("完了分 %d 回分を収穫して %d 個受け取った（%s）" % [ready_cycles, ready_amount, ready_quality_text])
	if return_seed_count > 0:
		parts.append("未完了分の種 %d 個を戻した" % return_seed_count)
	if parts.is_empty():
		parts.append("キャンセルした")

	ui.info_label.text = "%sをキャンセルした。%s" % [display_name, "、".join(parts)]
	ui._log_system("%sのスロット%dの%sをキャンセルした。%s" % [ui.current_machine.machine_name, target_slot_index + 1, display_name, "、".join(parts)])
	ui.refresh()


func on_unlock_slot_pressed() -> void:
	if ui == null or ui.current_machine == null or ui.current_player == null:
		return
	if not ui.current_machine.can_unlock_slot():
		ui.info_label.text = "これ以上スロットを増やせない"
		ui._update_action_buttons()
		return

	var unlock_cost: int = ui.current_machine.get_next_slot_unlock_cost()
	if not can_player_spend_credits(unlock_cost):
		ui.info_label.text = "クレジットが足りない（必要: %d Cr / 所持: %d Cr）" % [unlock_cost, get_player_credits()]
		ui._update_action_buttons()
		return

	if can_route_crop_actions_through_world():
		ui.info_label.text = "スロット解放要求を送信した"
		request_networked_crop_action({
			"interaction_kind": "crop_machine_unlock_slot",
			"machine_path": str(ui.current_machine.get_path()),
			"request_peer_id": get_request_peer_id(ui.current_player),
		})
		return

	if not spend_player_credits(unlock_cost):
		ui.info_label.text = "クレジットの支払いに失敗した"
		ui._update_action_buttons()
		return

	var next_slot_number: int = ui.current_machine.get_unlocked_slot_count() + 1
	var unlocked: bool = ui.current_machine.unlock_slot()
	if not unlocked:
		refund_player_credits(unlock_cost)
		ui.info_label.text = "スロット解放に失敗した"
		ui._update_action_buttons()
		return

	ui.selected_slot_index = ui.current_machine.get_unlocked_slot_count() - 1
	ui.info_label.text = "スロット%dを解放した（-%d Cr）" % [next_slot_number, unlock_cost]
	ui._log_system("%sのスロット%dを %d Cr で解放した" % [ui.current_machine.machine_name, next_slot_number, unlock_cost])
	ui.refresh()


func handle_network_plant_result(result: Dictionary) -> void:
	if ui == null or result.is_empty():
		return
	if String(result.get("interaction_kind", "")).strip_edges() != "crop_machine_plant":
		return

	var success: bool = bool(result.get("success", false))
	var message_text: String = String(result.get("message", ""))

	if not success:
		var rollback_payload: Array = result.get("rollback_removed_entries_payload", []) as Array
		if not rollback_payload.is_empty():
			restore_removed_entries_from_payload(rollback_payload)
		elif not ui._pending_network_plant_request.is_empty():
			restore_removed_seed_entries(ui._pending_network_plant_request.get("removed_entries", []))

	ui._pending_network_plant_request.clear()

	if ui.visible and not message_text.is_empty():
		ui.info_label.text = message_text

	if ui.visible and ui.current_machine != null:
		ui.refresh()


func handle_network_unlock_result(result: Dictionary) -> void:
	if ui == null or result.is_empty():
		return
	if String(result.get("interaction_kind", "")).strip_edges() != "crop_machine_unlock_slot":
		return

	apply_shared_credits_from_result(result)

	if bool(result.get("success", false)):
		ui.selected_slot_index = max(int(result.get("unlocked_slot_index", ui.selected_slot_index)), 0)

	var message_text: String = String(result.get("message", ""))
	if ui.visible and not message_text.is_empty():
		ui.info_label.text = message_text

	if ui.visible and ui.current_machine != null:
		ui.refresh()


func apply_shared_credits_from_result(result: Dictionary) -> void:
	if result.is_empty() or not result.has("shared_credits"):
		return

	var credits_value: int = max(int(result.get("shared_credits", 0)), 0)
	var current_scene: Node = ui.get_tree().current_scene if ui != null else null
	if current_scene != null and current_scene.has_method("_set_shared_credits_local"):
		current_scene.call("_set_shared_credits_local", credits_value)
		return

	if CurrencyManager != null and CurrencyManager.has_method("set_credits"):
		CurrencyManager.set_credits(credits_value)


func get_player_credits() -> int:
	if ui == null or ui.current_player == null:
		return 0
	if ui.current_player.has_method("get_credits"):
		return int(ui.current_player.call("get_credits"))
	if ui.current_player.has_method("getCredit"):
		return int(ui.current_player.call("getCredit"))
	return 0


func can_player_spend_credits(amount: int) -> bool:
	if amount <= 0:
		return true
	if ui == null or ui.current_player == null:
		return false
	if ui.current_player.has_method("can_spend_credits"):
		return bool(ui.current_player.call("can_spend_credits", amount))
	if ui.current_player.has_method("get_credits"):
		return int(ui.current_player.call("get_credits")) >= amount
	if ui.current_player.has_method("getCredit"):
		return int(ui.current_player.call("getCredit")) >= amount
	return false


func spend_player_credits(amount: int) -> bool:
	if amount <= 0:
		return true
	if ui == null or ui.current_player == null:
		return false
	if ui.current_player.has_method("spend_credits"):
		return bool(ui.current_player.call("spend_credits", amount))
	if ui.current_player.has_method("spendCredit"):
		return bool(ui.current_player.call("spendCredit", amount))
	return false


func refund_player_credits(amount: int) -> void:
	if amount <= 0:
		return
	if ui == null or ui.current_player == null:
		return
	if ui.current_player.has_method("add_credits"):
		ui.current_player.call("add_credits", amount)
	elif ui.current_player.has_method("addCredit"):
		ui.current_player.call("addCredit", amount)


func get_player_item_count(item_data: ItemData) -> int:
	if item_data == null:
		return -1

	var targets: Array = collect_item_count_targets()
	var method_names: Array[String] = [
		"get_item_count_by_data",
		"get_item_count",
		"get_inventory_item_count",
		"get_item_quantity",
		"count_item_in_inventory",
		"get_total_item_count"
	]

	var best_result: int = -1
	for target in targets:
		for method_name in method_names:
			var result: int = call_item_count_method(target, method_name, item_data)
			if result > 0:
				return result
			if result == 0:
				best_result = 0

	return best_result


func collect_item_count_targets() -> Array:
	var targets: Array = []
	append_item_count_target(targets, ui.current_player if ui != null else null)

	if ui != null and ui.current_player != null:
		for property_name in ["inventory_ui", "inventory", "inventory_manager"]:
			var value: Variant = ui.current_player.get(property_name)
			if value is Node:
				append_item_count_target(targets, value as Node)

	var inventory_ui: Node = ui.get_tree().get_first_node_in_group("inventory_ui") if ui != null else null
	append_item_count_target(targets, inventory_ui)

	return targets


func append_item_count_target(targets: Array, target: Node) -> void:
	if target == null:
		return
	if targets.has(target):
		return
	targets.append(target)


func call_item_count_method(target: Node, method_name: String, item_data: ItemData) -> int:
	if target == null or item_data == null:
		return -1
	if not target.has_method(method_name):
		return -1

	var attempts: Array = []
	match method_name:
		"get_item_count_by_data":
			attempts.append(item_data)
		"get_item_count", "get_inventory_item_count", "get_item_quantity", "count_item_in_inventory", "get_total_item_count":
			if not str(item_data.id).is_empty():
				attempts.append(StringName(item_data.id))
			if not item_data.resource_path.is_empty():
				attempts.append(item_data.resource_path)
			if not item_data.item_name.is_empty():
				attempts.append(item_data.item_name)
		_:
			attempts.append(item_data)
			if not str(item_data.id).is_empty():
				attempts.append(StringName(item_data.id))
			if not item_data.resource_path.is_empty():
				attempts.append(item_data.resource_path)
			if not item_data.item_name.is_empty():
				attempts.append(item_data.item_name)

	var best_numeric_result: int = -1
	for arg in attempts:
		var value: Variant = target.call(method_name, arg)
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			best_numeric_result = max(best_numeric_result, max(int(value), 0))
			if int(value) > 0:
				return int(value)

	return best_numeric_result


func collect_inventory_targets() -> Array:
	var targets: Array = []

	if ui != null and ui.current_player != null:
		for property_name in ["inventory_ui", "inventory", "inventory_manager"]:
			var value: Variant = ui.current_player.get(property_name)
			if value is Node:
				append_item_count_target(targets, value as Node)

	var inventory_ui: Node = ui.get_tree().get_first_node_in_group("inventory_ui") if ui != null else null
	append_item_count_target(targets, inventory_ui)
	append_item_count_target(targets, ui.current_player if ui != null else null)

	return targets


func remove_seed_items_for_planting(seed_item: ItemData, amount: int) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"removed_entries": [],
		"representative_item_data": seed_item,
		"seed_quality": 0
	}

	if seed_item == null or amount <= 0:
		return result

	for target in collect_inventory_targets():
		if target == null:
			continue

		if not str(seed_item.id).is_empty() and target.has_method("remove_highest_quality_items_by_id"):
			var advanced_result: Variant = target.call("remove_highest_quality_items_by_id", StringName(seed_item.id), amount)
			if typeof(advanced_result) == TYPE_DICTIONARY:
				var advanced_dict: Dictionary = advanced_result
				if bool(advanced_dict.get("success", false)):
					if advanced_dict.get("representative_item_data", null) == null:
						advanced_dict["representative_item_data"] = seed_item
					return advanced_dict

		if target == ui.current_player and ui.current_player != null and ui.current_player.has_method("remove_item_from_inventory"):
			var removed_ok: bool = bool(ui.current_player.call("remove_item_from_inventory", seed_item, amount))
			if removed_ok:
				result["success"] = true
				result["removed_entries"] = [{"item_data": seed_item, "count": amount}]
				result["seed_quality"] = max(seed_item.get_quality(), 0)
				return result

		if target.has_method("remove_item"):
			var remove_item_ok: bool = bool(target.call("remove_item", seed_item, amount))
			if remove_item_ok:
				result["success"] = true
				result["removed_entries"] = [{"item_data": seed_item, "count": amount}]
				result["seed_quality"] = max(seed_item.get_quality(), 0)
				return result

		if not str(seed_item.id).is_empty() and target.has_method("remove_item_by_id"):
			var remove_by_id_ok: bool = bool(target.call("remove_item_by_id", StringName(seed_item.id), amount))
			if remove_by_id_ok:
				result["success"] = true
				result["removed_entries"] = [{"item_data": seed_item, "count": amount}]
				result["seed_quality"] = max(seed_item.get_quality(), 0)
				return result

	return result


func restore_removed_seed_entries(removed_entries: Array) -> void:
	if removed_entries.is_empty():
		return

	for target in collect_inventory_targets():
		if target == null:
			continue

		if target.has_method("restore_removed_item_entries"):
			target.call("restore_removed_item_entries", removed_entries)
			return

		if target.has_method("add_item"):
			for removed_entry in removed_entries:
				if typeof(removed_entry) != TYPE_DICTIONARY:
					continue
				var item_data: ItemData = removed_entry.get("item_data", null) as ItemData
				var count: int = max(int(removed_entry.get("count", 0)), 0)
				if item_data == null or count <= 0:
					continue
				target.call("add_item", item_data, count)
			return

		if target == ui.current_player and ui.current_player != null and ui.current_player.has_method("add_item_to_inventory"):
			for removed_entry in removed_entries:
				if typeof(removed_entry) != TYPE_DICTIONARY:
					continue
				var item_data: ItemData = removed_entry.get("item_data", null) as ItemData
				var count: int = max(int(removed_entry.get("count", 0)), 0)
				if item_data == null or count <= 0:
					continue
				ui.current_player.call("add_item_to_inventory", item_data, count)
			return


func build_item_quality_text(item_data: ItemData) -> String:
	if item_data == null:
		return "品質0 / ☆☆☆☆☆"
	return "品質%d / %s" % [item_data.get_quality(), item_data.get_rank_stars()]


func build_removed_entries_payload(removed_entries: Array) -> Array:
	var payload: Array = []
	if ui == null or ui.current_machine == null:
		return payload

	for removed_entry in removed_entries:
		if typeof(removed_entry) != TYPE_DICTIONARY:
			continue

		var item_data: ItemData = removed_entry.get("item_data", null) as ItemData
		var count: int = max(int(removed_entry.get("count", 0)), 0)
		if item_data == null or count <= 0:
			continue

		var item_payload: Dictionary = {}
		if ui.current_machine.has_method("build_network_item_payload"):
			item_payload = ui.current_machine.call("build_network_item_payload", item_data) as Dictionary

		payload.append({
			"item_payload": item_payload,
			"count": count,
		})

	return payload


func restore_removed_entries_from_payload(payload: Array) -> void:
	if payload.is_empty() or ui == null or ui.current_machine == null:
		return

	var removed_entries: Array = []
	for entry_variant in payload:
		if typeof(entry_variant) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = entry_variant as Dictionary
		var item_payload: Dictionary = entry.get("item_payload", {}) as Dictionary
		var count: int = max(int(entry.get("count", 0)), 0)
		if count <= 0:
			continue

		if not ui.current_machine.has_method("build_item_from_network_payload"):
			continue

		var item_data: ItemData = ui.current_machine.call("build_item_from_network_payload", item_payload) as ItemData
		if item_data == null:
			continue

		removed_entries.append({
			"item_data": item_data,
			"count": count,
		})

	restore_removed_seed_entries(removed_entries)


func can_route_crop_actions_through_world() -> bool:
	if ui == null:
		return false
	var current_scene: Node = ui.get_tree().current_scene
	return current_scene != null and current_scene.has_method("request_networked_world_interaction")


func request_networked_crop_action(request: Dictionary) -> void:
	if ui == null:
		return
	var current_scene: Node = ui.get_tree().current_scene
	if current_scene != null and current_scene.has_method("request_networked_world_interaction"):
		current_scene.call("request_networked_world_interaction", request)


func get_request_peer_id(player: Node) -> int:
	if ui == null:
		return 1
	if player != null and player.has_method("get_network_peer_id"):
		return max(int(player.call("get_network_peer_id")), 1)

	var multiplayer_api: MultiplayerAPI = ui.get_tree().get_multiplayer()
	if multiplayer_api != null:
		return max(multiplayer_api.get_unique_id(), 1)

	return 1

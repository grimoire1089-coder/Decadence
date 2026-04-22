extends RefCounted
class_name BaseWorldInteractionModule

var _world: BaseWorld = null


func setup(world: BaseWorld) -> void:
	_world = world


func normalize_world_interaction_request(request: Dictionary) -> Dictionary:
	var interaction_kind: String = String(request.get("interaction_kind", request.get("kind", ""))).strip_edges()
	if interaction_kind.is_empty():
		return {}

	var normalized_request: Dictionary = request.duplicate(true)
	normalized_request["interaction_kind"] = interaction_kind
	normalized_request["machine_path"] = String(request.get("machine_path", request.get("target_node_path", ""))).strip_edges()
	normalized_request["request_peer_id"] = int(request.get("request_peer_id", _get_local_network_peer_id()))
	normalized_request["slot_index"] = int(request.get("slot_index", -1))
	normalized_request["plant_count"] = max(int(request.get("plant_count", 1)), 1)
	normalized_request["recipe_key"] = String(request.get("recipe_key", "")).strip_edges()

	var action_amount_variant: Variant = request.get("action_amount", 0)
	normalized_request["action_amount"] = max(int(action_amount_variant), 0)

	var item_payload_variant: Variant = request.get("item_payload", {})
	normalized_request["item_payload"] = item_payload_variant if typeof(item_payload_variant) == TYPE_DICTIONARY else {}

	var seed_item_payload_variant: Variant = request.get("seed_item_payload", {})
	normalized_request["seed_item_payload"] = seed_item_payload_variant if typeof(seed_item_payload_variant) == TYPE_DICTIONARY else {}

	var removed_entries_payload_variant: Variant = request.get("removed_entries_payload", [])
	normalized_request["removed_entries_payload"] = removed_entries_payload_variant if typeof(removed_entries_payload_variant) == TYPE_ARRAY else []

	return normalized_request


func apply_world_interaction_request_local(request: Dictionary, requesting_peer_id: int) -> void:
	var interaction_kind: String = String(request.get("interaction_kind", "")).strip_edges()
	match interaction_kind:
		"vending_machine_open":
			var vending_machine_path: String = String(request.get("machine_path", "")).strip_edges()
			if vending_machine_path.is_empty():
				return

			if _can_accept_network_gameplay_requests():
				var vending_target_peer_id: int = max(requesting_peer_id, 1)
				if vending_target_peer_id == _get_local_network_peer_id():
					open_vending_machine_local(vending_machine_path)
				elif _is_network_online():
					_world.rpc_id(vending_target_peer_id, "_rpc_open_vending_machine", vending_machine_path)
				return

			open_vending_machine_local(vending_machine_path)

		"vending_machine_stock_one":
			_handle_vending_machine_stock_request(request, requesting_peer_id)

		"vending_machine_take_back_one":
			_handle_vending_machine_take_back_request(request, requesting_peer_id)

		"vending_machine_collect_earnings":
			_handle_vending_machine_collect_request(request, requesting_peer_id)

		"crop_machine_open":
			var crop_machine_path: String = String(request.get("machine_path", "")).strip_edges()
			if crop_machine_path.is_empty():
				return

			if _can_accept_network_gameplay_requests():
				var crop_target_peer_id: int = max(requesting_peer_id, 1)
				if crop_target_peer_id == _get_local_network_peer_id():
					open_crop_machine_local(crop_machine_path)
				elif _is_network_online():
					_world.rpc_id(crop_target_peer_id, "_rpc_open_crop_machine", crop_machine_path)
				return

			open_crop_machine_local(crop_machine_path)

		"crop_machine_plant":
			_handle_crop_machine_plant_request(request, requesting_peer_id)

		"crop_machine_unlock_slot":
			_handle_crop_machine_unlock_request(request, requesting_peer_id)

		_:
			return


func open_vending_machine_local(machine_path: String) -> void:
	var normalized_machine_path: String = machine_path.strip_edges()
	if normalized_machine_path.is_empty():
		return

	var machine_node: Node = _world.get_node_or_null(NodePath(normalized_machine_path))
	var machine: VendingMachine = machine_node as VendingMachine
	if machine == null:
		return

	var vending_ui: Node = _world.get_tree().get_first_node_in_group("vending_ui")
	if vending_ui != null and vending_ui.has_method("open_machine"):
		vending_ui.call("open_machine", machine, _world.player)


func open_crop_machine_local(machine_path: String) -> void:
	var normalized_machine_path: String = machine_path.strip_edges()
	if normalized_machine_path.is_empty():
		return

	var machine_node: Node = _world.get_node_or_null(NodePath(normalized_machine_path))
	var machine: CropMachine = machine_node as CropMachine
	if machine == null:
		return

	var crop_machine_ui: Node = _world.get_tree().get_first_node_in_group("crop_machine_ui")
	if crop_machine_ui != null and crop_machine_ui.has_method("open_machine"):
		crop_machine_ui.call("open_machine", machine, _world.player)


func apply_vending_machine_state_local(machine_path: String, state: Dictionary) -> void:
	var normalized_machine_path: String = machine_path.strip_edges()
	if normalized_machine_path.is_empty():
		return

	var machine_node: Node = _world.get_node_or_null(NodePath(normalized_machine_path))
	var machine: VendingMachine = machine_node as VendingMachine
	if machine == null:
		return

	if machine.has_method("import_network_state"):
		machine.call("import_network_state", state)


func push_vending_machine_state_to_remote_peers(machine_path: String, state: Dictionary) -> void:
	if not _is_network_online():
		return
	_world.rpc("_rpc_sync_vending_machine_state", machine_path, state)


func send_vending_action_result_to_peer(target_peer_id: int, machine_path: String, result: Dictionary) -> void:
	var resolved_peer_id: int = max(target_peer_id, 1)
	var normalized_result: Dictionary = result.duplicate(true)
	normalized_result["machine_path"] = machine_path.strip_edges()

	if not _is_network_online() or resolved_peer_id == _get_local_network_peer_id():
		deliver_vending_action_result_local(machine_path, normalized_result)
		return

	_world.rpc_id(resolved_peer_id, "_rpc_vending_action_result", machine_path, normalized_result)


func deliver_vending_action_result_local(machine_path: String, result: Dictionary) -> void:
	var normalized_machine_path: String = machine_path.strip_edges()
	if not normalized_machine_path.is_empty():
		var machine_node: Node = _world.get_node_or_null(NodePath(normalized_machine_path))
		var machine: VendingMachine = machine_node as VendingMachine
		if machine != null and result.has("machine_state") and machine.has_method("import_network_state"):
			machine.call("import_network_state", result.get("machine_state", {}) as Dictionary)

	var vending_ui: Node = _world.get_tree().get_first_node_in_group("vending_ui")
	if vending_ui != null and vending_ui.has_method("handle_network_action_result"):
		vending_ui.call("handle_network_action_result", result)


func perform_crop_machine_plant_request(request: Dictionary) -> Dictionary:
	var result: Dictionary = {
		"interaction_kind": "crop_machine_plant",
		"success": false,
		"message": "",
		"machine_path": String(request.get("machine_path", "")).strip_edges(),
		"rollback_removed_entries_payload": request.get("removed_entries_payload", [])
	}

	var machine_path: String = String(request.get("machine_path", "")).strip_edges()
	if machine_path.is_empty():
		result["message"] = "栽培機が見つからない"
		return result

	var machine_node: Node = _world.get_node_or_null(NodePath(machine_path))
	var machine: CropMachine = machine_node as CropMachine
	if machine == null:
		result["message"] = "栽培機が見つからない"
		return result

	var recipe_key: String = String(request.get("recipe_key", "")).strip_edges()
	var recipe: CropRecipe = find_crop_machine_recipe_by_key(machine, recipe_key)
	if recipe == null:
		result["message"] = "植え付けレシピがない"
		return result

	var slot_index: int = int(request.get("slot_index", -1))
	var plant_count: int = max(int(request.get("plant_count", 1)), 1)
	if slot_index < 0 or slot_index >= machine.slots.size():
		result["message"] = "スロット未選択"
		return result

	if recipe.seed_item == null:
		result["message"] = "種アイテムが未設定"
		return result

	if not machine.can_plant_recipe_in_slot(slot_index, recipe):
		result["message"] = "使用中スロットには同じ作物だけ追加投入できる"
		return result

	var representative_seed_item: ItemData = recipe.seed_item
	var seed_item_payload: Dictionary = request.get("seed_item_payload", {}) as Dictionary
	if machine.has_method("build_item_from_network_payload"):
		var built_seed_item: ItemData = machine.call("build_item_from_network_payload", seed_item_payload) as ItemData
		if built_seed_item != null:
			representative_seed_item = built_seed_item

	var was_empty: bool = machine.is_slot_empty(slot_index)
	var planted: bool = machine.plant_slot(slot_index, recipe, plant_count, representative_seed_item)
	if not planted:
		result["message"] = "植え付けできなかった"
		return result

	machine.save_data()
	machine._refresh_open_ui()

	result["success"] = true
	result["message"] = "%sを %d 回分 セットした" % [recipe.get_display_name(), plant_count] if was_empty else "%sを %d 回分 追加投入した" % [recipe.get_display_name(), plant_count]
	if machine.has_method("export_network_state_payload"):
		result["machine_state"] = machine.call("export_network_state_payload")
	else:
		result["machine_state"] = machine.get_save_payload()

	return result


func find_crop_machine_recipe_by_key(machine: CropMachine, recipe_key: String) -> CropRecipe:
	if machine == null or recipe_key.is_empty():
		return null

	for recipe_variant in machine.available_recipes:
		var recipe: CropRecipe = recipe_variant as CropRecipe
		if recipe == null or not recipe.is_valid_recipe():
			continue

		var current_key: String = ""
		if machine.has_method("_get_recipe_unique_key"):
			current_key = String(machine.call("_get_recipe_unique_key", recipe))
		elif not recipe.resource_path.is_empty():
			current_key = recipe.resource_path
		elif not str(recipe.id).is_empty():
			current_key = str(recipe.id)
		else:
			current_key = recipe.get_display_name()

		if current_key == recipe_key:
			return recipe

	return null


func apply_crop_machine_state_local(machine_path: String, state_payload: Dictionary) -> void:
	var normalized_machine_path: String = machine_path.strip_edges()
	if normalized_machine_path.is_empty():
		return

	var machine_node: Node = _world.get_node_or_null(NodePath(normalized_machine_path))
	var machine: CropMachine = machine_node as CropMachine
	if machine == null:
		return

	if machine.has_method("apply_network_state_payload"):
		machine.call("apply_network_state_payload", state_payload)
		return

	machine.apply_save_payload(state_payload)
	machine._refresh_open_ui()


func handle_crop_machine_plant_result_local(result: Dictionary) -> void:
	var crop_machine_ui: Node = _world.get_tree().get_first_node_in_group("crop_machine_ui")
	if crop_machine_ui == null:
		return

	var interaction_kind: String = String(result.get("interaction_kind", "")).strip_edges()
	if interaction_kind == "crop_machine_unlock_slot":
		if crop_machine_ui.has_method("handle_network_unlock_result"):
			crop_machine_ui.call("handle_network_unlock_result", result)
		return

	if crop_machine_ui.has_method("handle_network_plant_result"):
		crop_machine_ui.call("handle_network_plant_result", result)


func _handle_vending_machine_stock_request(request: Dictionary, requesting_peer_id: int) -> void:
	var interaction_kind: String = "vending_machine_stock_one"
	var stock_machine_path: String = String(request.get("machine_path", "")).strip_edges()
	var stock_target_peer_id: int = max(requesting_peer_id, 1)
	if stock_machine_path.is_empty():
		send_vending_action_result_to_peer(stock_target_peer_id, stock_machine_path, {
			"interaction_kind": interaction_kind,
			"success": false,
			"message": "自販機が見つからない",
		})
		return

	var stock_machine_node: Node = _world.get_node_or_null(NodePath(stock_machine_path))
	var stock_machine: VendingMachine = stock_machine_node as VendingMachine
	if stock_machine == null:
		send_vending_action_result_to_peer(stock_target_peer_id, stock_machine_path, {
			"interaction_kind": interaction_kind,
			"success": false,
			"message": "自販機が見つからない",
		})
		return

	var stock_slot_index: int = int(request.get("slot_index", -1))
	var stock_amount: int = max(int(request.get("action_amount", 0)), 0)
	var stock_item_payload: Dictionary = request.get("item_payload", {}) as Dictionary
	var stock_item_data: Resource = null
	if stock_machine.has_method("build_item_from_network_payload"):
		stock_item_data = stock_machine.call("build_item_from_network_payload", stock_item_payload) as Resource

	if stock_item_data == null or stock_amount <= 0:
		send_vending_action_result_to_peer(stock_target_peer_id, stock_machine_path, {
			"interaction_kind": interaction_kind,
			"success": false,
			"message": "補充データが不正",
			"rollback_item_payload": stock_item_payload,
			"rollback_amount": stock_amount,
		})
		return

	var stocked: bool = stock_machine.stock_item(stock_slot_index, stock_item_data, stock_amount, 0)
	if not stocked:
		send_vending_action_result_to_peer(stock_target_peer_id, stock_machine_path, {
			"interaction_kind": interaction_kind,
			"success": false,
			"message": "そのスロットには別の商品が入ってる",
			"rollback_item_payload": stock_item_payload,
			"rollback_amount": stock_amount,
		})
		return

	var stock_sell_price: int = stock_machine.peek_slot_price(stock_slot_index)
	var machine_state: Dictionary = {}
	if stock_machine.has_method("export_network_state"):
		machine_state = stock_machine.call("export_network_state") as Dictionary
		push_vending_machine_state_to_remote_peers(stock_machine_path, machine_state)

	send_vending_action_result_to_peer(stock_target_peer_id, stock_machine_path, {
		"interaction_kind": interaction_kind,
		"success": true,
		"message": "%d個補充した（売値: %d Cr）" % [stock_amount, stock_sell_price],
		"machine_state": machine_state,
	})


func _handle_vending_machine_take_back_request(request: Dictionary, requesting_peer_id: int) -> void:
	var interaction_kind: String = "vending_machine_take_back_one"
	var take_machine_path: String = String(request.get("machine_path", "")).strip_edges()
	var take_target_peer_id: int = max(requesting_peer_id, 1)
	if take_machine_path.is_empty():
		send_vending_action_result_to_peer(take_target_peer_id, take_machine_path, {
			"interaction_kind": interaction_kind,
			"success": false,
			"message": "自販機が見つからない",
		})
		return

	var take_machine_node: Node = _world.get_node_or_null(NodePath(take_machine_path))
	var take_machine: VendingMachine = take_machine_node as VendingMachine
	if take_machine == null:
		send_vending_action_result_to_peer(take_target_peer_id, take_machine_path, {
			"interaction_kind": interaction_kind,
			"success": false,
			"message": "自販機が見つからない",
		})
		return

	var take_slot_index: int = int(request.get("slot_index", -1))
	var take_amount: int = max(int(request.get("action_amount", 0)), 0)
	var take_result: Dictionary = take_machine.take_back_item(take_slot_index, take_amount)
	if not bool(take_result.get("success", false)):
		send_vending_action_result_to_peer(take_target_peer_id, take_machine_path, {
			"interaction_kind": interaction_kind,
			"success": false,
			"message": "取り出せない",
		})
		return

	var returned_item: Resource = take_result.get("item_data", null) as Resource
	var returned_amount: int = max(int(take_result.get("amount", 0)), 0)
	var returned_payload: Dictionary = {}
	if returned_item != null and take_machine.has_method("build_network_item_payload"):
		returned_payload = take_machine.call("build_network_item_payload", returned_item) as Dictionary

	var machine_state: Dictionary = {}
	if take_machine.has_method("export_network_state"):
		machine_state = take_machine.call("export_network_state") as Dictionary
		push_vending_machine_state_to_remote_peers(take_machine_path, machine_state)

	send_vending_action_result_to_peer(take_target_peer_id, take_machine_path, {
		"interaction_kind": interaction_kind,
		"success": true,
		"message": "%d個取り戻した" % returned_amount,
		"returned_item_payload": returned_payload,
		"returned_amount": returned_amount,
		"machine_state": machine_state,
	})


func _handle_vending_machine_collect_request(request: Dictionary, requesting_peer_id: int) -> void:
	var interaction_kind: String = "vending_machine_collect_earnings"
	var collect_machine_path: String = String(request.get("machine_path", "")).strip_edges()
	var collect_target_peer_id: int = max(requesting_peer_id, 1)
	if collect_machine_path.is_empty():
		send_vending_action_result_to_peer(collect_target_peer_id, collect_machine_path, {
			"interaction_kind": interaction_kind,
			"success": false,
			"message": "自販機が見つからない",
		})
		return

	var collect_machine_node: Node = _world.get_node_or_null(NodePath(collect_machine_path))
	var collect_machine: VendingMachine = collect_machine_node as VendingMachine
	if collect_machine == null:
		send_vending_action_result_to_peer(collect_target_peer_id, collect_machine_path, {
			"interaction_kind": interaction_kind,
			"success": false,
			"message": "自販機が見つからない",
		})
		return

	var collected_amount: int = 0
	if collect_machine.has_method("consume_earnings_for_network"):
		collected_amount = int(collect_machine.call("consume_earnings_for_network"))
	else:
		collected_amount = collect_machine.collect_earnings(_world.player)

	if collected_amount <= 0:
		send_vending_action_result_to_peer(collect_target_peer_id, collect_machine_path, {
			"interaction_kind": interaction_kind,
			"success": false,
			"message": "回収できる売上がない",
		})
		return

	var machine_state: Dictionary = {}
	if collect_machine.has_method("export_network_state"):
		machine_state = collect_machine.call("export_network_state") as Dictionary
		push_vending_machine_state_to_remote_peers(collect_machine_path, machine_state)

	send_vending_action_result_to_peer(collect_target_peer_id, collect_machine_path, {
		"interaction_kind": interaction_kind,
		"success": true,
		"message": "売上を回収した",
		"collected_amount": collected_amount,
		"machine_state": machine_state,
	})


func _handle_crop_machine_plant_request(request: Dictionary, requesting_peer_id: int) -> void:
	var result: Dictionary = perform_crop_machine_plant_request(request)
	var target_peer_id: int = max(requesting_peer_id, 1)
	var machine_path: String = String(result.get("machine_path", request.get("machine_path", ""))).strip_edges()

	if bool(result.get("success", false)):
		var machine_state: Dictionary = result.get("machine_state", {}) as Dictionary
		if not machine_state.is_empty() and _is_network_online():
			_world.rpc("_rpc_sync_crop_machine_state", machine_path, machine_state)

	if not _is_network_online() or target_peer_id == _get_local_network_peer_id():
		handle_crop_machine_plant_result_local(result)
		return

	_world.rpc_id(target_peer_id, "_rpc_handle_crop_machine_plant_result", result)


func _handle_crop_machine_unlock_request(request: Dictionary, requesting_peer_id: int) -> void:
	var target_peer_id: int = max(requesting_peer_id, 1)
	var machine_path: String = String(request.get("machine_path", "")).strip_edges()
	var result: Dictionary = {
		"interaction_kind": "crop_machine_unlock_slot",
		"success": false,
		"message": "",
		"machine_path": machine_path,
		"shared_credits": _world._get_shared_credits(),
		"unlocked_slot_index": -1,
	}

	if machine_path.is_empty():
		result["message"] = "栽培機が見つからない"
		_deliver_crop_machine_unlock_result(target_peer_id, result)
		return

	var machine_node: Node = _world.get_node_or_null(NodePath(machine_path))
	var machine: CropMachine = machine_node as CropMachine
	if machine == null:
		result["message"] = "栽培機が見つからない"
		_deliver_crop_machine_unlock_result(target_peer_id, result)
		return

	if not machine.can_unlock_slot():
		result["message"] = "これ以上スロットを増やせない"
		_deliver_crop_machine_unlock_result(target_peer_id, result)
		return

	var unlock_cost: int = max(int(machine.get_next_slot_unlock_cost()), 0)
	var current_shared_credits: int = _world._get_shared_credits()
	if current_shared_credits < unlock_cost:
		result["message"] = "クレジットが足りない（必要: %d Cr / 所持: %d Cr）" % [unlock_cost, current_shared_credits]
		result["shared_credits"] = current_shared_credits
		_deliver_crop_machine_unlock_result(target_peer_id, result)
		return

	_world._set_shared_credits_local(current_shared_credits - unlock_cost)

	var next_slot_number: int = machine.get_unlocked_slot_count() + 1
	var unlocked: bool = machine.unlock_slot()
	if not unlocked:
		_world._set_shared_credits_local(current_shared_credits)
		result["message"] = "スロット解放に失敗した"
		result["shared_credits"] = _world._get_shared_credits()
		_deliver_crop_machine_unlock_result(target_peer_id, result)
		return

	machine._refresh_open_ui()

	var machine_state: Dictionary = {}
	if machine.has_method("export_network_state_payload"):
		machine_state = machine.call("export_network_state_payload") as Dictionary
	else:
		machine_state = machine.get_save_payload()

	if not machine_state.is_empty() and _is_network_online():
		_world.rpc("_rpc_sync_crop_machine_state", machine_path, machine_state)

	result["success"] = true
	result["message"] = "スロット%dを解放した（-%d Cr）" % [next_slot_number, unlock_cost]
	result["shared_credits"] = _world._get_shared_credits()
	result["machine_state"] = machine_state
	result["unlocked_slot_index"] = machine.get_unlocked_slot_count() - 1

	_deliver_crop_machine_unlock_result(target_peer_id, result)


func _deliver_crop_machine_unlock_result(target_peer_id: int, result: Dictionary) -> void:
	if not _is_network_online() or target_peer_id == _get_local_network_peer_id():
		handle_crop_machine_plant_result_local(result)
		return

	_world.rpc_id(target_peer_id, "_rpc_handle_crop_machine_plant_result", result)


func _get_local_network_peer_id() -> int:
	if _world == null:
		return 1
	return _world._get_local_network_peer_id()


func _can_accept_network_gameplay_requests() -> bool:
	if _world == null:
		return false
	return _world._can_accept_network_gameplay_requests()


func _is_network_online() -> bool:
	if _world == null:
		return false
	return _world._is_network_online()

extends RefCounted
class_name SkillHelpers


static func resolve_stats_manager(subject: Node) -> Node:
	if subject == null or not is_instance_valid(subject):
		return _resolve_global_player_stats_manager()

	if _looks_like_hp_stats_manager(subject):
		return subject

	if subject.has_method("get_stats_manager"):
		var stats_manager: Variant = subject.call("get_stats_manager")
		if _looks_like_hp_stats_manager(stats_manager):
			return stats_manager as Node

	if _belongs_to_player_chain(subject):
		var player_stats: Node = _resolve_global_player_stats_manager()
		if player_stats != null:
			return player_stats

	var candidate_paths: Array[NodePath] = [
		NodePath("PlayerStatsManager"),
		NodePath("StatsManager"),
		NodePath("CharacterStats"),
		NodePath("Vitals")
	]

	for path in candidate_paths:
		var candidate: Node = subject.get_node_or_null(path)
		if _looks_like_hp_stats_manager(candidate):
			return candidate

	var current: Node = subject
	while current != null:
		for path in candidate_paths:
			var parent_candidate: Node = current.get_node_or_null(path)
			if _looks_like_hp_stats_manager(parent_candidate):
				return parent_candidate
		current = current.get_parent()

	return null


static func resolve_role_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null

	var by_absolute: Node = tree.root.get_node_or_null("/root/RoleManager")
	if by_absolute != null:
		return by_absolute

	var by_name: Node = tree.root.get_node_or_null("RoleManager")
	if by_name != null:
		return by_name

	return null


static func can_spend_mp(subject: Node, amount: int) -> bool:
	if amount <= 0:
		return true

	var stats_manager: Node = resolve_stats_manager(subject)
	if stats_manager == null:
		add_system_log("MP確認失敗: ステータス管理が見つかりません")
		return false

	if stats_manager.has_method("can_spend_mp"):
		var result: Variant = stats_manager.call("can_spend_mp", amount)
		if result is bool:
			return result
		if result is int:
			return result != 0
		return false

	if stats_manager.has_method("get_mp"):
		var mp_value := int(stats_manager.call("get_mp"))
		return mp_value >= amount

	if stats_manager.has_method("get_current_mp"):
		var current_mp := int(stats_manager.call("get_current_mp"))
		return current_mp >= amount

	add_system_log("MP確認失敗: MP取得メソッドが見つかりません")
	return false


static func spend_mp(subject: Node, amount: int) -> bool:
	if amount <= 0:
		return true

	var stats_manager: Node = resolve_stats_manager(subject)
	if stats_manager == null:
		add_system_log("MP消費失敗: ステータス管理が見つかりません")
		return false

	if stats_manager.has_method("spend_mp"):
		var spend_result: Variant = stats_manager.call("spend_mp", amount)
		if spend_result is bool:
			return spend_result
		if spend_result is int:
			return spend_result != 0
		return false

	if stats_manager.has_method("consume_mp"):
		if can_spend_mp(subject, amount):
			stats_manager.call("consume_mp", amount)
			return true
		return false

	if stats_manager.has_method("use_mp"):
		var use_result: Variant = stats_manager.call("use_mp", amount)
		if use_result is bool:
			return use_result
		if use_result is int:
			return use_result != 0
		return false

	if stats_manager.has_method("get_mp") and stats_manager.has_method("set_mp"):
		var mp_value := int(stats_manager.call("get_mp"))
		if mp_value < amount:
			return false
		stats_manager.call("set_mp", mp_value - amount)
		return true

	add_system_log("MP消費失敗: MP消費メソッドが見つかりません")
	return false


static func heal_target(subject: Node, amount: int) -> bool:
	if amount <= 0:
		return true

	var stats_manager: Node = resolve_stats_manager(subject)
	if stats_manager == null:
		add_system_log("回復失敗: 対象のステータス管理が見つかりません")
		return false

	if stats_manager.has_method("heal_hp"):
		stats_manager.call("heal_hp", amount)
		return true

	if stats_manager.has_method("add_hp"):
		stats_manager.call("add_hp", amount)
		return true

	add_system_log("回復失敗: HP回復メソッドが見つかりません")
	return false


static func add_system_log(message: String) -> void:
	if message.is_empty():
		return

	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return

	var root := tree.root
	if root == null:
		return

	var log_targets: Array[Node] = [
		root.get_node_or_null("/root/MessageLog"),
		root.get_node_or_null("MessageLog"),
		root.get_node_or_null("/root/GameMessageLog"),
		root.get_node_or_null("GameMessageLog")
	]

	for target in log_targets:
		if target == null:
			continue

		if target.has_method("add_system_message"):
			target.call("add_system_message", message)
			return

		if target.has_method("add_system_log"):
			target.call("add_system_log", message)
			return

		if target.has_method("add_message"):
			target.call("add_message", message)
			return

		if target.has_method("push_message"):
			target.call("push_message", message)
			return

	print(message)


static func _resolve_global_player_stats_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null

	var absolute: Node = tree.root.get_node_or_null("/root/PlayerStatsManager")
	if absolute != null:
		return absolute

	var by_name: Node = tree.root.get_node_or_null("PlayerStatsManager")
	if by_name != null:
		return by_name

	return null


static func _looks_like_hp_stats_manager(candidate: Variant) -> bool:
	if candidate == null:
		return false
	if not (candidate is Node):
		return false

	var node := candidate as Node

	if node.has_method("heal_hp"):
		return true
	if node.has_method("damage_hp"):
		return true
	if node.has_method("get_hp") and node.has_method("get_max_hp"):
		return true

	return false


static func _belongs_to_player_chain(subject: Node) -> bool:
	var current: Node = subject
	while current != null:
		if current.is_in_group("player"):
			return true
		current = current.get_parent()
	return false

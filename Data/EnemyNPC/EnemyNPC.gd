extends CharacterBody2D
class_name EnemyNPC

signal hp_changed(current_hp: int, max_hp: int)
signal defeated(enemy)

@export_group("基本")
@export var enemy_name: String = "敵"
@export var max_hp: int = 30
@export var move_speed: float = 90.0
@export var chase_player: bool = true
@export var stop_distance: float = 8.0

@export_group("攻撃")
@export var contact_damage: int = 5
@export_range(0.05, 30.0, 0.05) var attack_interval: float = 1.0
@export var attack_on_touch_enter: bool = true

@export_group("見た目")
@export var sprite_offset: Vector2 = Vector2(0, -16)
@export var face_move_direction: bool = true

@export_group("ログ")
@export var write_attack_log: bool = true
@export var write_defeat_log: bool = true

@onready var sprite: Sprite2D = $Sprite2D
@onready var search_area: Area2D = $SearchArea
@onready var attack_area: Area2D = $AttackArea
@onready var attack_timer: Timer = $AttackTimer

var current_hp: int = 0
var _target_player: Node2D = null
var _players_in_attack_area: Array[Node2D] = []


func _ready() -> void:
	add_to_group("targetable")
	add_to_group("hostile_target")

	current_hp = max(max_hp, 1)

	if sprite != null:
		sprite.position = sprite_offset

	if search_area != null:
		if not search_area.body_entered.is_connected(_on_search_area_body_entered):
			search_area.body_entered.connect(_on_search_area_body_entered)
		if not search_area.body_exited.is_connected(_on_search_area_body_exited):
			search_area.body_exited.connect(_on_search_area_body_exited)

	if attack_area != null:
		if not attack_area.body_entered.is_connected(_on_attack_area_body_entered):
			attack_area.body_entered.connect(_on_attack_area_body_entered)
		if not attack_area.body_exited.is_connected(_on_attack_area_body_exited):
			attack_area.body_exited.connect(_on_attack_area_body_exited)

	if attack_timer != null:
		attack_timer.one_shot = false
		attack_timer.wait_time = max(attack_interval, 0.05)
		if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
			attack_timer.timeout.connect(_on_attack_timer_timeout)

	_emit_hp_changed()


func _physics_process(_delta: float) -> void:
	if not chase_player:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _target_player == null or not is_instance_valid(_target_player):
		_target_player = _find_player_in_search_area()

	if _target_player == null or not is_instance_valid(_target_player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var to_player: Vector2 = _target_player.global_position - global_position

	if face_move_direction and sprite != null and absf(to_player.x) > 0.001:
		sprite.flip_h = to_player.x < 0.0

	var distance_to_player: float = to_player.length()
	if distance_to_player <= max(stop_distance, 0.0):
		velocity = Vector2.ZERO
	else:
		velocity = to_player.normalized() * move_speed

	move_and_slide()


func take_damage(amount: int) -> void:
	if amount <= 0:
		return

	current_hp = max(current_hp - amount, 0)
	_emit_hp_changed()

	if current_hp <= 0:
		die()


func heal(amount: int) -> void:
	if amount <= 0:
		return

	current_hp = min(current_hp + amount, max(max_hp, 1))
	_emit_hp_changed()


func get_hp() -> int:
	return current_hp


func get_max_hp() -> int:
	return max(max_hp, 1)


func heal_hp(amount: int) -> void:
	heal(amount)


func damage_hp(amount: int) -> void:
	take_damage(amount)


func get_stats_manager() -> Node:
	return self


func get_target_display_name() -> String:
	return enemy_name


func is_target_selectable() -> bool:
	return true


func get_target_marker_world_position() -> Vector2:
	var local_offset: Vector2 = _get_target_marker_local_offset()
	return global_position + Vector2(local_offset.x * absf(global_scale.x), local_offset.y * absf(global_scale.y))


func get_target_ring_radius() -> float:
	var body_collision: CollisionShape2D = _get_body_collision_shape_node()
	if body_collision == null or body_collision.shape == null:
		return 18.0

	var shape: Shape2D = body_collision.shape
	if shape is RectangleShape2D:
		var rect: RectangleShape2D = shape as RectangleShape2D
		var scaled_width: float = rect.size.x * absf(global_scale.x)
		var scaled_height: float = rect.size.y * absf(global_scale.y)
		return max(min(scaled_width, scaled_height) * 0.28, 12.0)
	if shape is CircleShape2D:
		var circle: CircleShape2D = shape as CircleShape2D
		return max(circle.radius * absf(global_scale.x) * 0.95, 12.0)
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		return max(capsule.radius * absf(global_scale.x) * 0.95, 12.0)

	return 18.0


func die() -> void:
	if write_defeat_log:
		_log_system("%sを倒した" % enemy_name)

	defeated.emit(self)
	queue_free()


func _on_search_area_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body is Node2D:
		_target_player = body as Node2D


func _on_search_area_body_exited(body: Node) -> void:
	if body != _target_player:
		return

	_target_player = _find_player_in_search_area()


func _on_attack_area_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if not (body is Node2D):
		return

	var player_node: Node2D = body as Node2D
	if not _players_in_attack_area.has(player_node):
		_players_in_attack_area.append(player_node)

	if attack_on_touch_enter:
		_deal_damage_to_player(player_node)

	_refresh_attack_timer()


func _on_attack_area_body_exited(body: Node) -> void:
	if body is Node2D:
		_players_in_attack_area.erase(body as Node2D)
	_refresh_attack_timer()


func _on_attack_timer_timeout() -> void:
	_cleanup_attack_targets()

	if _players_in_attack_area.is_empty():
		if attack_timer != null:
			attack_timer.stop()
		return

	_deal_damage_to_player(_players_in_attack_area[0])


func _refresh_attack_timer() -> void:
	if attack_timer == null:
		return

	_cleanup_attack_targets()

	if contact_damage <= 0 or _players_in_attack_area.is_empty():
		attack_timer.stop()
		return

	attack_timer.wait_time = max(attack_interval, 0.05)
	if attack_timer.is_stopped():
		attack_timer.start()


func _cleanup_attack_targets() -> void:
	for i in range(_players_in_attack_area.size() - 1, -1, -1):
		var node: Node2D = _players_in_attack_area[i]
		if node == null or not is_instance_valid(node):
			_players_in_attack_area.remove_at(i)


func _find_player_in_search_area() -> Node2D:
	if search_area == null:
		return null

	for body in search_area.get_overlapping_bodies():
		if body.is_in_group("player") and body is Node2D:
			return body as Node2D

	return null


func _deal_damage_to_player(player: Node) -> void:
	if player == null or not is_instance_valid(player):
		return
	if contact_damage <= 0:
		return

	var applied_damage: int = 0
	var stats_manager: Node = get_node_or_null("/root/PlayerStatsManager")

	if player.is_in_group("player") and stats_manager != null:
		applied_damage = _apply_damage_via_stats_manager(stats_manager, contact_damage)

	if applied_damage <= 0 and player.has_method("receive_damage"):
		var before_hp: int = _read_player_hp(stats_manager)
		player.call("receive_damage", contact_damage, self)
		var after_hp: int = _read_player_hp(stats_manager)
		applied_damage = max(before_hp - after_hp, 0)

	if applied_damage <= 0:
		_log_warning("%sのダメージがHPに反映されませんでした。PlayerStatsManager.damage_hp() か receive_damage() を確認してくれ" % enemy_name)
		return

	if write_attack_log:
		_log_warning("%sから %d ダメージ受けた" % [enemy_name, applied_damage])


func _apply_damage_via_stats_manager(stats_manager: Node, amount: int) -> int:
	if stats_manager == null:
		return 0

	var before_hp: int = _read_player_hp(stats_manager)

	if stats_manager.has_method("damage_hp"):
		stats_manager.call("damage_hp", amount)
	elif stats_manager.has_method("apply_damage"):
		stats_manager.call("apply_damage", amount)
	elif stats_manager.has_method("take_damage"):
		stats_manager.call("take_damage", amount)
	else:
		return 0

	var after_hp: int = _read_player_hp(stats_manager)
	return max(before_hp - after_hp, 0)


func _read_player_hp(stats_manager: Node) -> int:
	if stats_manager == null:
		return -1
	if stats_manager.has_method("get_hp"):
		return int(stats_manager.call("get_hp"))
	if stats_manager.has_method("get_current_hp"):
		return int(stats_manager.call("get_current_hp"))
	if stats_manager.has_method("current_hp"):
		return int(stats_manager.call("current_hp"))
	return -1


func _emit_hp_changed() -> void:
	hp_changed.emit(current_hp, max(max_hp, 1))


func _get_body_collision_shape_node() -> CollisionShape2D:
	return get_node_or_null("CollisionShape2D") as CollisionShape2D


func _get_target_marker_local_offset() -> Vector2:
	var body_collision: CollisionShape2D = _get_body_collision_shape_node()
	if body_collision == null or body_collision.shape == null:
		return Vector2.ZERO

	var local_offset: Vector2 = body_collision.position
	var shape: Shape2D = body_collision.shape
	if shape is RectangleShape2D:
		var rect: RectangleShape2D = shape as RectangleShape2D
		local_offset.y += rect.size.y * 0.5
	elif shape is CircleShape2D:
		var circle: CircleShape2D = shape as CircleShape2D
		local_offset.y += circle.radius
	elif shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		local_offset.y += capsule.height * 0.5 + capsule.radius

	return local_offset


func _get_message_log() -> Node:
	var by_root: Node = get_node_or_null("/root/MessageLog")
	if by_root != null:
		return by_root
	return null


func _log_system(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node == null:
		return
	if log_node.has_method("add_system"):
		log_node.call("add_system", text)
	elif log_node.has_method("add_message"):
		log_node.call("add_message", text, "SYSTEM")


func _log_warning(text: String) -> void:
	var log_node: Node = _get_message_log()
	if log_node == null:
		return
	if log_node.has_method("add_warning"):
		log_node.call("add_warning", text)
	elif log_node.has_method("add_message"):
		log_node.call("add_message", text, "WARNING")

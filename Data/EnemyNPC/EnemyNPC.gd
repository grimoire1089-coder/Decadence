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

	if player.has_method("receive_damage"):
		player.call("receive_damage", contact_damage, self)
	elif PlayerStatsManager != null and PlayerStatsManager.has_method("damage_hp"):
		PlayerStatsManager.damage_hp(contact_damage)
	else:
		return

	if write_attack_log:
		_log_warning("%sから %d ダメージ受けた" % [enemy_name, contact_damage])


func _emit_hp_changed() -> void:
	hp_changed.emit(current_hp, max(max_hp, 1))


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

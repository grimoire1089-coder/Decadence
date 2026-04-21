extends RefCounted
class_name PlayerMotionController

const FACING_DOWN: int = 0
const FACING_UP: int = 1
const FACING_RIGHT: int = 2
const FACING_LEFT: int = 3

var owner: CharacterBody2D = null


func setup(owner_node: CharacterBody2D) -> void:
	owner = owner_node


func resolve_player_sprite() -> void:
	if owner == null:
		return

	if owner.sprite_path != NodePath():
		owner._player_sprite = owner.get_node_or_null(owner.sprite_path) as Sprite2D

	if owner._player_sprite == null:
		owner._player_sprite = owner.get_node_or_null("Sprite2D") as Sprite2D

	if owner._player_sprite == null:
		return

	owner._sprite_base_position = owner._player_sprite.position

	if owner.front_texture == null:
		owner.front_texture = owner._player_sprite.texture

	apply_facing_visual()
	reset_walk_bob_immediate()


func update_facing_from_direction(direction: Vector2) -> void:
	if owner == null or direction == Vector2.ZERO:
		return

	if absf(direction.x) > absf(direction.y):
		owner._facing = FACING_RIGHT if direction.x > 0.0 else FACING_LEFT
	else:
		owner._facing = FACING_DOWN if direction.y > 0.0 else FACING_UP

	apply_facing_visual()


func apply_facing_visual() -> void:
	if owner == null or owner._player_sprite == null:
		return

	match owner._facing:
		FACING_DOWN:
			if owner.front_texture != null:
				owner._player_sprite.texture = owner.front_texture
			owner._player_sprite.flip_h = false
		FACING_UP:
			if owner.back_texture != null:
				owner._player_sprite.texture = owner.back_texture
			elif owner.front_texture != null:
				owner._player_sprite.texture = owner.front_texture
			owner._player_sprite.flip_h = false
		FACING_RIGHT:
			if owner.side_texture != null:
				owner._player_sprite.texture = owner.side_texture
			elif owner.front_texture != null:
				owner._player_sprite.texture = owner.front_texture
			owner._player_sprite.flip_h = false
		FACING_LEFT:
			if owner.side_texture != null:
				owner._player_sprite.texture = owner.side_texture
			elif owner.front_texture != null:
				owner._player_sprite.texture = owner.front_texture
			owner._player_sprite.flip_h = owner.flip_side_for_left


func update_walk_bob(delta: float) -> void:
	if owner == null or owner._player_sprite == null:
		return

	if not owner.walk_bob_enabled:
		reset_walk_bob_smooth(delta)
		return

	var moving: bool = owner.velocity.length_squared() > 1.0
	if moving:
		var speed_ratio: float = 1.0
		if owner.speed > 0.0:
			speed_ratio = clampf(owner.velocity.length() / owner.speed, 0.0, 1.5)

		owner._walk_anim_time += delta * owner.walk_bob_speed * maxf(speed_ratio, 0.2)

		var side_offset: float = sin(owner._walk_anim_time) * owner.walk_bob_side_amount
		var up_offset: float = -absf(cos(owner._walk_anim_time)) * owner.walk_bob_up_amount
		var tilt_amount: float = sin(owner._walk_anim_time) * owner.walk_bob_tilt_degrees
		var target_position: Vector2 = owner._sprite_base_position + Vector2(side_offset, up_offset)

		owner._player_sprite.position = owner._player_sprite.position.lerp(target_position, clampf(delta * owner.walk_bob_return_speed, 0.0, 1.0))
		owner._player_sprite.rotation_degrees = lerpf(owner._player_sprite.rotation_degrees, tilt_amount, clampf(delta * owner.walk_bob_return_speed, 0.0, 1.0))
	else:
		reset_walk_bob_smooth(delta)


func reset_walk_bob_smooth(delta: float) -> void:
	if owner == null or owner._player_sprite == null:
		return

	owner._player_sprite.position = owner._player_sprite.position.lerp(owner._sprite_base_position, clampf(delta * owner.walk_bob_return_speed, 0.0, 1.0))
	owner._player_sprite.rotation_degrees = lerpf(owner._player_sprite.rotation_degrees, 0.0, clampf(delta * owner.walk_bob_return_speed, 0.0, 1.0))
	owner._walk_anim_time = 0.0 if owner._player_sprite.position.distance_squared_to(owner._sprite_base_position) < 0.01 and absf(owner._player_sprite.rotation_degrees) < 0.05 else owner._walk_anim_time


func reset_walk_bob_immediate() -> void:
	if owner == null or owner._player_sprite == null:
		return

	owner._walk_anim_time = 0.0
	owner._player_sprite.position = owner._sprite_base_position
	owner._player_sprite.rotation_degrees = 0.0


func update_remote_network_player(delta: float) -> void:
	if owner == null:
		return

	if owner.player_network_controller == null:
		owner.velocity = Vector2.ZERO
		owner._update_current_interactable()
		update_walk_bob(delta)
		return

	if owner.player_network_controller.has_remote_snapshot():
		owner.global_position = owner.player_network_controller.apply_remote_position(owner.global_position, delta)
		owner.velocity = owner.player_network_controller.get_remote_velocity()

		var remote_facing: int = owner.player_network_controller.get_remote_facing()
		if remote_facing >= FACING_DOWN and remote_facing <= FACING_LEFT:
			if owner._facing != remote_facing:
				owner._facing = remote_facing
				apply_facing_visual()
	else:
		owner.velocity = Vector2.ZERO

	owner._update_current_interactable()
	update_walk_bob(delta)

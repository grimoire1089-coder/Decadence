extends Node2D
class_name SkillProjectileOrb

signal hit(target: Node2D)
signal hit_target(target: Node2D)

const SAFE_Z_INDEX: int = 4000
const DEFAULT_HIT_RADIUS: float = 12.0

@export_group("Image Projectile")
@export var image_texture: Texture2D = null
@export var image_scale: float = 0.65
@export var base_visual_size_pixels: float = 28.0
@export var sprite_alpha: float = 1.0
@export var face_velocity: bool = false
@export var pulse_speed: float = 6.0
@export var pulse_amount: float = 0.035

@export_group("Fallback Orb")
@export var orb_radius: float = 10.0
@export var core_color: Color = Color(0.82, 0.97, 1.0, 0.96)
@export var ring_color: Color = Color(0.45, 0.94, 1.0, 0.70)

@export_group("Glow Halo")
@export var halo_color: Color = Color(0.40, 0.95, 1.0, 0.22)
@export var halo_radius_multiplier: float = 1.18
@export var outer_halo_alpha_scale: float = 0.42

@export_group("Trail Particles")
@export var use_trail_particles: bool = true
@export var trail_amount: int = 28
@export var trail_lifetime: float = 0.42
@export var trail_spread: float = 12.0
@export var trail_velocity_min: float = 20.0
@export var trail_velocity_max: float = 44.0
@export var trail_scale_min: float = 0.18
@export var trail_scale_max: float = 0.34
@export var trail_color_start: Color = Color(0.82, 1.0, 1.0, 0.78)
@export var trail_color_mid: Color = Color(0.45, 0.95, 1.0, 0.46)
@export var trail_color_end: Color = Color(0.10, 0.75, 1.0, 0.0)

var _caster: Node2D = null
var _target: Node2D = null
var _speed: float = 260.0
var _hit_radius: float = DEFAULT_HIT_RADIUS
var _pulse_time: float = 0.0
var _velocity: Vector2 = Vector2.ZERO

var _sprite: Sprite2D = null
var _trail_particles: GPUParticles2D = null
var _trail_texture: Texture2D = null


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = clampi(SAFE_Z_INDEX, RenderingServer.CANVAS_ITEM_Z_MIN, RenderingServer.CANVAS_ITEM_Z_MAX)
	_ensure_nodes()
	_apply_visual_mode()
	set_process(false)
	queue_redraw()


func setup(caster: Node2D, target: Node2D, speed: float, hit_radius: float = DEFAULT_HIT_RADIUS) -> void:
	_caster = caster
	_target = target
	_speed = max(speed, 1.0)
	_hit_radius = max(hit_radius, 1.0)

	if _caster != null and is_instance_valid(_caster):
		global_position = _resolve_node_position(_caster)

	_update_velocity()
	_ensure_nodes()
	_apply_visual_mode()
	_update_particle_direction()
	if _trail_particles != null:
		_trail_particles.emitting = use_trail_particles
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return

	_pulse_time += delta * max(pulse_speed, 0.0)
	_update_velocity()

	var distance: float = global_position.distance_to(_resolve_node_position(_target))
	if distance <= _hit_radius:
		_emit_hit_and_free()
		return

	global_position += _velocity * delta

	if face_velocity and _velocity.length_squared() > 0.0001:
		rotation = _velocity.angle()

	_update_sprite_visual()
	_update_particle_direction()
	queue_redraw()


func _draw() -> void:
	if image_texture != null:
		_draw_texture_halo()
	else:
		_draw_fallback_orb()


func _ensure_nodes() -> void:
	if _trail_particles == null:
		_trail_particles = get_node_or_null("TrailParticles") as GPUParticles2D
		if _trail_particles == null:
			_trail_particles = GPUParticles2D.new()
			_trail_particles.name = "TrailParticles"
			add_child(_trail_particles)
		_trail_particles.top_level = false
		_trail_particles.local_coords = false
		_trail_particles.z_as_relative = true
		_trail_particles.z_index = 0
		_trail_particles.amount = max(trail_amount, 4)
		_trail_particles.lifetime = max(trail_lifetime, 0.05)
		_trail_particles.preprocess = _trail_particles.lifetime
		_trail_particles.one_shot = false
		_trail_particles.explosiveness = 0.0
		_trail_particles.fixed_fps = 0
		_trail_particles.texture = _get_or_create_trail_texture()
		_trail_particles.material = _make_additive_canvas_material()
		_trail_particles.process_material = _build_trail_process_material()
		_trail_particles.emitting = false

	if _sprite == null:
		_sprite = get_node_or_null("ProjectileSprite") as Sprite2D
		if _sprite == null:
			_sprite = Sprite2D.new()
			_sprite.name = "ProjectileSprite"
			add_child(_sprite)
		_sprite.centered = true
		_sprite.z_as_relative = true
		_sprite.z_index = 2
		_sprite.material = null


func _apply_visual_mode() -> void:
	_ensure_nodes()
	if _sprite == null:
		return

	_sprite.texture = image_texture
	_sprite.visible = image_texture != null
	_update_sprite_visual()

	if _trail_particles != null:
		_trail_particles.amount = max(trail_amount, 4)
		_trail_particles.lifetime = max(trail_lifetime, 0.05)
		_trail_particles.texture = _get_or_create_trail_texture()
		_trail_particles.material = _make_additive_canvas_material()
		_trail_particles.process_material = _build_trail_process_material()


func _update_sprite_visual() -> void:
	if _sprite == null or image_texture == null:
		return

	var pulse: float = 1.0 + sin(_pulse_time) * pulse_amount
	_sprite.scale = Vector2.ONE * _get_normalized_texture_scale() * pulse
	_sprite.modulate = Color(1.0, 1.0, 1.0, clampf(sprite_alpha, 0.0, 1.0))


func _get_normalized_texture_scale() -> float:
	if image_texture == null:
		return max(image_scale, 0.01)

	var tex_size: Vector2 = image_texture.get_size()
	var max_dim: float = maxf(tex_size.x, tex_size.y)
	if max_dim <= 0.0:
		return max(image_scale, 0.01)

	var target_size_pixels: float = max(base_visual_size_pixels, 1.0) * max(image_scale, 0.01)
	return target_size_pixels / max_dim


func _get_texture_display_radius() -> float:
	var diameter: float = max(base_visual_size_pixels, 1.0) * max(image_scale, 0.01)
	return max(diameter * 0.5, 2.0)


func _update_velocity() -> void:
	if _target == null or not is_instance_valid(_target):
		_velocity = Vector2.ZERO
		return

	var to_target: Vector2 = _resolve_node_position(_target) - global_position
	if to_target.length_squared() <= 0.0001:
		_velocity = Vector2.ZERO
		return

	_velocity = to_target.normalized() * _speed


func _update_particle_direction() -> void:
	if _trail_particles == null or not is_instance_valid(_trail_particles):
		return
	var process_material: ParticleProcessMaterial = _trail_particles.process_material as ParticleProcessMaterial
	if process_material == null:
		return

	var backward: Vector2 = Vector2.LEFT
	if _velocity.length_squared() > 0.0001:
		backward = -_velocity.normalized()
	process_material.direction = Vector3(backward.x, backward.y, 0.0)


func _draw_texture_halo() -> void:
	var base_radius: float = _get_texture_display_radius()
	var pulse: float = 1.0 + sin(_pulse_time) * pulse_amount
	var inner_radius: float = base_radius * halo_radius_multiplier * pulse
	var outer_radius: float = inner_radius * 1.42
	var inner_color: Color = halo_color
	var outer_color: Color = halo_color
	outer_color.a *= outer_halo_alpha_scale
	draw_circle(Vector2.ZERO, outer_radius, outer_color)
	draw_circle(Vector2.ZERO, inner_radius, inner_color)


func _draw_fallback_orb() -> void:
	var pulse: float = 1.0 + sin(_pulse_time) * pulse_amount
	var core_radius: float = orb_radius * pulse
	var ring_radius: float = core_radius * 1.45
	var halo_radius: float = ring_radius * 1.35
	var outer_color: Color = halo_color
	outer_color.a *= outer_halo_alpha_scale
	draw_circle(Vector2.ZERO, halo_radius, outer_color)
	draw_circle(Vector2.ZERO, ring_radius, halo_color)
	draw_circle(Vector2.ZERO, core_radius, core_color)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 36, ring_color, 2.0, true)


func _emit_hit_and_free() -> void:
	if _trail_particles != null and is_instance_valid(_trail_particles):
		_trail_particles.emitting = false
	hit.emit(_target)
	hit_target.emit(_target)
	queue_free()


func _build_trail_process_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(-1.0, 0.0, 0.0)
	material.spread = trail_spread
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = trail_velocity_min
	material.initial_velocity_max = trail_velocity_max
	material.scale_min = trail_scale_min
	material.scale_max = trail_scale_max
	material.angular_velocity_min = -18.0
	material.angular_velocity_max = 18.0
	material.damping_min = 4.0
	material.damping_max = 8.0
	material.color_ramp = _build_trail_gradient()
	return material


func _build_trail_gradient() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gradient.colors = PackedColorArray([
		trail_color_start,
		trail_color_mid,
		trail_color_end
	])

	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _get_or_create_trail_texture() -> Texture2D:
	if _trail_texture != null:
		return _trail_texture

	var size: int = 48
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2((size - 1) * 0.5, (size - 1) * 0.5)
	var max_dist: float = center.x
	for y in range(size):
		for x in range(size):
			var dist: float = Vector2(x, y).distance_to(center) / max_dist
			var alpha: float = clampf(1.0 - dist, 0.0, 1.0)
			alpha = pow(alpha, 2.2)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	_trail_texture = ImageTexture.create_from_image(image)
	return _trail_texture


func _make_additive_canvas_material() -> CanvasItemMaterial:
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return material


func _resolve_node_position(node: Node) -> Vector2:
	if node == null or not is_instance_valid(node):
		return global_position
	if node.has_method("get_target_marker_world_position"):
		var value: Variant = node.call("get_target_marker_world_position")
		if value is Vector2:
			return value
	if node is Node2D:
		return (node as Node2D).global_position
	return global_position

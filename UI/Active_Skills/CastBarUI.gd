extends Control
class_name CastBarUI

@export var auto_hide_on_ready: bool = true
@export var show_time_text: bool = true
@export var skill_caster_path: NodePath
@export var auto_bind_on_ready: bool = true
@export var max_auto_bind_attempts: int = 30

@onready var panel: PanelContainer = $Panel
@onready var name_label: Label = $Panel/Margin/VBox/SkillNameLabel
@onready var progress_bar: ProgressBar = $Panel/Margin/VBox/CastProgressBar
@onready var time_label: Label = $Panel/Margin/VBox/TimeLabel

var _caster: Node = null
var _cast_skill_id: String = ""
var _cast_duration: float = 0.0
var _cast_started_at_msec: int = 0
var _is_active: bool = false
var _auto_bind_attempts: int = 0

func _ready() -> void:
	if auto_hide_on_ready:
		hide()

	progress_bar.min_value = 0.0
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0

	if not show_time_text:
		time_label.hide()

	if auto_bind_on_ready:
		call_deferred("_try_bind_skill_caster")

func bind_skill_caster(skill_caster: Node) -> void:
	if _caster == skill_caster:
		return

	_disconnect_current_caster()
	_caster = skill_caster

	if _caster == null:
		return

	if _caster.has_signal("skill_cast_started"):
		_caster.skill_cast_started.connect(_on_skill_cast_started)
	if _caster.has_signal("skill_cast_succeeded"):
		_caster.skill_cast_succeeded.connect(_on_skill_cast_finished)
	if _caster.has_signal("skill_cast_failed"):
		_caster.skill_cast_failed.connect(_on_skill_cast_failed)

func _disconnect_current_caster() -> void:
	if _caster == null:
		return

	if _caster.has_signal("skill_cast_started") and _caster.skill_cast_started.is_connected(_on_skill_cast_started):
		_caster.skill_cast_started.disconnect(_on_skill_cast_started)
	if _caster.has_signal("skill_cast_succeeded") and _caster.skill_cast_succeeded.is_connected(_on_skill_cast_finished):
		_caster.skill_cast_succeeded.disconnect(_on_skill_cast_finished)
	if _caster.has_signal("skill_cast_failed") and _caster.skill_cast_failed.is_connected(_on_skill_cast_failed):
		_caster.skill_cast_failed.disconnect(_on_skill_cast_failed)

	_caster = null

func _process(_delta: float) -> void:
	if _caster == null and auto_bind_on_ready and _auto_bind_attempts < max_auto_bind_attempts:
		_try_bind_skill_caster()

	if not _is_active:
		return

	if _cast_duration <= 0.0:
		progress_bar.value = 100.0
		if show_time_text:
			time_label.text = "0.0s"
		return

	var elapsed: float = max((Time.get_ticks_msec() - _cast_started_at_msec) / 1000.0, 0.0)
	var ratio: float = clamp(elapsed / _cast_duration, 0.0, 1.0)
	progress_bar.value = ratio * 100.0

	if show_time_text:
		var remain: float = max(_cast_duration - elapsed, 0.0)
		time_label.text = "%.1fs" % remain

func _try_bind_skill_caster() -> void:
	if _caster != null:
		return

	_auto_bind_attempts += 1

	var skill_caster: Node = null

	if skill_caster_path != NodePath():
		skill_caster = get_node_or_null(skill_caster_path)

	if skill_caster == null:
		var scene_root := get_tree().current_scene
		if scene_root != null:
			var player := scene_root.get_node_or_null("Player")
			if player != null:
				skill_caster = player.get_node_or_null("SkillCaster")
				if skill_caster == null:
					skill_caster = player.find_child("SkillCaster", true, false)

	if skill_caster == null:
		var scene_root := get_tree().current_scene
		if scene_root != null:
			skill_caster = scene_root.find_child("SkillCaster", true, false)

	if skill_caster != null:
		bind_skill_caster(skill_caster)

func _on_skill_cast_started(skill_id: String, display_name: String, cast_time: float) -> void:
	_cast_skill_id = skill_id
	_cast_duration = max(cast_time, 0.0)
	_cast_started_at_msec = Time.get_ticks_msec()
	_is_active = true

	name_label.text = display_name
	progress_bar.value = 0.0
	if show_time_text:
		time_label.text = "%.1fs" % _cast_duration

	show()

func _on_skill_cast_finished(skill_id: String, _target: Node) -> void:
	if _cast_skill_id != "" and skill_id != _cast_skill_id:
		return
	_finish_and_hide()

func _on_skill_cast_failed(skill_id: String, _reason: String) -> void:
	if _cast_skill_id != "" and skill_id != _cast_skill_id:
		return
	_finish_and_hide()

func _finish_and_hide() -> void:
	_is_active = false
	_cast_skill_id = ""
	_cast_duration = 0.0
	_cast_started_at_msec = 0
	progress_bar.value = 0.0
	if show_time_text:
		time_label.text = ""
	hide()

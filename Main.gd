extends Node2D

@export_file("*.tscn") var redirect_scene_path: String = "res://BaseWorld.tscn"
@export var auto_redirect: bool = true

var _redirect_started: bool = false

func _ready() -> void:
	if auto_redirect:
		call_deferred("_redirect_to_baseworld")

func _redirect_to_baseworld() -> void:
	if _redirect_started:
		return
	_redirect_started = true

	var normalized_path: String = redirect_scene_path.strip_edges()
	if normalized_path.is_empty():
		push_warning("Main redirect: redirect_scene_path が空です")
		return

	if not ResourceLoader.exists(normalized_path):
		push_warning("Main redirect: シーンが見つかりません: %s" % normalized_path)
		return

	get_tree().change_scene_to_file(normalized_path)

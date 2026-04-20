extends Marker2D
class_name SceneSpawnPoint

@export var spawn_id: String = ""


func _ready() -> void:
	add_to_group("scene_spawn_point")


func get_spawn_id() -> String:
	return spawn_id.strip_edges()

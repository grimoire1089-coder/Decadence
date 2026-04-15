extends Node

@export var player_path: NodePath = ^"BGMPlayer"
@export var now_playing_panel_path: NodePath
@export var day_tracks: Array[AudioStream] = []
@export var night_tracks: Array[AudioStream] = []
@export var default_volume_db: float = 0.0
@export var write_log: bool = true
@export var show_now_playing_panel: bool = true

var _player: AudioStreamPlayer = null
var _now_playing_panel: Node = null
var _current_period: int = -1
var _last_stream: AudioStream = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()

	_setup_player()
	_setup_now_playing_panel()
	_connect_time_manager()

	if _player == null:
		return

	var time_manager: Node = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		_log_system("TimeManager が見つからないためBGMを開始できません")
		return

	if not time_manager.has_method("get_time_period"):
		_log_system("TimeManager に get_time_period() がありません")
		return

	var period_value: Variant = time_manager.call("get_time_period")
	if typeof(period_value) != TYPE_INT:
		_log_system("get_time_period() の戻り値が int ではありません")
		return

	_current_period = int(period_value)
	_play_random_for_current_period(true)


func _setup_player() -> void:
	_player = get_node_or_null(player_path) as AudioStreamPlayer

	if _player == null:
		_player = AudioStreamPlayer.new()
		_player.name = "BGMPlayer"
		add_child(_player)

	_player.volume_db = default_volume_db

	var finished_callable: Callable = Callable(self, "_on_bgm_finished")
	if not _player.finished.is_connected(finished_callable):
		_player.finished.connect(finished_callable)


func _setup_now_playing_panel() -> void:
	_now_playing_panel = null

	if not show_now_playing_panel:
		return

	if not now_playing_panel_path.is_empty():
		_now_playing_panel = get_node_or_null(now_playing_panel_path)
		if _now_playing_panel != null:
			return

	var current_scene: Node = get_tree().current_scene
	if current_scene != null:
		_now_playing_panel = _find_node_by_name_recursive(current_scene, "BgmNowPlayingPanel")
		if _now_playing_panel != null:
			return

	_now_playing_panel = get_node_or_null("/root/BgmNowPlayingPanel")


func _connect_time_manager() -> void:
	var time_manager: Node = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return

	var callable_obj: Callable = Callable(self, "_on_period_changed")
	if not time_manager.is_connected("period_changed", callable_obj):
		time_manager.connect("period_changed", callable_obj)


func _on_period_changed(period: int) -> void:
	if _current_period == period and _player != null and _player.playing:
		return

	_current_period = period
	_play_random_for_current_period(true)


func _on_bgm_finished() -> void:
	_play_random_for_current_period(false)


func _play_random_for_current_period(switched_by_period: bool) -> void:
	if _player == null:
		return

	var track_list: Array[AudioStream] = []

	if _is_night_period(_current_period):
		track_list = night_tracks
	else:
		track_list = day_tracks

	var period_name: String = "夜" if _is_night_period(_current_period) else "昼"
	_play_random_from_list(track_list, period_name, switched_by_period)


func _play_random_from_list(track_list: Array[AudioStream], period_name: String, switched_by_period: bool) -> void:
	if track_list.is_empty():
		_player.stop()
		_last_stream = null
		_log_system("%sBGMリストが空です" % period_name)
		return

	var next_stream: AudioStream = _pick_random_stream(track_list)
	if next_stream == null:
		_player.stop()
		_last_stream = null
		_log_system("%sBGMの取得に失敗しました" % period_name)
		return

	_player.stop()
	_player.stream = next_stream
	_player.play()
	_last_stream = next_stream

	var track_name: String = _get_stream_name(next_stream)
	var detail_text: String = "%sBGMに切り替え" % period_name if switched_by_period else "%sBGMを再生" % period_name
	var panel_shown: bool = _show_now_playing(track_name, detail_text)

	if not panel_shown:
		if switched_by_period:
			_log_system("%sになったのでBGMを変更: %s" % [period_name, track_name])
		else:
			_log_system("%sBGMを再生: %s" % [period_name, track_name])


func _pick_random_stream(track_list: Array[AudioStream]) -> AudioStream:
	var valid_tracks: Array[AudioStream] = []

	for track: AudioStream in track_list:
		if track != null:
			valid_tracks.append(track)

	if valid_tracks.is_empty():
		return null

	if valid_tracks.size() == 1:
		return valid_tracks[0]

	var candidates: Array[AudioStream] = []

	for track: AudioStream in valid_tracks:
		if track != _last_stream:
			candidates.append(track)

	if candidates.is_empty():
		candidates = valid_tracks

	var index: int = _rng.randi_range(0, candidates.size() - 1)
	return candidates[index]


func _is_night_period(period: int) -> bool:
	return period == 1


func _get_stream_name(stream: AudioStream) -> String:
	if stream == null:
		return "Unknown"

	if not stream.resource_path.is_empty():
		return stream.resource_path.get_file().get_basename()

	if not stream.resource_name.is_empty():
		return stream.resource_name

	return "UnnamedBGM"


func _get_message_log() -> Node:
	return get_node_or_null("/root/MessageLog")


func _log_system(text: String) -> void:
	if not write_log:
		return

	var log_node: Node = _get_message_log()
	if log_node == null:
		return

	if log_node.has_method("add_system"):
		log_node.call("add_system", text)
	elif log_node.has_method("add_message"):
		log_node.call("add_message", text, "SYSTEM")


func _show_now_playing(track_name: String, detail_text: String) -> bool:
	if not show_now_playing_panel:
		return false

	if _now_playing_panel == null or not is_instance_valid(_now_playing_panel):
		_setup_now_playing_panel()

	if _now_playing_panel == null:
		return false

	if _now_playing_panel.has_method("show_track"):
		_now_playing_panel.call("show_track", track_name, detail_text)
		return true

	return false


func _find_node_by_name_recursive(root: Node, target_name: String) -> Node:
	if root == null:
		return null

	if root.name == target_name:
		return root

	for child: Node in root.get_children():
		var found: Node = _find_node_by_name_recursive(child, target_name)
		if found != null:
			return found

	return null

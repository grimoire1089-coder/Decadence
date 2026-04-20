extends CanvasLayer
class_name BootManager

const BOOT_MODE_CONTINUE: String = "continue"
const BOOT_MODE_NEW_GAME: String = "new_game"

@export_file("*.tscn") var default_game_scene_path: String = "res://BaseWorld.tscn"
@export_file("*.tscn") var new_game_scene_path: String = "res://BaseWorld.tscn"
@export var slot_name: String = "slot_01"
@export var threaded_load_poll_interval_sec: float = 0.03
@export var auto_start_boot: bool = true
@export_enum("continue", "new_game") var boot_mode: String = BOOT_MODE_CONTINUE

@onready var dim_rect: ColorRect = $Root/Dim
@onready var panel: PanelContainer = $Root/Panel
@onready var title_label: Label = $Root/Panel/Margin/VBox/TitleLabel
@onready var status_label: Label = $Root/Panel/Margin/VBox/StatusLabel
@onready var progress_bar: ProgressBar = $Root/Panel/Margin/VBox/ProgressBar
@onready var detail_label: Label = $Root/Panel/Margin/VBox/DetailLabel

var _boot_started: bool = false


func _ready() -> void:
	layer = 100
	visible = true
	_set_progress(0.0, "起動準備中...", "")
	if auto_start_boot:
		call_deferred("start_boot")


func configure_startup(mode: String, requested_slot_name: String = "", requested_new_game_scene_path: String = "") -> void:
	var normalized_mode: String = String(mode).strip_edges().to_lower()
	if normalized_mode == BOOT_MODE_NEW_GAME:
		boot_mode = BOOT_MODE_NEW_GAME
	else:
		boot_mode = BOOT_MODE_CONTINUE

	var normalized_slot: String = String(requested_slot_name).strip_edges()
	if not normalized_slot.is_empty():
		slot_name = normalized_slot

	var normalized_scene_path: String = String(requested_new_game_scene_path).strip_edges()
	if not normalized_scene_path.is_empty():
		new_game_scene_path = normalized_scene_path


func start_boot() -> void:
	if _boot_started:
		return
	_boot_started = true
	call_deferred("_run_boot_sequence")


func _run_boot_sequence() -> void:
	await _step(0.02, "ロード画面を準備中...", "Boot scene を初期化しています")
	_stop_time_manager()

	var save_manager: Node = _get_save_manager()
	if save_manager == null:
		push_error("BootManager: SaveManager autoload が見つかりません。project.godot の autoload を確認してください。")
		_set_progress(1.0, "起動に失敗しました", "SaveManager autoload が見つかりません")
		return

	var save_data: Dictionary = {}
	if boot_mode == BOOT_MODE_NEW_GAME:
		await _step(0.10, "新しいゲームを準備中...", "既存のスロットを初期状態で上書きします")
		var start_scene_path: String = new_game_scene_path.strip_edges()
		if start_scene_path.is_empty():
			start_scene_path = default_game_scene_path
		save_data = save_manager.create_new_game_save(slot_name, start_scene_path)
	else:
		await _step(0.10, "セーブデータを確認中...", "user://saves を確認しています")
		save_data = save_manager.load_or_create_boot_save(slot_name)

	await _step(0.22, "共通データを適用中...", "autoload マネージャへ保存内容を流し込みます")
	save_manager.apply_autoload_save_data(save_data)

	var target_scene_path: String = save_manager.get_saved_scene_path(save_data, default_game_scene_path)
	if boot_mode == BOOT_MODE_NEW_GAME:
		var explicit_new_game_scene: String = new_game_scene_path.strip_edges()
		if not explicit_new_game_scene.is_empty():
			target_scene_path = explicit_new_game_scene

	if target_scene_path.strip_edges().is_empty():
		push_error("BootManager: 読み込み先シーンが未設定です。default_game_scene_path を設定してください。")
		_set_progress(1.0, "起動に失敗しました", "default_game_scene_path が空です")
		return

	await _step(0.35, "シーンを読み込み中...", target_scene_path)
	var packed_scene: PackedScene = await _load_scene_threaded(target_scene_path)
	if packed_scene == null:
		_set_progress(1.0, "起動に失敗しました", "シーンのロードに失敗しました: %s" % target_scene_path)
		return

	await _step(0.65, "ワールドを生成中...", "シーンをインスタンス化しています")
	var new_scene: Node = _instantiate_target_scene(packed_scene)
	if new_scene == null:
		_set_progress(1.0, "起動に失敗しました", "シーンの生成に失敗しました")
		return

	if new_scene.has_method("prepare_world_before_restore"):
		new_scene.call("prepare_world_before_restore", save_data)

	await get_tree().process_frame
	await get_tree().process_frame

	await _step(0.82, "ワールド状態を復元中...", "persistent_id を持つノードとプレイヤー位置を復元します")
	save_manager.apply_world_state(new_scene, save_data)

	await get_tree().process_frame

	await _step(0.94, "時間を再開中...", "最後の処理として TimeManager をスタートします")
	_start_time_manager()

	await _step(1.0, "起動完了", "ゲームを開始します")
	await get_tree().process_frame
	queue_free()


func _set_progress(ratio: float, status: String, detail: String) -> void:
	if progress_bar != null:
		progress_bar.value = clampf(ratio * 100.0, 0.0, 100.0)
	if status_label != null:
		status_label.text = status
	if detail_label != null:
		detail_label.text = detail


func _step(ratio: float, status: String, detail: String) -> void:
	_set_progress(ratio, status, detail)
	await get_tree().process_frame


func _load_scene_threaded(scene_path: String) -> PackedScene:
	var request_error: int = ResourceLoader.load_threaded_request(scene_path, "PackedScene", true)
	if request_error != OK:
		push_error("BootManager: load_threaded_request failed (%d): %s" % [request_error, scene_path])
		return null

	var progress: Array = []
	while true:
		var status: int = ResourceLoader.load_threaded_get_status(scene_path, progress)
		match status:
			ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				push_error("BootManager: invalid resource: %s" % scene_path)
				return null
			ResourceLoader.THREAD_LOAD_FAILED:
				push_error("BootManager: threaded load failed: %s" % scene_path)
				return null
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				var internal_ratio: float = 0.0
				if not progress.is_empty():
					internal_ratio = float(progress[0])
				_set_progress(0.35 + internal_ratio * 0.25, "シーンを読み込み中...", scene_path)
				await get_tree().create_timer(threaded_load_poll_interval_sec).timeout
			ResourceLoader.THREAD_LOAD_LOADED:
				var resource: Variant = ResourceLoader.load_threaded_get(scene_path)
				if resource is PackedScene:
					return resource as PackedScene
				push_error("BootManager: loaded resource is not a PackedScene: %s" % scene_path)
				return null
			_:
				push_error("BootManager: unknown threaded load status (%d): %s" % [status, scene_path])
				return null

	return null


func _instantiate_target_scene(packed_scene: PackedScene) -> Node:
	if packed_scene == null:
		return null

	var previous_scene: Node = get_tree().current_scene
	var new_scene: Node = packed_scene.instantiate()
	if new_scene == null:
		return null

	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene

	if is_instance_valid(previous_scene):
		previous_scene.queue_free()

	return new_scene


func _stop_time_manager() -> void:
	var time_manager: Node = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return
	if time_manager.has_method("stop_time"):
		time_manager.call("stop_time")
		return
	if time_manager.has_method("set_time_running"):
		time_manager.call("set_time_running", false)
		return
	if _has_property(time_manager, "is_running"):
		time_manager.set("is_running", false)


func _start_time_manager() -> void:
	var time_manager: Node = get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return
	if time_manager.has_method("start_time"):
		time_manager.call("start_time")
		return
	if time_manager.has_method("set_time_running"):
		time_manager.call("set_time_running", true)
		return
	if _has_property(time_manager, "is_running"):
		time_manager.set("is_running", true)


func _get_save_manager() -> Node:
	return get_node_or_null("/root/SaveManager")


func _has_property(target: Object, property_name: String) -> bool:
	for property_info in target.get_property_list():
		if String(property_info.get("name", "")) == property_name:
			return true
	return false

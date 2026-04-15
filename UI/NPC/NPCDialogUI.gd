extends Control
class_name NPCDialogUI

const UI_LOCK_SOURCE: String = "NPC会話UI"
const UI_MODAL_MANAGER_SCRIPT_NAME: String = "UIModalManager.gd"
const TIME_MANAGER_SCRIPT_NAME: String = "TimeManager.gd"

const ROOT_DIMMER_COLOR: Color = Color(0.0, 0.0, 0.0, 0.52)
const PANEL_BG: Color = Color(0.05, 0.08, 0.12, 0.96)
const PANEL_BORDER: Color = Color(0.30, 0.75, 1.0, 0.72)
const PANEL_RADIUS: int = 16
const PORTRAIT_BG: Color = Color(0.10, 0.12, 0.16, 0.96)
const DIALOG_BG: Color = Color(0.09, 0.11, 0.15, 0.98)
const DEFAULT_VOICE_BUS: StringName = &"Voice"

var current_npc: Node = null
var current_player: Node = null

@onready var dimmer: ColorRect = $Dimmer
@onready var panel: Panel = $RootCenter/MainPanel
@onready var name_label: Label = $RootCenter/MainPanel/MarginContainer/RootVBox/HeaderHBox/NameLabel
@onready var close_button: Button = $RootCenter/MainPanel/MarginContainer/RootVBox/HeaderHBox/CloseButton
@onready var portrait_frame: Panel = $RootCenter/MainPanel/MarginContainer/RootVBox/BodyHBox/PortraitFrame
@onready var portrait_texture: TextureRect = $RootCenter/MainPanel/MarginContainer/RootVBox/BodyHBox/PortraitFrame/MarginContainer/PortraitTexture
@onready var portrait_placeholder: Label = $RootCenter/MainPanel/MarginContainer/RootVBox/BodyHBox/PortraitFrame/PortraitPlaceholder
@onready var dialogue_frame: Panel = $RootCenter/MainPanel/MarginContainer/RootVBox/BodyHBox/DialogueFrame
@onready var dialogue_text: RichTextLabel = $RootCenter/MainPanel/MarginContainer/RootVBox/BodyHBox/DialogueFrame/MarginContainer/DialogueVBox/DialogueText
@onready var next_button: Button = $RootCenter/MainPanel/MarginContainer/RootVBox/BodyHBox/DialogueFrame/MarginContainer/DialogueVBox/ButtonHBox/NextButton
@onready var end_button: Button = $RootCenter/MainPanel/MarginContainer/RootVBox/BodyHBox/DialogueFrame/MarginContainer/DialogueVBox/ButtonHBox/EndButton
@onready var voice_player: AudioStreamPlayer = $VoicePlayer


func _ready() -> void:
	visible = false
	add_to_group("npc_dialog_ui")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	next_button.mouse_filter = Control.MOUSE_FILTER_STOP
	end_button.mouse_filter = Control.MOUSE_FILTER_STOP

	_apply_layout()
	_apply_theme()

	close_button.pressed.connect(_on_close_pressed)
	next_button.pressed.connect(_on_next_pressed)
	end_button.pressed.connect(_on_end_pressed)
	if not resized.is_connected(_on_ui_resized):
		resized.connect(_on_ui_resized)

	dialogue_text.bbcode_enabled = false
	dialogue_text.scroll_active = false
	dialogue_text.fit_content = false
	dialogue_text.selection_enabled = false
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	voice_player.max_polyphony = 1
	voice_player.bus = DEFAULT_VOICE_BUS


func _exit_tree() -> void:
	_release_ui_lock()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close_dialog()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		_on_next_pressed()
		get_viewport().set_input_as_handled()


func _on_ui_resized() -> void:
	_apply_layout()


func _apply_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0
	offset_top = 0
	offset_right = 0
	offset_bottom = 0

	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.offset_left = 0
	dimmer.offset_top = 0
	dimmer.offset_right = 0
	dimmer.offset_bottom = 0

	var viewport_size: Vector2 = get_viewport_rect().size
	var target_width: float = min(1080.0, max(920.0, viewport_size.x - 120.0))
	var target_height: float = min(560.0, max(440.0, viewport_size.y - 120.0))
	panel.custom_minimum_size = Vector2(target_width, target_height)

	portrait_frame.custom_minimum_size = Vector2(320, 420)
	portrait_texture.custom_minimum_size = Vector2(288, 388)


func _apply_theme() -> void:
	dimmer.color = ROOT_DIMMER_COLOR

	panel.add_theme_stylebox_override("panel", _make_panel_stylebox(PANEL_BG, PANEL_BORDER, 2, PANEL_RADIUS))
	portrait_frame.add_theme_stylebox_override("panel", _make_panel_stylebox(PORTRAIT_BG, Color(0.40, 0.44, 0.50, 0.85), 2, 12))
	dialogue_frame.add_theme_stylebox_override("panel", _make_panel_stylebox(DIALOG_BG, Color(0.40, 0.44, 0.50, 0.85), 2, 12))

	name_label.add_theme_font_size_override("font_size", 26)
	portrait_placeholder.add_theme_font_size_override("font_size", 18)
	dialogue_text.add_theme_font_size_override("normal_font_size", 24)
	dialogue_text.add_theme_color_override("default_color", Color(0.97, 0.98, 1.0))

	next_button.custom_minimum_size = Vector2(140, 44)
	end_button.custom_minimum_size = Vector2(140, 44)
	close_button.custom_minimum_size = Vector2(110, 40)


func _make_panel_stylebox(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func open_dialog(npc: Node, player: Node) -> void:
	current_npc = npc
	current_player = player
	visible = true
	move_to_front()
	_acquire_ui_lock()
	_refresh_dialog()


func close_dialog() -> void:
	visible = false
	_release_ui_lock()
	current_npc = null
	current_player = null
	if voice_player != null:
		voice_player.stop()
		voice_player.stream = null
	portrait_texture.texture = null
	portrait_placeholder.show()
	name_label.text = ""
	dialogue_text.text = ""


func _refresh_dialog() -> void:
	if current_npc == null or not is_instance_valid(current_npc):
		close_dialog()
		return

	name_label.text = _get_npc_display_name()
	dialogue_text.text = _get_npc_current_line()

	var portrait: Texture2D = _get_npc_portrait()
	portrait_texture.texture = portrait
	portrait_placeholder.visible = portrait == null

	_update_buttons()
	_play_current_voice()


func _update_buttons() -> void:
	if current_npc == null or not is_instance_valid(current_npc):
		next_button.text = "次へ"
		return

	var loop_talk: bool = bool(current_npc.get("loop_talk")) if current_npc.get("loop_talk") != null else false
	var is_last: bool = false
	if current_npc.has_method("is_last_talk_line"):
		is_last = bool(current_npc.call("is_last_talk_line"))

	if not loop_talk and is_last:
		next_button.text = "閉じる"
	else:
		next_button.text = "次へ"


func _on_next_pressed() -> void:
	if current_npc == null or not is_instance_valid(current_npc):
		close_dialog()
		return

	var loop_talk: bool = bool(current_npc.get("loop_talk")) if current_npc.get("loop_talk") != null else false
	var is_last: bool = false
	if current_npc.has_method("is_last_talk_line"):
		is_last = bool(current_npc.call("is_last_talk_line"))

	if not loop_talk and is_last:
		close_dialog()
		return

	if current_npc.has_method("advance_talk_index"):
		current_npc.call("advance_talk_index")

	_refresh_dialog()


func _on_end_pressed() -> void:
	close_dialog()


func _on_close_pressed() -> void:
	close_dialog()


func _get_npc_display_name() -> String:
	if current_npc != null and current_npc.has_method("get_dialog_display_name"):
		return str(current_npc.call("get_dialog_display_name"))
	return "住人"


func _get_npc_current_line() -> String:
	if current_npc != null and current_npc.has_method("get_current_line"):
		return str(current_npc.call("get_current_line"))
	return "……"


func _get_npc_portrait() -> Texture2D:
	if current_npc != null and current_npc.has_method("get_dialog_portrait"):
		var value: Variant = current_npc.call("get_dialog_portrait")
		if value is Texture2D:
			return value
	return null


func _play_current_voice() -> void:
	if voice_player == null:
		return

	voice_player.stop()
	voice_player.stream = null

	if current_npc == null or not is_instance_valid(current_npc):
		return

	if not current_npc.has_method("get_current_voice_stream"):
		return

	var voice_stream: Variant = current_npc.call("get_current_voice_stream")
	if not (voice_stream is AudioStream):
		return

	voice_player.stream = voice_stream
	voice_player.bus = _get_npc_voice_bus()
	voice_player.volume_db = _get_npc_voice_volume_db()
	voice_player.pitch_scale = _get_npc_voice_pitch_scale()
	voice_player.play()


func _get_npc_voice_bus() -> StringName:
	if current_npc != null and current_npc.has_method("get_voice_bus"):
		var value: Variant = current_npc.call("get_voice_bus")
		var bus_name: String = str(value)
		if not bus_name.is_empty():
			return StringName(bus_name)
	return DEFAULT_VOICE_BUS


func _get_npc_voice_volume_db() -> float:
	if current_npc != null and current_npc.has_method("get_voice_volume_db"):
		return float(current_npc.call("get_voice_volume_db"))
	return 0.0


func _get_npc_voice_pitch_scale() -> float:
	if current_npc != null and current_npc.has_method("get_voice_pitch_scale"):
		return float(current_npc.call("get_voice_pitch_scale"))
	return 1.0


func _find_ui_modal_manager() -> Node:
	var by_path: Node = get_node_or_null("/root/UIModalManager")
	if by_path != null:
		return by_path

	var by_group: Node = get_tree().get_first_node_in_group("ui_modal_manager")
	if by_group != null:
		return by_group

	for child in get_tree().root.get_children():
		var script_value: Variant = child.get_script()
		if script_value is Script:
			var script_ref: Script = script_value as Script
			if script_ref != null and script_ref.resource_path.get_file() == UI_MODAL_MANAGER_SCRIPT_NAME:
				return child

	return null


func _find_time_manager() -> Node:
	var by_path: Node = get_node_or_null("/root/TimeManager")
	if by_path != null:
		return by_path

	var by_group: Node = get_tree().get_first_node_in_group("time_manager")
	if by_group != null:
		return by_group

	for child in get_tree().root.get_children():
		var script_value: Variant = child.get_script()
		if script_value is Script:
			var script_ref: Script = script_value as Script
			if script_ref != null and script_ref.resource_path.get_file() == TIME_MANAGER_SCRIPT_NAME:
				return child

	return null


func _acquire_ui_lock() -> void:
	var ui_modal_manager: Node = _find_ui_modal_manager()
	if ui_modal_manager != null and ui_modal_manager.has_method("acquire_lock"):
		ui_modal_manager.call("acquire_lock", UI_LOCK_SOURCE, true, true)
		return

	var time_manager: Node = _find_time_manager()
	if time_manager == null:
		return

	var pause_source: String = "UI:" + UI_LOCK_SOURCE
	if time_manager.has_method("request_pause"):
		time_manager.call("request_pause", pause_source)
	elif time_manager.has_method("pause_time"):
		time_manager.call("pause_time", pause_source)


func _release_ui_lock() -> void:
	var ui_modal_manager: Node = _find_ui_modal_manager()
	if ui_modal_manager != null and ui_modal_manager.has_method("release_lock"):
		ui_modal_manager.call("release_lock", UI_LOCK_SOURCE)
		return

	var time_manager: Node = _find_time_manager()
	if time_manager == null:
		return

	var pause_source: String = "UI:" + UI_LOCK_SOURCE
	if time_manager.has_method("release_pause"):
		time_manager.call("release_pause", pause_source)
	elif time_manager.has_method("resume_time"):
		time_manager.call("resume_time", pause_source)

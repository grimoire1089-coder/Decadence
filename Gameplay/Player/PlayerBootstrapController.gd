extends RefCounted
class_name PlayerBootstrapController

var owner: CharacterBody2D = null


func setup(owner_node: CharacterBody2D) -> void:
	owner = owner_node


func boot_ready() -> void:
	if owner == null:
		return

	owner.add_to_group("player")
	owner.refresh_from_stats()
	owner._resolve_player_sprite()

	ensure_network_controller()
	ensure_input_controller()
	ensure_support_controller()
	ensure_interaction_controller()

	if PlayerStatsManager != null and not PlayerStatsManager.stats_changed.is_connected(owner._on_player_stats_changed):
		PlayerStatsManager.stats_changed.connect(owner._on_player_stats_changed)

	owner.call_deferred("_ensure_pause_menu_exists")


func cleanup_exit_tree() -> void:
	if owner == null:
		return

	if PlayerStatsManager != null and PlayerStatsManager.stats_changed.is_connected(owner._on_player_stats_changed):
		PlayerStatsManager.stats_changed.disconnect(owner._on_player_stats_changed)


func ensure_network_controller() -> void:
	if owner == null or owner.player_network_controller != null:
		return

	if not ResourceLoader.exists(owner.PLAYER_NETWORK_CONTROLLER_SCRIPT_PATH):
		return

	var controller_script: Script = load(owner.PLAYER_NETWORK_CONTROLLER_SCRIPT_PATH) as Script
	if controller_script == null:
		push_warning("PlayerBootstrapController: PlayerNetworkController.gd を読み込めません")
		return

	var instance: Variant = controller_script.new()
	if instance is PlayerNetworkController:
		owner.player_network_controller = instance as PlayerNetworkController
		owner.player_network_controller.setup(owner)
		owner.player_network_controller.ensure_state()


func ensure_input_controller() -> void:
	if owner == null or owner.player_input_controller != null:
		return

	if not ResourceLoader.exists(owner.PLAYER_INPUT_CONTROLLER_SCRIPT_PATH):
		return

	var controller_script: Script = load(owner.PLAYER_INPUT_CONTROLLER_SCRIPT_PATH) as Script
	if controller_script == null:
		push_warning("PlayerBootstrapController: PlayerInputController.gd を読み込めません")
		return

	var instance: Variant = controller_script.new()
	if instance is PlayerInputController:
		owner.player_input_controller = instance as PlayerInputController
		owner.player_input_controller.setup(owner)


func ensure_support_controller() -> void:
	if owner == null or owner.player_support_controller != null:
		return

	if not ResourceLoader.exists(owner.PLAYER_SUPPORT_CONTROLLER_SCRIPT_PATH):
		return

	var controller_script: Script = load(owner.PLAYER_SUPPORT_CONTROLLER_SCRIPT_PATH) as Script
	if controller_script == null:
		push_warning("PlayerBootstrapController: PlayerSupportController.gd を読み込めません")
		return

	var instance: Variant = controller_script.new()
	if instance is PlayerSupportController:
		owner.player_support_controller = instance as PlayerSupportController
		owner.player_support_controller.setup(owner)


func ensure_interaction_controller() -> void:
	if owner == null or owner.player_interaction_controller != null:
		return

	if not ResourceLoader.exists(owner.PLAYER_INTERACTION_CONTROLLER_SCRIPT_PATH):
		return

	var controller_script: Script = load(owner.PLAYER_INTERACTION_CONTROLLER_SCRIPT_PATH) as Script
	if controller_script == null:
		push_warning("PlayerBootstrapController: PlayerInteractionController.gd を読み込めません")
		return

	var instance: Variant = controller_script.new()
	if instance is PlayerInteractionController:
		owner.player_interaction_controller = instance as PlayerInteractionController
		owner.player_interaction_controller.setup(owner, owner.UI_MODAL_MANAGER_SCRIPT_NAME, owner.PAUSE_MENU_SCENE_PATH, owner.MODAL_UI_GROUPS)

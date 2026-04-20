extends RefCounted
class_name MapRouteRegistry

static func register_default_routes(base_world: Node) -> void:
	if base_world == null:
		return
	if not base_world.has_method("register_map_transition_route"):
		return

	base_world.call(
		"register_map_transition_route",
		"robin_house_enter",
		"res://Maps/RobinHouseInteriorMap.tscn",
		"entry_from_outside",
		"ロビンの家",
		"ロビンの家に入った"
	)

	base_world.call(
		"register_map_transition_route",
		"robin_house_exit",
		"res://Maps/TownMap_MainExtract.tscn",
		"robin_house_outside",
		"外",
		"外に出た"
	)

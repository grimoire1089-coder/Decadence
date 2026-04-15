extends Resource
class_name RoleSkillData

@export_group("Basic")
@export var skill_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var role_name: String = ""
@export var is_active: bool = true

@export_group("Role Restriction")
@export_enum("any", "tank", "attacker", "healer") var required_main_role: String = "any"
@export_enum("any", "tank", "attacker", "healer", "trickster", "buffer", "debuffer") var required_sub_role: String = "any"
@export var requires_pure_specialization: bool = false

@export_group("Cost")
@export var mp_cost: int = 0
@export var cast_time_seconds: float = 0.0
@export var cooldown_seconds: float = 0.0

@export_group("Range")
@export var range_meters: float = 0.0
@export var pixels_per_meter: float = 16.0

@export_group("Effect")
@export_enum("heal_over_time") var effect_type: String = "heal_over_time"
@export var effect_duration_seconds: float = 0.0
@export var tick_interval_seconds: float = 1.0
@export var hp_heal_per_tick: int = 0

@export_group("UI")
@export var icon: Texture2D = null


func get_range_distance_pixels() -> float:
	return max(range_meters, 0.0) * max(pixels_per_meter, 0.0)


func get_total_tick_count() -> int:
	if tick_interval_seconds <= 0.0:
		return 0
	if effect_duration_seconds <= 0.0:
		return 0

	return int(floor((effect_duration_seconds / tick_interval_seconds) + 0.0001))


func matches_role(main_role: String, sub_role: String) -> bool:
	if required_main_role != "any" and main_role != required_main_role:
		return false
	if required_sub_role != "any" and sub_role != required_sub_role:
		return false
	if requires_pure_specialization:
		return main_role == sub_role
	return true

extends Resource
class_name AutoAttackModifierData

@export_group("Basic")
@export var modifier_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D = null

@export_group("Attack")
@export_enum("physical", "magical") var attack_source: String = "physical"
@export_enum("melee", "mid", "long") var range_type: String = "melee"
@export_range(0.1, 999.0, 0.1) var range_meters: float = 2.0
@export_range(0.01, 10.0, 0.01) var damage_multiplier: float = 1.0


func get_attack_source_label() -> String:
	match attack_source:
		"magical":
			return "魔法"
		_:
			return "物理"


func get_range_type_label() -> String:
	match range_type:
		"mid":
			return "中距離"
		"long":
			return "遠距離"
		_:
			return "近距離"


func get_summary_text() -> String:
	return "%s / %s / 射程 %.1fm / ダメージ補正 %.0f%%" % [
		get_attack_source_label(),
		get_range_type_label(),
		range_meters,
		damage_multiplier * 100.0
	]

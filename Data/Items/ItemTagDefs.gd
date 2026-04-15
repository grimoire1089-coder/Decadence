extends Object
class_name ItemTagDefs

const TAG_NONE := 0
const TAG_FOOD := 1 << 0
const TAG_VEGETABLE := 1 << 1
const TAG_FRUIT := 1 << 2
const TAG_SEED := 1 << 3
const TAG_MATERIAL := 1 << 4
const TAG_TOOL := 1 << 5
const TAG_DRINK := 1 << 6
const TAG_CROP := 1 << 7

const TRAIT_NONE := 0
const TRAIT_SWEET := 1 << 0
const TRAIT_SALTY := 1 << 1
const TRAIT_BITTER := 1 << 2
const TRAIT_SOUR := 1 << 3
const TRAIT_SPICY := 1 << 4
const TRAIT_BREAD := 1 << 5
const TRAIT_CHOCOLATE := 1 << 6
const TRAIT_SNACK := 1 << 7
const TRAIT_GIFTABLE := 1 << 8
const TRAIT_POPULAR := 1 << 9
const TRAIT_HEALTHY := 1 << 10
const TRAIT_RAW := 1 << 11
const TRAIT_COOKED := 1 << 12
const TRAIT_NotFORSALE := 1 << 13

const TAG_LABELS := {
	TAG_FOOD: "食品",
	TAG_VEGETABLE: "野菜",
	TAG_FRUIT: "果物",
	TAG_SEED: "種",
	TAG_MATERIAL: "素材",
	TAG_TOOL: "道具",
	TAG_DRINK: "飲料",
	TAG_CROP: "作物",
}

const TRAIT_LABELS := {
	TRAIT_SWEET: "甘い",
	TRAIT_SALTY: "しょっぱい",
	TRAIT_BITTER: "苦い",
	TRAIT_SOUR: "酸っぱい",
	TRAIT_SPICY: "辛い",
	TRAIT_BREAD: "パン",
	TRAIT_CHOCOLATE: "チョコ製品",
	TRAIT_SNACK: "お菓子",
	TRAIT_GIFTABLE: "皆に喜ばれる品",
	TRAIT_POPULAR: "人気商品",
	TRAIT_HEALTHY: "健康向き",
	TRAIT_RAW: "生もの",
	TRAIT_COOKED: "調理済み",
	TRAIT_NotFORSALE: "売却不可",
}


static func get_tag_hint_string() -> String:
	return _build_flags_hint(TAG_LABELS)


static func get_trait_hint_string() -> String:
	return _build_flags_hint(TRAIT_LABELS)


static func has_all(value: int, mask: int) -> bool:
	if mask == 0:
		return true
	return (value & mask) == mask


static func has_any(value: int, mask: int) -> bool:
	if mask == 0:
		return false
	return (value & mask) != 0


static func tag_names_from_mask(mask: int) -> PackedStringArray:
	return _names_from_mask(mask, TAG_LABELS)


static func trait_names_from_mask(mask: int) -> PackedStringArray:
	return _names_from_mask(mask, TRAIT_LABELS)


static func _build_flags_hint(label_map: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var keys: Array = label_map.keys()
	keys.sort()

	for raw_key in keys:
		var flag: int = int(raw_key)
		if flag <= 0:
			continue
		parts.append("%s:%d" % [String(label_map[flag]), flag])

	return ",".join(parts)


static func _names_from_mask(mask: int, label_map: Dictionary) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var keys: Array = label_map.keys()
	keys.sort()

	for raw_key in keys:
		var flag: int = int(raw_key)
		if flag <= 0:
			continue
		if (mask & flag) != 0:
			result.append(String(label_map[flag]))

	return result

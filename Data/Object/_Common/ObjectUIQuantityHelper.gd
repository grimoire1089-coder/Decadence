extends RefCounted
class_name ObjectUIQuantityHelper

static func get_modifier_multiplier(shift_multiplier: int = 10, ctrl_multiplier: int = 100) -> int:
	if Input.is_key_pressed(KEY_CTRL):
		return max(ctrl_multiplier, 1)
	if Input.is_key_pressed(KEY_SHIFT):
		return max(shift_multiplier, 1)
	return 1


static func resolve_fixed_amount(
	default_amount: int = 1,
	shift_multiplier: int = 10,
	ctrl_multiplier: int = 100
) -> int:
	var base_amount: int = max(default_amount, 1)
	return base_amount * get_modifier_multiplier(shift_multiplier, ctrl_multiplier)


static func resolve_spinbox_amount(
	spinbox: SpinBox,
	fallback_amount: int = 1,
	shift_multiplier: int = 10,
	ctrl_multiplier: int = 100
) -> int:
	var base_amount: int = max(fallback_amount, 1)
	if spinbox != null:
		base_amount = max(int(spinbox.value), 1)

	return base_amount * get_modifier_multiplier(shift_multiplier, ctrl_multiplier)


static func is_modifier_refresh_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false

	var key_event: InputEventKey = event as InputEventKey
	if key_event == null:
		return false

	return key_event.keycode == KEY_SHIFT or key_event.keycode == KEY_CTRL

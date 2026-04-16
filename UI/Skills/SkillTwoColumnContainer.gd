extends VBoxContainer
class_name SkillTwoColumnContainer

@export var column_gap: int = 18
@export var section_gap: int = 12
@export var header_bottom_gap: int = 16
@export_range(0.3, 0.7, 0.01) var left_ratio: float = 0.48
@export var min_left_width: float = 520.0
@export var min_right_width: float = 420.0

const HEADER_NAME := "HeaderHBox"
const LEFT_ORDER := ["LifeTitleLabel", "SummaryLabel", "ScrollContainer", "HintLabel"]
const RIGHT_PRIORITY := ["CombatTitleLabel"]

func _ready() -> void:
	queue_sort()

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_layout_children()
	elif what == NOTIFICATION_RESIZED:
		queue_sort()

func _layout_children() -> void:
	var header := get_node_or_null(HEADER_NAME) as Control

	var left_children: Array[Control] = _collect_named_children(LEFT_ORDER)
	var right_children: Array[Control] = _collect_right_children()

	var content_top := 0.0
	if header != null and header.visible:
		var header_height := max(header.get_combined_minimum_size().y, 40.0)
		fit_child_in_rect(header, Rect2(Vector2.ZERO, Vector2(size.x, header_height)))
		content_top = header_height + header_bottom_gap

	var available_height := max(size.y - content_top, 0.0)
	var available_width := max(size.x, min_left_width + min_right_width + column_gap)

	var left_width := clampf(
		available_width * left_ratio,
		min_left_width,
		max(min_left_width, available_width - min_right_width - column_gap)
	)
	var right_width := max(available_width - left_width - column_gap, min_right_width)

	if left_width + right_width + column_gap > available_width:
		left_width = max((available_width - column_gap) * 0.5, 320.0)
		right_width = max(available_width - left_width - column_gap, 320.0)

	_layout_stack(left_children, Rect2(0.0, content_top, left_width, available_height), true)
	_layout_stack(right_children, Rect2(left_width + column_gap, content_top, right_width, available_height), false)

func _collect_named_children(order: Array[String]) -> Array[Control]:
	var result: Array[Control] = []
	for node_name in order:
		var child := get_node_or_null(node_name) as Control
		if child != null and child.visible:
			result.append(child)
	return result

func _collect_right_children() -> Array[Control]:
	var result: Array[Control] = []

	for node_name in RIGHT_PRIORITY:
		var child := get_node_or_null(node_name) as Control
		if child != null and child.visible:
			result.append(child)

	for raw_child in get_children():
		var child := raw_child as Control
		if child == null or not child.visible:
			continue
		if child.name == HEADER_NAME:
			continue
		if LEFT_ORDER.has(child.name):
			continue
		if RIGHT_PRIORITY.has(child.name):
			continue
		result.append(child)

	return result

func _layout_stack(children: Array[Control], rect: Rect2, allow_scroll_flex: bool) -> void:
	if children.is_empty():
		return

	var flex_indices: Array[int] = []
	var min_heights: Array[float] = []
	var fixed_height := 0.0

	for index in range(children.size()):
		var child := children[index]
		var min_height := max(child.get_combined_minimum_size().y, 28.0)
		min_heights.append(min_height)

		var is_flex := false
		if allow_scroll_flex and (child is ScrollContainer or String(child.name).contains("Scroll")):
			is_flex = true
		elif not allow_scroll_flex and index == children.size() - 1:
			is_flex = true

		if is_flex:
			flex_indices.append(index)
		else:
			fixed_height += min_height

	fixed_height += max(children.size() - 1, 0) * section_gap
	var remaining_height := max(rect.size.y - fixed_height, 0.0)
	var flex_height := 0.0
	if not flex_indices.is_empty():
		flex_height = remaining_height / float(flex_indices.size())

	var y := rect.position.y
	for index in range(children.size()):
		var child := children[index]
		var child_height := min_heights[index]
		if flex_indices.has(index):
			child_height = max(child_height, flex_height)

		fit_child_in_rect(
			child,
			Rect2(rect.position.x, y, rect.size.x, max(child_height, 1.0))
		)
		y += child_height + section_gap

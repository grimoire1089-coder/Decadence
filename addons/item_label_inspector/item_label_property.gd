@tool
extends EditorProperty

const LABEL_DIR_CANDIDATES := [
	"res://Data/ItemLabels",
	"res://Data/ItemTags",
]

var _updating := false
var _current_value: Array = []
var _tag_resources: Array[Resource] = []
var _search_text := ""
var _category_filter := &"all"

var _root: VBoxContainer
var _toolbar: HBoxContainer
var _summary_label: Label
var _search_edit: LineEdit
var _category_option: OptionButton
var _refresh_button: Button
var _clear_button: Button
var _scroll: ScrollContainer
var _list_box: VBoxContainer


func _init() -> void:
	draw_label = false
	_build_ui()
	_reload_tag_resources()
	_refresh_list()


func _build_ui() -> void:
	_root = VBoxContainer.new()
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_root)
	set_bottom_editor(_root)

	_toolbar = HBoxContainer.new()
	_root.add_child(_toolbar)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "ラベル検索"
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_on_search_text_changed)
	_toolbar.add_child(_search_edit)
	add_focusable(_search_edit)

	_category_option = OptionButton.new()
	_category_option.add_item("全部")
	_category_option.set_item_metadata(0, StringName("all"))
	_category_option.add_item("タグ")
	_category_option.set_item_metadata(1, StringName("tag"))
	_category_option.add_item("属性")
	_category_option.set_item_metadata(2, StringName("trait"))
	_category_option.add_item("その他")
	_category_option.set_item_metadata(3, StringName("generic"))
	_category_option.item_selected.connect(_on_category_selected)
	_toolbar.add_child(_category_option)
	add_focusable(_category_option)

	_refresh_button = Button.new()
	_refresh_button.text = "再読込"
	_refresh_button.pressed.connect(_on_refresh_pressed)
	_toolbar.add_child(_refresh_button)
	add_focusable(_refresh_button)

	_clear_button = Button.new()
	_clear_button.text = "全解除"
	_clear_button.pressed.connect(_on_clear_pressed)
	_toolbar.add_child(_clear_button)
	add_focusable(_clear_button)

	_summary_label = Label.new()
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_summary_label)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0.0, 220.0)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(_scroll)

	_list_box = VBoxContainer.new()
	_list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list_box)


func _update_property() -> void:
	var edited_object := get_edited_object()
	var edited_property := get_edited_property()
	if edited_object == null or String(edited_property).is_empty():
		return

	var value = edited_object.get(edited_property)
	if value == null:
		value = []

	var normalized := _normalize_label_array(value)
	if normalized == _current_value:
		_update_summary()
		return

	_updating = true
	_current_value = normalized
	_refresh_list()
	_updating = false


func _set_read_only(read_only: bool) -> void:
	_search_edit.editable = not read_only
	_category_option.disabled = read_only
	_refresh_button.disabled = read_only
	_clear_button.disabled = read_only
	for child in _list_box.get_children():
		if child is CheckBox:
			child.disabled = read_only


func _on_search_text_changed(new_text: String) -> void:
	_search_text = new_text.strip_edges()
	_refresh_list()


func _on_category_selected(index: int) -> void:
	_category_filter = _category_option.get_item_metadata(index)
	_refresh_list()


func _on_refresh_pressed() -> void:
	_reload_tag_resources()
	_refresh_list()


func _on_clear_pressed() -> void:
	if is_read_only():
		return
	_apply_new_value([])


func _on_checkbox_toggled(checked: bool, label_resource: Resource) -> void:
	if _updating or is_read_only():
		return

	var next_value: Array = _normalize_label_array(_current_value)
	if checked:
		if not _contains_label(next_value, label_resource):
			next_value.append(label_resource)
	else:
		_remove_label(next_value, label_resource)

	_apply_new_value(next_value)


func _apply_new_value(next_value: Array) -> void:
	var edited_object := get_edited_object()
	var edited_property := get_edited_property()
	if edited_object == null or String(edited_property).is_empty():
		return

	var typed_value := _coerce_to_property_array(next_value)
	_current_value = _normalize_label_array(typed_value)

	# まず EditorProperty 経由で正式に通知
	emit_changed(edited_property, typed_value)

	# Resource 編集では Inspector 更新が遅れることがあるので、明示的にも反映
	edited_object.set(edited_property, typed_value)
	if edited_object is Resource:
		edited_object.emit_changed()

	_updating = true
	_refresh_list()
	_updating = false


func _coerce_to_property_array(next_value: Array) -> Array:
	var normalized := _normalize_label_array(next_value)
	var edited_object := get_edited_object()
	var edited_property := get_edited_property()
	if edited_object == null or String(edited_property).is_empty():
		return normalized

	var current_value = edited_object.get(edited_property)
	var typed_array: Array = []
	if typeof(current_value) == TYPE_ARRAY:
		typed_array = current_value.duplicate()
		typed_array.clear()

	for entry in normalized:
		typed_array.append(entry)

	return typed_array


func _refresh_list() -> void:
	if _list_box == null:
		return

	for child in _list_box.get_children():
		child.queue_free()

	var filtered := _get_filtered_resources()
	if filtered.is_empty():
		var empty_label := Label.new()
		empty_label.text = "該当ラベルなし"
		empty_label.modulate.a = 0.7
		_list_box.add_child(empty_label)
		_update_summary()
		return

	var current_category := ""
	for label_resource in filtered:
		var category_text := _get_resource_category_text(label_resource)
		if category_text != current_category:
			current_category = category_text
			var header := Label.new()
			header.text = _format_category_label(category_text)
			header.modulate = Color(0.9, 0.82, 0.45, 1.0)
			_list_box.add_child(header)

		var checkbox := CheckBox.new()
		checkbox.text = _get_resource_display_name(label_resource)
		checkbox.tooltip_text = _build_tooltip(label_resource)
		checkbox.button_pressed = _contains_label(_current_value, label_resource)
		checkbox.toggled.connect(_on_checkbox_toggled.bind(label_resource))
		_list_box.add_child(checkbox)

	_update_summary()
	_set_read_only(is_read_only())


func _update_summary() -> void:
	var names: PackedStringArray = PackedStringArray()
	for label_resource in _normalize_label_array(_current_value):
		names.append(_get_resource_display_name(label_resource))

	if names.is_empty():
		_summary_label.text = "選択中: なし"
	else:
		_summary_label.text = "選択中: %d件  /  %s" % [names.size(), " / ".join(names)]


func _reload_tag_resources() -> void:
	var found: Array[Resource] = []
	var seen_paths: Dictionary = {}
	var seen_ids: Dictionary = {}

	for base_dir in LABEL_DIR_CANDIDATES:
		_collect_label_resources(base_dir, found, seen_paths, seen_ids)

	found.sort_custom(Callable(self, "_sort_resources"))
	_tag_resources = found


func _collect_label_resources(base_dir: String, out: Array[Resource], seen_paths: Dictionary, seen_ids: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(base_dir):
		return

	var dir := DirAccess.open(base_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name.is_empty():
			break
		if name.begins_with("."):
			continue

		var full_path := base_dir.path_join(name)
		if dir.current_is_dir():
			_collect_label_resources(full_path, out, seen_paths, seen_ids)
			continue

		if not (name.ends_with(".tres") or name.ends_with(".res")):
			continue

		var resource: Resource = load(full_path)
		if resource == null:
			continue
		if not _looks_like_item_tag(resource):
			continue
		if seen_paths.has(resource.resource_path):
			continue

		var id_text := _get_resource_id_text(resource)
		if not id_text.is_empty() and seen_ids.has(id_text):
			continue

		seen_paths[resource.resource_path] = true
		if not id_text.is_empty():
			seen_ids[id_text] = true
		out.append(resource)

	dir.list_dir_end()


func _get_filtered_resources() -> Array[Resource]:
	var result: Array[Resource] = []
	var keyword := _search_text.to_lower()

	for label_resource in _tag_resources:
		var category := StringName(_get_resource_category_text(label_resource))
		if _category_filter != &"all" and category != _category_filter:
			continue

		if not keyword.is_empty():
			var display_name := _get_resource_display_name(label_resource).to_lower()
			var id_text := _get_resource_id_text(label_resource).to_lower()
			var desc := String(_get_resource_value(label_resource, &"description", "")).to_lower()
			if keyword not in display_name and keyword not in id_text and keyword not in desc:
				continue

		result.append(label_resource)

	return result


func _normalize_label_array(value) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	if typeof(value) != TYPE_ARRAY:
		return result

	for entry in value:
		if not (entry is Resource):
			continue
		if not _looks_like_item_tag(entry):
			continue

		var key := _make_resource_key(entry)
		if seen.has(key):
			continue
		seen[key] = true
		result.append(entry)

	return result


func _contains_label(source: Array, candidate: Resource) -> bool:
	var candidate_key := _make_resource_key(candidate)
	for entry in source:
		if not (entry is Resource):
			continue
		if _make_resource_key(entry) == candidate_key:
			return true
	return false


func _remove_label(source: Array, candidate: Resource) -> void:
	var candidate_key := _make_resource_key(candidate)
	for i in range(source.size() - 1, -1, -1):
		var entry = source[i]
		if not (entry is Resource):
			continue
		if _make_resource_key(entry) == candidate_key:
			source.remove_at(i)


func _make_resource_key(resource: Resource) -> String:
	if resource == null:
		return ""
	if not resource.resource_path.is_empty():
		return resource.resource_path
	return _get_resource_id_text(resource)


static func _get_resource_value(resource: Resource, property_name: StringName, fallback = null):
	if resource == null:
		return fallback
	var value = resource.get(property_name)
	if value == null:
		return fallback
	return value


func _looks_like_item_tag(resource: Resource) -> bool:
	return resource.get("id") != null and resource.get("display_name") != null and resource.get("category") != null


func _get_resource_display_name(resource: Resource) -> String:
	if resource == null:
		return "(null)"
	if resource.has_method("get_display_name"):
		return String(resource.call("get_display_name"))
	var display_name := String(_get_resource_value(resource, &"display_name", ""))
	if not display_name.is_empty():
		return display_name
	var id_text := _get_resource_id_text(resource)
	if not id_text.is_empty():
		return id_text
	return resource.resource_name


func _get_resource_id_text(resource: Resource) -> String:
	if resource == null:
		return ""
	return String(_get_resource_value(resource, &"id", &""))


func _get_resource_category_text(resource: Resource) -> String:
	if resource == null:
		return "generic"
	var text := String(_get_resource_value(resource, &"category", &"generic")).strip_edges()
	if text.is_empty():
		return "generic"
	return text


func _build_tooltip(resource: Resource) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("ID: %s" % _get_resource_id_text(resource))
	lines.append("カテゴリ: %s" % _format_category_label(_get_resource_category_text(resource)))
	var desc := String(_get_resource_value(resource, &"description", "")).strip_edges()
	if not desc.is_empty():
		lines.append("")
		lines.append(desc)
	return "\n".join(lines)


func _format_category_label(category_text: String) -> String:
	match category_text:
		"tag":
			return "タグ"
		"trait":
			return "属性"
		"generic":
			return "その他"
		_:
			return category_text


func _sort_resources(a: Resource, b: Resource) -> bool:
	var a_cat := String(_get_resource_value(a, &"category", &"generic"))
	var b_cat := String(_get_resource_value(b, &"category", &"generic"))
	if a_cat == b_cat:
		var a_name := String(a.call("get_display_name") if a.has_method("get_display_name") else _get_resource_value(a, &"display_name", ""))
		var b_name := String(b.call("get_display_name") if b.has_method("get_display_name") else _get_resource_value(b, &"display_name", ""))
		return a_name.naturalnocasecmp_to(b_name) < 0
	return a_cat.naturalnocasecmp_to(b_cat) < 0

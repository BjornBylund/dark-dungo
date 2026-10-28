## A form for any content resource, built from its exported fields, so a new
## field or a new kind of item gets an editor with no extra work: numbers,
## switches, text, enums, colours, art, rank pickers, lists, key-value tables,
## links to other content files (an encounter's enemies, a trinket's class)
## and nested resources (a unit's skills and their effects). @export_group
## groups fold away, opening by themselves when they hold a changed field.
## Fields changed from their default are named in gold, with the script's ##
## comment as their tooltip. Every change goes through the library, so it can
## be undone.
class_name ResourceForm
extends VBoxContainer

const LABEL_WIDTH := 200
const INDENT := 18
## Classes that are content files of their own: a field holding one links to
## a file instead of holding a copy.
const LINKED: Array[StringName] = [&"UnitDef", &"EncounterDef", &"TrinketDef", &"RegionDef"]

## Script -> {field name: its ## comment}.
static var _docs := {}
## Script -> a fresh instance, for each field's default.
static var _blanks := {}

var library: BalanceLibrary
## The content file being edited.
var root: Resource
## Section key -> open. The app keeps it, so a rebuilt form opens the same sections.
var open_sections: Dictionary
## Nested resource -> its section, for reveal().
var _sections := {}
var _file_dialog: FileDialog


func _init(content: BalanceLibrary, resource: Resource, open: Dictionary) -> void:
	library = content
	root = resource
	open_sections = open
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 3)
	_build()


func rebuild() -> void:
	for child in get_children():
		if child != _file_dialog:
			remove_child(child)
			child.queue_free()
	_sections.clear()
	_build()


func _build() -> void:
	_add_fields(self, root)


## Opens the sections down to `nested` (a skill, an effect...) and returns its
## section, or null when it isn't part of the form.
func reveal(nested: Resource) -> Control:
	var keys := _keys_to(root, nested)
	if keys.is_empty():
		return null
	for key in keys:
		open_sections[key] = true
	rebuild()
	return _sections.get(nested)


## The section keys that lead from `object` to `target`, or [] when it isn't inside.
func _keys_to(object: Resource, target: Resource) -> Array[String]:
	var group := ""
	for property in object.get_property_list():
		if property.usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY):
			group = property.name if property.usage & PROPERTY_USAGE_GROUP else ""
			continue
		if not _is_field(property):
			continue
		var value: Variant = object.get(property.name)
		var items: Array = value if value is Array else [value] if value is Resource else []
		for item: Variant in items:
			if not item is Resource or item.get_script() == null or _is_linked(item):
				continue
			var keys: Array[String] = []
			if group != "":
				keys.append(_group_key(object, group))
			if value is Array:
				keys.append(_field_key(object, property.name))
			keys.append(_item_key(item))
			if item == target:
				return keys
			var deeper := _keys_to(item, target)
			if not deeper.is_empty():
				keys.append_array(deeper)
				return keys
	return []


# --- Layout ---

func _add_fields(parent: Container, object: Resource) -> void:
	var docs := _docs_for(object.get_script())
	var groups: Array[Array] = [["", []]]
	for property in object.get_property_list():
		# A category starts a class's own fields, outside any group of its base class.
		if property.usage & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY):
			groups.append([property.name if property.usage & PROPERTY_USAGE_GROUP else "", []])
		elif _is_field(property):
			groups.back()[1].append(property)
	for group in groups:
		var fields: Array = group[1]
		if fields.is_empty():
			continue
		if group[0] == "":
			for property: Dictionary in fields:
				_add_field(parent, object, property, docs)
			continue
		var changed := fields.any(func(property: Dictionary) -> bool: return not _is_default(object, property.name))
		_section(parent, group[0], _group_key(object, group[0]), changed, func(body: VBoxContainer) -> void:
			for property: Dictionary in fields:
				_add_field(body, object, property, docs))


func _is_field(property: Dictionary) -> bool:
	return property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_EDITOR


func _add_field(parent: Container, object: Resource, property: Dictionary, docs: Dictionary) -> void:
	var name: StringName = property.name
	var value: Variant = object.get(name)
	var title := String(name).capitalize()
	if value is Array and _typed_class(value) != &"" and _typed_class(value) not in LINKED:
		_add_resource_list(parent, object, name, title, value)
		return
	if property.type == TYPE_OBJECT and property.hint_string not in LINKED and property.hint_string != "Texture2D":
		_add_nested(parent, object, name, title, property.hint_string)
		return
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = LABEL_WIDTH
	label.tooltip_text = docs.get(name, "")
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	if not _is_default(object, name):
		label.add_theme_color_override("font_color", UiStyle.GOLD)
	row.add_child(label)
	var editor := _editor(object, property, value)
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(editor)
	parent.add_child(row)


## A foldable section: a header button (with `buttons` beside it) and a body
## built the first time it opens.
func _section(parent: Container, title: String, key: String, open_by_default: bool, build: Callable,
		buttons: Array[Control] = []) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var header := HBoxContainer.new()
	var toggle := Button.new()
	toggle.flat = true
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle.add_theme_color_override("font_color", UiStyle.TEXT)
	header.add_child(toggle)
	for button in buttons:
		header.add_child(button)
	box.add_child(header)
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", INDENT)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 3)
	indent.add_child(body)
	box.add_child(indent)
	var state := {built = false}
	var set_open := func(open: bool) -> void:
		toggle.text = ("▾  " if open else "▸  ") + title
		indent.visible = open
		open_sections[key] = open
		if open and not state.built:
			state.built = true
			build.call(body)
	toggle.pressed.connect(func() -> void: set_open.call(not indent.visible))
	set_open.call(open_sections.get(key, open_by_default))
	parent.add_child(box)
	return box


## A list of nested resources (skills, effects, bonuses, triggers): one
## section each, with buttons to move, copy and remove it, and one to add.
func _add_resource_list(parent: Container, object: Resource, name: StringName, title: String, items: Array) -> void:
	var item_script: Script = items.get_typed_script()
	var build := func(body: VBoxContainer) -> void:
		for i in items.size():
			var item: Resource = items[i]
			var buttons: Array[Control] = [
				_small_button("▲", "Move up", _move_item.bind(object, name, i, -1), i > 0),
				_small_button("▼", "Move down", _move_item.bind(object, name, i, 1), i < items.size() - 1),
				_small_button("Copy", "Add a copy after it", _copy_item.bind(object, name, i)),
				_small_button("✕", "Remove", _remove_item.bind(object, name, i)),
			]
			_sections[item] = _section(body, _item_title(item), _item_key(item), false, func(item_body: VBoxContainer) -> void:
				_add_fields(item_body, item), buttons)
		var kind := String(_typed_class(items)).trim_suffix("Def").capitalize().to_lower()
		var add := Button.new()
		add.text = "+ Add %s" % kind
		add.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		add.pressed.connect(func() -> void:
			var grown: Array = object.get(name).duplicate()
			grown.append(_new_item(item_script, kind, grown))
			_change(object, name, grown))
		body.add_child(add)
	_section(parent, "%s (%d)" % [title, items.size()], _field_key(object, name), not items.is_empty(), build)


## One optional nested resource, like a unit's riposte skill.
func _add_nested(parent: Container, object: Resource, name: StringName, title: String, class_title: String) -> void:
	var value: Resource = object.get(name)
	if value == null:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = title
		label.custom_minimum_size.x = LABEL_WIDTH
		row.add_child(label)
		var add := Button.new()
		add.text = "+ Add"
		add.pressed.connect(func() -> void: _change(object, name, _class_script(class_title).new()))
		row.add_child(add)
		parent.add_child(row)
		return
	var remove: Array[Control] = [_small_button("✕", "Remove", func() -> void: _change(object, name, null))]
	_sections[value] = _section(parent, "%s: %s" % [title, _item_title(value)], _item_key(value), false,
			func(body: VBoxContainer) -> void: _add_fields(body, value), remove)


## A new entry for a list: with a name, and an id none of `siblings` has, where it takes them.
static func _new_item(item_script: Script, kind: String, siblings: Array) -> Resource:
	var item: Resource = item_script.new()
	if &"display_name" in item:
		item.set(&"display_name", "New " + kind)
	if &"id" in item:
		var taken := siblings.map(func(each: Resource) -> StringName: return each.get(&"id"))
		var base := "new_" + kind.to_snake_case()
		var id := base
		var n := 2
		while StringName(id) in taken:
			id = "%s_%d" % [base, n]
			n += 1
		item.set(&"id", StringName(id))
	return item


func _small_button(text: String, tooltip: String, action: Callable, enabled: bool = true) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(action)
	return button


func _item_title(item: Resource) -> String:
	if item is SkillDef:
		return item.display_name if item.display_name != "" else String(item.id)
	if item is EffectDef:
		var icons := RegEx.create_from_string("\\[img[^\\]]*\\][^\\[]*\\[/img\\]")
		var text := UiStyle.plain(icons.sub(UiStyle.effect_bbcode(item), "", true)).strip_edges()
		return text if text != "" else EffectDef.Kind.keys()[item.kind].capitalize()
	if item is TrinketBonus:
		return UiStyle.trinket_stat_text(item.stat, item.amount)
	if item is TrinketTrigger:
		return "%s → %s" % [TrinketTrigger.When.keys()[item.when].capitalize(), TrinketTrigger.To.keys()[item.to].capitalize()]
	if item.has_method(&"describe"):
		return item.describe()
	for field: StringName in [&"display_name", &"name", &"id", &"title"]:
		if field in item and str(item.get(field)) != "":
			return str(item.get(field))
	return String(item.get_script().get_global_name())


# --- Editors ---

func _editor(object: Resource, property: Dictionary, value: Variant) -> Control:
	var name: StringName = property.name
	match property.type:
		TYPE_BOOL:
			var check := CheckBox.new()
			check.button_pressed = value
			check.toggled.connect(func(on: bool) -> void: _apply(object, name, on))
			return check
		TYPE_INT:
			if property.hint == PROPERTY_HINT_ENUM:
				return _enum_editor(object, name, value, property.hint_string)
			return _number_editor(object, name, value, property, true)
		TYPE_FLOAT:
			return _number_editor(object, name, value, property, false)
		TYPE_STRING, TYPE_STRING_NAME:
			return _text_editor(object, name, value, property.type == TYPE_STRING_NAME)
		TYPE_COLOR:
			var picker := ColorPickerButton.new()
			picker.color = value
			picker.custom_minimum_size = Vector2(80, 28)
			picker.color_changed.connect(func(color: Color) -> void: _apply(object, name, color))
			return picker
		TYPE_OBJECT:
			if property.hint_string == "Texture2D":
				return _texture_editor(object, name, value)
			return _link_editor(object, name, value, StringName(property.hint_string))
		TYPE_ARRAY:
			match value.get_typed_builtin():
				TYPE_INT:
					if String(name).ends_with("_ranks"):
						return _ranks_editor(object, name, value)
					return _list_editor(object, name, value)
				TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME:
					return _list_editor(object, name, value)
				TYPE_OBJECT:
					return _link_list_editor(object, name, value)
		TYPE_DICTIONARY:
			return _dictionary_editor(object, name, value)
	var label := Label.new()
	label.text = str(value)
	label.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	return label


func _number_editor(object: Resource, name: StringName, value: float, property: Dictionary, whole: bool) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = -100000
	spin.max_value = 100000
	spin.step = 1.0 if whole else 0.001
	spin.custom_arrow_step = 1.0 if whole else 0.05
	if property.hint == PROPERTY_HINT_RANGE:
		var parts: PackedStringArray = property.hint_string.split(",")
		spin.min_value = float(parts[0])
		spin.max_value = float(parts[1])
	else:
		spin.allow_greater = true
		spin.allow_lesser = true
	spin.value = value
	spin.select_all_on_focus = true
	spin.custom_minimum_size.x = 120
	spin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	spin.value_changed.connect(func(changed: float) -> void: _apply(object, name, roundi(changed) if whole else changed))
	return spin


func _text_editor(object: Resource, name: StringName, value: Variant, string_name: bool) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = str(value)
	if name == &"id" and library.is_locked(object):
		edit.editable = false
		edit.tooltip_text = "Saves and other content refer to this id, so it can't change once saved."
	edit.text_changed.connect(func(text: String) -> void: _apply(object, name, StringName(text) if string_name else text))
	return edit


## "ACTION,SWAP,PASS" or "Action:0,Swap:1": the enum's names, with values when given.
func _enum_editor(object: Resource, name: StringName, value: int, hint: String) -> OptionButton:
	var option := OptionButton.new()
	var next := 0
	for entry in hint.split(","):
		var parts := entry.split(":")
		var id := int(parts[1]) if parts.size() > 1 else next
		option.add_item(parts[0].capitalize(), id)
		next = id + 1
	option.select(option.get_item_index(value))
	option.item_selected.connect(func(index: int) -> void: _apply(object, name, option.get_item_id(index)))
	return option


func _texture_editor(object: Resource, name: StringName, value: Texture2D) -> Control:
	var row := HBoxContainer.new()
	var path := Label.new()
	path.text = value.resource_path.trim_prefix("res://") if value else "(none: placeholder)"
	path.clip_text = true
	path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path.tooltip_text = path.text
	path.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(path)
	row.add_child(_small_button("Pick…", "Choose an image file", func() -> void: _pick_texture(object, name, value)))
	row.add_child(_small_button("✕", "Clear", func() -> void: _change(object, name, null), value != null))
	return row


func _pick_texture(object: Resource, name: StringName, current: Texture2D) -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.access = FileDialog.ACCESS_RESOURCES
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.filters = PackedStringArray(["*.png, *.svg, *.jpg, *.webp ; Images"])
		add_child(_file_dialog)
	for connection in _file_dialog.file_selected.get_connections():
		_file_dialog.file_selected.disconnect(connection.callable)
	_file_dialog.file_selected.connect(func(path: String) -> void: _change(object, name, load(path)))
	_file_dialog.current_dir = current.resource_path.get_base_dir() if current else "res://art"
	_file_dialog.popup_centered(Vector2i(900, 640))


## A pick of one content file: a trinket's class, say.
func _link_editor(object: Resource, name: StringName, value: Resource, class_title: StringName) -> OptionButton:
	var choices := _choices(class_title, name)
	var option := OptionButton.new()
	option.add_item("(none)")
	for choice in choices:
		option.add_item(_item_title(choice))
	option.select(choices.find(value) + 1)
	option.item_selected.connect(func(index: int) -> void: _change(object, name, choices[index - 1] if index > 0 else null))
	return option


## The content files a link may point to: heroes for a trinket's class,
## enemies for an encounter's.
func _choices(class_title: StringName, field: StringName) -> Array:
	match class_title:
		&"UnitDef":
			match field:
				&"hero":
					return library.heroes
				&"enemies":
					return library.enemies
			return library.heroes + library.enemies
		&"EncounterDef":
			return library.encounters
		&"TrinketDef":
			return library.trinkets
		&"RegionDef":
			return library.campaign.regions
	return []


## A list of links, like an encounter's enemies: a pick per entry, with buttons
## to move and remove it, and one to add. Units show how many ranks they fill.
func _link_list_editor(object: Resource, name: StringName, value: Array) -> Control:
	var class_title := _typed_class(value)
	var choices := _choices(class_title, name)
	var box := VBoxContainer.new()
	for i in value.size():
		var row := HBoxContainer.new()
		var option := OptionButton.new()
		for choice in choices:
			option.add_item(_item_title(choice))
		option.select(choices.find(value[i]))
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.item_selected.connect(func(index: int) -> void:
			var changed: Array = object.get(name).duplicate()
			changed[i] = choices[index]
			_change(object, name, changed))
		row.add_child(option)
		row.add_child(_small_button("▲", "Move towards rank 1", _move_item.bind(object, name, i, -1), i > 0))
		row.add_child(_small_button("▼", "Move back", _move_item.bind(object, name, i, 1), i < value.size() - 1))
		row.add_child(_small_button("✕", "Remove", _remove_item.bind(object, name, i)))
		box.add_child(row)
	var footer := HBoxContainer.new()
	var add := _small_button("+ Add", "Add one", func() -> void:
		var grown: Array = object.get(name).duplicate()
		grown.append(grown.back() if not grown.is_empty() else choices[0])
		_change(object, name, grown), not choices.is_empty())
	footer.add_child(add)
	if class_title == &"UnitDef":
		var ranks := 0
		for unit: UnitDef in value:
			ranks += unit.size
		var fill := Label.new()
		fill.text = "fills %d of %d ranks" % [ranks, Rules.RANKS]
		fill.add_theme_color_override("font_color", UiStyle.DAMAGE if ranks > Rules.RANKS else UiStyle.TEXT_DIM)
		footer.add_child(fill)
	box.add_child(footer)
	return box


## Four toggles for ranks 1-4.
func _ranks_editor(object: Resource, name: StringName, value: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	for rank in range(1, Rules.RANKS + 1):
		var check := CheckBox.new()
		check.text = str(rank)
		check.button_pressed = rank in value
		check.toggled.connect(func(on: bool) -> void:
			var changed: Array = object.get(name).duplicate()
			if on and rank not in changed:
				changed.append(rank)
			elif not on:
				changed.erase(rank)
			changed.sort()
			_apply(object, name, changed))
		row.add_child(check)
	return row


## Comma-separated values, applied on Enter or leaving the field.
func _list_editor(object: Resource, name: StringName, value: Array) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = ", ".join(value.map(func(item: Variant) -> String: return str(item)))
	edit.placeholder_text = "comma-separated"
	var apply := func() -> void:
		var changed := value.duplicate()
		changed.clear()
		for part in edit.text.split(",", false):
			var text := part.strip_edges()
			match value.get_typed_builtin():
				TYPE_INT:
					changed.append(int(text))
				TYPE_FLOAT:
					changed.append(float(text))
				TYPE_STRING_NAME:
					changed.append(StringName(text))
				_:
					changed.append(text)
		_apply(object, name, changed)
	edit.text_submitted.connect(func(_text: String) -> void: apply.call())
	edit.focus_exited.connect(apply)
	return edit


## Key-value rows, like a trinket's stats. Each change starts from the field's
## current dictionary, as rows change it without rebuilding the form.
func _dictionary_editor(object: Resource, name: StringName, value: Dictionary) -> VBoxContainer:
	var box := VBoxContainer.new()
	var whole := value.get_typed_value_builtin() == TYPE_INT
	for key: Variant in value.keys():
		var row := HBoxContainer.new()
		var key_edit := LineEdit.new()
		key_edit.text = str(key)
		key_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var rename := func() -> void:
			var current: Dictionary = object.get(name)
			var new_key: Variant = StringName(key_edit.text.strip_edges())
			if value.get_typed_key_builtin() == TYPE_STRING:
				new_key = String(new_key)
			if new_key == key or current.has(new_key) or not current.has(key):
				return
			var changed := current.duplicate()
			changed.clear()
			for each: Variant in current:
				changed[new_key if each == key else each] = current[each]
			_change(object, name, changed)
		key_edit.text_submitted.connect(func(_text: String) -> void: rename.call())
		key_edit.focus_exited.connect(rename)
		row.add_child(key_edit)
		var spin := SpinBox.new()
		spin.step = 1.0 if whole else 0.001
		spin.custom_arrow_step = 1.0 if whole else 0.05
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.min_value = -100000
		spin.max_value = 100000
		spin.value = value[key]
		spin.select_all_on_focus = true
		spin.custom_minimum_size.x = 120
		spin.value_changed.connect(func(amount: float) -> void:
			var changed: Dictionary = object.get(name).duplicate()
			changed[key] = roundi(amount) if whole else amount
			_apply(object, name, changed))
		row.add_child(spin)
		row.add_child(_small_button("✕", "Remove", func() -> void:
			var changed: Dictionary = object.get(name).duplicate()
			changed.erase(key)
			_change(object, name, changed)))
		box.add_child(row)
	box.add_child(_small_button("+ Add", "Add an entry", func() -> void:
		var changed: Dictionary = object.get(name).duplicate()
		var key: Variant = StringName("new")
		if value.get_typed_key_builtin() == TYPE_STRING:
			key = "new"
		changed[key] = 0 if whole else 0.0
		_change(object, name, changed), not value.has(&"new")))
	return box


# --- Changes ---

func _apply(object: Resource, name: StringName, value: Variant) -> void:
	library.set_value(root, object, name, value)


## A change that alters the form's shape (adding, removing, relinking): rebuilds it after.
func _change(object: Resource, name: StringName, value: Variant) -> void:
	library.set_value(root, object, name, value)
	rebuild.call_deferred()


func _move_item(object: Resource, name: StringName, index: int, step: int) -> void:
	var changed: Array = object.get(name).duplicate()
	var item: Variant = changed[index]
	changed.remove_at(index)
	changed.insert(index + step, item)
	_change(object, name, changed)


func _copy_item(object: Resource, name: StringName, index: int) -> void:
	var changed: Array = object.get(name).duplicate()
	changed.insert(index + 1, changed[index].duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL))
	_change(object, name, changed)


func _remove_item(object: Resource, name: StringName, index: int) -> void:
	var changed: Array = object.get(name).duplicate()
	changed.remove_at(index)
	_change(object, name, changed)


# --- Helpers ---

func _is_default(object: Resource, name: StringName) -> bool:
	var script: Script = object.get_script()
	if not _blanks.has(script):
		_blanks[script] = script.new()
	var default: Variant = _blanks[script].get(name)
	var value: Variant = object.get(name)
	return typeof(default) == typeof(value) and default == value


## The class a typed array holds, like &"SkillDef", or &"" for built-in types.
func _typed_class(value: Array) -> StringName:
	var script: Script = value.get_typed_script()
	return script.get_global_name() if script else StringName(value.get_typed_class_name())


func _is_linked(resource: Resource) -> bool:
	var script: Script = resource.get_script()
	return script != null and script.get_global_name() in LINKED


static func _class_script(class_title: String) -> Script:
	for entry in ProjectSettings.get_global_class_list():
		if entry.class == class_title:
			return load(entry.path)
	return null


func _group_key(object: Resource, group: String) -> String:
	return "%d/%s" % [object.get_instance_id(), group]


func _field_key(object: Resource, name: StringName) -> String:
	return "%d.%s" % [object.get_instance_id(), name]


func _item_key(item: Resource) -> String:
	return str(item.get_instance_id())


## The ## comments above each exported field of `script`, read from its source.
static func _docs_for(script: Script) -> Dictionary:
	if script == null:
		return {}
	if not _docs.has(script):
		var result := {}
		var pending: Array[String] = []
		var field := RegEx.create_from_string("^@export\\S*(\\(.*\\))?\\s+var\\s+(\\w+)")
		for line in script.source_code.split("\n"):
			var text := line.strip_edges()
			if text.begins_with("##"):
				pending.append(text.trim_prefix("##").strip_edges())
				continue
			var found := field.search(text)
			if found and not pending.is_empty():
				result[StringName(found.get_string(2))] = " ".join(pending)
			pending.clear()
		_docs[script] = result
	return _docs[script]

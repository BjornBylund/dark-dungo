## The balance tool's Dialogue tab: a script picker, the script as text with
## its sections, conditions, speakers and placeholders coloured, and the
## problems Dialogue.problems() finds, checked as you type (click one to go to
## its line). Play shows the variant under the caret as the game plays it.
## Every edit goes through the library, so it undoes and saves like the rest.
class_name BalanceDialoguePanel
extends VBoxContainer

## The tool should show `resource` (a script) in its detail panel.
signal show_resource(resource: Resource)
## The tool should play `scene` over itself, as the town does.
signal play(scene: DialogueScene)

## Seconds after typing before the problems are checked again.
const CHECK_DELAY := 0.3

var library: BalanceLibrary
var shown: DialogueFile
var _picker: OptionButton
var _sections: OptionButton
var _where: Label
var _code: CodeEdit
var _highlighter: DialogueHighlighter
var _problems: ItemList
var _found: Array[Dictionary] = []
var _check_in := -1.0
## Set while the editor's text is put back from the library, so it isn't sent back as an edit.
var _syncing := false


func _init(content: BalanceLibrary) -> void:
	library = content
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 6)
	_build()
	library.edited.connect(_on_edited)


func _process(delta: float) -> void:
	if _check_in >= 0.0:
		_check_in -= delta
		if _check_in < 0.0:
			_check()


## Shows `file` in the editor.
func show_script(file: DialogueFile) -> void:
	if file == shown:
		return
	shown = file
	_syncing = true
	_code.text = shown.text
	_code.clear_undo_history()
	_syncing = false
	_code.set_caret_line(0)
	_refresh_picker()
	_check()


# --- Building ---

func _build() -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	add_child(bar)
	bar.add_child(_label("Script"))
	_picker = OptionButton.new()
	_picker.custom_minimum_size.x = 220
	_picker.item_selected.connect(func(index: int) -> void: show_resource.emit(library.dialogues[index]))
	bar.add_child(_picker)
	bar.add_child(_label("Go to"))
	_sections = OptionButton.new()
	_sections.custom_minimum_size.x = 160
	_sections.item_selected.connect(func(index: int) -> void: _go_to(_sections.get_item_id(index)))
	bar.add_child(_sections)
	var play_button := Button.new()
	play_button.text = "▶ Play"
	play_button.tooltip_text = "Play the variant the caret is in, as the game would (placeholders filled with examples)"
	play_button.focus_mode = Control.FOCUS_NONE
	play_button.add_theme_color_override("font_color", UiStyle.GOLD)
	play_button.pressed.connect(_play)
	bar.add_child(play_button)
	_where = _label("")
	_where.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_where.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	bar.add_child(_where)

	_code = CodeEdit.new()
	_code.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_code.gutters_draw_line_numbers = true
	_code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_code.indent_use_spaces = false
	_code.add_theme_font_size_override("font_size", 16)
	_code.add_theme_color_override("background_color", Color("121317"))
	_code.add_theme_color_override("font_color", UiStyle.TEXT)
	_highlighter = DialogueHighlighter.new()
	_highlighter.speakers[Dialogue.NARRATOR] = UiStyle.GOLD
	_code.syntax_highlighter = _highlighter
	_code.text_changed.connect(_on_typed)
	_code.caret_changed.connect(_show_where)
	add_child(_code)

	_problems = ItemList.new()
	_problems.custom_minimum_size.y = 130
	_problems.add_theme_color_override("font_color", UiStyle.TEXT)
	_problems.item_selected.connect(func(index: int) -> void:
		var line: int = _found[index].line if index < _found.size() else -1
		if line >= 0:
			_go_to(line))
	add_child(_problems)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


# --- Editing ---

func _on_typed() -> void:
	if _syncing or shown == null:
		return
	library.set_value(shown, shown, &"text", _code.text)
	_check_in = CHECK_DELAY


## Undo and redo put the library's text back in the editor, near where the caret was.
func _on_edited(roots: Array[Resource], from_history: bool) -> void:
	_refresh_picker()
	if shown == null or shown not in roots or not from_history or _code.text == shown.text:
		return
	var line := _code.get_caret_line()
	_syncing = true
	_code.text = shown.text
	_syncing = false
	_code.set_caret_line(mini(line, _code.get_line_count() - 1))
	_check()


func _go_to(line: int) -> void:
	_code.set_caret_line(line)
	_code.set_caret_column(0)
	_code.center_viewport_to_caret()
	_code.grab_focus()


# --- Checking ---

## Lists the script's problems and tints their lines, and fills the section list.
func _check() -> void:
	_check_in = -1.0
	if shown == null:
		return
	for hero in library.heroes:
		_highlighter.speakers[hero.display_name] = hero.color.lerp(Color.WHITE, 0.45)
	for line in _code.get_line_count():
		_code.set_line_background_color(line, Color(0, 0, 0, 0))
	_found = Dialogue.problems(_code.text, library.dialogue_context(shown))
	_problems.clear()
	for problem in _found:
		var where := "Line %d: " % (problem.line + 1) if problem.line >= 0 else "Script: "
		_problems.add_item(where + problem.text)
		_problems.set_item_custom_fg_color(_problems.item_count - 1, DialogueHighlighter.WRONG)
		if problem.line >= 0:
			_code.set_line_background_color(problem.line, Color(DialogueHighlighter.WRONG, 0.16))
	if _found.is_empty():
		_problems.add_item("No problems: every section it needs is there, and every line checks out.")
		_problems.set_item_custom_fg_color(0, UiStyle.PALE_GREEN)
		_problems.set_item_selectable(0, false)
	_sections.clear()
	var lines := _code.text.split("\n")
	for i in lines.size():
		if lines[i].strip_edges().begins_with("=="):
			_sections.add_item(lines[i].strip_edges().trim_prefix("==").strip_edges(), i)
	_refresh_picker()
	_show_where()


func _refresh_picker() -> void:
	_picker.clear()
	for each in library.dialogues:
		var mark := "● " if library.is_unsaved(each) else ""
		_picker.add_item(mark + each.display_name)
	_picker.select(library.dialogues.find(shown))


## The section and variant the caret is in, beside the buttons.
func _show_where() -> void:
	var found := _at_caret()
	if found.is_empty():
		_where.text = ""
		return
	var conditions: Array = found.variant.conditions
	_where.text = "%s, %s" % [found.section, "? " + ", ".join(conditions) if not conditions.is_empty()
			else "lines that always play"]
	for i in _sections.item_count:
		if _sections.get_item_text(i) == found.section:
			_sections.select(i)


## {section, variant} holding the caret line, or empty outside any section.
func _at_caret() -> Dictionary:
	var caret := _code.get_caret_line()
	var lines := _code.text.split("\n")
	var section := ""
	for i in range(mini(caret, lines.size() - 1), -1, -1):
		if lines[i].strip_edges().begins_with("=="):
			section = lines[i].strip_edges().trim_prefix("==").strip_edges()
			break
	var variants: Array = Dialogue.parse(_code.text).get(section, [])
	if variants.is_empty():
		return {}
	var variant: Dictionary = variants[0]
	for each: Dictionary in variants:
		if each.at <= caret:
			variant = each
	return {section = section, variant = variant}


# --- Playing ---

## The variant under the caret as a scene, its placeholders filled with
## examples: the first region and its boss, the next region opened, another hero.
func _play() -> void:
	var found := _at_caret()
	if found.is_empty():
		return
	var regions := library.campaign.regions
	var region: RegionDef = regions[0] if not regions.is_empty() else null
	var other := library.heroes.filter(func(hero: UnitDef) -> bool: return hero != shown.hero)
	var other_name: String = other[0].display_name if not other.is_empty() else "Crusader"
	var values := {
		"region": Dialogue.mid_sentence(region.display_name) if region else "the Graveyard",
		"boss": Dialogue.mid_sentence(region.boss.display_name) if region and region.boss else "the Gravelord",
		"opened": Dialogue.mid_sentence(regions[1].display_name) if regions.size() > 1 else "the Burrows",
		"week": "4", "fallen": other_name, "partner": other_name,
	}
	var conditions: Array = found.variant.conditions
	var scene := DialogueScene.new("%s%s" % [found.section, ", ? " + ", ".join(conditions) if not conditions.is_empty() else ""])
	for line: Array in found.variant.lines:
		if line[0] == Dialogue.NARRATOR:
			scene.add_line(null, Dialogue.fill(line[1], values))
			continue
		for hero in library.heroes:
			if hero.display_name == line[0]:
				scene.add_line(hero, Dialogue.fill(line[1], values))
	if not scene.is_empty():
		play.emit(scene)

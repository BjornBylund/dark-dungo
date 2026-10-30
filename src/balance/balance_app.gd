## The balance tool: tables of every hero, enemy, encounter and trinket with
## their numbers on paper and what the last sweep of simulated fights found,
## and a form to edit the selected one. Opened with `-- --balance`, or from the
## title screen when running from the project folder. Ctrl+S saves, Ctrl+Z and
## Ctrl+Y undo and redo.
extends Control

enum Tab { HEROES, ENEMIES, ENCOUNTERS, TRINKETS, ARENA }

const TAB_NAMES := ["Heroes", "Enemies", "Encounters", "Trinkets", "Arena"]
const TAB_KINDS := [BalanceLibrary.Kind.HERO, BalanceLibrary.Kind.ENEMY, BalanceLibrary.Kind.ENCOUNTER,
		BalanceLibrary.Kind.TRINKET]
const KIND_NAMES := {
	BalanceLibrary.Kind.HERO: "Hero", BalanceLibrary.Kind.ENEMY: "Enemy",
	BalanceLibrary.Kind.ENCOUNTER: "Encounter", BalanceLibrary.Kind.TRINKET: "Trinket",
	BalanceLibrary.Kind.OTHER: "Settings",
}
## Encounter filter: [label, the end of the role it matches ("" for all, "-" for none)].
const ROLE_FILTERS := [["All", ""], ["Fights", "fights"], ["Elites", "elites"], ["Finales", "finales"],
		["Bosses", "boss"], ["Sandbox", "Sandbox wave"], ["Unused", "-"]]
const RESIST_TITLES := {
	&"stun": "STN", &"bleed": "BLD", &"blight": "BLGT", &"burn": "BURN", &"move": "MOV", &"debuff": "DBFF",
	&"deathblow": "DTH", &"stress": "STR",
}
const BACKGROUND := Color("16171b")
const PANEL := Color("1d1f24")
const NOTES := "Numbers on paper: base heroes (level 0, rank-1 skills, the first 5 skills; dim ones sit out) " \
		+ "against Apprentice enemies, over a %d-round fight. Resisted effects use the other side's average " \
		+ "resistance; effects that need a token (like Stun vs Combo) don't count; per-round heal and stress " \
		+ "assume every turn goes to it. Hover a cell for its rank. Ctrl+S saves, Ctrl+Z / Ctrl+Y undo and redo."
## How often the progress of a running sweep is read, in seconds.
const POLL_EVERY := 0.25

var library := BalanceLibrary.new()
var _tab := Tab.HEROES
var _table: BalanceTable
var _filters: Control
var _arena: BalanceArenaPanel
var _search: LineEdit
var _role_filter: OptionButton
var _form_scroll: ScrollContainer
var _form: ResourceForm
var _title: Label
var _info: RichTextLabel
var _duplicate: Button
var _listing: MenuButton
var _undo: Button
var _redo: Button
var _save: Button
var _preset_pick: OptionButton
var _size_pick: OptionButton
var _run: Button
var _pin: Button
var _progress: Label
var _status: Label
var _refresh_timer: Timer
## The sweep running now, the last one's results, and the pinned ones.
var _sweep: BalanceSweep
var _results: BalanceSweep.Results
var _pinned: BalanceSweep.Results
var _poll := 0.0
## The result cells for the rows being built.
var _found: BalanceResultColumns
## The content file shown in the form.
var _current: Resource
## Per tab, the row last selected.
var _selected := {}
## Root instance id -> its form's open sections.
var _open := {}
var _status_note := ""


func _ready() -> void:
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.mode = Window.MODE_MAXIMIZED
	window.title = "Darko Dungo: Balance"
	get_tree().auto_accept_quit = false
	theme = _make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	column.add_child(_make_toolbar())
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(split)
	split.add_child(_make_table_side())
	split.add_child(_make_detail_side())
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_status.add_theme_font_size_override("font_size", 13)
	column.add_child(_status)
	_refresh_timer = Timer.new()
	_refresh_timer.one_shot = true
	_refresh_timer.wait_time = 0.12
	_refresh_timer.timeout.connect(_refresh)
	add_child(_refresh_timer)
	library.edited.connect(_on_edited)
	_switch_tab(Tab.HEROES)


func _exit_tree() -> void:
	if _sweep:
		_sweep.cancel()
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().title = ProjectSettings.get_setting("application/config/name")
	get_tree().auto_accept_quit = true


func _make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 15
	result.set_color("font_color", "Label", UiStyle.TEXT)
	result.set_stylebox("panel", "PanelContainer", UiStyle.box(PANEL, Color("2c2f36"), 1, 4))
	result.set_constant("v_separation", "Tree", 2)
	result.set_font_size("title_button_font_size", "Tree", 13)
	# The default unchecked box is too faint on these dark panels.
	var box := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for i in 16:
		for edge in [0, 15]:
			box.set_pixel(i, edge, UiStyle.GREY)
			box.set_pixel(edge, i, UiStyle.GREY)
	result.set_icon("unchecked", "CheckBox", ImageTexture.create_from_image(box))
	return result


# --- Layout ---

func _make_toolbar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "Balance"
	title.add_theme_font_override("font", UiStyle.DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	bar.add_child(title)
	var tabs := TabBar.new()
	for name: String in TAB_NAMES:
		tabs.add_tab(name)
	tabs.tab_changed.connect(func(index: int) -> void: _switch_tab(index as Tab))
	tabs.clip_tabs = false
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(tabs)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	bar.add_child(_make_sweep_controls())
	bar.add_child(VSeparator.new())
	_undo = _tool_button("Undo", "Ctrl+Z", _do_undo)
	_redo = _tool_button("Redo", "Ctrl+Y", _do_redo)
	_save = _tool_button("Save", "Ctrl+S: write every changed file", _do_save)
	for button in [_undo, _redo, _save, _tool_button("Back to the title", "", _leave.bind(Game.go_to_menu))]:
		bar.add_child(button)
	return bar


## The preset, Quick or Thorough, Run, Pin, the targets, and the progress of a run.
func _make_sweep_controls() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_progress = Label.new()
	_progress.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_progress)
	_preset_pick = OptionButton.new()
	_preset_pick.tooltip_text = "The heroes' level, gear, skill ranks and trinkets, and the enemies' tier"
	_preset_pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_preset_pick)
	_size_pick = OptionButton.new()
	_size_pick.add_item("Quick")
	_size_pick.add_item("Thorough")
	_size_pick.tooltip_text = "Thorough plays %d times as many fights, for narrower margins of error" \
			% BalanceSweep.THOROUGH_SCALE
	_size_pick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_size_pick)
	_run = _tool_button("▶ Run", "Simulate what's on screen, saved or not", _toggle_run)
	_run.add_theme_color_override("font_color", UiStyle.GOLD)
	row.add_child(_run)
	_pin = _tool_button("Pin", "Keep these results to compare later runs with (vs pin)", _pin_results)
	row.add_child(_pin)
	row.add_child(_tool_button("Targets", "Edit the presets and targets", func() -> void: _show(library.targets)))
	_refresh_presets()
	return row


func _refresh_presets() -> void:
	var chosen := _preset_pick.get_item_text(_preset_pick.selected) if _preset_pick.selected >= 0 else "Base"
	_preset_pick.clear()
	for preset in library.targets.presets:
		_preset_pick.add_item(preset.name)
		if preset.name == chosen:
			_preset_pick.select(_preset_pick.item_count - 1)
	if _preset_pick.selected < 0 and _preset_pick.item_count > 0:
		_preset_pick.select(0)


func _tool_button(text: String, tooltip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	return button


func _make_table_side() -> Control:
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 1.5
	var filters := HBoxContainer.new()
	_search = LineEdit.new()
	_search.placeholder_text = "Search by name"
	_search.clear_button_enabled = true
	_search.custom_minimum_size.x = 260
	_search.text_changed.connect(func(_text: String) -> void: _refresh())
	filters.add_child(_search)
	_role_filter = OptionButton.new()
	for filter: Array in ROLE_FILTERS:
		_role_filter.add_item(filter[0])
	_role_filter.item_selected.connect(func(_index: int) -> void: _refresh())
	filters.add_child(_role_filter)
	side.add_child(filters)
	_filters = filters
	_table = BalanceTable.new()
	_table.row_selected.connect(_show)
	side.add_child(_table)
	_arena = BalanceArenaPanel.new(library)
	_arena.show_resource.connect(_show)
	_arena.watch.connect(_open_watch)
	_arena.hide()
	side.add_child(_arena)
	return side


func _make_detail_side() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 560
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	panel.add_child(column)
	_title = Label.new()
	_title.add_theme_font_override("font", UiStyle.DISPLAY_FONT)
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", UiStyle.GOLD)
	column.add_child(_title)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = true
	_info.add_theme_font_size_override("normal_font_size", 14)
	column.add_child(_info)
	var buttons := HBoxContainer.new()
	_duplicate = _tool_button("Duplicate", "Add a copy with its own id, to make a new one from", _duplicate_current)
	buttons.add_child(_duplicate)
	_listing = MenuButton.new()
	_listing.text = "List in campaign ▾"
	_listing.flat = false
	_listing.tooltip_text = "Where the game uses it"
	_listing.get_popup().hide_on_checkable_item_selection = false
	_listing.get_popup().id_pressed.connect(_toggle_listing)
	buttons.add_child(_listing)
	column.add_child(buttons)
	column.add_child(HSeparator.new())
	_form_scroll = ScrollContainer.new()
	_form_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_form_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_form_scroll)
	return panel


# --- Tabs and rows ---

func _switch_tab(tab: Tab) -> void:
	_tab = tab
	_filters.visible = tab != Tab.ARENA
	_table.visible = tab != Tab.ARENA
	_arena.visible = tab == Tab.ARENA
	if tab == Tab.ARENA:
		_refresh()
		var first := _arena.arena.slots.filter(func(slot: Dictionary) -> bool: return slot.hero != null)
		if _current == null and not first.is_empty():
			_show(first[0].hero)
		return
	_role_filter.visible = tab == Tab.ENCOUNTERS
	_table.set_column_defs(_columns())
	_refresh()
	var selected: Resource = _selected.get(tab)
	var list := library.list_of(TAB_KINDS[tab])
	if selected == null and not list.is_empty():
		selected = list[0]
	_table.select_resource(selected)
	_show(selected)


func _refresh() -> void:
	_found = BalanceResultColumns.new(library, _results, _pinned)
	match _tab:
		Tab.HEROES:
			_table.show_rows(_unit_rows(library.heroes, true))
		Tab.ENEMIES:
			_table.show_rows(_unit_rows(library.enemies, false))
		Tab.ENCOUNTERS:
			_table.show_rows(_encounter_rows())
		Tab.TRINKETS:
			_table.show_rows(_trinket_rows())
	_refresh_header()
	_refresh_toolbar()


func _columns() -> Array[Dictionary]:
	var stress_tip := "Stress relieved per round (negative), if every turn went to it." if _tab == Tab.HEROES \
			else "Stress dealt per round, if every turn went to it."
	var columns: Array[Dictionary] = [{title = "Name", width = 230}]
	# What the last sweep found comes first, then the numbers on paper.
	match _tab:
		Tab.HEROES:
			columns.append_array(BalanceResultColumns.hero_columns())
		Tab.ENEMIES:
			columns.append_array(BalanceResultColumns.enemy_columns())
		Tab.ENCOUNTERS:
			columns.append_array(BalanceResultColumns.encounter_columns())
		Tab.TRINKETS:
			columns.append_array(BalanceResultColumns.trinket_columns())
	match _tab:
		Tab.HEROES, Tab.ENEMIES:
			columns.append_array([
				{title = "HP", width = 50, better = 1, tip = "Max HP"},
				{title = "Spd", width = 46, better = 1, tip = "Speed"},
				{title = "Size", width = 44, tip = "Ranks it fills"},
				{title = "Dmg", width = 62, tip = "Skill: its damage roll"},
				{title = "Crit", width = 50, better = 1, tip = "Skill: crit chance"},
				{title = "CD", width = 52, better = -1, tip = "Skill: cooldown in turns, ×uses per battle"},
				{title = "Turn", width = 58, better = 1,
						tip = "Unit: the most expected damage in one turn.\nSkill: expected damage per use, over every "
						+ "target, with crits and DoTs."},
				{title = "Dmg/rd", width = 66, better = 1,
						tip = "Expected damage per round over a %d-round fight, counting cooldowns and use limits.\n" \
						% BalanceStats.ROUNDS + "A unit uses its best ready skill each turn."},
				{title = "DoT", width = 50, better = 1, tip = "Skill: expected DoT damage per use, after resistance"},
				{title = "Heal/rd", width = 66, better = 1, tip = "HP healed per round, if every turn went to it"},
				{title = "Stress/rd", width = 74, better = -1 if _tab == Tab.HEROES else 1, tip = stress_tip},
				{title = "Stun", width = 52, better = 1, tip = "Best chance a stun sticks, past the average stun resist"},
				{title = "Move", width = 52, better = 1, tip = "Best chance a push or pull sticks, past the average move resist"},
				{title = "Ranks", width = 100, tip = "Ranks it acts from → ranks it reaches"},
			])
			for kind: StringName in BalanceStats.RESISTS:
				columns.append({title = RESIST_TITLES[kind], width = 50, better = 1,
						tip = "%s resist" % ("Death blow" if kind == &"deathblow" else String(kind).capitalize())})
		Tab.ENCOUNTERS:
			columns.append_array([
				{title = "Role", width = 220, tip = "Where the game uses it"},
				{title = "Enemies", width = 300},
				{title = "Ranks", width = 56, tip = "Ranks filled, of 4"},
				{title = "HP", width = 56, better = 1, tip = "Total HP"},
				{title = "Turn", width = 58, better = 1, tip = "Each enemy's most expected damage in one turn, added up"},
				{title = "Dmg/rd", width = 66, better = 1, tip = "Expected damage per round, added up"},
				{title = "Stress/rd", width = 74, better = 1, tip = "Stress per round, added up"},
				{title = "Stun", width = 52, better = 1, tip = "Best chance a stun sticks"},
				{title = "Spd", width = 50, better = 1, tip = "Average speed"},
			])
		Tab.TRINKETS:
			columns.append_array([
				{title = "Rarity", width = 92},
				{title = "Class", width = 110},
				{title = "Price", width = 66},
				{title = "Boss", width = 50, tip = "Only region bosses give it"},
				{title = "Listed", width = 60, tip = "In the campaign's trinket list"},
				{title = "Effects", width = 400, expand = true},
			])
	return columns


func _matches(resource: Resource) -> bool:
	var text := _search.text.strip_edges().to_lower()
	if text == "":
		return true
	if text in str(resource.get(&"display_name")).to_lower():
		return true
	if resource is UnitDef:
		return resource.skills.any(func(skill: SkillDef) -> bool: return text in skill.display_name.to_lower())
	if resource is EncounterDef:
		return resource.enemies.any(func(enemy: UnitDef) -> bool: return text in enemy.display_name.to_lower())
	return false


func _unit_rows(units: Array[UnitDef], heroes: bool) -> Array[Dictionary]:
	var versus := _versus(heroes)
	var rows: Array[Dictionary] = []
	for unit in units:
		if not _matches(unit):
			continue
		var row := _unit_row(unit, heroes, versus)
		var children: Array[Dictionary] = []
		for i in unit.skills.size():
			children.append(_skill_row(unit.skills[i], unit, versus, heroes and i >= Rules.SKILL_SLOTS))
		row.children = children
		rows.append(row)
	return rows


func _versus(heroes: bool) -> BalanceStats.Versus:
	return BalanceStats.versus(library.heroes, library.enemies) if heroes \
			else BalanceStats.versus(library.enemies, library.heroes)


func _unit_row(unit: UnitDef, is_hero: bool, versus: BalanceStats.Versus) -> Dictionary:
	var numbers := BalanceStats.unit(unit, is_hero, versus)
	var cells: Array = [_name_cell(unit)]
	cells.append_array(_found.hero_cells(unit) if is_hero else _found.enemy_cells(unit))
	cells.append_array([
		_num(unit.max_hp, 0), _num(unit.speed, 0), _num(unit.size, 0), null, null, null,
		_num(numbers.turn), _num(numbers.damage_rd), null, _num(numbers.heal_rd), _num(numbers.stress_rd),
		_pct(numbers.stun), _pct(numbers.move),
		_text(BalanceStats.unit_ranks_text(BalanceStats.fighting_skills(unit, is_hero))),
	])
	for kind in BalanceStats.RESISTS:
		cells.append(_pct(unit.base_resist(kind)))
	return {resource = unit, cells = cells, children = []}


func _skill_row(skill: SkillDef, unit: UnitDef, versus: BalanceStats.Versus, sits_out: bool) -> Dictionary:
	var n := BalanceStats.skill(skill, versus, unit.max_hp)
	var damage: Variant = null
	var crit: Variant = null
	if skill.deals_damage():
		damage = {value = n.average, text = "%d–%d" % [skill.damage_min, skill.damage_max]}
		if skill.damage_from_dots > 0.0:
			damage = {value = 0.0, text = "DoTs", tip = "%s of the target's DoTs" % UiStyle.percent(skill.damage_from_dots)}
		crit = _pct(skill.crit_chance)
	var cooldown: Variant = null
	if skill.cooldown > 0 or skill.uses_per_battle > 0:
		var uses := " ×%d" % skill.uses_per_battle if skill.uses_per_battle > 0 else ""
		cooldown = {value = float(skill.cooldown), text = "%d%s" % [skill.cooldown, uses]}
	var name := {value = skill.display_name, text = "    " + skill.display_name,
			tip = UiStyle.plain(UiStyle.skill_bbcode(skill))}
	if sits_out:
		name.tip = "Not among the first %d skills, so left out of the hero's numbers.\n\n%s" % [Rules.SKILL_SLOTS, name.tip]
	var cells: Array = [name]
	cells.append_array(_found.hero_skill_cells(skill) if _tab == Tab.HEROES else _found.enemy_skill_cells(skill))
	cells.append_array([
		null, null, null, damage, crit, cooldown,
		_num_or_blank(n.damage), _num_or_blank(n.damage_rd), _num_or_blank(n.dot), _num_or_blank(n.heal_rd),
		_num_or_blank(n.stress_rd), _pct_or_blank(n.stun), _pct_or_blank(n.move), _text(BalanceStats.ranks_text(skill)),
	])
	return {resource = skill, cells = cells, children = [], dim = sits_out}


func _encounter_rows() -> Array[Dictionary]:
	var versus := _versus(false)
	var filter: String = ROLE_FILTERS[_role_filter.selected][1]
	var rows: Array[Dictionary] = []
	for encounter in library.encounters:
		var roles := library.roles_of(encounter)
		var shown := filter == "" or (filter == "-" and roles.is_empty()) \
				or roles.any(func(role: String) -> bool: return role.ends_with(filter))
		if not shown or not _matches(encounter):
			continue
		var totals := {hp = 0.0, turn = 0.0, damage_rd = 0.0, stress_rd = 0.0, stun = 0.0, speed = 0.0, ranks = 0}
		var children: Array[Dictionary] = []
		for enemy in encounter.enemies:
			var n := BalanceStats.unit(enemy, false, versus)
			totals.hp += enemy.max_hp
			totals.turn += n.turn
			totals.damage_rd += n.damage_rd
			totals.stress_rd += n.stress_rd
			totals.stun = maxf(totals.stun, n.stun)
			totals.speed += enemy.speed
			totals.ranks += enemy.size
			var enemy_cells: Array = [{value = enemy.display_name, text = "    " + enemy.display_name}]
			enemy_cells.resize(1 + BalanceResultColumns.encounter_columns().size())
			enemy_cells.append_array([
				null, null, _num(enemy.size, 0), _num(enemy.max_hp, 0), _num(n.turn), _num(n.damage_rd),
				_num(n.stress_rd), _pct(n.stun), _num(enemy.speed, 0),
			])
			children.append({resource = enemy, children = [], cells = enemy_cells})
		var count := maxi(1, encounter.enemies.size())
		var lineup := ", ".join(encounter.enemies.map(func(enemy: UnitDef) -> String: return enemy.display_name))
		var role_text := ", ".join(roles) if not roles.is_empty() else "unused"
		var cells: Array = [_name_cell(encounter)]
		cells.append_array(_found.encounter_cells(encounter))
		cells.append_array([
			_text(role_text), _text(lineup),
			{value = float(totals.ranks), text = "%d/%d" % [totals.ranks, Rules.RANKS],
					tip = "Too many for the battlefield!" if totals.ranks > Rules.RANKS else ""},
			_num(totals.hp, 0), _num(totals.turn), _num(totals.damage_rd), _num(totals.stress_rd), _pct(totals.stun),
			_num(totals.speed / count),
		])
		rows.append({resource = encounter, children = children, dim = roles.is_empty(), cells = cells})
	return rows


func _trinket_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for trinket in library.trinkets:
		if not _matches(trinket):
			continue
		var effects := "; ".join(UiStyle.perk_effects(trinket).map(func(line: Array) -> String: return line[0]))
		var listed := trinket in library.campaign.trinkets
		var cells: Array = [_name_cell(trinket)]
		cells.append_array(_found.trinket_cells(trinket))
		cells.append_array([
			{value = float(trinket.rarity), text = CampaignRules.RARITY_NAMES[trinket.rarity], left = true},
			_text(trinket.hero.display_name if trinket.hero else "any"),
			_num(trinket.price, 0), _centered("yes" if trinket.boss_only else ""), _centered("yes" if listed else "no"),
			{value = effects, text = effects, tip = effects.replace("; ", "\n")},
		])
		rows.append({resource = trinket, children = [], dim = not listed, cells = cells})
	return rows


func _name_cell(resource: Resource) -> Dictionary:
	var name: String = resource.get(&"display_name")
	var mark := "● " if library.is_unsaved(resource) else ""
	var path := resource.resource_path.trim_prefix("res://") if resource.resource_path != "" else "new, not saved yet"
	return {value = name, text = mark + name, tip = path + ("\nUnsaved changes" if mark != "" else "")}


func _text(text: String) -> Dictionary:
	return {value = text, text = text}


func _centered(text: String) -> Dictionary:
	return {value = text, text = text, center = true}


func _num(value: float, decimals: int = 1) -> Dictionary:
	if is_zero_approx(value):
		value = 0.0
	return {value = value, text = String.num(value, decimals) if decimals > 0 else str(roundi(value))}


func _num_or_blank(value: float) -> Variant:
	return _num(value) if not is_zero_approx(value) else null


func _pct(value: float) -> Dictionary:
	return {value = value, text = UiStyle.percent(value)}


func _pct_or_blank(value: float) -> Variant:
	return _pct(value) if value > 0.0 else null


# --- The selected file ---

## Shows `resource` in the form: a content file, or a skill (in its unit's form).
func _show(resource: Resource) -> void:
	var nested: Resource = null
	if resource is SkillDef:
		nested = resource
		resource = _owner_of(resource)
	if resource == null:
		return
	if library.kind_of(resource) != BalanceLibrary.Kind.OTHER:
		_selected[_tab] = nested if nested else resource
	if resource != _current or _form == null:
		_current = resource
		if _form:
			_form_scroll.remove_child(_form)
			_form.queue_free()
		_form = ResourceForm.new(library, resource, _open.get_or_add(resource.get_instance_id(), {}))
		_form_scroll.add_child(_form)
	_refresh_header()
	if nested:
		var section := _form.reveal(nested)
		if section:
			await get_tree().process_frame
			await get_tree().process_frame
			if is_instance_valid(section):
				_form_scroll.ensure_control_visible(section)


func _owner_of(skill: SkillDef) -> UnitDef:
	for unit: UnitDef in library.heroes + library.enemies:
		if skill in unit.skills:
			return unit
	return null


func _refresh_header() -> void:
	if _current == null:
		return
	var kind := library.kind_of(_current)
	_title.text = _current.get(&"display_name") if &"display_name" in _current else "Presets and targets"
	var lines: Array[String] = []
	var file := _current.resource_path.trim_prefix("res://") if _current.resource_path != "" else "new, not saved yet"
	lines.append("[color=#%s]%s · %s%s[/color]" % [UiStyle.TEXT_DIM.to_html(false), KIND_NAMES.get(kind, ""), file,
			" · unsaved changes" if library.is_unsaved(_current) else ""])
	var listings := library.listings(_current)
	if kind == BalanceLibrary.Kind.ENEMY:
		var places := library.encounters_with(_current).map(func(e: EncounterDef) -> String: return e.display_name)
		lines.append("In: " + (", ".join(places) if not places.is_empty() else "no encounter yet"))
	elif not listings.is_empty():
		var on := listings.filter(func(l: Dictionary) -> bool: return l.on).map(func(l: Dictionary) -> String:
			return l.label)
		if kind == BalanceLibrary.Kind.ENCOUNTER and _current in library.sandbox.waves:
			on.append("Sandbox wave")
		lines.append("Listed in: " + (", ".join(on) if not on.is_empty()
				else "[color=#%s]nowhere, so the game doesn't use it[/color]" % UiStyle.AMBER.to_html(false)))
	_info.text = "\n".join(lines)
	_duplicate.disabled = kind == BalanceLibrary.Kind.OTHER
	_listing.visible = not listings.is_empty()
	var popup := _listing.get_popup()
	popup.clear()
	for i in listings.size():
		popup.add_check_item(listings[i].label, i)
		popup.set_item_checked(i, listings[i].on)


func _toggle_listing(index: int) -> void:
	var listing: Dictionary = library.listings(_current)[index]
	library.set_listed(_current, listing, not listing.on)


func _duplicate_current() -> void:
	if _current == null:
		return
	var copy := library.duplicate_root(_current)
	_refresh()
	_table.select_resource(copy)
	_show(copy)


func _refresh_toolbar() -> void:
	var count := library.unsaved().size()
	_save.text = "Save (%d)" % count if count > 0 else "Save"
	_save.disabled = count == 0
	_undo.disabled = not library.history.has_undo()
	_redo.disabled = not library.history.has_redo()
	_run.text = "■ Stop" if _sweep else "▶ Run"
	_pin.disabled = _results == null or _sweep != null
	var lines: Array[String] = []
	if _status_note != "":
		lines.append(_status_note)
	if _results:
		var run := "Results: %s at %s, %s fights in %d s." % [BalanceSweep.SIZE_NAMES[_results.size], _results.preset.name,
				UiStyle.gold_text(_results.played), roundi(_results.seconds)]
		if _found.stale:
			run += " Greyed: edited since, so out of date; run again."
		if _pinned:
			run += " Compared with the pinned %s run at %s." % [BalanceSweep.SIZE_NAMES[_pinned.size], _pinned.preset.name]
		lines.append(run)
	elif not _sweep:
		lines.append("Press ▶ Run to simulate fights and fill the result columns.")
	lines.append(NOTES % BalanceStats.ROUNDS)
	_status.text = "  ".join(lines)


# --- Sweeps ---

func _toggle_run() -> void:
	if _sweep:
		_sweep.cancel()
		_sweep = null
		_progress.text = ""
		_status_note = "Run stopped."
		_refresh()
		return
	get_viewport().gui_release_focus()
	var preset := library.targets.preset_named(_preset_pick.get_item_text(_preset_pick.selected))
	_sweep = BalanceSweep.of(library, preset, _size_pick.selected as BalanceSweep.Size)
	_sweep.start()
	_status_note = ""
	_poll = 0.0
	_refresh_toolbar()


func _process(delta: float) -> void:
	if _sweep == null:
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL_EVERY
	if not _sweep.is_finished():
		_progress.text = "%s / %s fights" % [UiStyle.gold_text(_sweep.done_count()), UiStyle.gold_text(_sweep.fight_count())]
		return
	_results = _sweep.results()
	_sweep = null
	_progress.text = ""
	if _results.played < _results.fights:
		_status_note = "Only %d of %d fights came back; a worker may have failed." % [_results.played, _results.fights]
	_refresh()


## Opens the Arena's fight in the real combat screen over the tool, which stays
## as it is (unsaved edits and all) until the screen closes.
func _open_watch(bot_plays: bool) -> void:
	get_viewport().gui_release_focus()
	_arena.arena.bot_plays = bot_plays
	_arena.paused = true
	var screen: Control = load(Game.BATTLE).instantiate()
	screen.arena = _arena.arena
	screen.closed.connect(func() -> void: _arena.paused = false)
	add_child(screen)


func _pin_results() -> void:
	_pinned = _results
	_status_note = "Pinned. Later runs show their change against it in the vs pin columns."
	_refresh()


# --- Changes ---

func _on_edited(roots: Array[Resource], from_history: bool) -> void:
	_refresh_timer.start()
	if library.targets in roots:
		_refresh_presets()
	if not from_history:
		return
	if _current and _current not in library.roots():
		_current = null
	if _current == null:
		var list := library.list_of(TAB_KINDS[_tab]) if _tab != Tab.ARENA else library.heroes
		_show(list[0] if not list.is_empty() else null)
	elif _current in roots and _form:
		_form.rebuild()


func _do_undo() -> void:
	get_viewport().gui_release_focus()
	library.undo()


func _do_redo() -> void:
	get_viewport().gui_release_focus()
	library.redo()


func _do_save() -> void:
	get_viewport().gui_release_focus()
	var count := library.unsaved().size()
	var error := library.save()
	_status_note = "Saved %d file%s." % [count, "" if count == 1 else "s"] if error == OK \
			else "Saving failed: %s" % error_string(error)
	_refresh()


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not key.is_command_or_control_pressed():
		return
	match key.keycode:
		KEY_S:
			_do_save()
		KEY_Z:
			if key.shift_pressed:
				_do_redo()
			else:
				_do_undo()
		KEY_Y:
			_do_redo()
		_:
			return
	get_viewport().set_input_as_handled()


# --- Leaving ---

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_leave(get_tree().quit)


## Runs `then` (go to the title, quit), asking first about unsaved changes.
func _leave(then: Callable) -> void:
	var count := library.unsaved().size()
	if count == 0:
		then.call()
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "Unsaved changes"
	dialog.dialog_text = "%d file%s changed since the last save." % [count, "" if count == 1 else "s"]
	dialog.ok_button_text = "Save"
	dialog.cancel_button_text = "Cancel"
	dialog.add_button("Discard", true, "discard")
	dialog.confirmed.connect(func() -> void:
		if library.save() == OK:
			then.call())
	dialog.custom_action.connect(func(_action: StringName) -> void:
		library.discard()
		dialog.hide()
		then.call())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()

## The balance tool's Arena tab: picks one fight (up to four heroes in rank
## order with their loadouts, trinkets and talents, an encounter, a preset, the party's
## starting HP and stress) and shows what many plays of it come to. It plays
## it again a moment after anything changes, the content included, a few
## fights each frame. Watch and Play open it in the real combat screen.
class_name BalanceArenaPanel
extends VBoxContainer

## The tool should show `resource` in its form.
signal show_resource(resource: Resource)
## The tool should open the fight in the combat screen, played by the bot or the player.
signal watch(bot_plays: bool)

## Seconds after a change before playing again, so typing doesn't restart it at every key.
const RESTART_DELAY := 0.4
## Milliseconds of fights per frame, and how often the numbers on screen update.
const FRAME_BUDGET := 10
const SHOW_EVERY := 0.2

var library: BalanceLibrary
var arena: BalanceArena
## While the combat screen is open over the tool, the Arena stops playing.
var paused := false
var _restart_in := -1.0
var _show_in := 0.0
var _encounter_pick: OptionButton
var _preset_pick: OptionButton
var _hp_slider: HSlider
var _stress_slider: HSlider
var _hp_label: Label
var _stress_label: Label
var _slots_box: HBoxContainer
var _summary: RichTextLabel
var _more: Button
var _watch: Button
var _play: Button
## Per slot: {hero_label: Label, skills: {SkillDef: Button}}, to show results in place.
var _slot_views: Array[Dictionary] = []
## The content changed: names and kits on the picks may be out of date.
var _stale := false


func _init(content: BalanceLibrary) -> void:
	library = content
	arena = BalanceArena.loaded(content)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	_build()
	library.edited.connect(func(_roots: Array[Resource], _from_history: bool) -> void:
		_stale = true
		_schedule_restart(RESTART_DELAY))
	arena.restart()


func _process(delta: float) -> void:
	if _restart_in >= 0.0:
		_restart_in -= delta
		if _restart_in < 0.0:
			arena.restart()
			_show_results()
	if not is_visible_in_tree():
		return
	if _stale:
		_rebuild()
	if paused or arena.is_done():
		return
	arena.step(FRAME_BUDGET)
	_show_in -= delta
	if _show_in <= 0.0 or arena.is_done():
		_show_in = SHOW_EVERY
		_show_results()


func _schedule_restart(delay: float) -> void:
	_restart_in = delay


## After a change to the setup: keep it, and play again shortly.
func _changed() -> void:
	arena.save_setup()
	_schedule_restart(0.1)


# --- Layout ---

func _build() -> void:
	var fight := HBoxContainer.new()
	fight.add_theme_constant_override("separation", 10)
	fight.add_child(_label("Against"))
	_encounter_pick = OptionButton.new()
	_encounter_pick.custom_minimum_size.x = 320
	_encounter_pick.item_selected.connect(func(index: int) -> void:
		arena.encounter = library.encounters[index]
		_changed())
	fight.add_child(_encounter_pick)
	fight.add_child(_small_button("Edit", "Show the encounter in the form", func() -> void:
		show_resource.emit(arena.encounter)))
	fight.add_child(_label("   at"))
	_preset_pick = OptionButton.new()
	_preset_pick.item_selected.connect(func(index: int) -> void:
		arena.preset = library.targets.presets[index]
		_changed())
	fight.add_child(_preset_pick)
	fight.add_child(_label("   Starting HP"))
	_hp_slider = _slider(5, 100, 5, func(value: float) -> void:
		arena.hp = value / 100.0
		_hp_label.text = "%d%%" % roundi(value)
		_changed())
	fight.add_child(_hp_slider)
	_hp_label = _label("")
	_hp_label.custom_minimum_size.x = 44
	fight.add_child(_hp_label)
	fight.add_child(_label("   Stress"))
	_stress_slider = _slider(0, Rules.STRESS_MAX - 1, 1, func(value: float) -> void:
		arena.stress = roundi(value)
		_stress_label.text = str(roundi(value))
		_changed())
	fight.add_child(_stress_slider)
	_stress_label = _label("")
	_stress_label.custom_minimum_size.x = 24
	fight.add_child(_stress_label)
	add_child(fight)
	_slots_box = HBoxContainer.new()
	_slots_box.add_theme_constant_override("separation", 10)
	add_child(_slots_box)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	_watch = _small_button("▶ Watch", "Open the fight in the combat screen, played by the bot",
			func() -> void: watch.emit(true))
	_watch.add_theme_color_override("font_color", UiStyle.GOLD)
	actions.add_child(_watch)
	_play = _small_button("Play it", "Open the fight in the combat screen and play it yourself",
			func() -> void: watch.emit(false))
	actions.add_child(_play)
	_more = _small_button("More fights", "Play %d fights for narrower margins" % BalanceArena.MORE, func() -> void:
		arena.restart(BalanceArena.MORE)
		_restart_in = -1.0
		_show_results())
	actions.add_child(_more)
	add_child(actions)
	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	_summary.add_theme_font_size_override("normal_font_size", 17)
	_summary.add_theme_font_size_override("bold_font_size", 22)
	add_child(_summary)
	_rebuild()


## Fills the picks and the four slots from the arena and the library, first
## dropping what the content no longer has: a deleted encounter, skills gone
## from a hero's kit, trinkets gone or no longer theirs to wear, talents gone
## from their rows.
func _rebuild() -> void:
	_stale = false
	if arena.encounter not in library.encounters:
		arena.encounter = library.encounters[0] if not library.encounters.is_empty() else null
	for slot in arena.slots:
		var hero: UnitDef = slot.hero
		if hero == null:
			continue
		slot.skills = slot.skills.filter(func(skill: SkillDef) -> bool: return skill in hero.skills)
		slot.trinkets = slot.trinkets.filter(func(trinket: TrinketDef) -> bool:
			return trinket in library.trinkets and (trinket.hero == null or trinket.hero == hero))
		slot.talents = slot.get("talents", []).filter(func(talent: TalentDef) -> bool: return talent in hero.talents)
	_encounter_pick.clear()
	for encounter in library.encounters:
		var roles := library.roles_of(encounter)
		_encounter_pick.add_item("%s%s" % [encounter.display_name, " (%s)" % ", ".join(roles) if not roles.is_empty() else ""])
	_encounter_pick.select(library.encounters.find(arena.encounter))
	_preset_pick.clear()
	for preset in library.targets.presets:
		_preset_pick.add_item(preset.name)
	_preset_pick.select(library.targets.presets.find(arena.preset))
	_hp_slider.set_value_no_signal(arena.hp * 100.0)
	_hp_label.text = "%d%%" % roundi(arena.hp * 100.0)
	_stress_slider.set_value_no_signal(arena.stress)
	_stress_label.text = str(arena.stress)
	while arena.slots.size() < 4:
		arena.slots.append({hero = null, skills = [], trinkets = [], talents = []})
	for child in _slots_box.get_children():
		_slots_box.remove_child(child)
		child.queue_free()
	_slot_views.clear()
	for i in arena.slots.size():
		_slots_box.add_child(_slot_panel(i))
	_show_results()


## One rank of the party: its hero, the skills they take (five at most), two
## trinkets and a talent per row.
func _slot_panel(index: int) -> Control:
	var slot: Dictionary = arena.slots[index]
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)
	var top := HBoxContainer.new()
	var rank := _label("Rank %d" % (index + 1))
	rank.add_theme_color_override("font_color", UiStyle.GOLD)
	top.add_child(rank)
	var hero_pick := OptionButton.new()
	hero_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_pick.add_item("(empty)")
	for hero in library.heroes:
		hero_pick.add_item(hero.display_name)
	hero_pick.select(library.heroes.find(slot.hero) + 1)
	hero_pick.item_selected.connect(func(choice: int) -> void:
		var hero: UnitDef = library.heroes[choice - 1] if choice > 0 else null
		arena.slots[index] = {hero = hero, skills = hero.skills.slice(0, Rules.SKILL_SLOTS) if hero else [], trinkets = [],
				talents = []}
		_changed()
		_rebuild.call_deferred())
	top.add_child(hero_pick)
	column.add_child(top)
	var view := {hero_label = _label(""), skills = {}}
	_slot_views.append(view)
	var hero: UnitDef = slot.hero
	if hero == null:
		return panel
	top.add_child(_small_button("Edit", "Show the hero in the form", func() -> void: show_resource.emit(hero)))
	view.hero_label.add_theme_font_size_override("font_size", 14)
	column.add_child(view.hero_label)
	var skills := GridContainer.new()
	skills.columns = 2
	for skill in hero.skills:
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = skill in slot.skills
		button.focus_mode = Control.FOCUS_NONE
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 120
		button.tooltip_text = UiStyle.plain(UiStyle.skill_bbcode(skill))
		button.toggled.connect(func(on: bool) -> void:
			var taken: Array = arena.slots[index].skills
			if on and taken.size() >= Rules.SKILL_SLOTS:
				button.set_pressed_no_signal(false)
				return
			if on:
				taken.append(skill)
			else:
				taken.erase(skill)
			_style_skill(button, skill, on)
			_changed())
		_style_skill(button, skill, button.button_pressed)
		view.skills[skill] = button
		skills.add_child(button)
	column.add_child(skills)
	for t in CampaignRules.TRINKET_SLOTS:
		column.add_child(_trinket_pick(index, t, hero))
	for row in hero.talents.size() / CampaignRules.TALENTS_PER_ROW:
		column.add_child(_talent_pick(index, row, hero))
	return panel


func _style_skill(button: Button, _skill: SkillDef, taken: bool) -> void:
	button.add_theme_color_override("font_color", UiStyle.TEXT if taken else UiStyle.TEXT_DIM.darkened(0.2))
	button.add_theme_color_override("font_pressed_color", UiStyle.GOLD)


func _trinket_pick(index: int, place: int, hero: UnitDef) -> OptionButton:
	var choices := library.trinkets.filter(func(t: TrinketDef) -> bool: return t.hero == null or t.hero == hero)
	var pick := OptionButton.new()
	pick.add_item("(no trinket)")
	for trinket: TrinketDef in choices:
		pick.add_item("%s (%s)" % [trinket.display_name, CampaignRules.RARITY_NAMES[trinket.rarity]])
	var worn: Array = arena.slots[index].trinkets
	pick.select(choices.find(worn[place]) + 1 if place < worn.size() else 0)
	pick.item_selected.connect(func(choice: int) -> void:
		var picked: Array = []
		for t in CampaignRules.TRINKET_SLOTS:
			var current: Variant = worn[t] if t < worn.size() else null
			if t == place:
				current = choices[choice - 1] if choice > 0 else null
			if current != null and current not in picked:
				picked.append(current)
		arena.slots[index].trinkets = picked
		_changed()
		_rebuild.call_deferred())
	return pick


## The talent on one of the hero's rows, or none. Any row can be set, whatever
## the preset's level, to try a talent early.
func _talent_pick(index: int, row: int, hero: UnitDef) -> OptionButton:
	var choices := hero.talents.slice(row * CampaignRules.TALENTS_PER_ROW, (row + 1) * CampaignRules.TALENTS_PER_ROW)
	var level: int = CampaignRules.TALENT_LEVELS[row] if row < CampaignRules.TALENT_LEVELS.size() else 0
	var pick := OptionButton.new()
	pick.clip_text = true
	pick.add_item("Lv %d: (no talent)" % level)
	for talent: TalentDef in choices:
		pick.add_item("Lv %d: %s" % [level, talent.display_name])
		pick.set_item_tooltip(pick.item_count - 1, UiStyle.plain(UiStyle.perk_bbcode(talent, "\n", hero)))
	var taken: Array = arena.slots[index].get("talents", [])
	var current := taken.filter(func(talent: TalentDef) -> bool: return talent in choices)
	pick.select(choices.find(current[0]) + 1 if not current.is_empty() else 0)
	if level > arena.preset.level:
		pick.tooltip_text = "Opens at level %d, above the preset's %d; still applied here." % [level, arena.preset.level]
	pick.item_selected.connect(func(choice: int) -> void:
		var kept: Array = arena.slots[index].get("talents", []).filter(func(talent: TalentDef) -> bool:
			return talent not in choices)
		if choice > 0:
			kept.append(choices[choice - 1])
		arena.slots[index].talents = kept
		_changed())
	return pick


# --- Results ---

func _show_results() -> void:
	if not is_instance_valid(_summary):
		return
	_watch.disabled = not arena.is_ready()
	_play.disabled = not arena.is_ready()
	if not arena.is_ready():
		_summary.text = "Pick an encounter and at least one hero."
		return
	var n := arena.played()
	var lines: Array[String] = []
	if n == 0:
		lines.append("[color=#%s]Playing...[/color]" % UiStyle.TEXT_DIM.to_html(false))
	else:
		var win := arena.rate("wins")
		var line := "[b]Win %s[/b] ±%d%%   HP lost %s   deaths %.1f   rounds %.1f   stress %.1f" % [UiStyle.percent(win),
				roundi(100 * BalanceSweep.Results.margin(win, n)), UiStyle.percent(arena.rate("lost")),
				arena.rate("deaths"), arena.rate("rounds"), arena.rate("stress")]
		lines.append(line)
		var progress := "%d fights" % n if n >= arena.goal() else "%d / %d fights" % [n, arena.goal()]
		if arena.totals.get("stalled", 0) > 0:
			progress += ", %d hit the %d-round cap" % [arena.totals.stalled, BalanceSweep.MAX_ROUNDS]
		if not arena.previous.is_empty():
			progress += "   Before the last change: win %s, HP lost %s (now %s, %s)" % [
					UiStyle.percent(arena.previous.win), UiStyle.percent(arena.previous.lost),
					BalanceResultColumns.signed(win - arena.previous.win),
					BalanceResultColumns.signed(arena.rate("lost") - arena.previous.lost)]
		lines.append("[color=#%s]%s[/color]" % [UiStyle.TEXT_DIM.to_html(false), progress])
	_summary.text = "\n".join(lines)
	for i in _slot_views.size():
		var hero: UnitDef = arena.slots[i].hero if i < arena.slots.size() else null
		var view := _slot_views[i]
		if hero == null:
			continue
		view.hero_label.text = "HP lost %s   died %s" % [UiStyle.percent(arena.hero_rate(hero, "lost")),
				UiStyle.percent(arena.hero_rate(hero, "died"))] if n > 0 else ""
		for skill: SkillDef in view.skills:
			var button: Button = view.skills[skill]
			var share := arena.usage(hero, skill)
			button.text = skill.display_name + ("   %s" % UiStyle.percent(share) if button.button_pressed and n > 0 else "")


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _small_button(text: String, tooltip: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(action)
	return button


func _slider(low: float, high: float, step: float, changed: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size.x = 140
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(changed)
	return slider

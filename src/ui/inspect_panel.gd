## A unit's details in combat, DD2's inspect sheet: its portrait, name and
## rank, HP, speed and stress, resistances, what it has on it now (tokens,
## DoTs, Regen and buffs, each with what it does), bond bonuses, and its
## skills (hover one, or long-press it, for what it does). Opened by clicking
## a unit that isn't a target, or right-clicking any unit.
class_name InspectPanel
extends PanelContainer

signal closed

const WIDTH := 760.0

var unit: Combatant
var _battle: Battle
var _box: VBoxContainer


## Sized by its content on desktop; on phones the screen sets its size and it scrolls.
func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.frame(16.0 if Device.phone else 22.0))
	mouse_filter = Control.MOUSE_FILTER_STOP
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8 if Device.phone else 10)
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Device.phone:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		add_child(scroll)
		scroll.add_child(_box)
	else:
		_box.custom_minimum_size = Vector2(WIDTH, 0)
		add_child(_box)


func show_unit(target: Combatant, battle: Battle) -> void:
	unit = target
	_battle = battle
	refresh()
	show()


## Rebuilds from the unit as it is now, after events have played.
func refresh() -> void:
	if unit == null:
		return
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_header()
	_vitals()
	if unit.is_corpse:
		_box.add_child(_label("A corpse: %d HP, decays in %d rounds. It holds its place in the ranks."
				% [unit.hp, unit.corpse_rounds], 17, UiStyle.TEXT_DIM, true))
		return
	_resistances()
	_status()
	_skills()


func _header() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_box.add_child(row)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(72, 72)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.draw.connect(func() -> void: UiStyle.draw_portrait(portrait, Rect2(Vector2.ZERO, portrait.size), unit.def))
	row.add_child(portrait)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	words.add_child(_label(unit.display_name, 34, UiStyle.GOLD if unit.is_hero else UiStyle.BLUE.lightened(0.15),
			false, UiStyle.DISPLAY_FONT))
	var where := "%s, rank %d" % ["Hero" if unit.is_hero else "Enemy", _battle.rank_of(unit)]
	if unit.size > 1:
		where += "-%d" % (_battle.rank_of(unit) + unit.size - 1)
	if unit.deaths_door:
		where += "   On Death's Door"
	words.add_child(_label(where, 16, UiStyle.DAMAGE.lightened(0.3) if unit.deaths_door else UiStyle.TEXT_DIM))
	var close := Button.new()
	close.text = "Close" if Device.handheld else "Close (Esc)"
	close.theme_type_variation = &"ActionButton"
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func() -> void:
		hide()
		closed.emit())
	row.add_child(close)


## HP with a bar, speed, and for heroes stress as pips.
func _vitals() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	_box.add_child(row)
	var max_hp := unit.def.corpse_hp if unit.is_corpse else unit.max_hp
	row.add_child(_label("HP %d / %d" % [unit.hp, max_hp], 19))
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(180, 12)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		var rect := Rect2(Vector2.ZERO, bar.size)
		bar.draw_rect(rect, UiStyle.HP_EMPTY)
		if not unit.deaths_door:
			bar.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(float(unit.hp) / maxf(max_hp, 1), 0.0, 1.0),
					rect.size.y)), UiStyle.CORPSE_FILL if unit.is_corpse else UiStyle.HP_FILL)
		bar.draw_rect(rect, UiStyle.HP_FRAME, false, 1.5))
	row.add_child(bar)
	if unit.is_corpse:
		return
	row.add_child(_label("Speed %d" % unit.speed(), 19))
	if not unit.is_hero:
		return
	row.add_child(_label("Stress %d / %d" % [unit.stress, Rules.STRESS_MAX], 19))
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(Rules.STRESS_MAX * 14.0, 14)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(func() -> void:
		for i in Rules.STRESS_MAX:
			pips.draw_rect(Rect2(i * 14.0, 1, 10, 12), UiStyle.STRESS_ON if i < unit.stress else UiStyle.STRESS_OFF))
	row.add_child(pips)


func _resistances() -> void:
	var note := ""
	if unit.is_hero:
		note = "Deathblow %s" % UiStyle.percent(clampf(unit.resist(&"deathblow"), Rules.DEATHBLOW_MIN, Rules.DEATHBLOW_MAX))
	elif unit.death_armor > 0:
		note = "Death Armor %d" % unit.death_armor
	_box.add_child(_heading("Resistances", note))
	var row := Control.new()
	row.custom_minimum_size = Vector2(UiStyle.RESIST_COLUMNS.size() * 70.0, UiStyle.RESIST_ROW_HEIGHT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.draw.connect(func() -> void: UiStyle.draw_resists(row, Vector2.ZERO, unit))
	_box.add_child(row)


## What is on the unit now: tokens, DoTs, Regen and passing buffs, with what
## each does, and bond bonuses.
func _status() -> void:
	var lines: Array[Array] = []
	for token: StringName in unit.tokens:
		var count := unit.token_count(token)
		lines.append([UiStyle.token_icon(token), "%s%s" % [UiStyle.token_name(token), " x%d" % count if count > 1 else ""],
				UiStyle.TOKEN_HELP.get(token, "")])
	for dot: Dictionary in unit.dots:
		lines.append([UiStyle.token_icon(dot.type), "%s %d" % [String(dot.type).capitalize(), dot.amount],
				"for %d more turn%s" % [dot.turns, "" if dot.turns == 1 else "s"]])
	for regen: Dictionary in unit.regens:
		lines.append([null, "Regen %d" % regen.amount, "heals each turn, %d more" % regen.turns])
	for buff: Dictionary in unit.buffs:
		if buff.expiry in [Combatant.BuffExpiry.TRINKET, Combatant.BuffExpiry.BOND]:
			continue
		var lasts := "for %d more rounds" % buff.rounds if buff.expiry == Combatant.BuffExpiry.ROUNDS else ""
		lines.append([null, UiStyle.buff_text(buff.stat, buff.amount), lasts])
	var bonds := UiStyle._bond_bonuses(unit)
	if lines.is_empty() and bonds == "":
		return
	_box.add_child(_heading("Status", ""))
	for line: Array in lines:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		_box.add_child(row)
		var icon := TextureRect.new()
		icon.texture = line[0]
		icon.custom_minimum_size = Vector2(24, 24)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		row.add_child(_label(line[1], 17))
		var help := _label(line[2], 16, UiStyle.TEXT_DIM, true)
		help.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(help)
	if bonds != "":
		_box.add_child(_label(bonds, 16, UiStyle.PALE_GREEN, true))


## The unit's skills as icon rows with their rank pips; hover one for what it does.
func _skills() -> void:
	if unit.skills.is_empty():
		return
	_box.add_child(_heading("Skills", "Hover one for what it does." if not Device.touch else "Hold one for what it does."))
	var grid := GridContainer.new()
	grid.columns = 1 if Device.phone else 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	_box.add_child(grid)
	for skill in unit.skills:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		row.tooltip_text = "%s\n%s" % [skill.display_name, UiStyle.plain(UiStyle.skill_bbcode(skill))]
		grid.add_child(row)
		var icon := TextureRect.new()
		icon.texture = UiStyle.skill_icon(skill)
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		# Enemy skills have no icons yet.
		icon.visible = icon.texture != null
		row.add_child(icon)
		var words := VBoxContainer.new()
		words.add_theme_constant_override("separation", 0)
		words.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(words)
		var rank := unit.skill_rank(skill) if unit.is_hero else 0
		words.add_child(_label(skill.display_name + ("   rank %d" % rank if rank > 1 else ""), 17))
		var pips := RankPips.new()
		pips.set_skill(skill)
		words.add_child(pips)


func _heading(title: String, note: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_label(title, 24, UiStyle.GOLD, false, UiStyle.DISPLAY_FONT))
	if note != "":
		var aside := _label(note, 15, UiStyle.TEXT_DIM)
		aside.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(aside)
	return row


func _label(text: String, font_size: int, color: Color = UiStyle.TEXT, wrap: bool = false, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font:
		label.add_theme_font_override("font", font)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label

## The hamlet, DD1-style: click a building to open its window, the roster runs
## down the right, and the week, gold and heirlooms sit along the top. A plate
## over each building shows its upgrades, or when it opens. Building windows
## have a Services and an Upgrades tab. Every action goes through Game.campaign
## and is saved straight away. Embark (or the mission board) opens the
## expedition map.
## Authored for 1920x1080 on a centred stage, like the combat screen. In the
## phone layout the hamlet shrinks to fit (its plates grow to stay readable)
## and the bar, roster and windows sit on top at full size, the windows
## filling the screen and scrolling.
extends Control

const STAGE_SIZE := Vector2(1920, 1080)
## Clickable areas on the hamlet picture (art/backgrounds/hamlet.svg), by building.
const SPOTS := {
	&"blacksmith": Rect2(390, 420, 300, 300),
	&"guild": Rect2(720, 320, 280, 410),
	&"abbey": Rect2(1040, 260, 260, 480),
	&"tavern": Rect2(320, 830, 400, 250),
	&"exchange": Rect2(790, 860, 260, 220),
	&"board": Rect2(1330, 560, 240, 250),
}
## What each level of an Abbey or Tavern activity's upgrade line brings.
const ACTIVITY_UPGRADES := ["More stress relief", "Prices -15%", "One more slot", "More stress relief",
		"Prices -15% more", "One more slot"]
## Building plates grow this much on phones, where the hamlet is drawn small.
const PHONE_PLATE_SCALE := 2.2

var _stage: Control
## Where the bar, roster and windows live: the stage itself on desktop, a layer
## over the whole screen in the phone layout.
var _ui: Control
var _bar: EstateBar
var _roster_panel: PanelContainer
var _roster_title: Label
var _roster: VBoxContainer
## The building plates, on the stage.
var _plates: Control
var _window: PanelContainer
var _window_title: Label
var _window_message: Label
var _window_body: VBoxContainer
## Rebuilds whichever window is open, after an action changes the campaign.
var _rebuild_window: Callable
## The hero picked in a building window.
var _selected: HeroRecord
## Whether the open building window shows its Upgrades tab.
var _showing_upgrades := false


func _ready() -> void:
	if Game.campaign == null:
		Game.go_to_menu.call_deferred()
		return
	theme = UiStyle.make_theme()
	_build()
	resized.connect(_center_stage)
	_center_stage()
	_refresh()
	if _campaign().recruits_waiting > 0 and not _campaign().recruit_choices().is_empty():
		_open_recruits()
	else:
		_show_week_report()
	if "--autoplay" in OS.get_cmdline_user_args():
		_autoplay_embark()


## After a week passed without a mission, what happened in town.
func _show_week_report() -> void:
	var report := _campaign().week_report.duplicate()
	if report.is_empty():
		return
	_campaign().week_report.clear()
	_open("The week in town", func() -> void:
		for line: String in report:
			_text(line, 18))


## After a region boss's first defeat: pick who joins, from those not yet in the roster.
func _open_recruits() -> void:
	_open("A new hero joins", func() -> void:
		var campaign := _campaign()
		if campaign.recruits_waiting <= 0 or campaign.recruit_choices().is_empty():
			_text("They're settling in.", 18, UiStyle.TEXT_DIM)
			return
		_text("Word of the victory has spread. Choose who joins the roster, at level 1.", 18, UiStyle.TEXT_DIM)
		for hero in campaign.recruit_choices():
			var row := _row()
			var badge := HeroBadge.new()
			badge.setup(hero)
			row.add_child(badge)
			var skills := _label(", ".join(hero.def.skills.map(func(s: SkillDef) -> String: return s.display_name)),
					16, UiStyle.TEXT_DIM)
			skills.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			skills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(skills)
			row.add_child(_action("Recruit", func() -> void: _after(campaign.recruit(hero)))))


## With `-- --autoplay` the town plays itself: take any recruit waiting, treat
## the wounded it can afford, then embark on the first mission with the first
## heroes who can go (or wait out the week if nobody can).
func _autoplay_embark() -> void:
	await get_tree().create_timer(1.5).timeout
	var campaign := _campaign()
	while campaign.recruits_waiting > 0 and not campaign.recruit_choices().is_empty():
		campaign.recruit(campaign.recruit_choices()[0])
	for hero in campaign.roster():
		campaign.treat(hero)
	if campaign.wait_week() == "":
		Game.save()
		_refresh()
		_autoplay_embark()
		return
	for mission in campaign.board:
		var party: Array[HeroRecord] = []
		for hero in campaign.roster():
			var eligibility := campaign.eligibility(hero, mission)
			if party.size() < 4 and eligibility in [Campaign.Eligibility.OK, Campaign.Eligibility.UNDERLEVELED]:
				party.append(hero)
		if campaign.can_embark(mission, party) == "" and campaign.embark(mission, party):
			Game.save()
			Game.go_to_map()
			return


func _campaign() -> Campaign:
	return Game.campaign


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var background: Texture2D = _campaign().def.town_background if Game.campaign else null
	if background and _stage:
		draw_texture_rect(background, Rect2(_stage.position, STAGE_SIZE * _stage.scale), false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _window.visible:
		_close_window()
		get_viewport().set_input_as_handled()


# --- Refreshing ---

func _refresh() -> void:
	var campaign := _campaign()
	_bar.refresh(campaign)
	_roster_title.text = "Roster   %d / %d" % [campaign.roster().size(), campaign.heroes.size()]
	for child in _roster.get_children():
		child.queue_free()
	for hero in campaign.roster():
		var badge := HeroBadge.new()
		var status := UiStyle.hero_status(hero)
		badge.setup(hero, status[0], status[1])
		badge.pressed.connect(_open_hero.bind(hero))
		_roster.add_child(badge)
	_refresh_plates()
	if _window.visible and _rebuild_window.is_valid():
		_rebuild_window.call()


## A plate over each building: its name, and how many upgrades are bought (in
## gold when one can be bought now), or the week it opens. Phones, short of
## room, leave out the count.
func _refresh_plates() -> void:
	for child in _plates.get_children():
		_plates.remove_child(child)
		child.queue_free()
	var campaign := _campaign()
	var grow := PHONE_PLATE_SCALE if Device.phone else 1.0
	for id: StringName in SPOTS:
		var spot: Rect2 = SPOTS[id]
		var plate := VBoxContainer.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_theme_constant_override("separation", 0)
		plate.size = Vector2(440, 0) * grow
		plate.position = Vector2(spot.get_center().x - 220 * grow, spot.position.y - 64 * grow)
		var title: String = "Embark" if id == &"board" else CampaignRules.BUILDINGS[id].name
		plate.add_child(_plate_label(title, roundi(30 * grow), UiStyle.GOLD, UiStyle.DISPLAY_FONT))
		if id != &"board":
			var lines: Array = CampaignRules.BUILDINGS[id].lines
			var note := ""
			var color := UiStyle.TEXT
			if not campaign.building_open(id):
				note = "Opens in week %d" % CampaignRules.BUILDINGS[id].opens
				color = UiStyle.TEXT_DIM
			elif not lines.is_empty():
				var bought := 0
				var total := 0
				for line: StringName in lines:
					bought += campaign.upgrades[line]
					total += CampaignRules.UPGRADES[line].size()
				note = "" if Device.phone else "Upgrades %d/%d" % [bought, total]
				if campaign.upgrade_ready(id):
					note = "Upgrade ready" if Device.phone else "Upgrade ready   %d/%d" % [bought, total]
					color = UiStyle.GOLD
			if note != "":
				plate.add_child(_plate_label(note, roundi(18 * grow), color))
		_plates.add_child(plate)


func _plate_label(text: String, font_size: int, color: Color, font: Font = null) -> Label:
	var label := _label(text, font_size, color, font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", maxi(6, font_size / 4))
	return label


## Shows `reason` if the action was refused; otherwise saves and refreshes.
func _after(reason: String) -> void:
	if reason != "":
		_window_message.text = reason
		return
	_window_message.text = ""
	Game.save()
	_refresh()


# --- Windows ---

func _open(title: String, builder: Callable) -> void:
	_window_title.text = title
	_window_message.text = ""
	_rebuild_window = func() -> void:
		for child in _window_body.get_children():
			_window_body.remove_child(child)
			child.queue_free()
		builder.call()
	_rebuild_window.call()
	_window.show()


func _close_window() -> void:
	_window.hide()
	_rebuild_window = Callable()


func _open_building(id: StringName) -> void:
	if id == &"board":
		Game.go_to_expedition()
		return
	_showing_upgrades = false
	var title: String = CampaignRules.BUILDINGS[id].name
	if not _campaign().building_open(id):
		_open(title, func() -> void:
			_text("Opens in week %d." % CampaignRules.BUILDINGS[id].opens, 20, UiStyle.TEXT_DIM))
		return
	match id:
		&"blacksmith":
			_open(title, _build_blacksmith)
		&"guild":
			_open(title, _build_guild)
		&"abbey":
			_open(title, _build_relief.bind(&"abbey",
					"Safe and steady: no surprises. Heroes sent here miss this week's mission; the stress comes off when the week ends."))
		&"tavern":
			_open(title, _build_relief.bind(&"tavern",
					"More of a gamble: about 1 visit in 4 has a side effect, good or bad. Heroes at the Bar together bond (+%d each pair)."
					% CampaignRules.BAR_BOND_POINTS))
		&"exchange":
			_open(title, _build_exchange)


func _open_hero(hero: HeroRecord) -> void:
	_selected = hero
	_open(hero.display_name, _build_hero_sheet)


func _build_blacksmith() -> void:
	if _upgrades_tab(&"blacksmith"):
		return
	var campaign := _campaign()
	var columns := _columns()
	_hero_picker(columns[0], func(hero: HeroRecord) -> String:
		return "W%d  A%d" % [hero.weapon_rank, hero.armor_rank])
	var right: VBoxContainer = columns[1]
	if _selected == null:
		right.add_child(_label("Choose a hero.", 18, UiStyle.TEXT_DIM))
	else:
		var hero := _selected
		right.add_child(_label("Weapon, rank %d" % hero.weapon_rank, 24, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
		right.add_child(_label(_weapon_text(hero.weapon_rank), 17))
		_rank_button(right, hero.weapon_rank, campaign.gear_cost(hero.weapon_rank), campaign.can_upgrade_weapon(hero),
				_weapon_text(hero.weapon_rank + 1), func() -> void: _after(campaign.upgrade_weapon(hero)))
		right.add_child(_label("Armour, rank %d" % hero.armor_rank, 24, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
		right.add_child(_label("Max HP %d" % (hero.def.max_hp + Growth.armor_hp_bonus(hero.def, hero.armor_rank)), 17))
		_rank_button(right, hero.armor_rank, campaign.gear_cost(hero.armor_rank), campaign.can_upgrade_armor(hero),
				"Max HP %d" % (hero.def.max_hp + Growth.armor_hp_bonus(hero.def, hero.armor_rank + 1)),
				func() -> void: _after(campaign.upgrade_armor(hero)))


func _build_guild() -> void:
	if _upgrades_tab(&"guild"):
		return
	var campaign := _campaign()
	var columns := _columns()
	_hero_picker(columns[0], func(_hero: HeroRecord) -> String: return "")
	var right: VBoxContainer = columns[1]
	if _selected == null:
		right.add_child(_label("Choose a hero.", 18, UiStyle.TEXT_DIM))
	else:
		var hero := _selected
		right.add_child(_label("Each rank: +10% damage or healing, +1% crit, +10% resistance pierce.", 16,
				UiStyle.TEXT_DIM))
		for skill in hero.def.skills:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 14)
			var icon := TextureRect.new()
			icon.texture = UiStyle.skill_icon(skill)
			icon.custom_minimum_size = Vector2(52, 52)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(icon)
			var skill_label := _label("%s   rank %d/5" % [skill.display_name, hero.skill_rank(skill)], 19)
			skill_label.custom_minimum_size = Vector2(300, 0)
			row.add_child(skill_label)
			var cost := campaign.skill_cost(hero, skill)
			var reason := campaign.can_upgrade_skill(hero, skill)
			if cost > 0:
				var button := _action("Train  %s gold" % UiStyle.gold_text(cost), func() -> void: _after(campaign.upgrade_skill(hero, skill)))
				button.disabled = reason != ""
				button.tooltip_text = reason
				row.add_child(button)
				if reason != "":
					row.add_child(_label(reason, 15, UiStyle.TEXT_DIM))
			right.add_child(row)


## The Abbey or the Tavern: its activities with who is there, a Send button
## for the hero picked on the left, and (at the Abbey) wound treatment.
func _build_relief(building: StringName, blurb: String) -> void:
	if _upgrades_tab(building):
		return
	var campaign := _campaign()
	var columns := _columns()
	_hero_picker(columns[0], func(hero: HeroRecord) -> String: return "%d / %d" % [hero.stress, Rules.STRESS_MAX])
	var right: VBoxContainer = columns[1]
	var intro := _label(blurb, 16, UiStyle.TEXT_DIM)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(intro)
	for activity: StringName in CampaignRules.ACTIVITIES:
		if CampaignRules.ACTIVITIES[activity].building != building:
			continue
		var occupants := campaign.activity_occupants(activity)
		var title := "%s   -%d stress   %d/%d" % [CampaignRules.ACTIVITIES[activity].name,
				campaign.activity_relief(activity), occupants.size(), campaign.activity_slots(activity)]
		right.add_child(_label(title, 22, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 12)
		for hero in occupants:
			row.add_child(_action("%s  (cancel)" % hero.display_name, func() -> void:
				campaign.cancel_activity(hero)
				_after("")))
		if _selected:
			var hero := _selected
			var button := _action("Send %s  %s gold" % [hero.display_name,
					UiStyle.gold_text(campaign.activity_price(hero, activity))],
					func() -> void: _after(campaign.send(hero, activity)))
			var reason := campaign.can_send(hero, activity)
			button.disabled = reason != ""
			button.tooltip_text = reason
			row.add_child(button)
		right.add_child(row)
	if building != &"abbey":
		return
	var wounded := campaign.roster().filter(func(h: HeroRecord) -> bool: return h.wounded)
	if not wounded.is_empty():
		_section("Wounded")
		_text("Wounded heroes sit out this week, or can be treated now.", 16, UiStyle.TEXT_DIM)
		for hero: HeroRecord in wounded:
			_window_body.add_child(_action("Treat %s  %s gold" % [hero.display_name, UiStyle.gold_text(campaign.treatment_price(hero))],
					func() -> void: _after(campaign.treat(hero))))


func _build_exchange() -> void:
	var campaign := _campaign()
	_text("Trade one kind of heirloom for another, at a loss. As often as you like.", 18, UiStyle.TEXT_DIM)
	var grid := GridContainer.new()
	grid.columns = 1 if Device.phone else 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 10)
	_window_body.add_child(grid)
	for index in CampaignRules.EXCHANGE_TRADES.size():
		var trade: Array = CampaignRules.EXCHANGE_TRADES[index]
		var button := _action("%s  for  %s" % [_cost_text(trade[0]), _cost_text(trade[1])],
				func() -> void: _after(campaign.exchange(index)))
		var reason := campaign.can_exchange(index)
		button.disabled = reason != ""
		button.tooltip_text = reason
		grid.add_child(button)


# --- Upgrades ---

## Services and Upgrades tabs at the top of a building window. Draws the
## Upgrades tab and returns true when it is the one showing.
func _upgrades_tab(building: StringName) -> bool:
	var row := _row()
	for tab: Array in [[false, "Services"], [true, "Upgrades"]]:
		var button := _action(tab[1], func() -> void:
			_showing_upgrades = tab[0]
			_rebuild_window.call())
		button.toggle_mode = true
		button.button_pressed = _showing_upgrades == tab[0]
		row.add_child(button)
	if not _showing_upgrades:
		return false
	for line: StringName in CampaignRules.BUILDINGS[building].lines:
		_upgrade_line(line)
	return true


## One upgrade line: its name and level pips, what it does now, and a button
## for the next level with what that brings.
func _upgrade_line(line: StringName) -> void:
	var campaign := _campaign()
	var level := campaign.upgrades[line]
	var top: int = CampaignRules.UPGRADES[line].size()
	_section("%s   level %d/%d" % [CampaignRules.UPGRADE_NAMES[line], level, top])
	_text(_line_now(line), 17, UiStyle.TEXT_DIM)
	var row := _row()
	if level >= top:
		row.add_child(_label("Fully upgraded.", 16, UiStyle.TEXT_DIM))
		return
	var reason := campaign.can_upgrade(line)
	var button := _action("Upgrade  " + _cost_text(campaign.upgrade_cost(line)),
			func() -> void: _after(campaign.upgrade(line)))
	button.disabled = reason != ""
	row.add_child(button)
	row.add_child(_label("Next: " + _line_next(line, level + 1) + ("   (%s)" % reason if reason != "" else ""), 16))


## What an upgrade line gives at its current level.
func _line_now(line: StringName) -> String:
	var campaign := _campaign()
	var level := campaign.upgrades[line]
	match line:
		&"weaponsmith":
			return "Weapons up to rank %d." % (level + 1)
		&"armorsmith":
			return "Armour up to rank %d." % (level + 1)
		&"guild":
			return "Skills up to rank %d." % (level + 1)
		&"furnace", &"regimen":
			return "%s cost %d%% less." % ["Weapons and armour" if line == &"furnace" else "Skill ranks",
					roundi(level * CampaignRules.UPGRADE_DISCOUNT * 100)]
	var slots := campaign.activity_slots(line)
	return "%s: -%d stress, %s gold (levels 0-2), %d %s." % [CampaignRules.ACTIVITIES[line].name,
			campaign.activity_relief(line), UiStyle.gold_text(roundi(campaign.activity_base_price(line))), slots,
			"slot" if slots == 1 else "slots"]


## What reaching `level` on an upgrade line brings.
func _line_next(line: StringName, level: int) -> String:
	match line:
		&"weaponsmith":
			return "weapons up to rank %d" % (level + 1)
		&"armorsmith":
			return "armour up to rank %d" % (level + 1)
		&"guild":
			return "skills up to rank %d" % (level + 1)
		&"furnace", &"regimen":
			return "%d%% off" % roundi(level * CampaignRules.UPGRADE_DISCOUNT * 100)
	return ACTIVITY_UPGRADES[level - 1].to_lower()


func _build_hero_sheet() -> void:
	var hero := _selected
	var row := _row()
	var art := TextureRect.new()
	art.texture = hero.def.sprite
	art.custom_minimum_size = Vector2(200, 340) if Device.phone else Vector2(300, 520)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(art)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	row.add_child(info)
	var level := hero.level()
	var next_xp := "max level" if level >= CampaignRules.MAX_LEVEL else "%d / %d XP" % [hero.xp, CampaignRules.LEVEL_XP[level]]
	info.add_child(_label("Level %d   (%s)" % [level, next_xp], 20, UiStyle.TEXT_DIM))
	var status: String = UiStyle.hero_status(hero)[0]
	info.add_child(_label("Stress %d / %d%s" % [hero.stress, Rules.STRESS_MAX, "   " + status if status != "" else ""], 20))
	var perks: Array[String] = []
	if hero.next_mission.has(&"max_hp"):
		perks.append("+%d%% max HP" % roundi(hero.next_mission[&"max_hp"] * 100))
	if hero.next_mission.has(&"speed"):
		perks.append("+%d speed" % roundi(hero.next_mission[&"speed"]))
	if not perks.is_empty():
		info.add_child(_label("Next mission, from the Tavern: " + ", ".join(perks), 18, UiStyle.GOLD))
	info.add_child(_label("Max HP %d   Speed %d" % [hero.def.max_hp + Growth.armor_hp_bonus(hero.def, hero.armor_rank),
			hero.def.speed + Growth.weapon_speed_bonus(hero.weapon_rank)], 20))
	info.add_child(_label("Weapon rank %d: %s" % [hero.weapon_rank, _weapon_text(hero.weapon_rank)], 18))
	info.add_child(_label("Armour rank %d" % hero.armor_rank, 18))
	var resists: Array[String] = []
	for kind: StringName in Rules.LEVELED_RESISTS:
		resists.append("%s %s" % [String(kind).capitalize(),
				UiStyle.percent(hero.def.base_resist(kind) + CampaignRules.LEVEL_RESIST_BONUS * level)])
	info.add_child(_label("Resist: " + ", ".join(resists), 16, UiStyle.TEXT_DIM))
	info.add_child(_label("Bonds", 24, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	for line in _bond_lines(hero):
		info.add_child(_label(line, 18))
	info.add_child(_label("Skills", 24, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	for skill in hero.def.skills:
		var skill_row := HBoxContainer.new()
		var icon := TextureRect.new()
		icon.texture = UiStyle.skill_icon(skill)
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skill_row.add_child(icon)
		skill_row.add_child(_label("  %s, rank %d" % [skill.display_name, hero.skill_rank(skill)], 18))
		info.add_child(skill_row)


## "Mender: Friendly, 7 / 12" for each hero this one has bonded with, closest first.
func _bond_lines(hero: HeroRecord) -> Array[String]:
	var bonds := Game.campaign.bonds
	var others := Game.campaign.roster().filter(func(other: HeroRecord) -> bool:
		return other != hero and bonds.points_of(hero, other) > 0)
	others.sort_custom(func(a: HeroRecord, b: HeroRecord) -> bool:
		return bonds.points_of(hero, a) > bonds.points_of(hero, b))
	var lines: Array[String] = []
	for other: HeroRecord in others:
		var points := bonds.points_of(hero, other)
		var level := bonds.level(hero, other)
		var next := "" if level == Bonds.Level.PARTNERS else ", %d / %d" % [points, CampaignRules.BOND_POINTS[level + 1]]
		lines.append("%s: %s%s" % [other.display_name, Bonds.level_name(level), next])
	if lines.is_empty():
		lines.append("None yet. Heroes bond on missions together and by helping each other in fights.")
	return lines


# --- Window pieces ---

func _text(text: String, font_size: int, color: Color = UiStyle.TEXT) -> void:
	_window_body.add_child(_label(text, font_size, color))


func _section(title: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	_window_body.add_child(gap)
	_window_body.add_child(_label(title, 26, UiStyle.GOLD, UiStyle.DISPLAY_FONT))


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_window_body.add_child(row)
	return row


## A hero list on the left and a detail column on the right.
func _columns() -> Array[VBoxContainer]:
	var row := _row()
	row.add_theme_constant_override("separation", 20 if Device.phone else 30)
	var result: Array[VBoxContainer] = []
	for width: float in [300.0, 0.0 if Device.phone else 860.0]:
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(width, 0)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL if width == 0.0 else Control.SIZE_FILL
		column.add_theme_constant_override("separation", 8)
		row.add_child(column)
		result.append(column)
	return result


func _hero_picker(parent: VBoxContainer, tag_for: Callable) -> void:
	for hero in _campaign().roster():
		var badge := HeroBadge.new()
		badge.setup(hero, tag_for.call(hero), UiStyle.TEXT_DIM)
		badge.button_pressed = hero == _selected
		badge.pressed.connect(func() -> void:
			_selected = hero
			_after(""))
		parent.add_child(badge)


func _rank_button(parent: VBoxContainer, rank: int, cost: int, reason: String, next_text: String,
		action: Callable) -> void:
	if rank >= CampaignRules.MAX_RANK:
		parent.add_child(_label("Fully upgraded.", 16, UiStyle.TEXT_DIM))
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var button := _action("Rank %d  %s gold" % [rank + 1, UiStyle.gold_text(cost)], action)
	button.disabled = reason != ""
	row.add_child(button)
	row.add_child(_label(reason if reason != "" else next_text, 16, UiStyle.TEXT_DIM))
	parent.add_child(row)


func _weapon_text(rank: int) -> String:
	var steps := rank - 1
	var text := "+%d%% damage, +%d%% crit" % [roundi(steps * CampaignRules.WEAPON_DAMAGE_PER_RANK * 100),
			roundi(steps * CampaignRules.WEAPON_CRIT_PER_RANK * 100)]
	var speed := Growth.weapon_speed_bonus(rank)
	return text + (", +%d speed" % speed if speed > 0 else "")


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for heirloom: StringName in cost:
		var name: String = CampaignRules.HEIRLOOM_NAMES[heirloom]
		parts.append("%d %s" % [cost[heirloom], name.trim_suffix("s") if cost[heirloom] == 1 else name])
	return ", ".join(parts)


func _label(text: String, font_size: int, color: Color = UiStyle.TEXT, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _action(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"ActionButton"
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(action)
	return button


# --- Building the screen ---

func _center_stage() -> void:
	if _stage:
		Device.fit_stage(_stage, size)
	if Device.phone and _ui:
		# The hamlet sits at the left so the roster doesn't cover the gate.
		_stage.position.x = 0.0
		_ui.size = size
		_bar.fit_width(size.x)
		_roster_panel.position = Vector2(size.x - _roster_panel.size.x - 8, EstateBar.HEIGHT + 6)
		_roster_panel.size.y = size.y - EstateBar.HEIGHT - 14
		_window.position = Vector2(8, EstateBar.HEIGHT + 4)
		_window.size = size - _window.position - Vector2(8, 8)
	queue_redraw()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage = Control.new()
	_stage.size = STAGE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_ui = _stage
	if Device.phone:
		_ui = Control.new()
		_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_ui)

	for id: StringName in SPOTS:
		var hotspot := Control.new()
		hotspot.position = (SPOTS[id] as Rect2).position
		hotspot.size = (SPOTS[id] as Rect2).size
		hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hotspot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_open_building(id))
		_stage.add_child(hotspot)

	_plates = Control.new()
	_plates.size = STAGE_SIZE
	_plates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_plates)

	# Top band: week, gold and heirlooms, Embark, and a way back to the menu.
	_bar = EstateBar.new()
	_ui.add_child(_bar)
	var embark := _action("Embark", Game.go_to_expedition)
	embark.theme_type_variation = &"PrimaryButton"
	embark.custom_minimum_size = Vector2(150, 44)
	embark.add_theme_font_override("font", UiStyle.DISPLAY_FONT)
	embark.add_theme_font_size_override("font_size", 26)
	_bar.add_button(embark)
	var menu := Button.new()
	menu.text = "Quit" if Device.phone else "Save and quit"
	menu.focus_mode = Control.FOCUS_NONE
	menu.pressed.connect(func() -> void:
		Game.save()
		Game.go_to_menu())
	_bar.add_button(menu)

	# Roster down the right; it scrolls in the phone layout.
	_roster_panel = PanelContainer.new()
	_roster_panel.position = Vector2(STAGE_SIZE.x - 340, 84)
	_roster_panel.size = Vector2(324, 0)
	_ui.add_child(_roster_panel)
	var roster_box := VBoxContainer.new()
	roster_box.add_theme_constant_override("separation", 6)
	_roster_panel.add_child(roster_box)
	_roster_title = _label("Roster", 28, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	roster_box.add_child(_roster_title)
	roster_box.add_child(UiStyle.divider(290.0))
	_roster = VBoxContainer.new()
	_roster.add_theme_constant_override("separation", 6)
	roster_box.add_child(UiStyle.scroll_on_phone(_roster))

	# One building window at a time; the phone layout fills the screen with it and scrolls.
	_window = PanelContainer.new()
	_window.position = Vector2(60, 90)
	_window.size = Vector2(1500, 960)
	_window.add_theme_stylebox_override("panel", UiStyle.frame(16.0 if Device.phone else 30.0))
	_window.hide()
	_ui.add_child(_window)
	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 6 if Device.phone else 12)
	_window.add_child(frame)
	var header := HBoxContainer.new()
	frame.add_child(header)
	_window_title = _label("", 36 if Device.phone else 44, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	_window_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_window_title)
	var close := _action("Close" if Device.handheld else "Close (Esc)", _close_window)
	close.custom_minimum_size = Vector2(110, 48) if Device.phone else Vector2.ZERO
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(close)
	frame.add_child(UiStyle.divider(600.0 if Device.phone else 900.0))
	_window_message = _label("", 17, UiStyle.DAMAGE.lightened(0.3))
	frame.add_child(_window_message)
	_window_body = VBoxContainer.new()
	_window_body.add_theme_constant_override("separation", 10)
	frame.add_child(UiStyle.scroll_on_phone(_window_body))

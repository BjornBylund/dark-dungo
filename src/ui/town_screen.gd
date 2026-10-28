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
	&"wagon": Rect2(1080, 880, 300, 200),
	&"board": Rect2(1330, 560, 240, 250),
}
## Lit windows and lamps on the hamlet picture that flicker: x, y and radius.
const LAMPS: Array[Vector3] = [
	Vector3(468, 660, 100), Vector3(1170, 540, 90), Vector3(786, 540, 55), Vector3(932, 540, 55),
	Vector3(404, 984, 70), Vector3(636, 984, 70), Vector3(1090, 990, 55), Vector3(1320, 210, 35),
]
## Height of a scrolling trinket list in a window, so the Wagon's lists fit
## under its banner without the window scrolling.
const TRINKET_LIST_HEIGHT := 440.0
## What each level of an Abbey or Tavern activity's upgrade line brings.
const ACTIVITY_UPGRADES := ["More stress relief", "Prices -15%", "One more slot", "More stress relief",
		"Prices -15% more", "One more slot"]
## Building plates grow this much on phones, where the hamlet is drawn small.
const PHONE_PLATE_SCALE := 2.2

var _stage: Control
var _atmosphere: Atmosphere
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
## The skill whose details show on the open hero sheet.
var _sheet_skill: SkillDef
var _skill_title: Label
var _skill_state: Label
var _skill_pips: RankPips
var _skill_info: RichTextLabel
var _skill_hint: Label
## Equip or Unequip, on touch screens where a tap only shows a skill.
var _skill_toggle: Button
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
	await _play_scenes()
	if _campaign().recruits_waiting > 0 and not _campaign().recruit_choices().is_empty():
		_open_recruits()
	else:
		_show_week_report()
	if _autoplay():
		_autoplay_embark()


## Plays the campaign's waiting dialogue scenes, one after another, full screen.
## Each is saved as seen when it ends, so quitting part-way shows it again.
func _play_scenes() -> void:
	var campaign := _campaign()
	while not campaign.scenes.is_empty():
		var view := DialogueView.new()
		add_child(view)
		view.play(campaign.scenes[0], campaign.def.town_background, _autoplay())
		await view.finished
		view.queue_free()
		campaign.scenes.pop_front()
		Game.save()


func _autoplay() -> bool:
	return "--autoplay" in OS.get_cmdline_user_args()


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
			row.add_child(_action("Recruit", _recruit.bind(hero))))


## The new hero joins, and their scene plays before the window comes back.
func _recruit(hero: HeroRecord) -> void:
	_after(_campaign().recruit(hero))
	if _campaign().scenes.is_empty():
		return
	_close_window()
	await _play_scenes()
	if _campaign().recruits_waiting > 0 and not _campaign().recruit_choices().is_empty():
		_open_recruits()


## With `-- --autoplay` the town plays itself: take any recruit waiting, treat
## the wounded it can afford, then embark on the first mission with the first
## heroes who can go (or wait out the week if nobody can).
func _autoplay_embark() -> void:
	await get_tree().create_timer(1.5).timeout
	var campaign := _campaign()
	while campaign.recruits_waiting > 0 and not campaign.recruit_choices().is_empty():
		campaign.recruit(campaign.recruit_choices()[0])
	await _play_scenes()
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


## A building's window: its banner, then its services, or the Upgrades tab
## with its upgrade lines. A building not open yet shows only when it opens.
func _open_building(id: StringName) -> void:
	if id == &"board":
		Game.go_to_expedition()
		return
	_showing_upgrades = false
	_sheet_skill = null
	var title: String = CampaignRules.BUILDINGS[id].name
	if not _campaign().building_open(id):
		_open(title, func() -> void:
			_window_body.add_child(_banner(id, "Opens in week %d." % CampaignRules.BUILDINGS[id].opens)))
		return
	var services: Callable
	match id:
		&"blacksmith":
			services = _build_blacksmith
		&"guild":
			services = _build_guild
		&"abbey", &"tavern":
			services = _build_relief.bind(id)
		&"exchange":
			services = _build_exchange
		&"wagon":
			services = _build_wagon
	_open(title, func() -> void:
		_window_body.add_child(_banner(id, _blurb(id), not CampaignRules.BUILDINGS[id].lines.is_empty()))
		if _showing_upgrades:
			for line: StringName in CampaignRules.BUILDINGS[id].lines:
				_upgrade_card(line)
		else:
			services.call())


## What a building is for, on its banner.
func _blurb(id: StringName) -> String:
	match id:
		&"blacksmith":
			return "Better steel and stouter armour: each hero's weapon and armour ranks, as far as the smiths' skill allows."
		&"guild":
			return ("Learn new skills and train them (each rank: +10%% damage or healing, +1%% crit, +10%% resistance"
					+ " pierce). Each hero takes %d into fights.") % CampaignRules.SKILL_SLOTS
		&"abbey":
			return "Safe and steady: no surprises. Heroes sent here miss this week's mission; the stress comes off when the week ends."
		&"tavern":
			return ("More of a gamble: about 1 visit in 4 has a side effect, good or bad. Heroes at the Bar together"
					+ " bond (+%d each pair).") % CampaignRules.BAR_BOND_POINTS
		&"exchange":
			return "Trade one kind of heirloom for another, at a loss. As often as you like."
		&"wagon":
			return "New wares every week. Sell what nobody wears; boss and Ancestral trinkets can't be sold."
	return ""


## The top of a building's window: its corner of the hamlet picture, darkened
## on the left behind what the building is for, and the Services and Upgrades
## tabs when it has upgrade lines.
func _banner(id: StringName, blurb: String, tabs: bool = false) -> Control:
	var banner := MarginContainer.new()
	banner.custom_minimum_size = Vector2(0, 110 if Device.phone else 150)
	for side: String in ["left", "right", "top", "bottom"]:
		banner.add_theme_constant_override("margin_" + side, 18)
	var picture: Texture2D = _campaign().def.town_background
	var border := UiStyle.card()
	border.draw_center = false
	banner.draw.connect(func() -> void:
		var rect := Rect2(Vector2.ZERO, banner.size)
		var shade := Color("0c0807")
		banner.draw_rect(rect, shade)
		# The picture fills the right part, fading into the dark behind the words.
		var view := Rect2(rect.size.x * 0.4, 0, rect.size.x * 0.6, rect.size.y)
		if picture:
			banner.draw_texture_rect_region(picture, view, _banner_region(id, view.size, picture), Color(0.85, 0.8, 0.8))
		var clear := Color(shade, 0.0)
		var fade := Vector2(view.position.x, rect.size.x * 0.62)
		banner.draw_polygon(PackedVector2Array([Vector2(fade.x, 0), Vector2(fade.y, 0), Vector2(fade.y, rect.size.y),
				Vector2(fade.x, rect.size.y)]), PackedColorArray([shade, clear, clear, shade]))
		banner.draw_style_box(border, rect))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	banner.add_child(row)
	var words := _label(blurb, 16 if Device.phone else 19)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_stretch_ratio = 3.0
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(words)
	var room := Control.new()
	room.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room.size_flags_stretch_ratio = 2.0
	row.add_child(room)
	if tabs:
		var tab_row := HBoxContainer.new()
		tab_row.size_flags_vertical = Control.SIZE_SHRINK_END
		row.add_child(tab_row)
		for tab: Array in [[false, "Services"], [true, "Upgrades"]]:
			var button := _action(tab[1], func() -> void:
				_showing_upgrades = tab[0]
				_rebuild_window.call())
			button.toggle_mode = true
			button.button_pressed = _showing_upgrades == tab[0]
			tab_row.add_child(button)
	return banner


## The part of the hamlet picture a building's banner shows, `size_now`'s
## shape, with the building in the middle where the picture's edges allow.
func _banner_region(id: StringName, size_now: Vector2, picture: Texture2D) -> Rect2:
	var to_picture := picture.get_size() / STAGE_SIZE
	var spot: Rect2 = SPOTS[id]
	var height := minf(spot.size.y * 0.75 * to_picture.y, picture.get_height())
	var width := height * size_now.x / size_now.y
	if width > picture.get_width():
		width = picture.get_width()
		height = width * size_now.y / size_now.x
	var center := spot.get_center() * to_picture
	var corner := Vector2(center.x - width * 0.5, center.y - height * 0.55)
	corner = corner.clamp(Vector2.ZERO, picture.get_size() - Vector2(width, height))
	return Rect2(corner, Vector2(width, height))


func _open_hero(hero: HeroRecord) -> void:
	_selected = hero
	_sheet_skill = null
	_open(hero.display_name, _build_hero_sheet)


## The hero picker, and the chosen hero's weapon and armour as cards with their
## ranks as steps (those past what the smiths can make locked).
func _build_blacksmith() -> void:
	var campaign := _campaign()
	var columns := _columns()
	_hero_picker(columns[0], func(hero: HeroRecord) -> String:
		return "Wpn %d   Arm %d" % [hero.weapon_rank, hero.armor_rank])
	var right: VBoxContainer = columns[1]
	if _selected == null:
		right.add_child(_label("Choose a hero.", 18, UiStyle.TEXT_DIM))
		return
	var hero := _selected
	right.add_child(_hero_header(hero))
	var hp := func(rank: int) -> int: return hero.def.max_hp + Growth.armor_hp_bonus(hero.def, rank)
	var gear := [
		["Weapon", hero.weapon_rank, &"weaponsmith", campaign.can_upgrade_weapon(hero), campaign.upgrade_weapon,
				_weapon_text(hero.weapon_rank), func(rank: int) -> String: return _weapon_text(rank).replace(", ", "\n")],
		["Armour", hero.armor_rank, &"armorsmith", campaign.can_upgrade_armor(hero), campaign.upgrade_armor,
				"Max HP %d" % hp.call(hero.armor_rank), func(rank: int) -> String: return "Max HP %d" % hp.call(rank)],
	]
	for piece: Array in gear:
		var rank: int = piece[1]
		var reason: String = piece[3]
		var box := _card(right)
		var header := _card_header(box, piece[0], "rank %d / %d" % [rank, CampaignRules.MAX_RANK], piece[5])
		if rank >= CampaignRules.MAX_RANK:
			header.add_child(_label("Fully upgraded", 16, UiStyle.TEXT_DIM))
		else:
			header.add_child(_cost_chips({}, campaign.gear_cost(rank)))
			var upgrade: Callable = piece[4]
			var button := _action("Rank %d" % (rank + 1), func() -> void: _after(upgrade.call(hero)))
			button.disabled = reason != ""
			header.add_child(button)
		var labels: Array[String] = []
		for step in CampaignRules.MAX_RANK:
			labels.append((piece[6] as Callable).call(step + 1))
		box.add_child(_steps(labels, rank, campaign.upgrades[piece[2]] + 1))
		if reason != "" and rank < CampaignRules.MAX_RANK:
			box.add_child(_label(reason, 15, UiStyle.TEXT_DIM))


## The hero picker, and the chosen hero's skills as the hero sheet's icon grid:
## pick one to learn it, train it, or equip or unequip it.
func _build_guild() -> void:
	var columns := _columns()
	_hero_picker(columns[0], func(hero: HeroRecord) -> String:
		return "%d / %d learned" % [hero.known.size(), hero.def.skills.size()])
	var right: VBoxContainer = columns[1]
	if _selected == null:
		right.add_child(_label("Choose a hero.", 18, UiStyle.TEXT_DIM))
		return
	var hero := _selected
	right.add_child(_hero_header(hero))
	right.add_child(_heading("Skills", "%d / %d equipped" % [hero.equipped.size(), CampaignRules.SKILL_SLOTS]))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	right.add_child(grid)
	for skill in hero.def.skills:
		var slot := SkillSlot.new()
		slot.setup(skill, hero.knows(skill), hero.is_equipped(skill), hero.skill_rank(skill), skill == _sheet_skill)
		slot.pressed.connect(func() -> void:
			_sheet_skill = skill
			_after(""))
		grid.add_child(slot)
	var box := _card(right)
	var skill: SkillDef = _sheet_skill if _sheet_skill in hero.def.skills else null
	if skill == null:
		box.add_child(_label("Choose a skill to learn, train or equip it.", 17, UiStyle.TEXT_DIM))
		return
	_guild_skill(box, hero, skill)


## A skill at the Guild: what it does, and the buttons that apply: learn it,
## train it to the next rank, and equip or unequip it.
func _guild_skill(box: VBoxContainer, hero: HeroRecord, skill: SkillDef) -> void:
	var campaign := _campaign()
	var state := "rank %d / %d%s" % [hero.skill_rank(skill), CampaignRules.MAX_RANK,
			"   equipped" if hero.is_equipped(skill) else ""] if hero.knows(skill) else "not learned"
	var header := _card_header(box, skill.display_name, state, "")
	var pips := RankPips.new()
	pips.set_skill(skill)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(pips)
	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.scroll_active = false
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_theme_font_size_override("normal_font_size", 17)
	var usage := UiStyle.usage_text(skill)
	info.text = UiStyle.skill_bbcode(skill) + ("\n[color=#%s]%s[/color]" % [UiStyle.TEXT_DIM.to_html(false), usage]
			if usage != "" else "")
	box.add_child(info)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 14)
	buttons.add_theme_constant_override("v_separation", 8)
	box.add_child(buttons)
	var reasons: Array[String] = []
	if not hero.knows(skill):
		var learn := _action("Learn  %s gold" % UiStyle.gold_text(campaign.learn_price(hero)),
				func() -> void: _after(campaign.learn(hero, skill)))
		learn.disabled = campaign.can_learn(hero, skill) != ""
		reasons.append(campaign.can_learn(hero, skill))
		buttons.add_child(learn)
	else:
		if hero.is_equipped(skill):
			buttons.add_child(_action("Unequip", func() -> void: _after(campaign.unequip(hero, skill))))
		else:
			var equip := _action("Equip", func() -> void: _after(campaign.equip(hero, skill)))
			equip.disabled = hero.equipped.size() >= CampaignRules.SKILL_SLOTS
			if equip.disabled:
				reasons.append("All %d slots are taken: unequip a skill first." % CampaignRules.SKILL_SLOTS)
			buttons.add_child(equip)
		var cost := campaign.skill_cost(hero, skill)
		if cost > 0:
			var train := _action("Train to rank %d  %s gold" % [hero.skill_rank(skill) + 1, UiStyle.gold_text(cost)],
					func() -> void: _after(campaign.upgrade_skill(hero, skill)))
			train.disabled = campaign.can_upgrade_skill(hero, skill) != ""
			reasons.append(campaign.can_upgrade_skill(hero, skill))
			buttons.add_child(train)
	for reason in reasons:
		if reason != "":
			var why := _label(reason, 15, UiStyle.TEXT_DIM)
			why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(why)


## The Abbey or the Tavern: the hero picker, each activity as a card with its
## seats (the heroes there, click one to bring them back) and a Send button for
## the hero picked, and at the Abbey the wounded with Treat buttons.
func _build_relief(building: StringName) -> void:
	var campaign := _campaign()
	var columns := _columns()
	_hero_picker(columns[0], func(hero: HeroRecord) -> String: return UiStyle.hero_status(hero)[0])
	var right: VBoxContainer = columns[1]
	var cards := GridContainer.new()
	cards.columns = 1 if Device.phone else 3
	cards.add_theme_constant_override("h_separation", 14)
	cards.add_theme_constant_override("v_separation", 14)
	right.add_child(cards)
	for activity: StringName in CampaignRules.ACTIVITIES:
		if CampaignRules.ACTIVITIES[activity].building == building:
			_activity_card(cards, activity)
	if building != &"abbey":
		return
	var wounded := campaign.roster().filter(func(h: HeroRecord) -> bool: return h.wounded)
	if wounded.is_empty():
		return
	right.add_child(_heading("Wounded", "They sit out this week, or can be treated now."))
	for hero: HeroRecord in wounded:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		right.add_child(row)
		var badge := HeroBadge.new()
		badge.setup(hero, "WOUNDED", UiStyle.DAMAGE)
		badge.disabled = true
		row.add_child(badge)
		var treat := _action("Treat  %s gold" % UiStyle.gold_text(campaign.treatment_price(hero)),
				func() -> void: _after(campaign.treat(hero)))
		treat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(treat)


## One Abbey or Tavern activity: its relief and price, a seat per slot holding
## the hero there (click to bring them back) or empty, and Send for the hero picked.
func _activity_card(parent: Control, activity: StringName) -> void:
	var campaign := _campaign()
	var box := _card(parent, true)
	box.add_child(_label(CampaignRules.ACTIVITIES[activity].name, 24, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	box.add_child(_label("-%d stress   %s gold" % [campaign.activity_relief(activity),
			UiStyle.gold_text(roundi(campaign.activity_base_price(activity)))], 17))
	var seats := HBoxContainer.new()
	seats.add_theme_constant_override("separation", 10)
	box.add_child(seats)
	var occupants := campaign.activity_occupants(activity)
	for i in campaign.activity_slots(activity):
		var hero: HeroRecord = occupants[i] if i < occupants.size() else null
		var seat := Button.new()
		seat.custom_minimum_size = Vector2(64, 64)
		seat.focus_mode = Control.FOCUS_NONE
		seat.disabled = hero == null
		seat.draw.connect(func() -> void:
			var rect := Rect2(Vector2.ZERO, seat.size)
			if hero:
				UiStyle.draw_portrait(seat, rect, hero.def)
				if seat.is_hovered():
					seat.draw_rect(rect, UiStyle.GOLD, false, 2.0)
			else:
				seat.draw_rect(rect, Color("0c0807"))
				seat.draw_rect(rect.grow(-1.5), Color("3a2a1c"), false, 2.0))
		if hero:
			seat.tooltip_text = "%s is here. Click to bring them back." % hero.display_name
			seat.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			seat.pressed.connect(func() -> void:
				campaign.cancel_activity(hero)
				_after(""))
		seats.add_child(seat)
	if _selected == null:
		box.add_child(_label("Choose a hero to send.", 15, UiStyle.TEXT_DIM))
		return
	var hero := _selected
	var reason := campaign.can_send(hero, activity)
	var send := _action("Send %s  %s gold" % [hero.display_name, UiStyle.gold_text(campaign.activity_price(hero, activity))],
			func() -> void: _after(campaign.send(hero, activity)))
	send.disabled = reason != ""
	box.add_child(send)
	if reason != "":
		var why := _label(reason, 15, UiStyle.TEXT_DIM)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(why)


## Each trade as a card: the heirlooms given, those got, and Trade.
func _build_exchange() -> void:
	var campaign := _campaign()
	var grid := GridContainer.new()
	grid.columns = 2 if Device.phone else 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	_window_body.add_child(grid)
	for index in CampaignRules.EXCHANGE_TRADES.size():
		var trade: Array = CampaignRules.EXCHANGE_TRADES[index]
		var box := _card(grid, true)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(row)
		row.add_child(_cost_chips(trade[0]))
		row.add_child(_label("for", 16, UiStyle.TEXT_DIM))
		row.add_child(_cost_chips(trade[1], 0, false))
		var reason := campaign.can_exchange(index)
		var button := _action("Trade", func() -> void: _after(campaign.exchange(index)))
		button.disabled = reason != ""
		button.tooltip_text = reason
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(button)


## DD1's Nomad Wagon: this week's trinkets for sale, and the estate's unworn
## ones to sell.
func _build_wagon() -> void:
	var campaign := _campaign()
	var grid := GridContainer.new()
	grid.columns = 1 if Device.phone else 2
	grid.add_theme_constant_override("h_separation", 40)
	_window_body.add_child(grid)
	var buying := _trinket_list(grid, "For sale")
	if campaign.wagon.is_empty():
		buying.add_child(_label("Sold out until next week.", 16, UiStyle.TEXT_DIM))
	for trinket in campaign.wagon:
		var buy := _action("Buy  %s gold" % UiStyle.gold_text(campaign.wagon_price(trinket)),
				func() -> void: _after(campaign.buy(trinket)))
		buy.disabled = campaign.can_buy(trinket) != ""
		buy.tooltip_text = campaign.can_buy(trinket)
		buying.add_child(_trinket_row(trinket, [buy]))
	var selling := _trinket_list(grid, "The estate's trinkets")
	if campaign.trinkets.is_empty():
		selling.add_child(_label("Nothing unworn. Trinkets come from caches, elites and completed missions.", 16,
				UiStyle.TEXT_DIM))
	for trinket in campaign.trinkets:
		var sell := _action("Sell  %s gold" % UiStyle.gold_text(campaign.sell_price(trinket)),
				func() -> void: _after(campaign.sell(trinket)))
		sell.disabled = campaign.can_sell(trinket) != ""
		sell.tooltip_text = campaign.can_sell(trinket)
		selling.add_child(_trinket_row(trinket, [sell]))


## A titled column of trinket rows in `parent`, `width` wide (0 to fill) and
## scrolling past `height` on desktop, where the window doesn't scroll.
## Returns the box to add the rows to.
func _trinket_list(parent: Control, title: String, width: float = 640.0,
		height: float = TRINKET_LIST_HEIGHT) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(0.0 if Device.phone else width, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	column.add_child(_label(title, 24, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if Device.phone:
		column.add_child(rows)
		return rows
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, height)
	scroll.add_child(rows)
	column.add_child(scroll)
	return rows


## A trinket's icon, name (in its rarity's colour), kind and effects, with
## `actions` (buttons) at the end.
func _trinket_row(trinket: TrinketDef, actions: Array) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var icon := TrinketIcon.new()
	icon.setup(trinket)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name := _label("%s   %s" % [trinket.display_name, UiStyle.trinket_kind(trinket)], 18,
			UiStyle.RARITY_COLORS[trinket.rarity])
	text.add_child(name)
	var effects := RichTextLabel.new()
	effects.bbcode_enabled = true
	effects.fit_content = true
	effects.scroll_active = false
	effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effects.add_theme_font_size_override("normal_font_size", 16)
	effects.text = UiStyle.trinket_bbcode(trinket, "\n")
	text.add_child(effects)
	row.add_child(text)
	for action: Control in actions:
		action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(action)
	return row


# --- Upgrades ---

## One upgrade line as a card: its name, level and what it does now, the
## Upgrade button with its heirloom cost, and its levels as steps saying what
## each brings.
func _upgrade_card(line: StringName) -> void:
	var campaign := _campaign()
	var level: int = campaign.upgrades[line]
	var top: int = CampaignRules.UPGRADES[line].size()
	var box := _card(_window_body)
	var header := _card_header(box, CampaignRules.UPGRADE_NAMES[line], "level %d / %d" % [level, top], _line_now(line))
	var reason := campaign.can_upgrade(line) if level < top else ""
	if level >= top:
		header.add_child(_label("Fully upgraded", 16, UiStyle.TEXT_DIM))
	else:
		header.add_child(_cost_chips(campaign.upgrade_cost(line)))
		var button := _action("Upgrade", func() -> void: _after(campaign.upgrade(line)))
		button.disabled = reason != ""
		header.add_child(button)
	var labels: Array[String] = []
	for step in top:
		labels.append(_line_next(line, step + 1))
	box.add_child(_steps(labels, level))
	if reason != "":
		box.add_child(_label(reason, 15, UiStyle.TEXT_DIM))


# --- Window pieces for buildings ---

## A card in `parent` (a framed panel) and the box to fill it with. With
## `expand`, cards in a grid share its width.
func _card(parent: Control, expand: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := UiStyle.card()
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	if expand:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	return box


## A card's top row, which wraps on narrow screens: a gold title, a dim note,
## and `now` (what it is or does now). Returns the row, for buttons at its end.
func _card_header(box: VBoxContainer, title: String, note: String, now: String) -> Container:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 16)
	row.add_theme_constant_override("v_separation", 6)
	box.add_child(row)
	row.add_child(_label(title, 26, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	var aside := _label(note, 16, UiStyle.TEXT_DIM)
	aside.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(aside)
	var current := _label(now, 17)
	current.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	current.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(current)
	return row


## A price as heirloom icons with their amounts, then gold. Amounts the estate
## can't pay show red, unless `check` is false (what a trade gives).
func _cost_chips(heirlooms: Dictionary, gold: int = 0, check: bool = true) -> Control:
	var campaign := _campaign()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for heirloom: StringName in heirlooms:
		var icon := TextureRect.new()
		icon.texture = UiStyle.heirloom_icon(heirloom)
		icon.custom_minimum_size = Vector2(26, 26)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = CampaignRules.HEIRLOOM_NAMES[heirloom]
		row.add_child(icon)
		var short: bool = check and campaign.heirlooms[heirloom] < heirlooms[heirloom]
		row.add_child(_label(str(heirlooms[heirloom]), 18, UiStyle.DAMAGE.lightened(0.2) if short else UiStyle.TEXT))
	if gold > 0:
		var short := check and campaign.gold < gold
		row.add_child(_label("%s gold" % UiStyle.gold_text(gold), 18, UiStyle.DAMAGE.lightened(0.2) if short else UiStyle.GOLD))
	return row


## Levels or ranks as a track of steps, each saying what it brings: the first
## `done` filled gold with a check, the next one ringed gold, steps from
## `locked_from` (1-based) on locked, and the rest dim.
func _steps(labels: Array[String], done: int, locked_from: int = 0) -> Control:
	var track := Control.new()
	var pitch := 120.0 if Device.phone else 150.0
	track.custom_minimum_size = Vector2(pitch * labels.size(), 96)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.draw.connect(func() -> void:
		var y := 16.0
		var font := UiStyle.BODY_FONT
		track.draw_line(Vector2(pitch / 2.0, y), Vector2(pitch * (labels.size() - 0.5), y), Color("3a2a1c"), 3.0)
		if done > 0:
			track.draw_line(Vector2(pitch / 2.0, y), Vector2(pitch * (mini(done, labels.size()) - 0.5), y), UiStyle.GOLD, 3.0)
		for i in labels.size():
			var center := Vector2(pitch * (i + 0.5), y)
			var locked := locked_from > 0 and i + 1 > locked_from
			var color := UiStyle.TEXT_DIM
			track.draw_circle(center, 12.0, Color("0c0807"))
			if i < done:
				track.draw_circle(center, 11.0, UiStyle.GOLD)
				track.draw_polyline(PackedVector2Array([center + Vector2(-5, 0), center + Vector2(-1, 4),
						center + Vector2(6, -4)]), Color("1a1416"), 2.5, true)
				color = UiStyle.TEXT
			elif i == done and not locked:
				track.draw_arc(center, 11.0, 0.0, TAU, 32, UiStyle.GOLD, 3.0, true)
				color = UiStyle.GOLD
			else:
				track.draw_arc(center, 11.0, 0.0, TAU, 32, Color("4a3a2a"), 2.0, true)
			if locked:
				UiStyle.draw_lock(track, center + Vector2(0, 1), 15.0)
			track.draw_multiline_string(font, Vector2(i * pitch + 4.0, y + 34.0), labels[i], HORIZONTAL_ALIGNMENT_CENTER,
					pitch - 8.0, 14, 3, color))
	return track


## The hero a building window is serving: their portrait, name and level.
func _hero_header(hero: HeroRecord) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(56, 56)
	portrait.draw.connect(func() -> void:
		var rect := Rect2(Vector2.ZERO, portrait.size)
		UiStyle.draw_portrait(portrait, rect, hero.def)
		UiStyle.draw_level_badge(portrait, Vector2(6, rect.size.y - 6), hero.level(), 12.0))
	row.add_child(portrait)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_child(_label(hero.display_name, 28, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	words.add_child(_label("Level %d   Stress %d / %d" % [hero.level(), hero.stress, Rules.STRESS_MAX], 15, UiStyle.TEXT_DIM))
	row.add_child(words)
	return row


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
		&"furnace", &"regimen", &"haggling":
			var what: String = {&"furnace": "Weapons and armour", &"regimen": "Skill ranks", &"haggling": "Trinkets"}[line]
			return "%s cost %d%% less." % [what, roundi(level * CampaignRules.UPGRADE_DISCOUNT * 100)]
		&"wagon_stock":
			return "%d trinkets for sale each week." % (CampaignRules.WAGON_STOCK + level)
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
		&"furnace", &"regimen", &"haggling":
			return "%d%% off" % roundi(level * CampaignRules.UPGRADE_DISCOUNT * 100)
		&"wagon_stock":
			return "%d trinkets a week" % (CampaignRules.WAGON_STOCK + level)
	return ACTIVITY_UPGRADES[level - 1].to_lower()


## DD1's character sheet, in three parts side by side (stacked on phones): the
## hero in a frame with level, XP, stress and bonds; stats, resistances and the
## class's skills as an icon grid; and the trinket slots with the estate's
## trinkets the hero could wear. Click a skill to equip or unequip it and hover
## it for what it does; on touch screens a tap shows it, with a button to equip.
func _build_hero_sheet() -> void:
	var hero := _selected
	var parts: BoxContainer = VBoxContainer.new() if Device.phone else HBoxContainer.new()
	parts.add_theme_constant_override("separation", 22 if Device.phone else 34)
	_window_body.add_child(parts)
	parts.add_child(_sheet_figure(hero))
	# As the hero would fight now: gear, level, trinkets and Tavern perks.
	parts.add_child(_sheet_details(hero, Growth.hero_combatant(hero)))
	parts.add_child(_sheet_gear(hero))


## The hero standing in a card frame, their level with a bar to the next,
## stress pips, where they are this week, Tavern perks and bonds.
func _sheet_figure(hero: HeroRecord) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.custom_minimum_size = Vector2(0.0 if Device.phone else 290.0, 0)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 20)
	column.add_child(top)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyle.card())
	var art := TextureRect.new()
	art.texture = hero.def.sprite
	art.custom_minimum_size = Vector2(150, 200) if Device.phone else Vector2(276, 340)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(art)
	top.add_child(frame)
	var meters := VBoxContainer.new()
	meters.add_theme_constant_override("separation", 6)
	meters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Beside the portrait on phones, under it on desktop.
	if Device.phone:
		top.add_child(meters)
	else:
		column.add_child(meters)
	var level := hero.level()
	var maxed := level >= CampaignRules.MAX_LEVEL
	var from: int = 0 if level == 0 else CampaignRules.LEVEL_XP[level - 1]
	var to: int = CampaignRules.LEVEL_XP[mini(level, CampaignRules.MAX_LEVEL - 1)]
	meters.add_child(_label("Level %d" % level, 28, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	meters.add_child(_meter(1.0 if maxed else float(hero.xp - from) / (to - from)))
	meters.add_child(_label("Max level" if maxed else "%d / %d XP" % [hero.xp, to], 16, UiStyle.TEXT_DIM))
	meters.add_child(_label("Stress %d / %d" % [hero.stress, Rules.STRESS_MAX], 18))
	meters.add_child(_stress_pips(hero.stress))
	var status := UiStyle.hero_status(hero)
	if status[0] != "":
		meters.add_child(_label(status[0], 16, status[1]))
	var perks: Array[String] = []
	if hero.next_mission.has(&"max_hp"):
		perks.append("+%d%% max HP" % roundi(hero.next_mission[&"max_hp"] * 100))
	if hero.next_mission.has(&"speed"):
		perks.append("+%d speed" % roundi(hero.next_mission[&"speed"]))
	if not perks.is_empty():
		var perk_line := _label("Next mission, from the Tavern: " + ", ".join(perks), 16, UiStyle.GOLD)
		perk_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		meters.add_child(perk_line)
	column.add_child(_label("Bonds", 22, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	var bonded := _campaign().roster().any(func(other: HeroRecord) -> bool:
		return other != hero and _campaign().bonds.points_of(hero, other) > 0)
	for line in _bond_lines(hero):
		var bond := _label(line, 16, UiStyle.TEXT if bonded else UiStyle.TEXT_DIM)
		bond.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(bond)
	return column


## Stats, the resistance row, and the class's skills as an icon grid with the
## hovered or chosen skill's details under it.
func _sheet_details(hero: HeroRecord, unit: Combatant) -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.custom_minimum_size = Vector2(0.0 if Device.phone else 600.0, 0)
	var stats := GridContainer.new()
	stats.columns = 4
	stats.add_theme_constant_override("h_separation", 14)
	stats.add_theme_constant_override("v_separation", 4)
	for pair: Array in [["Max HP", str(unit.max_hp)], ["Speed", str(unit.speed())],
			["Weapon", "rank %d: %s" % [hero.weapon_rank, _weapon_text(hero.weapon_rank)]],
			["Armour", "rank %d" % hero.armor_rank]]:
		stats.add_child(_label(pair[0], 16, UiStyle.TEXT_DIM))
		stats.add_child(_label(pair[1], 18))
	column.add_child(stats)

	var deathblow := clampf(unit.resist(&"deathblow"), Rules.DEATHBLOW_MIN, Rules.DEATHBLOW_MAX)
	column.add_child(_heading("Resistances", "Deathblow %s" % UiStyle.percent(deathblow)))
	var resists := Control.new()
	resists.custom_minimum_size = Vector2(UiStyle.RESIST_COLUMNS.size() * 70.0, UiStyle.RESIST_ROW_HEIGHT)
	resists.mouse_filter = Control.MOUSE_FILTER_IGNORE
	resists.draw.connect(func() -> void: UiStyle.draw_resists(resists, Vector2.ZERO, unit))
	column.add_child(resists)

	column.add_child(_heading("Skills", "%d / %d equipped" % [hero.equipped.size(), CampaignRules.SKILL_SLOTS]))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for skill in hero.def.skills:
		var slot := SkillSlot.new()
		slot.setup(skill, hero.knows(skill), hero.is_equipped(skill), hero.skill_rank(skill), skill == _sheet_skill)
		slot.pressed.connect(_press_skill.bind(hero, skill))
		if not Device.touch:
			slot.mouse_entered.connect(func() -> void: _show_skill(hero, skill))
			slot.mouse_exited.connect(func() -> void: _show_skill(hero, _sheet_skill))
		grid.add_child(slot)
	column.add_child(grid)
	column.add_child(_skill_details())
	_show_skill(hero, _sheet_skill)
	return column


## The panel under the skill grid that _show_skill fills.
func _skill_details() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.card())
	panel.custom_minimum_size = Vector2(0, 200)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	box.add_child(title_row)
	_skill_title = _label("", 24, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	title_row.add_child(_skill_title)
	_skill_state = _label("", 16, UiStyle.TEXT_DIM)
	_skill_state.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_skill_state)
	_skill_pips = RankPips.new()
	_skill_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_skill_pips)
	_skill_info = RichTextLabel.new()
	_skill_info.bbcode_enabled = true
	_skill_info.fit_content = true
	_skill_info.scroll_active = false
	_skill_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_info.add_theme_font_size_override("normal_font_size", 17)
	_skill_info.add_theme_font_size_override("italics_font_size", 16)
	box.add_child(_skill_info)
	var hint_row := HBoxContainer.new()
	hint_row.add_theme_constant_override("separation", 14)
	box.add_child(hint_row)
	_skill_hint = _label("", 16, UiStyle.TEXT_DIM)
	_skill_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skill_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint_row.add_child(_skill_hint)
	_skill_toggle = _action("", func() -> void: _toggle_skill(_selected, _sheet_skill))
	hint_row.add_child(_skill_toggle)
	return panel


## Fills the details panel with what `skill` does and how to equip it, or a
## hint when no skill is chosen.
func _show_skill(hero: HeroRecord, skill: SkillDef) -> void:
	if not is_instance_valid(_skill_info):
		return
	_skill_toggle.hide()
	if skill == null:
		_skill_title.text = "Skills"
		_skill_state.text = ""
		_skill_pips.set_skill(null)
		_skill_info.text = "Tap a skill to see what it does." if Device.touch \
				else "Hover a skill to see what it does, and click one to equip or unequip it."
		_skill_hint.text = "Gold frames are the %d taken into fights. Learn and train skills at the Guild." \
				% CampaignRules.SKILL_SLOTS
		return
	_skill_title.text = skill.display_name
	_skill_state.text = ("rank %d / %d%s" % [hero.skill_rank(skill), CampaignRules.MAX_RANK,
			"   equipped" if hero.is_equipped(skill) else ""]) if hero.knows(skill) else "not learned"
	_skill_pips.set_skill(skill)
	var usage := UiStyle.usage_text(skill)
	_skill_info.text = UiStyle.skill_bbcode(skill) + ("\n[color=#%s]%s[/color]" % [UiStyle.TEXT_DIM.to_html(false),
			usage] if usage != "" else "")
	var full := not hero.is_equipped(skill) and hero.equipped.size() >= CampaignRules.SKILL_SLOTS
	if not hero.knows(skill):
		_skill_hint.text = "Learn it at the Guild."
	elif full:
		_skill_hint.text = "All %d slots are taken: unequip a skill first." % CampaignRules.SKILL_SLOTS
	elif Device.touch:
		_skill_hint.text = ""
	else:
		_skill_hint.text = "Click to unequip." if hero.is_equipped(skill) else "Click to equip."
	if Device.touch and hero.knows(skill) and not full:
		_skill_toggle.text = "Unequip" if hero.is_equipped(skill) else "Equip"
		_skill_toggle.show()


## Chooses `skill` for the details panel; with a mouse, also equips or unequips it.
func _press_skill(hero: HeroRecord, skill: SkillDef) -> void:
	_sheet_skill = skill
	if Device.touch or not hero.knows(skill):
		_after("")
		return
	_toggle_skill(hero, skill)


func _toggle_skill(hero: HeroRecord, skill: SkillDef) -> void:
	var campaign := _campaign()
	var reason := campaign.unequip(hero, skill) if hero.is_equipped(skill) else campaign.equip(hero, skill)
	_after(reason)
	if reason != "":
		_rebuild_window.call()


## The trinket slots (press a filled one to take its trinket off) with what the
## worn trinkets do, and the estate's unworn trinkets the hero could wear.
func _sheet_gear(hero: HeroRecord) -> Control:
	var campaign := _campaign()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_heading("Trinkets", "%d / %d worn" % [hero.trinkets.size(), CampaignRules.TRINKET_SLOTS]))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 18)
	column.add_child(slots)
	for i in CampaignRules.TRINKET_SLOTS:
		var worn: TrinketDef = hero.trinkets[i] if i < hero.trinkets.size() else null
		var slot := VBoxContainer.new()
		slot.add_theme_constant_override("separation", 4)
		slot.custom_minimum_size = Vector2(200, 0)
		slots.add_child(slot)
		var socket := TrinketSocket.new()
		socket.setup(worn)
		socket.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		slot.add_child(socket)
		if worn == null:
			slot.add_child(_label("Empty", 16, UiStyle.TEXT_DIM))
			continue
		socket.pressed.connect(func() -> void: _after(campaign.take_off(hero, worn)))
		var name := _label(worn.display_name, 17, UiStyle.RARITY_COLORS[worn.rarity])
		name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slot.add_child(name)
		var effects := RichTextLabel.new()
		effects.bbcode_enabled = true
		effects.fit_content = true
		effects.scroll_active = false
		effects.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		effects.add_theme_font_size_override("normal_font_size", 15)
		effects.text = UiStyle.trinket_bbcode(worn, "\n")
		slot.add_child(effects)
	if not hero.trinkets.is_empty():
		column.add_child(_label("Click a worn trinket to take it off.", 15, UiStyle.TEXT_DIM))
	var wearable := campaign.trinkets.filter(func(t: TrinketDef) -> bool: return t.hero == null or t.hero == hero.def)
	if wearable.is_empty():
		var none := _label("No unworn trinket fits. They come from caches, elites, completed missions and the "
				+ "Nomad Wagon.", 16, UiStyle.TEXT_DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(none)
		return column
	var rows := _trinket_list(column, "The estate's trinkets", 0.0, 330.0)
	for trinket: TrinketDef in wearable:
		var reason := campaign.can_wear(hero, trinket)
		var put_on := _action("Wear", func() -> void: _after(campaign.wear(hero, trinket)))
		put_on.disabled = reason != ""
		put_on.tooltip_text = reason
		rows.add_child(_trinket_row(trinket, [put_on]))
	return column


## A section title in gold with a dim note beside it.
func _heading(title: String, note: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_label(title, 24, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	var aside := _label(note, 16, UiStyle.TEXT_DIM)
	aside.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(aside)
	return row


## A thin bar filled to `fraction`, for XP.
func _meter(fraction: float) -> Control:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(200, 12)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.draw.connect(func() -> void:
		var rect := Rect2(Vector2.ZERO, bar.size)
		bar.draw_rect(rect, UiStyle.HP_EMPTY)
		bar.draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0.0, 1.0), rect.size.y)),
				UiStyle.GOLD.darkened(0.25))
		bar.draw_rect(rect, UiStyle.HP_FRAME, false, 1.5))
	return bar


## Stress as the combat screen shows it: 3 small pips then 7 large, lit up to `stress`.
func _stress_pips(stress: int) -> Control:
	var pips := Control.new()
	pips.custom_minimum_size = Vector2(0, 16)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.draw.connect(func() -> void:
		var x := 0.0
		for i in Rules.STRESS_MAX:
			var side := 9.0 if i < 3 else 14.0
			pips.draw_rect(Rect2(x, (pips.size.y - side) / 2.0, side, side),
					UiStyle.STRESS_ON if i < stress else UiStyle.STRESS_OFF)
			x += side + 4.0)
	return pips


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
		# The hero list keeps its width; the detail column takes the rest.
		column.size_flags_horizontal = Control.SIZE_FILL if width == 300.0 else Control.SIZE_EXPAND_FILL
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


func _weapon_text(rank: int) -> String:
	var steps := rank - 1
	var text := "+%d%% damage, +%d%% crit" % [roundi(steps * CampaignRules.WEAPON_DAMAGE_PER_RANK * 100),
			roundi(steps * CampaignRules.WEAPON_CRIT_PER_RANK * 100)]
	var speed := Growth.weapon_speed_bonus(rank)
	return text + (", +%d speed" % speed if speed > 0 else "")


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
	if _atmosphere and _stage:
		_atmosphere.set_lights(LAMPS, _stage.position, _stage.scale.x)
	queue_redraw()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_atmosphere = Atmosphere.new(0.08)
	add_child(_atmosphere)
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
	_window_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The window scrolls when its content runs long, like a building with many wounded.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_window_body)
	frame.add_child(scroll)

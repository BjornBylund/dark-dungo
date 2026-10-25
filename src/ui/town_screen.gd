## The hamlet, DD1-style: click a building to open its window, the roster runs
## down the right, and the week, gold and heirlooms sit along the top. Every
## action goes through Game.campaign and is saved straight away. Embark (or the
## mission board) opens the expedition map.
## Authored for 1920x1080 on a centred stage, like the combat screen. In the
## phone layout the hamlet shrinks to fit and the bar, roster and windows sit
## on top at full size, the windows filling the screen and scrolling.
extends Control

const STAGE_SIZE := Vector2(1920, 1080)
## Clickable areas on the hamlet picture (art/backgrounds/hamlet.svg).
const BUILDINGS := [
	[&"stagecoach", "Stagecoach", Rect2(40, 480, 370, 320)],
	[&"blacksmith", "Blacksmith", Rect2(390, 420, 300, 300)],
	[&"guild", "Guild", Rect2(720, 320, 280, 410)],
	[&"abbey", "Abbey", Rect2(1040, 260, 260, 480)],
	[&"board", "Embark", Rect2(1330, 560, 240, 250)],
]
const ABBEY_UPGRADES := ["More stress relief", "Prices -15%", "A second slot per activity",
		"More stress relief", "Prices -15% more", "A third slot per activity"]

var _stage: Control
## Where the bar, roster and windows live: the stage itself on desktop, a layer
## over the whole screen in the phone layout.
var _ui: Control
var _bar: EstateBar
var _roster_panel: PanelContainer
var _roster: VBoxContainer
var _hover_label: Label
var _window: PanelContainer
var _window_title: Label
var _window_message: Label
var _window_body: VBoxContainer
## Rebuilds whichever window is open, after an action changes the campaign.
var _rebuild_window: Callable
## The hero picked in a building window.
var _selected: HeroRecord


func _ready() -> void:
	if Game.campaign == null:
		Game.go_to_menu.call_deferred()
		return
	theme = UiStyle.make_theme()
	_build()
	resized.connect(_center_stage)
	_center_stage()
	_refresh()
	if "--autoplay" in OS.get_cmdline_user_args():
		_autoplay_embark()


## With `-- --autoplay` the town plays itself: hire whoever has arrived, treat
## the wounded it can afford, then embark on the first mission with the first
## heroes who can go (or wait out the week if nobody can).
func _autoplay_embark() -> void:
	await get_tree().create_timer(1.5).timeout
	var campaign := _campaign()
	for hero in campaign.stagecoach():
		campaign.hire(hero)
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
	for child in _roster.get_children():
		child.queue_free()
	for hero in campaign.roster():
		var badge := HeroBadge.new()
		var status := _status(hero)
		badge.setup(hero, status[0], status[1])
		badge.pressed.connect(_open_hero.bind(hero))
		_roster.add_child(badge)
	if _window.visible and _rebuild_window.is_valid():
		_rebuild_window.call()


## [tag, colour] describing where a hero is this week.
func _status(hero: HeroRecord) -> Array:
	if hero.wounded:
		return ["WOUNDED", UiStyle.DAMAGE]
	if hero.abbey_activity >= 0:
		return ["AT THE ABBEY", UiStyle.GOLD]
	return ["", UiStyle.GREY]


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
	match id:
		&"stagecoach":
			_open("Stagecoach", _build_stagecoach)
		&"blacksmith":
			_open("Blacksmith", _build_blacksmith)
		&"guild":
			_open("Guild", _build_guild)
		&"abbey":
			_open("Abbey", _build_abbey)
		&"board":
			Game.go_to_expedition()


func _open_hero(hero: HeroRecord) -> void:
	_selected = hero
	_open(hero.display_name, _build_hero_sheet)


func _build_stagecoach() -> void:
	var campaign := _campaign()
	_text("A new hero arrives each week. Hiring is free.", 18, UiStyle.TEXT_DIM)
	var waiting := campaign.stagecoach()
	for hero in waiting:
		var row := _row()
		var badge := HeroBadge.new()
		badge.setup(hero)
		row.add_child(badge)
		row.add_child(_action("Hire", func() -> void: _after(campaign.hire(hero))))
	if waiting.is_empty():
		var next := campaign.heroes.filter(func(h: HeroRecord) -> bool: return not h.arrived)
		_text("Next week: the %s arrives." % next[0].display_name if not next.is_empty()
				else "Every hero has arrived.", 18)
	var level := campaign.buildings[&"stagecoach"]
	_section("Experienced arrivals")
	_text("New heroes arrive at level %d." % level, 17)
	_upgrade_row(&"stagecoach", "New heroes arrive at level %d" % (level + 1))


func _build_blacksmith() -> void:
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
	_section("Forges")
	_upgrade_row(&"weaponsmith", "Weapons up to rank %d" % (campaign.buildings[&"weaponsmith"] + 2))
	_upgrade_row(&"armorsmith", "Armour up to rank %d" % (campaign.buildings[&"armorsmith"] + 2))


func _build_guild() -> void:
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
	_section("Instructors")
	_upgrade_row(&"guild", "Skills up to rank %d" % (campaign.buildings[&"guild"] + 2))


func _build_abbey() -> void:
	var campaign := _campaign()
	var columns := _columns()
	_hero_picker(columns[0], func(hero: HeroRecord) -> String: return "Stress %d" % hero.stress)
	var right: VBoxContainer = columns[1]
	right.add_child(_label("Heroes sent here miss this week's mission; the stress comes off when the week ends.",
			16, UiStyle.TEXT_DIM))
	for activity in CampaignRules.ABBEY_ACTIVITIES.size():
		var occupants := campaign.abbey_occupants(activity)
		var title := "%s   -%d stress   %d/%d" % [CampaignRules.ABBEY_ACTIVITIES[activity],
				campaign.abbey_relief(activity), occupants.size(), campaign.abbey_slots()]
		right.add_child(_label(title, 22, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		for hero in occupants:
			row.add_child(_action("%s  (cancel)" % hero.display_name, func() -> void:
				campaign.cancel_abbey(hero)
				_after("")))
		if _selected:
			var hero := _selected
			var button := _action("Send %s  %s gold" % [hero.display_name, UiStyle.gold_text(campaign.abbey_price(hero, activity))],
					func() -> void: _after(campaign.send_to_abbey(hero, activity)))
			var reason := campaign.can_send_to_abbey(hero, activity)
			button.disabled = reason != ""
			button.tooltip_text = reason
			row.add_child(button)
		right.add_child(row)
	var wounded := campaign.roster().filter(func(h: HeroRecord) -> bool: return h.wounded)
	if not wounded.is_empty():
		_section("Wounded")
		_text("Wounded heroes sit out this week, or can be treated now.", 16, UiStyle.TEXT_DIM)
		for hero: HeroRecord in wounded:
			_window_body.add_child(_action("Treat %s  %s gold" % [hero.display_name, UiStyle.gold_text(campaign.treatment_price(hero))],
					func() -> void: _after(campaign.treat(hero))))
	var level := campaign.buildings[&"abbey"]
	_section("Abbey")
	_upgrade_row(&"abbey", ABBEY_UPGRADES[level] if level < ABBEY_UPGRADES.size() else "")


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
	var status: String = _status(hero)[0]
	info.add_child(_label("Stress %d / %d%s" % [hero.stress, Rules.STRESS_MAX, "   " + status if status != "" else ""], 20))
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


func _upgrade_row(id: StringName, next_effect: String) -> void:
	var campaign := _campaign()
	var cost := campaign.building_upgrade_cost(id)
	var row := _row()
	var building_label := _label("%s, level %d" % [CampaignRules.BUILDING_NAMES[id], campaign.buildings[id]], 18)
	building_label.custom_minimum_size = Vector2(260, 0)
	row.add_child(building_label)
	if cost.is_empty():
		row.add_child(_label("Fully upgraded.", 16, UiStyle.TEXT_DIM))
		return
	var button := _action("Upgrade  " + _cost_text(cost), func() -> void: _after(campaign.upgrade_building(id)))
	row.add_child(button)
	row.add_child(_label(next_effect, 16, UiStyle.TEXT_DIM))


func _weapon_text(rank: int) -> String:
	var steps := rank - 1
	var text := "+%d%% damage, +%d%% crit" % [roundi(steps * CampaignRules.WEAPON_DAMAGE_PER_RANK * 100),
			roundi(steps * CampaignRules.WEAPON_CRIT_PER_RANK * 100)]
	var speed := Growth.weapon_speed_bonus(rank)
	return text + (", +%d speed" % speed if speed > 0 else "")


func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for heirloom: StringName in cost:
		parts.append("%d %s" % [cost[heirloom], CampaignRules.HEIRLOOM_NAMES[heirloom]])
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

	for building: Array in BUILDINGS:
		var hotspot := Control.new()
		hotspot.position = (building[2] as Rect2).position
		hotspot.size = (building[2] as Rect2).size
		hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hotspot.mouse_entered.connect(func() -> void:
			_hover_label.text = building[1]
			_hover_label.position = Vector2(hotspot.position.x + hotspot.size.x / 2.0 - 200, hotspot.position.y - 52)
			_hover_label.show())
		hotspot.mouse_exited.connect(_hover_label_hide)
		hotspot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_open_building(building[0]))
		_stage.add_child(hotspot)

	_hover_label = _label("", 34, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	_hover_label.size = Vector2(400, 50)
	_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hover_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hover_label.add_theme_constant_override("outline_size", 10)
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_label.hide()
	_stage.add_child(_hover_label)

	# Top band: week, gold and heirlooms, Embark, and a way back to the menu.
	_bar = EstateBar.new()
	_ui.add_child(_bar)
	var embark := _action("Embark", Game.go_to_expedition)
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
	roster_box.add_child(_label("Roster", 28, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	_roster = VBoxContainer.new()
	_roster.add_theme_constant_override("separation", 6)
	roster_box.add_child(UiStyle.scroll_on_phone(_roster))

	# One building window at a time; the phone layout fills the screen with it and scrolls.
	_window = PanelContainer.new()
	_window.position = Vector2(60, 90)
	_window.size = Vector2(1500, 960)
	_window.add_theme_stylebox_override("panel", UiStyle.box(Color("0e0b0cfa"), Color("4a3e34"), 1, 4))
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
	header.add_child(close)
	_window_message = _label("", 17, UiStyle.DAMAGE.lightened(0.3))
	frame.add_child(_window_message)
	_window_body = VBoxContainer.new()
	_window_body.add_theme_constant_override("separation", 10)
	frame.add_child(UiStyle.scroll_on_phone(_window_body))


func _hover_label_hide() -> void:
	_hover_label.hide()

## DD1's expedition map: the land beyond the hamlet with each region's quests as
## markers, the chosen quest's details top left, the roster down the right and
## the lineup along the bottom. Embark starts the first fight; Esc goes back to
## town. Authored for 1920x1080 on a centred stage, like the other screens.
## The phone layout keeps the map and quest panel, with bigger quest shields,
## and moves the lineup and roster onto a party sheet opened from a button.
extends Control

const STAGE_SIZE := Vector2(1920, 1080)
const MARKER_GAP := 12.0
const SLOT_FIGURE := 150.0
const PHONE_SLOT_FIGURE := 150.0
## Quest shields and region names grow by this much on phones, so they stay easy to tap.
const PHONE_MARKER_SCALE := 1.8
const SHADE_BEHIND: Shader = preload("res://src/ui/shade_behind.gdshader")

var _stage: Control
## The phone layout's full-screen layer for the bar, quest panel and party sheet.
var _ui: Control
var _bar: EstateBar
var _map: Control
var _quest_panel: PanelContainer
var _quest: VBoxContainer
var _roster: BoxContainer
var _lineup: HBoxContainer
## The bonds within the chosen party, under the lineup.
var _bonds: Label
var _embark: Button
var _reason: Label
var _party_button: Button
var _sheet: Control
var _sheet_box: VBoxContainer
## The quest chosen on the map, and the party in rank order (index 0 in rank 1).
var _mission: Mission
var _party: Array[HeroRecord] = []
## On touch screens: the rank of the hero picked up to swap, or 0.
var _picked := 0


func _ready() -> void:
	if Game.campaign == null:
		Game.go_to_menu.call_deferred()
		return
	theme = UiStyle.make_theme()
	_mission = _campaign().board.front()
	_build()
	resized.connect(func() -> void:
		_center_stage()
		_refresh_map())
	_center_stage()
	_refresh()


func _campaign() -> Campaign:
	return Game.campaign


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var background: Texture2D = _campaign().def.expedition_background if Game.campaign else null
	if background and _stage:
		draw_texture_rect(background, Rect2(_stage.position, STAGE_SIZE * _stage.scale), false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		Game.go_to_town()


# --- Refreshing ---

func _refresh() -> void:
	var campaign := _campaign()
	if _mission not in campaign.board:
		_mission = campaign.board.front()
	_party.assign(_party.filter(_can_join))
	_bar.refresh(campaign)
	_refresh_map()
	_refresh_quest()
	_refresh_roster()
	_refresh_lineup()
	var reason := campaign.can_embark(_mission, _party)
	_embark.disabled = reason != ""
	_reason.text = reason
	if _party_button:
		_party_button.text = "Party  %d/4" % _party.size()


## Each region's quests side by side at its spot on the map, its name beneath.
func _refresh_map() -> void:
	_clear(_map)
	var grow := PHONE_MARKER_SCALE if Device.phone else 1.0
	var marker_size := QuestMarker.SIZE * grow
	for region in _campaign().def.regions:
		var quests := _campaign().board.filter(func(m: Mission) -> bool: return m.region == region)
		var width := quests.size() * marker_size.x + (quests.size() - 1) * MARKER_GAP
		var spot := region.map_position
		if Device.phone:
			# Keep the bigger shields clear of the top bar.
			spot.y = maxf(spot.y, (EstateBar.HEIGHT + 8.0) / _stage.scale.y + marker_size.y / 2.0)
		if not _campaign().region_open(region):
			_map.add_child(_closed_landmark(region))
			var lock := Control.new()
			lock.size = Vector2(80, 80) * grow
			lock.position = spot - lock.size / 2.0
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lock.draw.connect(func() -> void: UiStyle.draw_lock(lock, lock.size / 2.0, lock.size.y * 0.8))
			_map.add_child(lock)
		for i in quests.size():
			var marker := QuestMarker.new()
			marker.setup(quests[i])
			marker.scale = Vector2(grow, grow)
			marker.position = spot + Vector2(-width / 2.0 + i * (marker_size.x + MARKER_GAP), -marker_size.y / 2.0)
			marker.button_pressed = quests[i] == _mission
			marker.pressed.connect(func() -> void:
				_mission = marker.mission
				_refresh())
			_map.add_child(marker)
		var open := _campaign().region_open(region)
		var name_label := _label(region.display_name, roundi(30 * grow), UiStyle.GOLD if open else UiStyle.TEXT_DIM,
				UiStyle.DISPLAY_FONT)
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", roundi(10 * grow))
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.size = Vector2(320, 40) * grow
		name_label.position = spot + Vector2(-160 * grow, marker_size.y / 2.0 + 4)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map.add_child(name_label)
		var below := name_label.position + Vector2(0, 40 * grow)
		var status := _region_status(region)
		if status == "":
			var bar := BossProgressBar.new()
			var share := _campaign().progress_for(_mission) if _mission.region == region else 0.0
			bar.setup(_campaign().boss_progress(region), share)
			bar.scale = Vector2(grow, grow)
			bar.position = below + Vector2(160 * grow - BossProgressBar.SIZE.x * grow / 2.0, 4 * grow)
			_map.add_child(bar)
			continue
		var progress := _label(status, roundi(18 * grow), UiStyle.TEXT if open else UiStyle.TEXT_DIM, UiStyle.DISPLAY_FONT)
		progress.add_theme_color_override("font_outline_color", Color.BLACK)
		progress.add_theme_constant_override("outline_size", roundi(8 * grow))
		progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress.size = Vector2(320, 26) * grow
		progress.position = below - Vector2(0, 2 * grow)
		progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map.add_child(progress)


## Greys out a closed region's landmark in the map picture, glow and all.
func _closed_landmark(region: RegionDef) -> Control:
	var shade := ColorRect.new()
	shade.position = region.landmark.position
	shade.size = region.landmark.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = SHADE_BEHIND
	shade.material = material
	return shade


## What opens a closed region, "Boss awaits", "Conquered", or "" while its boss
## progress bar is filling.
func _region_status(region: RegionDef) -> String:
	var campaign := _campaign()
	if not campaign.region_open(region):
		var before := campaign.def.regions[campaign.def.regions.find(region) - 1]
		return "Opens when %s falls" % before.boss.display_name if before.boss else "Closed"
	if campaign.boss_conquered(region):
		return "Conquered"
	if campaign.boss_ready(region):
		return "Boss awaits"
	return ""


func _refresh_quest() -> void:
	_clear(_quest)
	var campaign := _campaign()
	var mission := _mission
	if mission.region:
		_quest.add_child(_label(mission.region.display_name, 20, UiStyle.TEXT_DIM, UiStyle.DISPLAY_FONT))
	_quest.add_child(_label(mission.title(), 40, QuestMarker.tier_color(mission.tier), UiStyle.DISPLAY_FONT))
	_quest.add_child(_label("Level %d   %d columns" % [mission.level(), CampaignRules.MAP_COLUMNS[mission.length]], 18))
	_quest.add_child(_heading("Goal"))
	var goal_text := "Reach the end of the map and win the final fight."
	if mission.boss:
		goal_text = "Reach the end of the map and defeat %s." % mission.region.boss.display_name
		if campaign.boss_tier(mission.region) == 0 and not campaign.recruit_choices().is_empty():
			goal_text += "\nThe first victory lets a new hero join."
	var goal := _label(goal_text, 18)
	goal.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if Device.phone else TextServer.AUTOWRAP_OFF
	_quest.add_child(goal)
	_quest.add_child(_heading("Rewards"))
	_quest.add_child(_label("%s gold on completion" % UiStyle.gold_text(mission.completion_gold()), 20))
	_quest.add_child(_label("%s gold for each fight won" % UiStyle.gold_text(mission.fight_gold()), 20))
	var heirloom := HBoxContainer.new()
	heirloom.add_theme_constant_override("separation", 8)
	var icon := TextureRect.new()
	icon.texture = load("res://art/heirlooms/%s.svg" % mission.heirloom)
	icon.custom_minimum_size = Vector2(30, 30)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heirloom.add_child(icon)
	heirloom.add_child(_label("%d %s" % [mission.heirloom_amount(), CampaignRules.HEIRLOOM_NAMES[mission.heirloom]],
			20))
	_quest.add_child(heirloom)
	_quest.add_child(_label("%d XP for each hero" % mission.xp(), 20))
	var share := campaign.progress_for(mission)
	if share > 0.0:
		_quest.add_child(_label("+%s boss progress" % UiStyle.percent(share), 20))
	if campaign.can_wait() == "":
		var note := _label("Nobody is fit to go. Treat the wounded at the Abbey, or let the week pass.", 16,
				UiStyle.TEXT_DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_quest.add_child(note)
		_quest.add_child(_action("Wait out the week", func() -> void:
			if campaign.wait_week() == "":
				Game.save()
				Game.go_to_town()))


func _refresh_roster() -> void:
	_clear(_roster)
	for hero in _campaign().roster():
		var badge := HeroBadge.new()
		var place := _party.find(hero)
		var tag := _eligibility_tag(hero)
		badge.setup(hero, "RANK %d" % (place + 1) if place >= 0 else tag[0], UiStyle.GOLD if place >= 0 else tag[1],
				not _can_join(hero))
		badge.button_pressed = place >= 0
		badge.disabled = not _can_join(hero)
		badge.pressed.connect(_on_roster_pressed.bind(hero))
		_roster.add_child(badge)


## Adds a hero at the back of the lineup, or takes them out. With a hero picked
## up on a touch screen, a hero from the roster takes their slot instead.
func _on_roster_pressed(hero: HeroRecord) -> void:
	if _picked > 0 and hero not in _party:
		_party[_picked - 1] = hero
	elif hero in _party:
		_party.erase(hero)
	elif _party.size() < 4:
		_party.append(hero)
	_picked = 0
	_refresh()


## Rank 4 on the left to rank 1 on the right, as the party stands in combat.
func _refresh_lineup() -> void:
	_clear(_lineup)
	if _picked > _party.size():
		_picked = 0
	for rank in range(4, 0, -1):
		var hero: HeroRecord = _party[rank - 1] if rank <= _party.size() else null
		var short := _campaign().levels_short(hero, _mission) if hero else 0
		var slot := FormationSlot.new()
		slot.setup(rank, hero, "+%d stress" % (short * CampaignRules.UNDERLEVEL_STRESS) if short > 0 else "",
				UiStyle.STRESS_TEXT, PHONE_SLOT_FIGURE if Device.phone else SLOT_FIGURE)
		slot.picked = rank == _picked
		slot.clicked.connect(_on_slot_clicked)
		# Deferred so the lineup isn't rebuilt while the viewport is still finishing the drop.
		slot.dropped.connect(_place_in_lineup, CONNECT_DEFERRED)
		_lineup.add_child(slot)
	var bonds := _campaign().bonds
	var pairs: Array[String] = []
	for i in _party.size():
		for j in range(i + 1, _party.size()):
			var level := bonds.level(_party[i], _party[j])
			if level > Bonds.Level.STRANGERS:
				pairs.append("%s & %s %s" % [_party[i].display_name, _party[j].display_name, Bonds.level_name(level)])
	_bonds.text = "Bonds: " + ", ".join(pairs) if not pairs.is_empty() else "No bonds in this party yet."


## With a mouse, clicking a hero takes them out. On a touch screen the first
## tap picks a hero up, a tap on another slot swaps them (or moves them to the
## back, for an empty slot), and a second tap on the same hero takes them out.
func _on_slot_clicked(rank: int) -> void:
	if not Device.touch:
		if rank <= _party.size():
			_party.remove_at(rank - 1)
	elif _picked == 0:
		if rank <= _party.size():
			_picked = rank
	elif _picked == rank:
		_party.remove_at(rank - 1)
		_picked = 0
	else:
		var hero := _party[_picked - 1]
		_picked = 0
		_place_in_lineup(hero, rank)
		return
	_refresh()


func _can_join(hero: HeroRecord) -> bool:
	return _campaign().eligibility(hero, _mission) in [Campaign.Eligibility.OK, Campaign.Eligibility.UNDERLEVELED]


## A hero dropped on a lineup slot. One already in the lineup swaps places with
## whoever stands there; a new one takes the slot and the occupant steps out.
## Empty slots are always behind the last hero, so a drop there joins the back.
func _place_in_lineup(hero: HeroRecord, rank: int) -> void:
	if not _can_join(hero):
		return
	var from := _party.find(hero)
	var to := rank - 1
	if from >= 0:
		to = mini(to, _party.size() - 1)
		_party[from] = _party[to]
		_party[to] = hero
	elif to < _party.size():
		_party[to] = hero
	else:
		_party.append(hero)
	_refresh()


## [tag, colour] for why a hero can't go on the chosen quest, or what it costs them.
func _eligibility_tag(hero: HeroRecord) -> Array:
	match _campaign().eligibility(hero, _mission):
		Campaign.Eligibility.WOUNDED, Campaign.Eligibility.BUSY:
			return UiStyle.hero_status(hero)
		Campaign.Eligibility.WILL_NOT_GO:
			return ["WILL NOT GO", UiStyle.GREY]
		Campaign.Eligibility.UNDERLEVELED:
			return ["+%d STRESS" % (_campaign().levels_short(hero, _mission) * CampaignRules.UNDERLEVEL_STRESS),
					UiStyle.STRESS_TEXT]
	return ["", UiStyle.GREY]


func _on_embark() -> void:
	if _campaign().embark(_mission, _party):
		Game.go_to_map()


# --- Building the screen ---

func _center_stage() -> void:
	if _stage:
		Device.fit_stage(_stage, size)
	if Device.phone and _ui:
		# The map sits at the right so the quest panel covers as little of it as possible.
		_stage.position.x = size.x - STAGE_SIZE.x * _stage.scale.x
		_ui.size = size
		_bar.fit_width(size.x)
		_quest_panel.position = Vector2(8, EstateBar.HEIGHT + 6)
		_party_button.position = size - _party_button.size - Vector2(12, 12)
		_sheet.size = size
		_sheet_box.position = Vector2(12, 10)
		_sheet_box.size = size - Vector2(24, 20)
	queue_redraw()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(Atmosphere.new(0.1))
	_stage = Control.new()
	_stage.size = STAGE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_map = Control.new()
	_map.size = STAGE_SIZE
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_map)

	if Device.phone:
		_build_phone()
		return

	_bar = EstateBar.new()
	_stage.add_child(_bar)
	var back := Button.new()
	back.text = "Back to town (Esc)"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(Game.go_to_town)
	_bar.add_button(back)

	# The chosen quest, top left.
	_quest_panel = PanelContainer.new()
	_quest_panel.position = Vector2(40, 88)
	_quest_panel.custom_minimum_size = Vector2(440, 0)
	_stage.add_child(_quest_panel)
	_quest = VBoxContainer.new()
	_quest.add_theme_constant_override("separation", 6)
	_quest_panel.add_child(_quest)

	# Roster down the right.
	var roster_panel := PanelContainer.new()
	roster_panel.position = Vector2(STAGE_SIZE.x - 340, 84)
	roster_panel.size = Vector2(324, 0)
	_stage.add_child(roster_panel)
	var roster_box := VBoxContainer.new()
	roster_box.add_theme_constant_override("separation", 6)
	roster_panel.add_child(roster_box)
	roster_box.add_child(_label("Roster", 28, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	_roster = VBoxContainer.new()
	_roster.add_theme_constant_override("separation", 6)
	roster_box.add_child(_roster)

	# The lineup along the bottom, with Embark beside it.
	var lineup_panel := PanelContainer.new()
	lineup_panel.position = Vector2(40, 662)
	_stage.add_child(lineup_panel)
	var lineup_box := VBoxContainer.new()
	lineup_box.add_theme_constant_override("separation", 4)
	lineup_panel.add_child(lineup_box)
	var lineup_title := HBoxContainer.new()
	lineup_title.add_theme_constant_override("separation", 18)
	lineup_box.add_child(lineup_title)
	lineup_title.add_child(_label("Lineup", 28, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	lineup_title.add_child(_label("Rank 1 is the front. Click or drag heroes in, drag to reorder, click to take out.",
			15, UiStyle.TEXT_DIM))
	_lineup = HBoxContainer.new()
	_lineup.add_theme_constant_override("separation", 16)
	lineup_box.add_child(_lineup)
	_bonds = _label("", 16, UiStyle.TEXT_DIM)
	lineup_box.add_child(_bonds)

	var embark_box := VBoxContainer.new()
	embark_box.position = Vector2(950, 940)
	embark_box.size = Vector2(380, 110)
	embark_box.alignment = BoxContainer.ALIGNMENT_END
	_stage.add_child(embark_box)
	_reason = _label("", 16, UiStyle.TEXT_DIM)
	embark_box.add_child(_reason)
	_embark = _action("Embark", _on_embark)
	_embark.theme_type_variation = &"PrimaryButton"
	_embark.custom_minimum_size = Vector2(320, 72)
	_embark.add_theme_font_override("font", UiStyle.DISPLAY_FONT)
	_embark.add_theme_font_size_override("font_size", 36)
	embark_box.add_child(_embark)


## Phones: the bar and a compact quest panel over the map, a Party button, and
## the party sheet (lineup above a scrolling roster strip, with Embark).
func _build_phone() -> void:
	_ui = Control.new()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)
	_bar = EstateBar.new()
	_ui.add_child(_bar)
	var back := Button.new()
	back.text = "Town"
	back.focus_mode = Control.FOCUS_NONE
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(Game.go_to_town)
	_bar.add_button(back)

	_quest_panel = PanelContainer.new()
	_quest_panel.custom_minimum_size = Vector2(300, 0)
	_ui.add_child(_quest_panel)
	_quest = VBoxContainer.new()
	_quest.add_theme_constant_override("separation", 2)
	_quest_panel.add_child(_quest)

	_party_button = _action("", func() -> void: _sheet.show())
	_party_button.custom_minimum_size = Vector2(240, 60)
	_party_button.size = _party_button.custom_minimum_size
	_party_button.add_theme_font_override("font", UiStyle.DISPLAY_FONT)
	_party_button.add_theme_font_size_override("font_size", 30)
	_ui.add_child(_party_button)

	_sheet = Control.new()
	_sheet.hide()
	_ui.add_child(_sheet)
	var dim := ColorRect.new()
	dim.color = Color("0b0809f4")
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.add_child(dim)
	_sheet_box = VBoxContainer.new()
	_sheet_box.add_theme_constant_override("separation", 8)
	_sheet.add_child(_sheet_box)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	_sheet_box.add_child(header)
	header.add_child(_label("Lineup", 30, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	var hint := _label("Rank 1 is the front. Tap a hero to pick them up, then a slot to swap.", 15, UiStyle.TEXT_DIM)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(hint)
	_reason = _label("", 15, UiStyle.TEXT_DIM)
	header.add_child(_reason)
	var map_button := _action("Map", func() -> void:
		_picked = 0
		_sheet.hide()
		_refresh())
	map_button.custom_minimum_size = Vector2(100, 52)
	header.add_child(map_button)
	_embark = _action("Embark", _on_embark)
	_embark.theme_type_variation = &"PrimaryButton"
	_embark.custom_minimum_size = Vector2(170, 52)
	_embark.add_theme_font_override("font", UiStyle.DISPLAY_FONT)
	_embark.add_theme_font_size_override("font_size", 28)
	header.add_child(_embark)
	_lineup = HBoxContainer.new()
	_lineup.alignment = BoxContainer.ALIGNMENT_CENTER
	_lineup.add_theme_constant_override("separation", 10)
	_sheet_box.add_child(_lineup)
	_bonds = _label("", 15, UiStyle.TEXT_DIM)
	_bonds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bonds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sheet_box.add_child(_bonds)
	var strip := ScrollContainer.new()
	strip.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip.custom_minimum_size = Vector2(0, HeroBadge.SIZE.y + 14)
	_sheet_box.add_child(strip)
	_roster = HBoxContainer.new()
	_roster.add_theme_constant_override("separation", 8)
	strip.add_child(_roster)


# --- Pieces ---

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _heading(text: String) -> Label:
	var heading := _label(text, 26, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	heading.custom_minimum_size.y = 30 if Device.phone else 40
	heading.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return heading


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

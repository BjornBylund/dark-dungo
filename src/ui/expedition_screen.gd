## DD1's expedition map: the land beyond the hamlet with each region's quests as
## markers, the chosen quest's details top left, the roster down the right and
## the lineup along the bottom. Embark starts the first fight; Esc goes back to
## town. Authored for 1920x1080 on a centred stage, like the other screens.
extends Control

const STAGE_SIZE := Vector2(1920, 1080)
const MARKER_GAP := 12.0
const SLOT_FIGURE := 150.0

var _stage: Control
var _bar: EstateBar
var _map: Control
var _quest: VBoxContainer
var _roster: VBoxContainer
var _lineup: HBoxContainer
var _embark: Button
var _reason: Label
## The quest chosen on the map, and the party in rank order (index 0 in rank 1).
var _mission: Mission
var _party: Array[HeroRecord] = []


func _ready() -> void:
	if Game.campaign == null:
		Game.go_to_menu.call_deferred()
		return
	theme = UiStyle.make_theme()
	_mission = _campaign().board.front()
	_build()
	resized.connect(_center_stage)
	_center_stage()
	_refresh()


func _campaign() -> Campaign:
	return Game.campaign


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var background: Texture2D = _campaign().def.expedition_background if Game.campaign else null
	if background and _stage:
		draw_texture_rect(background, Rect2(_stage.position, STAGE_SIZE), false)


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


## Each region's quests side by side at its spot on the map, its name beneath.
func _refresh_map() -> void:
	_clear(_map)
	for region in _campaign().def.regions:
		var quests := _campaign().board.filter(func(m: Mission) -> bool: return m.region == region)
		var width := quests.size() * QuestMarker.SIZE.x + (quests.size() - 1) * MARKER_GAP
		for i in quests.size():
			var marker := QuestMarker.new()
			marker.setup(quests[i])
			marker.position = region.map_position + Vector2(-width / 2.0 + i * (QuestMarker.SIZE.x + MARKER_GAP),
					-QuestMarker.SIZE.y / 2.0)
			marker.button_pressed = quests[i] == _mission
			marker.pressed.connect(func() -> void:
				_mission = marker.mission
				_refresh())
			_map.add_child(marker)
		var name_label := _label(region.display_name, 30, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", 10)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.size = Vector2(320, 40)
		name_label.position = region.map_position + Vector2(-160, QuestMarker.SIZE.y / 2.0 + 4)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_map.add_child(name_label)


func _refresh_quest() -> void:
	_clear(_quest)
	var campaign := _campaign()
	var mission := _mission
	if mission.region:
		_quest.add_child(_label(mission.region.display_name, 20, UiStyle.TEXT_DIM, UiStyle.DISPLAY_FONT))
	_quest.add_child(_label(mission.title(), 40, QuestMarker.tier_color(mission.tier), UiStyle.DISPLAY_FONT))
	_quest.add_child(_label("Level %d   %d columns" % [mission.level(), CampaignRules.MAP_COLUMNS[mission.length]], 18))
	_quest.add_child(_heading("Goal"))
	_quest.add_child(_label("Reach the end of the map and win the final fight.", 18))
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
	if campaign.can_wait() == "":
		var note := _label("Nobody is fit to go. Treat the wounded at the Abbey, or let the week pass.", 16,
				UiStyle.TEXT_DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_quest.add_child(note)
		_quest.add_child(_action("Wait out the week", func() -> void:
			if campaign.wait_week() == "":
				Game.save()
				_party.clear()
				_refresh()))


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
		badge.pressed.connect(func() -> void:
			if hero in _party:
				_party.erase(hero)
			elif _party.size() < 4:
				_party.append(hero)
			_refresh())
		_roster.add_child(badge)


## Rank 4 on the left to rank 1 on the right, as the party stands in combat.
func _refresh_lineup() -> void:
	_clear(_lineup)
	for rank in range(4, 0, -1):
		var hero: HeroRecord = _party[rank - 1] if rank <= _party.size() else null
		var short := _campaign().levels_short(hero, _mission) if hero else 0
		var slot := FormationSlot.new()
		slot.setup(rank, hero, "+%d stress" % (short * CampaignRules.UNDERLEVEL_STRESS) if short > 0 else "",
				UiStyle.STRESS_TEXT, SLOT_FIGURE)
		slot.clicked.connect(func(r: int) -> void:
			_party.remove_at(r - 1)
			_refresh())
		# Deferred so the lineup isn't rebuilt while the viewport is still finishing the drop.
		slot.dropped.connect(_place_in_lineup, CONNECT_DEFERRED)
		_lineup.add_child(slot)


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
		Campaign.Eligibility.WOUNDED:
			return ["WOUNDED", UiStyle.DAMAGE]
		Campaign.Eligibility.BUSY:
			return ["AT THE ABBEY", UiStyle.GOLD]
		Campaign.Eligibility.WILL_NOT_GO:
			return ["WILL NOT GO", UiStyle.GREY]
		Campaign.Eligibility.UNDERLEVELED:
			return ["+%d STRESS" % (_campaign().levels_short(hero, _mission) * CampaignRules.UNDERLEVEL_STRESS),
					UiStyle.STRESS_TEXT]
	return ["", UiStyle.GREY]


func _on_embark() -> void:
	if _campaign().embark(_mission, _party):
		Game.save()
		Game.go_to_map()


# --- Building the screen ---

func _center_stage() -> void:
	if _stage:
		_stage.position = ((size - STAGE_SIZE) / 2.0).floor()
	queue_redraw()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage = Control.new()
	_stage.size = STAGE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_map = Control.new()
	_map.size = STAGE_SIZE
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_map)

	_bar = EstateBar.new()
	_stage.add_child(_bar)
	var back := Button.new()
	back.text = "Back to town (Esc)"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(Game.go_to_town)
	_bar.add_button(back)

	# The chosen quest, top left.
	var quest_panel := PanelContainer.new()
	quest_panel.position = Vector2(40, 88)
	quest_panel.custom_minimum_size = Vector2(440, 0)
	_stage.add_child(quest_panel)
	_quest = VBoxContainer.new()
	_quest.add_theme_constant_override("separation", 6)
	quest_panel.add_child(_quest)

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

	var embark_box := VBoxContainer.new()
	embark_box.position = Vector2(950, 940)
	embark_box.size = Vector2(380, 110)
	embark_box.alignment = BoxContainer.ALIGNMENT_END
	_stage.add_child(embark_box)
	_reason = _label("", 16, UiStyle.TEXT_DIM)
	embark_box.add_child(_reason)
	_embark = _action("Embark", _on_embark)
	_embark.custom_minimum_size = Vector2(320, 72)
	_embark.add_theme_font_override("font", UiStyle.DISPLAY_FONT)
	_embark.add_theme_font_size_override("font_size", 36)
	embark_box.add_child(_embark)


# --- Pieces ---

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _heading(text: String) -> Label:
	var heading := _label(text, 26, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	heading.custom_minimum_size.y = 40
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

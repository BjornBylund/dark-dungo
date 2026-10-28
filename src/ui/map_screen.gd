## A mission in progress, like a Slay the Spire act: the map of rooms, the
## party's route so far and the rooms it can go to next. Fight rooms go to the
## combat screen and come back here; rests, caches and events open a panel over
## the map. The party panel shows each hero's HP, stress and carried tokens, the
## loot earned on the way, and Retreat.
## Authored for 1920x1080 on a centred stage, like the other screens. In the
## phone layout the map shrinks to fit with bigger room buttons, and the party
## strip and room panels sit on top at full size. On touch screens a tap on a
## room shows what it holds, with a Go button.
extends Control

const STAGE_SIZE := Vector2(1920, 1080)
## Where the rooms are spread, first column to the final room.
const MAP_AREA := Rect2(150, 130, 1620, 620)
const PATH_DIM := Color(0.55, 0.5, 0.45, 0.35)
const PATH_AHEAD := Color(0.85, 0.8, 0.7, 0.75)
## The worn earth of a corridor, and its darker edges.
const EARTH := Color("2e2420")
const EARTH_EDGE := Color("120d0e", 0.9)
## Points along each corridor's curve.
const COURSE_STEPS := 24
## How a corridor is drawn: one the party may take next, one taken, one left
## behind, or one further on.
enum Way { FAINT, BEHIND, AHEAD, TAKEN }
## Room buttons grow by this much on phones, so they stay easy to tap.
const PHONE_ROOM_SCALE := 1.6

var _stage: Control
## Where the menu button, party strip and room panel live: the stage on desktop,
## a layer over the whole screen in the phone layout.
var _ui: Control
var _band: ColorRect
var _top: HBoxContainer
var _menu: Button
var _bottom: PanelContainer
var _paths: Control
var _rooms: Control
var _buttons: Dictionary[int, RoomButton] = {}
var _token: PartyToken
## The token is walking to a room the party chose.
var _walking := false
var _week: Label
var _header: Label
var _party: HBoxContainer
var _loot: VBoxContainer
var _retreat: Button
var _confirm_retreat := false
var _overlay: Control
var _panel_title: Label
var _panel_text: Label
var _panel_buttons: VBoxContainer
## Extra content a panel may show between its text and buttons, like loadouts.
var _panel_extra: VBoxContainer
var _skills_button: Button
## Run with `-- --autoplay` to let the map play itself.
var _autoplay := "--autoplay" in OS.get_cmdline_user_args()


func _ready() -> void:
	if Game.campaign == null or Game.campaign.run == null:
		(Game.go_to_town if Game.campaign else Game.go_to_menu).call_deferred()
		return
	theme = UiStyle.make_theme()
	_build()
	resized.connect(_center_stage)
	_center_stage()
	var run := _run()
	if run.has_pending_fight():
		Game.go_to_battle.call_deferred()
		return
	_refresh()
	if not run.room_done:
		_open_room()
	elif not run.setting_out.is_empty():
		_show_panel("Setting out", "Some of the party set out at the end of their tether.\n\n" +
				"\n".join(run.setting_out), [["Onward", _close_panel]])
		run.setting_out.clear()
	if _autoplay:
		_autoplay_step()


func _run() -> MissionRun:
	return Game.campaign.run


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	var background: Texture2D = Game.campaign.def.map_background if Game.campaign else null
	if background and _stage:
		draw_texture_rect(background, Rect2(_stage.position, STAGE_SIZE * _stage.scale), false)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _confirm_retreat:
		_confirm_retreat = false
		_refresh()
		get_viewport().set_input_as_handled()


# --- The map ---

func _refresh() -> void:
	var run := _run()
	var mission := run.mission
	_week.text = "Week %d" % Game.campaign.week
	_header.text = "%s%s" % [mission.region.display_name + "   " if mission.region else "", mission.title()]
	for child in _rooms.get_children():
		child.queue_free()
	_buttons.clear()
	var reachable := run.next_rooms()
	var furthest := -1
	for id in run.visited:
		furthest = maxi(furthest, run.map.room(id).column)
	for room in run.map.rooms:
		var state := RoomButton.State.AHEAD
		if room.id == run.room_id:
			state = RoomButton.State.CURRENT
		elif room.id in run.visited:
			state = RoomButton.State.VISITED
		elif room in reachable:
			state = RoomButton.State.REACHABLE
		elif room.column <= furthest:
			state = RoomButton.State.PASSED_BY
		var button := RoomButton.new()
		var known := run.revealed(room)
		button.setup(room, state, _describe(room) if known else "Unknown", not known)
		var grow := _room_scale()
		button.scale = Vector2(grow, grow)
		button.position = _room_center(room) - button.size * grow / 2.0
		button.pressed.connect(_on_room_pressed.bind(room))
		_rooms.add_child(button)
		_buttons[room.id] = button
	_paths.queue_redraw()
	var front := run.party.filter(func(hero: HeroRecord) -> bool: return hero not in run.defeated)
	_token.hero = front[0].def if not front.is_empty() else null
	_token.scale = Vector2(_room_scale(), _room_scale())
	if not _walking:
		_token.position = _token_position(run.current_room() if run.room_id >= 0 else null)
	_refresh_party()


## Where the party token stands to point at `room`, or at the camp before the
## first: above it, or below it when the top band would hide the token.
func _token_position(room: MapRoom) -> Vector2:
	var s := _room_scale()
	var center := _camp() if room == null else _room_center(room)
	var reach := 26.0 * s if room == null else _room_radius(room) - 4.0
	# The top band in stage units; on phones it sits on top at full size.
	var band := _band.size.y / _stage.scale.y if Device.phone else _band.size.y
	_token.below = center.y - reach - PartyToken.SIZE.y * s < band + 8.0
	return center + Vector2(0, reach if _token.below else -reach) - _token.tip() * s


## Room buttons grow on phones, and shrink on long maps, so columns keep a gap
## for the paths between them (a smaller one on phones, where rooms must stay
## big enough to tap).
func _room_scale() -> float:
	var spacing := MAP_AREA.size.x / float(_run().map.columns - 1)
	if Device.phone:
		return minf(PHONE_ROOM_SCALE, spacing * 0.72 / RoomButton.SIZE)
	return minf(1.0, spacing * 0.55 / RoomButton.SIZE)


func _room_center(room: MapRoom) -> Vector2:
	var x := MAP_AREA.position.x + MAP_AREA.size.x * room.column / float(_run().map.columns - 1)
	if room.row < 0:
		return Vector2(x, MAP_AREA.get_center().y)
	return Vector2(x, MAP_AREA.position.y + MAP_AREA.size.y * (room.row + 0.5) / CampaignRules.MAP_ROWS)


## Where the party camps before the first room, left of the first column.
func _camp() -> Vector2:
	var spacing := MAP_AREA.size.x / float(_run().map.columns - 1)
	return Vector2(maxf(70.0, MAP_AREA.position.x - spacing * 0.6), MAP_AREA.get_center().y)


## Corridors as worn earth paths, gently bowed: the route taken marked with
## gold footsteps, the ways on from where the party stands with bright dashes,
## those left behind faded, the rest faint. The first column's start at the camp.
func _draw_paths() -> void:
	var run := _run()
	var reachable := run.next_rooms()
	var furthest := -1
	for id in run.visited:
		furthest = maxi(furthest, run.map.room(id).column)
	var camp_gap := 26.0 * _room_scale()
	for room in run.map.in_column(0):
		var way := Way.AHEAD if run.room_id < 0 else (Way.TAKEN if run.visited[0] == room.id else Way.BEHIND)
		# Up or down from the camp first, then in from the left, clear of the column's other rooms.
		var corner := Vector2(_camp().x, _room_center(room).y)
		_draw_corridor(_curve(_camp(), corner, _room_center(room), camp_gap, _room_radius(room)), way)
	for room in run.map.rooms:
		for exit in room.exits:
			var to := run.map.room(exit)
			var way := Way.FAINT
			var taken := run.visited.find(room.id)
			if taken >= 0 and taken + 1 < run.visited.size() and run.visited[taken + 1] == exit:
				way = Way.TAKEN
			elif room.id == run.room_id and to in reachable:
				way = Way.AHEAD
			elif to.column <= furthest:
				way = Way.BEHIND
			# The same bow every time for the same corridor.
			var bend := float((room.id * 37 + exit * 11) % 41 - 20) * _room_scale()
			_draw_corridor(_course(_room_center(room), _room_center(to), bend, _room_radius(room), _room_radius(to)), way)
	_draw_campfire(_camp())


func _room_radius(room: MapRoom) -> float:
	var side := RoomButton.FINALE_SIZE if room.type == MapRoom.Type.FINALE else RoomButton.SIZE
	return side * _room_scale() / 2.0 + 6.0


## A corridor's course: a curve from `from` to `to`, bowed sideways by `bend`.
func _course(from: Vector2, to: Vector2, bend: float, gap_from: float, gap_to: float) -> PackedVector2Array:
	return _curve(from, (from + to) / 2.0 + (to - from).orthogonal().normalized() * bend, to, gap_from, gap_to)


## A curve from `from` to `to` drawn towards `control`, stopping `gap_from` and
## `gap_to` short of its ends.
func _curve(from: Vector2, control: Vector2, to: Vector2, gap_from: float, gap_to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in COURSE_STEPS + 1:
		var t := float(i) / COURSE_STEPS
		var point := from.lerp(control, t).lerp(control.lerp(to, t), t)
		if point.distance_to(from) >= gap_from and point.distance_to(to) >= gap_to:
			points.append(point)
	return points


func _draw_corridor(points: PackedVector2Array, way: Way) -> void:
	if points.size() < 2:
		return
	var s := _room_scale()
	var fade := 0.45 if way == Way.BEHIND else 1.0
	_paths.draw_polyline(points, Color(EARTH_EDGE, fade), 24.0 * s, true)
	_paths.draw_polyline(points, Color(EARTH, fade), 15.0 * s, true)
	match way:
		Way.TAKEN:
			# Footsteps, left and right.
			var left := true
			for step: Array in _along(points, 15.0 * s, 6.0 * s):
				var at: Vector2 = step[0] + (step[1] as Vector2).orthogonal() * (3.5 * s if left else -3.5 * s)
				_paths.draw_circle(at, 2.6 * s, UiStyle.GOLD)
				left = not left
		Way.AHEAD:
			for step: Array in _along(points, 18.0 * s, 4.0 * s):
				_paths.draw_line(step[0], step[0] + step[1] * 10.0 * s, PATH_AHEAD, 4.0 * s, true)
		_:
			for step: Array in _along(points, 18.0 * s, 4.0 * s):
				_paths.draw_line(step[0], step[0] + step[1] * 8.0 * s, Color(PATH_DIM, PATH_DIM.a * fade), 3.0 * s, true)


## Points every `spacing` along `points`, starting `offset` in, each with the
## direction of travel there: [position, direction].
func _along(points: PackedVector2Array, spacing: float, offset: float) -> Array[Array]:
	var result: Array[Array] = []
	var next := offset
	var walked := 0.0
	for i in points.size() - 1:
		var length := points[i].distance_to(points[i + 1])
		if length <= 0.0:
			continue
		var direction := (points[i + 1] - points[i]) / length
		while next <= walked + length:
			result.append([points[i] + direction * (next - walked), direction])
			next += spacing
		walked += length
	return result


## Two crossed logs and a small fire, where the party set out from.
func _draw_campfire(at: Vector2) -> void:
	var s := _room_scale()
	_paths.draw_circle(at + Vector2(0, 6) * s, 22.0 * s, Color(1.0, 0.55, 0.2, 0.12))
	for tilt: float in [-0.5, 0.5]:
		var along := Vector2(cos(tilt), sin(tilt)) * 16.0 * s
		_paths.draw_line(at + Vector2(0, 10) * s - along, at + Vector2(0, 10) * s + along, Color("3a2416"), 6.0 * s)
	_paths.draw_colored_polygon(PackedVector2Array([at + Vector2(-9, 8) * s, at + Vector2(0, -16) * s,
			at + Vector2(9, 8) * s]), Color("e07a3a"))
	_paths.draw_colored_polygon(PackedVector2Array([at + Vector2(-4, 8) * s, at + Vector2(1, -5) * s,
			at + Vector2(5, 8) * s]), Color("f0c050"))


func _describe(room: MapRoom) -> String:
	var run := _run()
	match room.type:
		MapRoom.Type.FIGHT, MapRoom.Type.ELITE, MapRoom.Type.FINALE:
			var kind := "Boss" if room.type == MapRoom.Type.FINALE and run.mission.boss else room.type_name()
			return "%s: %s" % [kind, room.encounter.display_name]
		MapRoom.Type.REST:
			return "Rest: heal %d%% HP or relieve %d stress" % [roundi(CampaignRules.REST_HEAL * 100), CampaignRules.REST_STRESS]
		MapRoom.Type.CACHE:
			if room.cache_heirloom == &"":
				return "Cache: %s gold" % UiStyle.gold_text(run.cache_gold())
			return "Cache: %d %s" % [run.cache_heirlooms(), CampaignRules.HEIRLOOM_NAMES[room.cache_heirloom]]
	return room.type_name()


## A click goes straight there; on a touch screen a tap first shows what the room holds.
func _on_room_pressed(room: MapRoom) -> void:
	if not Device.touch:
		_enter(room)
		return
	_show_panel(room.type_name(), _describe(room), [
		["Go", _enter.bind(room)],
		["Not yet", _close_panel],
	])


## The token walks to the room, then the party goes in.
func _enter(room: MapRoom) -> void:
	_overlay.hide()
	if _walking:
		return
	_walking = true
	var walk := create_tween()
	walk.tween_property(_token, "position", _token_position(room), 0.45).set_trans(Tween.TRANS_SINE)\
			.set_ease(Tween.EASE_IN_OUT)
	await walk.finished
	_walking = false
	var run := _run()
	if run.enter(room.id) != "":
		_refresh()
		return
	_confirm_retreat = false
	if run.has_pending_fight():
		Game.go_to_battle()
		return
	_refresh()
	_open_room(true)


# --- Rooms that open a panel ---

## `entered` is false when reopening a room (after loading, or after the quit
## question), so a cache isn't announced twice.
func _open_room(entered: bool = false) -> void:
	var run := _run()
	var room := run.current_room()
	match room.type:
		MapRoom.Type.CACHE:
			if entered:
				var found := "%s gold" % UiStyle.gold_text(run.cache_gold()) if room.cache_heirloom == &"" \
						else "%d %s" % [run.cache_heirlooms(), CampaignRules.HEIRLOOM_NAMES[room.cache_heirloom]]
				if run.just_found:
					found += ", and a trinket: %s (%s)" % [run.just_found.display_name,
							CampaignRules.RARITY_NAMES[run.just_found.rarity]]
					run.just_found = null
				_show_panel("Cache", "Someone hid this well, but not well enough. You find %s." % found,
						[["Continue", _close_panel]])
		MapRoom.Type.REST:
			_show_panel("Rest", "The party makes camp and takes stock.", [
				["Tend wounds: the party heals %d%% HP" % roundi(CampaignRules.REST_HEAL * 100), _rest.bind(true)],
				["Steady nerves: the party %+d stress" % -CampaignRules.REST_STRESS, _rest.bind(false)],
			])
		MapRoom.Type.EVENT:
			var event := run.event()
			var buttons: Array = []
			for i in event.choices.size():
				var choice := event.choices[i]
				var effects := run.describe_choice(choice)
				var label := choice.label + (": " + effects if effects != "" else "")
				var blocked := run.choice_blocked(choice)
				if blocked != "":
					label += "   (%s)" % blocked
				buttons.append([label, _choose.bind(i), blocked != ""])
			_show_panel(event.title, event.text, buttons)


func _rest(heal: bool) -> void:
	_run().rest(heal)
	_show_panel("Rest", "The party heals." if heal else "The party's nerves steady.", [["Continue", _close_panel]])
	_refresh()


func _choose(index: int) -> void:
	var run := _run()
	var event := run.event()
	var result := run.choose(index)
	if result.is_empty():
		return
	var text: String = result.text
	if not result.lines.is_empty():
		text += "\n\n" + "\n".join(result.lines)
	if run.has_pending_fight():
		_show_panel(event.title, text, [["Fight!", Game.go_to_battle]])
	else:
		_show_panel(event.title, text, [["Continue", _close_panel]])
	_refresh()


func _show_panel(title: String, text: String, buttons: Array) -> void:
	_panel_title.text = title
	_panel_text.text = text
	for child in _panel_extra.get_children():
		_panel_extra.remove_child(child)
		child.queue_free()
	for child in _panel_buttons.get_children():
		child.queue_free()
	for entry: Array in buttons:
		var button := _action(entry[0], entry[1])
		button.disabled = entry.size() > 2 and entry[2]
		button.size_flags_horizontal = Control.SIZE_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if Device.phone:
			button.custom_minimum_size.y = 48
			button.add_theme_font_size_override("font_size", 18)
		_panel_buttons.add_child(button)
	_overlay.show()


func _close_panel() -> void:
	_overlay.hide()
	_refresh()


# --- Party, loot and retreat ---

## Heroes in rank order, rank 4 on the left as in combat, then the defeated.
func _refresh_party() -> void:
	var run := _run()
	for child in _party.get_children():
		_party.remove_child(child)
		child.queue_free()
	for i in range(run.formation.size() - 1, -1, -1):
		var card := MapHeroCard.new()
		card.setup(run.formation[i], "Rank %d" % (i + 1))
		_party.add_child(card)
	for i in run.party.size():
		if run.party[i] in run.defeated:
			var card := MapHeroCard.new()
			card.setup(run.combatants[i], "Defeated", true)
			_party.add_child(card)
	if Device.phone:
		# Four cards and the loot column share the screen's width.
		for card: MapHeroCard in _party.get_children():
			card.custom_minimum_size.x = clampf((size.x - 330.0) / 4.0 - 8.0, 160.0, MapHeroCard.PHONE_SIZE.x)
		# The strip sits against the bottom edge, so it moves when its height changes.
		_center_stage.call_deferred()
	for child in _loot.get_children():
		_loot.remove_child(child)
		child.queue_free()
	_loot.add_child(_label("Earned so far", 24, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	_loot.add_child(_label("%s gold" % UiStyle.gold_text(run.gold_earned), 20))
	for type: StringName in run.heirlooms_earned:
		if run.heirlooms_earned[type] > 0:
			_loot.add_child(_label("%d %s" % [run.heirlooms_earned[type], CampaignRules.HEIRLOOM_NAMES[type]], 20))
	_retreat.visible = run.can_retreat()
	_retreat.text = "Retreat? +%d stress each. %s again" % [CampaignRules.RETREAT_STRESS,
			"Tap" if Device.touch else "Click"] if _confirm_retreat else "Retreat"
	_skills_button.visible = run.can_retreat()


## Between rooms, each hero's learned skills as toggles: up to SKILL_SLOTS are
## taken into the next fight.
func _open_loadouts() -> void:
	var run := _run()
	_show_panel("Skills", "Choose up to %d skills for each hero. They apply from the next fight."
			% CampaignRules.SKILL_SLOTS, [["Done", _close_panel]])
	for unit in run.formation:
		var hero := run.record_of(unit)
		_panel_extra.add_child(_label("%s   %d / %d" % [hero.display_name, hero.equipped.size(), CampaignRules.SKILL_SLOTS],
				22, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		row.add_theme_constant_override("v_separation", 8)
		for skill in hero.def.skills:
			if not hero.knows(skill):
				continue
			var toggle := _action(skill.display_name, func() -> void:
				if hero.is_equipped(skill):
					Game.campaign.unequip(hero, skill)
				else:
					Game.campaign.equip(hero, skill)
				_open_loadouts())
			toggle.toggle_mode = true
			toggle.button_pressed = hero.is_equipped(skill)
			toggle.disabled = not hero.is_equipped(skill) and hero.equipped.size() >= CampaignRules.SKILL_SLOTS
			row.add_child(toggle)
		_panel_extra.add_child(row)


func _on_retreat() -> void:
	if not _confirm_retreat:
		_confirm_retreat = true
		_refresh_party()
		return
	_run().retreat()
	var summary := Game.campaign.finish_mission()
	Game.save()
	var text: Array = UiStyle.mission_summary(summary, Game.campaign)
	_retreat.hide()
	_show_panel(text[0], text[1], [["Return to town", Game.go_to_town]])


## The game saves only in town and after fights, so quitting asks first.
func _on_quit() -> void:
	_show_panel("Quit to the menu?",
			"The game saves in town and after each fight. Rooms since the last fight are lost.", [
		["Quit to the menu", Game.go_to_menu],
		["Keep going", _keep_going],
	])


## Back from the quit question, to the room's own panel if it is still open.
func _keep_going() -> void:
	_close_panel()
	if not _run().room_done:
		_open_room()


# --- Autoplay ---

## With `-- --autoplay`: pick rooms, rests and event choices with MapAutoPlayer.
func _autoplay_step() -> void:
	await get_tree().create_timer(1.2).timeout
	if not is_inside_tree() or Game.campaign.run == null:
		return
	var run := _run()
	if _overlay.visible:
		if run.event():
			_choose(MapAutoPlayer.choose_event(run))
		elif not run.room_done:
			_rest(MapAutoPlayer.choose_rest(run))
		else:
			var first: Button = _panel_buttons.get_child(0)
			first.pressed.emit()
	elif run.room_done and run.outcome == MissionRun.Outcome.IN_PROGRESS:
		_enter(run.map.room(MapAutoPlayer.choose_room(run)))
	if is_inside_tree():
		_autoplay_step()


# --- Building the screen ---

func _center_stage() -> void:
	if _stage:
		Device.fit_stage(_stage, size)
	if Device.phone and _ui:
		_ui.size = size
		_overlay.size = size
		_band.size = Vector2(size.x, 52)
		_top.position = Vector2(16, 4)
		_top.size = Vector2(size.x - _menu.size.x - 40, 44)
		_menu.position = Vector2(size.x - _menu.size.x - 12, 4)
		_bottom.size = Vector2(size.x - 16, 0)
		_bottom.position = Vector2(8, size.y - _bottom.get_combined_minimum_size().y - 8)
	queue_redraw()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(Atmosphere.new())
	_stage = Control.new()
	_stage.size = STAGE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_ui = _stage
	if Device.phone:
		_ui = Control.new()
		_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_ui)

	_paths = Control.new()
	_paths.size = STAGE_SIZE
	_paths.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paths.draw.connect(_draw_paths)
	_stage.add_child(_paths)
	_rooms = Control.new()
	_rooms.size = STAGE_SIZE
	_rooms.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_rooms)
	_token = PartyToken.new()
	_stage.add_child(_token)

	# Top band: week, region and mission, and a way back to the menu.
	_band = ColorRect.new()
	_band.color = Color(0, 0, 0, 0.75)
	_band.size = Vector2(STAGE_SIZE.x, 64)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_band)
	_top = HBoxContainer.new()
	_top.position = Vector2(28, 8)
	_top.size = Vector2(STAGE_SIZE.x - 56, 48)
	_top.add_theme_constant_override("separation", 20 if Device.phone else 30)
	_ui.add_child(_top)
	var top := _top
	_week = _label("", 26 if Device.phone else 34, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	top.add_child(_week)
	_header = _label("", 26 if Device.phone else 34, UiStyle.TEXT, UiStyle.DISPLAY_FONT)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_header)
	_menu = Button.new()
	_menu.text = "Quit"
	_menu.focus_mode = Control.FOCUS_NONE
	_menu.custom_minimum_size = Vector2(80, 44) if Device.phone else Vector2.ZERO
	_menu.size = _menu.custom_minimum_size
	_menu.add_theme_font_size_override("font_size", 18 if Device.phone else 15)
	_menu.pressed.connect(_on_quit)
	if Device.phone:
		_ui.add_child(_menu)
	else:
		top.add_child(_menu)

	# Party panel along the bottom, with the loot and Retreat on the right.
	_bottom = PanelContainer.new()
	_bottom.position = Vector2(40, 840)
	_bottom.size = Vector2(STAGE_SIZE.x - 80, 0)
	_ui.add_child(_bottom)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16 if Device.phone else 40)
	_bottom.add_child(row)
	var party_box := VBoxContainer.new()
	party_box.add_theme_constant_override("separation", 8)
	row.add_child(party_box)
	if not Device.phone:
		party_box.add_child(_label("Party", 28, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	_party = HBoxContainer.new()
	_party.add_theme_constant_override("separation", 8 if Device.phone else 14)
	party_box.add_child(_party)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	_loot = VBoxContainer.new()
	_loot.add_theme_constant_override("separation", 0 if Device.phone else 4)
	side.add_child(_loot)
	_retreat = _action("Retreat", _on_retreat)
	_retreat.custom_minimum_size = Vector2(0, 48) if Device.phone else Vector2(300, 48)
	_retreat.size_flags_horizontal = Control.SIZE_FILL if Device.phone else Control.SIZE_SHRINK_BEGIN
	side.add_child(_retreat)
	_skills_button = _action("Skills", _open_loadouts)
	_skills_button.custom_minimum_size = _retreat.custom_minimum_size
	_skills_button.size_flags_horizontal = _retreat.size_flags_horizontal
	side.add_child(_skills_button)

	# The room panel over the map.
	_overlay = Control.new()
	_overlay.size = STAGE_SIZE
	_overlay.hide()
	_ui.add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.frame(24.0 if Device.phone else 36.0))
	panel.custom_minimum_size = Vector2(760 if Device.phone else 820, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12 if Device.phone else 18)
	panel.add_child(box)
	_panel_title = _label("", 36 if Device.phone else 44, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	box.add_child(_panel_title)
	box.add_child(UiStyle.divider(560.0))
	_panel_text = _label("", 20, UiStyle.TEXT)
	_panel_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_text.custom_minimum_size = Vector2(716 if Device.phone else 756, 0)
	box.add_child(_panel_text)
	_panel_extra = VBoxContainer.new()
	_panel_extra.add_theme_constant_override("separation", 8)
	box.add_child(_panel_extra)
	_panel_buttons = VBoxContainer.new()
	_panel_buttons.add_theme_constant_override("separation", 10)
	box.add_child(_panel_buttons)


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
	button.pressed.connect(action)
	return button

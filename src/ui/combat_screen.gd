## The combat screen, laid out like Darkest Dungeon 2: the battlefield in the top
## ~70% fading to black, a frameless HUD below it, the turn queue at the top right,
## and a letterboxed close-up for every attack. Plays the campaign's mission in
## progress (Game.campaign.run), or the combat sandbox when there is none, and
## plays the battle's events back as short animations.
## Authored for 1920x1080 on a centred stage; measurements come from
## docs/research/darkest-dungeon-ui.md.
extends Control

const SANDBOX: SandboxDef = preload("res://content/sandbox.tres")
const STAGE_SIZE := Vector2(1920, 1080)
const GROUND_Y := 680.0
const HERO_RANK_1_X := 845.0
const ENEMY_RANK_1_X := 1090.0
const RANK_PITCH := 195.0
const TOP_BAND := 64.0
const FADE_TOP := 700.0
const FADE_BOTTOM := 780.0
## Close-up staging: where each side stands, and participant scale by count per side.
const CLOSEUP_HERO_X := 620.0
const CLOSEUP_ENEMY_X := 1300.0
const CLOSEUP_SCALES := [1.5, 1.25, 1.0]
const CLOSEUP_TINT := Color(0.3, 0.1, 0.08, 0.6)

## Sandbox mode: the fixed party against three waves.
var _run: SandboxRun
## Campaign mode: the mission in progress.
var _mission_run: MissionRun
var _battle: Battle
## Every unit of the current wave by uid, including ones that have left the field.
var _units: Dictionary[int, Combatant] = {}
var _views: Dictionary[int, UnitView] = {}
var _selected: SkillDef
var _targets: Array[Combatant] = []
var _focus_index := 0
var _speed := 1.0
var _busy := false
## Bumped on restart so animations and loops from the previous run stop.
var _generation := 0
var _last_skill: Dictionary[int, StringName] = {}
var _in_closeup := false
var _closeup_views: Array[UnitView] = []
var _floats_per_view: Dictionary[int, int] = {}
## Run with `-- --autoplay` to let heroes play themselves (demos and screenshot capture).
var _autoplay := "--autoplay" in OS.get_cmdline_user_args()
## Run with `-- --start-wave=N` to begin a run at wave N, for testing.
var _start_wave_number := 1

var _stage: Control
var _field: Control
var _tint: ColorRect
var _ink: Control
var _top_band: Control
var _hud: Control
var _hero_portrait: TextureRect
var _hero_name: Label
var _skill_text: RichTextLabel
var _skill_name: Label
var _pips: RankPips
var _skill_row: HBoxContainer
var _preview: PreviewStrip
var _target_panel: TargetPanel
var _wave_label: Label
var _round_label: Label
var _queue: TurnQueue
var _speed_button: Button
var _log_button: Button
var _closeup_title: Label
var _wave_title: Label
var _fx: Control
var _log_panel: PanelContainer
var _log: RichTextLabel
var _end_panel: Control
var _end_title: Label
var _end_text: Label
var _end_button: Button
var _end_action: Callable
var _end_retreat: Button


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--speed="):
			_speed = maxf(float(arg.trim_prefix("--speed=")), 0.1)
		elif arg.begins_with("--start-wave="):
			_start_wave_number = int(arg.trim_prefix("--start-wave="))
	theme = UiStyle.make_theme()
	if Game.campaign and Game.campaign.run:
		_mission_run = Game.campaign.run
	_build()
	resized.connect(_center_stage)
	_center_stage()
	if _mission_run:
		_start_fight()
	else:
		_new_run()


## Background scene and the fade to black under the battlefield.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b0809"))
	var offset := _stage.position if _stage else Vector2.ZERO
	var background: Texture2D = Game.campaign.def.battle_background if _mission_run else SANDBOX.background
	if background:
		draw_texture_rect(background, Rect2(offset, STAGE_SIZE), false)
	var clear := Color(0, 0, 0, 0)
	var fade_top := offset.y + FADE_TOP
	var fade_bottom := offset.y + FADE_BOTTOM
	draw_polygon(PackedVector2Array([Vector2(0, fade_top), Vector2(size.x, fade_top),
			Vector2(size.x, fade_bottom), Vector2(0, fade_bottom)]),
			PackedColorArray([clear, clear, Color.BLACK, Color.BLACK]))
	draw_rect(Rect2(0, fade_bottom, size.x, size.y - fade_bottom), Color.BLACK)


## The ragged black band across the top of the window.
func _draw_top_band() -> void:
	var width := _top_band.size.x
	var bottom := _stage.position.y + TOP_BAND
	var band := PackedVector2Array([Vector2(0, 0), Vector2(width, 0)])
	var x := width
	while x >= 0.0:
		band.append(Vector2(x, bottom + sin(x * 0.07) * 5.0 + sin(x * 0.023) * 8.0))
		x -= 24.0
	band.append(Vector2(0, bottom))
	_top_band.draw_colored_polygon(band, Color.BLACK)


# --- Run and wave flow ---

func _new_run() -> void:
	_generation += 1
	_busy = false
	_end_panel.hide()
	_end_closeup()
	_clear_fx()
	_last_skill.clear()
	_log.clear()
	var seed_value := randi() % 1000000
	_run = SandboxRun.new(SANDBOX, seed_value)
	_run.wave_index = clampi(_start_wave_number, 1, _run.wave_count()) - 2
	_log_line("[color=#d9b45a]New run, seed %d[/color]" % seed_value)
	_start_wave()


func _start_wave() -> void:
	var generation := _generation
	_end_panel.hide()
	_hud.hide()
	_battle = _run.start_next_wave()
	_units.clear()
	for unit in _battle.all_units():
		_units[unit.uid] = unit
	_rebuild_views()
	var encounter := _run.sandbox.waves[_run.wave_index]
	_wave_label.text = "Wave %d/%d   Seed %d" % [_run.wave_index + 1, _run.wave_count(), _run.seed_value]
	_round_label.text = ""
	_queue.show_units([])
	_log_line("[color=#d9b45a]== Wave %d: %s ==[/color]" % [_run.wave_index + 1, encounter.display_name])
	_show_wave_title(encounter.display_name + "!")
	await _wait(1.6)
	if generation == _generation:
		_pump()


## Plays out turns until the player has to choose or the battle ends.
func _pump() -> void:
	var generation := _generation
	_busy = true
	while _battle.state == Battle.State.RUNNING:
		await _play(_battle.advance())
		if generation != _generation:
			return
	_busy = false
	match _battle.state:
		Battle.State.AWAITING_INPUT:
			_begin_player_turn()
		Battle.State.VICTORY:
			_on_victory()
		Battle.State.DEFEAT:
			if _mission_run:
				_on_fight_over()
			else:
				_show_end("Defeat", "The party has fallen on wave %d." % (_run.wave_index + 1), "Try again", _new_run)


func _on_victory() -> void:
	if _mission_run:
		_on_fight_over()
		return
	var survivors := "\n".join(_battle.heroes.map(func(h: Combatant) -> String:
		return "%s   %d/%d HP   %d stress" % [h.display_name, h.hp, h.max_hp, h.stress]))
	if _run.has_next_wave():
		_show_end("Wave %d cleared" % (_run.wave_index + 1), survivors, "Next wave", _start_wave)
	else:
		_show_end("Victory", "Every wave is cleared.\n" + survivors, "Play again", _new_run)


func _show_end(title: String, text: String, button: String, action: Callable) -> void:
	_set_active(null)
	_clear_player_ui()
	_end_title.text = title
	_end_text.text = text
	_end_button.text = button + "  (Enter)"
	_end_action = action
	_end_retreat.hide()
	_end_panel.show()
	if _autoplay:
		var generation := _generation
		await get_tree().create_timer(2.0).timeout
		if generation == _generation and _end_panel.visible:
			_end_action.call()


# --- Campaign missions ---

func _start_fight() -> void:
	var generation := _generation
	_end_panel.hide()
	_hud.hide()
	var mission := _mission_run.mission
	_battle = _mission_run.start_next_fight()
	_units.clear()
	for unit in _battle.all_units():
		_units[unit.uid] = unit
	_rebuild_views()
	var encounter := mission.encounters[_mission_run.fight_index]
	_wave_label.text = "Week %d   %s   Fight %d/%d" % [Game.campaign.week, mission.title(),
			_mission_run.fight_index + 1, mission.fights()]
	_round_label.text = ""
	_queue.show_units([])
	_log_line("[color=#d9b45a]== Fight %d: %s ==[/color]" % [_mission_run.fight_index + 1, encounter.display_name])
	_show_wave_title(encounter.display_name + "!")
	await _wait(1.6)
	if generation == _generation:
		_pump()


## After a fight: settle it, save, and either offer Continue / Retreat or show the results.
func _on_fight_over() -> void:
	_mission_run.finish_fight()
	Game.save()
	if _mission_run.outcome != MissionRun.Outcome.IN_PROGRESS:
		_show_results()
		return
	var survivors := "\n".join(_mission_run.formation.map(func(h: Combatant) -> String:
		return "%s   %d/%d HP   %d stress" % [h.display_name, h.hp, h.max_hp, h.stress]))
	_show_end("Fight won", "Gold so far: %d\n%s" % [_mission_run.gold_earned, survivors], "Continue", _start_fight)
	_end_retreat.show()


func _retreat() -> void:
	_mission_run.retreat()
	_show_results()


## Ends the mission in the campaign (which also ends the week) and shows what it earned.
func _show_results() -> void:
	var summary := Game.campaign.finish_mission()
	Game.save()
	var lines: Array[String] = []
	var title := "Mission complete"
	match summary.outcome:
		MissionRun.Outcome.RETREATED:
			title = "Retreated"
		MissionRun.Outcome.FAILED:
			title = "Mission failed"
			lines.append("The whole party fell. No rewards.")
	if summary.gold > 0:
		lines.append("Gold +%d" % summary.gold)
	if summary.heirlooms > 0:
		lines.append("%s +%d" % [CampaignRules.HEIRLOOM_NAMES[summary.heirloom], summary.heirlooms])
	if summary.xp > 0:
		lines.append("XP +%d" % summary.xp)
	for hero: HeroRecord in summary.level_ups:
		lines.append("%s reaches level %d!" % [hero.display_name, hero.level()])
	for hero: HeroRecord in summary.wounded:
		lines.append("%s is wounded and sits out next week." % hero.display_name)
	_show_end(title, "\n".join(lines), "Return to town", Game.go_to_town)


# --- Player turn ---

func _begin_player_turn() -> void:
	var actor := _battle.current
	_set_active(_views.get(actor.uid))
	_queue.show_units(_battle.turn_order())
	_hero_name.text = actor.display_name
	_hero_portrait.texture = _portrait_texture(actor)
	_clear_skill_row()
	var preferred: SkillDef = null
	var actions := _battle.actions_for(actor)
	for i in actions.size():
		var skill := actions[i]
		var button := SkillButton.new()
		var uses := actor.uses_left(skill) if skill.uses_per_battle > 0 else -1
		button.setup(skill, i + 1, _battle.can_use(actor, skill), actor.cooldown_left(skill), uses)
		button.pressed.connect(_select_skill.bind(skill))
		button.mouse_entered.connect(_show_skill_details.bind(skill))
		button.mouse_exited.connect(func() -> void: _show_skill_details(_selected))
		_skill_row.add_child(button)
		if button.usable and preferred == null and skill.kind == SkillDef.Kind.ACTION:
			preferred = skill
		if button.usable and skill.id == _last_skill.get(actor.uid, &""):
			preferred = skill
	if preferred == null:
		preferred = BasicSkills.pass_turn
	_hud.show()
	_select_skill(preferred)
	if _autoplay:
		var generation := _generation
		var choice := AutoPlayer.sensible(_battle)
		await _wait(0.4)
		if generation != _generation:
			return
		_select_skill(choice[0])
		_focus_index = maxi(_targets.find(choice[1]), 0)
		_update_targeting()
		await _wait(0.9)
		if generation == _generation:
			_confirm(choice[1])


func _select_skill(skill: SkillDef) -> void:
	if _busy or _battle.state != Battle.State.AWAITING_INPUT or not _battle.can_use(_battle.current, skill):
		return
	_selected = skill
	for button: SkillButton in _skill_row.get_children():
		button.set_selected(button.skill == skill)
	_targets = _battle.targets_for(_battle.current, skill)
	_targets.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		return _views[a.uid].position.x < _views[b.uid].position.x)
	# Default focus: the actor for self and ally skills, otherwise the first living target.
	_focus_index = 0
	if skill.side != SkillDef.TargetSide.ENEMY and _battle.current in _targets:
		_focus_index = _targets.find(_battle.current)
	else:
		for i in _targets.size():
			if _targets[i].is_active():
				_focus_index = i
				break
	_show_skill_details(skill)
	_update_targeting()


func _confirm(target: Combatant) -> void:
	if _busy or _selected == null or target not in _targets:
		return
	var actor := _battle.current
	_last_skill[actor.uid] = _selected.id
	var skill := _selected
	_clear_player_ui()
	_busy = true
	var generation := _generation
	await _play(_battle.submit(skill, target))
	if generation == _generation:
		_pump()


func _clear_player_ui() -> void:
	_selected = null
	_targets.clear()
	_clear_skill_row()
	_hud.hide()
	_update_targeting()


func _clear_skill_row() -> void:
	for child in _skill_row.get_children():
		_skill_row.remove_child(child)
		child.queue_free()


func _focused_target() -> Combatant:
	if _targets.is_empty():
		return null
	return _targets[clampi(_focus_index, 0, _targets.size() - 1)]


## Target brackets and boxes, the tokens the attack would spend, the target panel and the preview.
func _update_targeting() -> void:
	var focused := _focused_target()
	for view: UnitView in _views.values():
		view.highlight = UnitView.Highlight.NONE
		view.focused = false
		view.consumed_tokens.clear()
		view.queue_redraw()
	_preview.show_columns([])
	if _selected == null or _battle.current == null:
		_target_panel.clear()
		return
	var actor := _battle.current
	for target in _targets:
		var view: UnitView = _views.get(target.uid)
		if view == null:
			continue
		view.highlight = UnitView.Highlight.ENEMY_TARGET if target.is_hero != actor.is_hero \
				else UnitView.Highlight.ALLY_TARGET
		view.focused = _selected.multi_target or target == focused
		if view.focused:
			view.consumed_tokens = _consumed_by(_selected, target)
	if focused == null:
		_target_panel.clear()
		return
	_target_panel.show_unit(focused, _tested_resists(_selected))
	_update_preview(actor, _selected, focused)


func _update_preview(actor: Combatant, skill: SkillDef, target: Combatant) -> void:
	if skill.kind != SkillDef.Kind.ACTION:
		return
	var preview := _battle.preview(actor, skill, target)
	var columns := []
	if skill.is_attack():
		columns.append([UiStyle.percent(preview.hit_chance), "HIT"])
	if skill.deals_damage():
		columns.append(["%d-%d" % [preview.damage_min, preview.damage_max], "DMG"])
		columns.append([UiStyle.percent(preview.crit_chance), "CRIT"])
	elif skill.heals():
		columns.append(["%d-%d" % [preview.heal_min, preview.heal_max], "HEAL"])
		columns.append([UiStyle.percent(preview.crit_chance), "CRIT"])
	_preview.show_columns(columns)


## Tokens on the target that this attack would use up.
func _consumed_by(skill: SkillDef, target: Combatant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not skill.is_attack():
		return result
	for token: StringName in [Tokens.DODGE_PLUS, Tokens.DODGE]:
		if target.has_token(token):
			result.append(token)
			break
	if skill.deals_damage():
		for token: StringName in [Tokens.BLOCK_PLUS, Tokens.BLOCK]:
			if target.has_token(token):
				result.append(token)
				break
		if target.has_token(Tokens.VULNERABLE):
			result.append(Tokens.VULNERABLE)
		if skill.combo_damage_bonus > 0.0 and target.has_token(Tokens.COMBO):
			result.append(Tokens.COMBO)
	if not skill.multi_target and target.has_token(Tokens.TAUNT):
		result.append(Tokens.TAUNT)
	return result


## Resistances the skill's effects roll against.
func _tested_resists(skill: SkillDef) -> Array[StringName]:
	var result: Array[StringName] = []
	if not skill.is_attack():
		return result
	for effect in skill.effects:
		match effect.kind:
			EffectDef.Kind.DOT:
				result.append(effect.dot)
			EffectDef.Kind.MOVE:
				result.append(&"move")
			EffectDef.Kind.TOKEN:
				var tokens: Array = effect.token_pool if not effect.token_pool.is_empty() else [effect.token]
				for token: StringName in tokens:
					if Tokens.resist_of(token) != &"":
						result.append(Tokens.resist_of(token))
	return result


func _show_skill_details(skill: SkillDef) -> void:
	if skill == null:
		_skill_name.text = ""
		_skill_text.text = ""
		_pips.set_skill(null)
		return
	_skill_name.text = skill.display_name
	_skill_text.text = UiStyle.skill_bbcode(skill)
	_pips.set_skill(skill)


func _on_view_clicked(view: UnitView) -> void:
	if view.unit in _targets:
		_confirm(view.unit)


func _on_view_hovered(view: UnitView, inside: bool) -> void:
	if inside and view.unit in _targets and _hud.visible:
		_focus_index = _targets.find(view.unit)
		_update_targeting()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := (event as InputEventKey).keycode
	match key:
		KEY_L:
			_toggle_log()
		KEY_S:
			_toggle_speed()
		KEY_R:
			if _mission_run == null:
				_new_run()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _end_panel.visible:
				_end_button.pressed.emit()
			elif _focused_target():
				_confirm(_focused_target())
		KEY_LEFT, KEY_RIGHT, KEY_TAB:
			if not _targets.is_empty():
				var step := -1 if key == KEY_LEFT else 1
				_focus_index = posmod(_focus_index + step, _targets.size())
				_update_targeting()
		_:
			if key >= KEY_1 and key <= KEY_9:
				var index := key - KEY_1
				if index < _skill_row.get_child_count():
					_select_skill((_skill_row.get_child(index) as SkillButton).skill)
			return
	get_viewport().set_input_as_handled()


# --- Event playback ---

func _play(events: Array[Dictionary]) -> void:
	var generation := _generation
	for event in events:
		var line := CombatLog.describe(event, _name_of)
		if line != "":
			_log_line(line)
		var seconds := _apply_event(event)
		if seconds > 0.0:
			await _wait(seconds)
		if generation != _generation:
			return
	if _in_closeup:
		await _wait(0.35)
		if generation != _generation:
			return
	_end_closeup()
	_refresh_views()
	_layout(true)
	_queue.show_units(_battle.turn_order())
	if not events.is_empty():
		await _wait(0.2)


## Shows one event and returns how long to linger on it, in seconds at 1x speed.
func _apply_event(event: Dictionary) -> float:
	var view: UnitView = _views.get(event.uid)
	match event.type:
		&"round_start":
			_round_label.text = "Round %d" % event.round
			_queue.show_units(_battle.turn_order())
			return 0.3
		&"turn_start":
			_set_active(view)
			_queue.show_units(_battle.turn_order())
			if view and not view.unit.is_hero:
				_hud.hide()
			return 0.25
		&"dazed":
			_float(view, "Dazed", UiStyle.GREY, 44)
			return 0.5
		&"stunned":
			_set_active(view)
			_float(view, "Stunned", Color("ffe070"), 48)
			return 0.7
		&"skill":
			var skill: SkillDef = event.skill
			if skill.is_attack():
				_start_closeup(event)
				return 0.55
			_float(view, skill.display_name, UiStyle.GOLD, 36)
			return 0.5
		&"miss":
			_float(view, "Dodge" if event.reason == &"dodge" else "Miss", UiStyle.GREY, 56)
			return 0.4
		&"guarded":
			_float(view, "Guard!", UiStyle.GOLD, 40)
			return 0.3
		&"damage":
			_show_damage(view, event)
			return 0.45
		&"heal":
			if view:
				view.set_hp(event.hp)
			if event.amount > 0:
				_float(view, "+%d" % event.amount, UiStyle.GREEN, 48)
				return 0.35
			return 0.0
		&"stress":
			if view:
				view.set_stress(event.stress)
			_float(view, "%+d Stress" % event.amount, UiStyle.STRESS_TEXT, 32, false)
			return 0.3
		&"stress_resisted":
			_float(view, "Resist", UiStyle.GREY, 44)
			return 0.3
		&"token":
			if event.added > 0:
				var color := UiStyle.BLUE.lightened(0.3) if Tokens.is_negative(event.token) else UiStyle.GOLD
				_float(view, "%s %s" % [UiStyle.icon_bbcode(event.token, 30), UiStyle.token_name(event.token)], color, 30)
			for negated: StringName in event.negated:
				_float(view, "[s]%s[/s]" % UiStyle.token_name(negated), UiStyle.GREY, 28)
			if view:
				view.refresh()
			return 0.2
		&"resisted":
			_float(view, "Resist", UiStyle.GREY, 56)
			return 0.35
		&"dot_applied":
			_float(view, "%s %s %d" % [UiStyle.icon_bbcode(event.dot, 30), String(event.dot).capitalize(), event.amount],
					UiStyle.DOT_COLORS.get(event.dot, UiStyle.TEXT), 32)
			if view:
				view.refresh()
			return 0.25
		&"cleansed":
			_float(view, "Cleansed", UiStyle.GREEN, 36)
			if view:
				view.refresh()
			return 0.25
		&"immobile":
			_float(view, "Immobile", UiStyle.GREY, 36)
			return 0.25
		&"moved":
			_layout(true)
			return 0.25
		&"reposition":
			_set_active(view)
			_float(view, "Repositions", UiStyle.GREY, 36)
			return 0.4
		&"pass":
			_set_active(view)
			_float(view, "Waits", UiStyle.GREY, 36)
			return 0.45
		&"deaths_door":
			_float(view, "Death's Door!", UiStyle.DAMAGE, 52)
			if view:
				view.refresh()
			return 0.8
		&"left_deaths_door":
			_float(view, "Saved", UiStyle.GREEN, 40)
			return 0.3
		&"deathblow_resisted":
			_float(view, "Deathblow Resisted", UiStyle.GOLD, 44)
			return 0.7
		&"deathblow":
			_float(view, "Deathblow", UiStyle.DAMAGE, 60)
			return 0.7
		&"death_armor":
			_float(view, "Death Armor holds", Color("c0c0c0"), 36)
			if view:
				view.refresh()
			return 0.45
		&"death":
			if view:
				view.refresh()
			var fallen_hero := view != null and view.unit.is_hero and _mission_run != null
			_float(view, "Defeated" if fallen_hero else "Slain", UiStyle.DAMAGE, 52)
			return 0.7
		&"removed":
			if view:
				_views.erase(event.uid)
				_closeup_views.erase(view)
				var tween := view.create_tween()
				tween.tween_property(view, "modulate:a", 0.0, 0.3 / _speed)
				tween.tween_callback(view.queue_free)
			_layout(true)
			return 0.3
		&"meltdown":
			if view:
				view.set_hp(event.hp)
				view.set_stress(event.stress)
			_float(view, "Meltdown!", Color("c9b8ff"), 64)
			return 1.0
		&"resolute":
			if view:
				view.set_stress(0)
			_float(view, "Resolute!", UiStyle.GOLD, 64)
			return 1.0
	return 0.0


## Damage pop-up: red number; blocked hits show the original struck through;
## crits get an orange "Critical!" over a bigger number; DoT ticks use the DoT colour.
func _show_damage(view: UnitView, event: Dictionary) -> void:
	if view == null:
		return
	view.set_hp(event.hp)
	var cause: StringName = event.get("cause", &"hit")
	if cause != &"hit":
		_float(view, "%s %d" % [UiStyle.icon_bbcode(cause, 36), event.amount], UiStyle.DOT_COLORS.get(cause, UiStyle.DAMAGE), 44)
		return
	var crit: bool = event.get("crit", false)
	var unblocked: int = maxi(1, roundi(event.base * event.attack_mod * (Rules.WEAK_MULTIPLIER if event.weak else 1.0)))
	var number := "%d" % event.amount
	if unblocked > event.amount:
		number = "[color=#ffffff][s]%d[/s][/color] %d" % [unblocked, event.amount]
	if crit:
		_float(view, "[font_size=30]Critical![/font_size]\n" + number, UiStyle.CRIT, 72)
		_shake_field()
	else:
		_float(view, number, UiStyle.DAMAGE, 60)
	if view.unit.is_active() or view.unit.is_corpse:
		_shake(view)


# --- Close-up ---

## Cuts to the attacker and its targets: everyone else fades out, the scene is
## tinted, participants are re-staged larger, and the skill name shows in gold.
func _start_closeup(event: Dictionary) -> void:
	var participants: Array[UnitView] = []
	for uid: int in [event.uid] + event.targets:
		var view: UnitView = _views.get(uid)
		if view and view not in participants:
			participants.append(view)
	if participants.is_empty():
		return
	_in_closeup = true
	_closeup_views = participants
	_hud.hide()
	var time := 0.15 / _speed
	for view: UnitView in _views.values():
		view.closeup = view in participants
		view.queue_redraw()
		if view not in participants:
			view.create_tween().tween_property(view, "modulate:a", 0.0, time)
	for side_is_hero: bool in [true, false]:
		var side := participants.filter(func(v: UnitView) -> bool: return v.unit.is_hero == side_is_hero)
		# Heroes keep rank 1 nearest the middle; enemies too.
		side.sort_custom(func(a: UnitView, b: UnitView) -> bool:
			return (_battle.rank_of(a.unit) > _battle.rank_of(b.unit)) == side_is_hero)
		var count := side.size()
		var scale_factor: float = CLOSEUP_SCALES[mini(count - 1, CLOSEUP_SCALES.size() - 1)] if count > 0 else 1.0
		var center_x := CLOSEUP_HERO_X if side_is_hero else CLOSEUP_ENEMY_X
		for i in count:
			var view: UnitView = side[i]
			var x := center_x + (i - (count - 1) / 2.0) * 240.0 * scale_factor
			var tween := view.create_tween().set_parallel()
			tween.tween_property(view, "modulate:a", 1.0, time)
			tween.tween_property(view, "scale", Vector2.ONE * scale_factor, time)
			tween.tween_property(view, "position", Vector2(x - view.feet.x, GROUND_Y - view.feet.y), time)
	# The attacker lunges towards its targets.
	var actor: UnitView = _views.get(event.uid)
	if actor:
		var lunge := 60.0 if actor.unit.is_hero else -60.0
		var tween := actor.create_tween()
		tween.tween_interval(time)
		tween.tween_property(actor, "position:x", lunge, 0.25 / _speed).as_relative() \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tint.create_tween().tween_property(_tint, "color:a", CLOSEUP_TINT.a, time)
	_ink.show()
	_closeup_title.text = (event.skill as SkillDef).display_name
	_closeup_title.show()


func _end_closeup() -> void:
	if not _in_closeup:
		return
	_in_closeup = false
	_closeup_views.clear()
	var time := 0.2 / _speed
	for view: UnitView in _views.values():
		view.closeup = false
		view.queue_redraw()
		var tween := view.create_tween().set_parallel()
		tween.tween_property(view, "scale", Vector2.ONE, time)
		tween.tween_property(view, "modulate:a", 1.0, time)
	_tint.create_tween().tween_property(_tint, "color:a", 0.0, time)
	_ink.hide()
	_closeup_title.hide()


# --- Pop-ups and small effects ---

func _float(view: UnitView, bbcode: String, color: Color, font_size: int, display: bool = true) -> void:
	if view == null or not is_instance_valid(view):
		return
	# A close-up only shows pop-ups over its participants; the log has the rest.
	if _in_closeup and view not in _closeup_views:
		return
	var uid := view.unit.uid
	var stack: int = _floats_per_view.get(uid, 0)
	_floats_per_view[uid] = stack + 1
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font", UiStyle.DISPLAY_FONT if display else UiStyle.BODY_FONT)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.text = "[center]%s[/center]" % bbcode
	label.size = Vector2(560, 0)
	label.position = view.float_origin() - Vector2(280, 0) + Vector2(0, stack * 56.0)
	_fx.add_child(label)
	var duration := 1.1 / _speed
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 40.0, duration).set_ease(Tween.EASE_OUT) \
			.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, duration * 0.4).set_delay(duration * 0.6)
	tween.chain().tween_callback(func() -> void:
		label.queue_free()
		if _floats_per_view.has(uid):
			_floats_per_view[uid] = maxi(0, _floats_per_view[uid] - 1))


func _shake(view: UnitView) -> void:
	var tween := view.create_tween()
	var x := view.position.x
	for offset: float in [10.0, -8.0, 5.0, 0.0]:
		tween.tween_property(view, "position:x", x + offset, 0.04 / _speed)


func _shake_field() -> void:
	var tween := _field.create_tween()
	for offset: Vector2 in [Vector2(4, -3), Vector2(-3, 3), Vector2(2, -1), Vector2.ZERO]:
		tween.tween_property(_field, "position", offset, 0.04 / _speed)


func _set_active(view: UnitView) -> void:
	for other: UnitView in _views.values():
		other.is_active_turn = other == view
		other.queue_redraw()


func _show_wave_title(text: String) -> void:
	_wave_title.text = text
	_wave_title.modulate.a = 0.0
	var tween := _wave_title.create_tween()
	tween.tween_property(_wave_title, "modulate:a", 1.0, 0.25 / _speed)
	tween.tween_interval(1.0 / _speed)
	tween.tween_property(_wave_title, "modulate:a", 0.0, 0.4 / _speed)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds / _speed).timeout


func _clear_fx() -> void:
	for child in _fx.get_children():
		child.queue_free()
	_floats_per_view.clear()


# --- Unit views and layout ---

func _rebuild_views() -> void:
	for view: UnitView in _views.values():
		view.queue_free()
	_views.clear()
	_clear_fx()
	for unit in _battle.all_units():
		var view := UnitView.new()
		view.setup(unit)
		view.clicked.connect(_on_view_clicked)
		view.hovered.connect(_on_view_hovered)
		_field.add_child(view)
		_views[unit.uid] = view
	_layout(false)


func _refresh_views() -> void:
	for view: UnitView in _views.values():
		view.refresh()


func _layout(animated: bool) -> void:
	if _in_closeup:
		return
	for unit in _battle.all_units():
		var view: UnitView = _views.get(unit.uid)
		if view == null:
			continue
		var rank := _battle.rank_of(unit)
		var center := (_rank_center(rank, unit.is_hero) + _rank_center(rank + unit.size - 1, unit.is_hero)) / 2.0
		var target := Vector2(center - view.feet.x, GROUND_Y - view.feet.y)
		if animated:
			view.create_tween().tween_property(view, "position", target, 0.25 / _speed) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			view.position = target


func _rank_center(rank: int, hero: bool) -> float:
	if hero:
		return HERO_RANK_1_X - (rank - 1) * RANK_PITCH
	return ENEMY_RANK_1_X + (rank - 1) * RANK_PITCH


func _portrait_texture(unit: Combatant) -> Texture2D:
	var sprite := unit.def.sprite
	if sprite == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = sprite
	var region := UiStyle.portrait_region(sprite)
	# A wide crop of the head and shoulders for the 110x60 slot.
	atlas.region = Rect2(region.position.x, region.position.y + region.size.y * 0.1, region.size.x,
			region.size.x * 60.0 / 110.0)
	return atlas


func _name_of(uid: int) -> String:
	return _units[uid].display_name if _units.has(uid) else "?"


# --- Toggles ---

func _toggle_log() -> void:
	_log_panel.visible = not _log_panel.visible
	_log_button.set_pressed_no_signal(_log_panel.visible)


func _toggle_speed() -> void:
	_speed = 2.0 if _speed == 1.0 else 1.0
	_speed_button.text = "Speed %dx (S)" % roundi(_speed)


func _log_line(line: String) -> void:
	_log.append_text(line + "\n")


# --- Building the screen ---

func _center_stage() -> void:
	if _stage:
		_stage.position = ((size - STAGE_SIZE) / 2.0).floor()
		# Window-wide layers inside the stage are pulled back to cover the whole window.
		for layer: Control in [_ink, _top_band]:
			layer.position = -_stage.position
			layer.size = size
			layer.queue_redraw()
		# The close-up tint stops where the battlefield fades to black, keeping the letterbox black.
		_tint.position = -_stage.position
		_tint.size = Vector2(size.x, _stage.position.y + FADE_BOTTOM)
	queue_redraw()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage = _layer(self, STAGE_SIZE)

	_field = _layer(_stage, STAGE_SIZE)
	_tint = ColorRect.new()
	_tint.color = Color(CLOSEUP_TINT, 0.0)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(_tint)

	_ink = _layer(_stage, STAGE_SIZE)
	_ink.draw.connect(_draw_ink)
	_ink.hide()

	_top_band = _layer(_stage, STAGE_SIZE)
	_top_band.draw.connect(_draw_top_band)

	# Top band: wave and seed, small buttons, round counter and turn queue.
	var top_left := HBoxContainer.new()
	top_left.position = Vector2(24, 14)
	top_left.add_theme_constant_override("separation", 18)
	_stage.add_child(top_left)
	_wave_label = _label(16, UiStyle.GREY)
	_log_button = _button("Log (L)", _toggle_log)
	_log_button.toggle_mode = true
	_speed_button = _button("Speed %dx (S)" % roundi(_speed), _toggle_speed)
	for node: Control in [_wave_label, _log_button, _speed_button]:
		top_left.add_child(node)
	if _mission_run == null:
		top_left.add_child(_button("Restart (R)", _new_run))
	_round_label = _label(28, UiStyle.GREY, UiStyle.DISPLAY_FONT)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_round_label.position = Vector2(1240, 14)
	_round_label.size = Vector2(300, 40)
	_stage.add_child(_round_label)
	_queue = TurnQueue.new()
	_queue.position = Vector2(STAGE_SIZE.x - 24 - _queue.custom_minimum_size.x, 6)
	_queue.size = _queue.custom_minimum_size
	_stage.add_child(_queue)

	# Bottom HUD on black: hero (left), skill bar and preview (centre), target (right).
	_hud = _layer(_stage, STAGE_SIZE)
	_hud.draw.connect(_draw_hud_decor)
	_hero_portrait = TextureRect.new()
	_hero_portrait.position = Vector2(40, 792)
	_hero_portrait.size = Vector2(110, 60)
	_hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_hero_portrait.material = UiStyle.greyscale(0.9)
	_hud.add_child(_hero_portrait)
	_hero_name = _label(32, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	_hero_name.position = Vector2(164, 792)
	_hero_name.size = Vector2(400, 60)
	_hero_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud.add_child(_hero_name)
	_skill_text = RichTextLabel.new()
	_skill_text.bbcode_enabled = true
	_skill_text.scroll_active = false
	_skill_text.position = Vector2(40, 866)
	_skill_text.size = Vector2(520, 200)
	_skill_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_text.add_theme_font_size_override("normal_font_size", 19)
	_skill_text.add_theme_font_size_override("italics_font_size", 17)
	_hud.add_child(_skill_text)
	_skill_name = _label(28, UiStyle.TEXT, UiStyle.DISPLAY_FONT)
	_skill_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_name.position = Vector2(560, 772)
	_skill_name.size = Vector2(800, 40)
	_hud.add_child(_skill_name)
	_pips = RankPips.new()
	_pips.position = Vector2(560, 820)
	_pips.size = Vector2(800, 22)
	_hud.add_child(_pips)
	_skill_row = HBoxContainer.new()
	_skill_row.position = Vector2(560, 852)
	_skill_row.size = Vector2(800, 100)
	_skill_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_skill_row.add_theme_constant_override("separation", 14)
	_skill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_skill_row)
	_preview = PreviewStrip.new()
	_preview.position = Vector2(560, 968)
	_preview.size = Vector2(800, 80)
	_hud.add_child(_preview)
	_target_panel = TargetPanel.new()
	_target_panel.position = Vector2(1344, 786)
	_target_panel.size = Vector2(576, 260)
	_hud.add_child(_target_panel)
	_hud.hide()

	_closeup_title = _label(44, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	_closeup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_closeup_title.position = Vector2(0, 876)
	_closeup_title.size = Vector2(STAGE_SIZE.x, 60)
	_closeup_title.hide()
	_stage.add_child(_closeup_title)

	_wave_title = _label(72, Color("b8b0a4"), UiStyle.DISPLAY_FONT)
	_wave_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wave_title.position = Vector2(860, 560)
	_wave_title.size = Vector2(1000, 100)
	_wave_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_wave_title.add_theme_constant_override("outline_size", 12)
	_wave_title.modulate.a = 0.0
	_stage.add_child(_wave_title)

	_fx = _layer(_stage, STAGE_SIZE)
	_fx.z_index = 20

	_log_panel = PanelContainer.new()
	_log_panel.position = Vector2(STAGE_SIZE.x - 520, 110)
	_log_panel.size = Vector2(496, 580)
	_log_panel.z_index = 30
	_log_panel.hide()
	_stage.add_child(_log_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.add_theme_font_size_override("bold_font_size", 14)
	_log_panel.add_child(_log)

	_end_panel = _layer(_stage, STAGE_SIZE)
	_end_panel.z_index = 40
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.size = STAGE_SIZE
	_end_panel.add_child(backdrop)
	var center := CenterContainer.new()
	center.size = STAGE_SIZE
	_end_panel.add_child(center)
	var frame := PanelContainer.new()
	var frame_style := UiStyle.box(Color("0e0b0cf4"), Color("4a3e34"), 1, 4)
	frame_style.set_content_margin_all(36)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.custom_minimum_size = Vector2(620, 0)
	center.add_child(frame)
	var end_box := VBoxContainer.new()
	end_box.add_theme_constant_override("separation", 22)
	frame.add_child(end_box)
	_end_title = _label(64, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_text = _label(20, UiStyle.TEXT)
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_button = _button("", func() -> void: _end_action.call())
	_end_button.theme_type_variation = &"ActionButton"
	_end_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_end_button.custom_minimum_size = Vector2(280, 52)
	_end_button.add_theme_font_size_override("font_size", 22)
	_end_retreat = _button("Retreat with what you have", _retreat)
	_end_retreat.theme_type_variation = &"ActionButton"
	_end_retreat.custom_minimum_size = Vector2(280, 44)
	_end_retreat.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_end_retreat.hide()
	for node: Control in [_end_title, _end_text, _end_button, _end_retreat]:
		end_box.add_child(node)
	_end_panel.hide()


## Rules framing the hero name, and the thin diamond outline behind the skill name.
func _draw_hud_decor() -> void:
	for y: float in [786.0, 858.0]:
		_rule(Vector2(30, y), Vector2(560, y))
	_rule(Vector2(1360, 786), Vector2(1890, 786))
	var apex := Vector2(960, 746)
	var points := PackedVector2Array([apex + Vector2(-240, 120), apex, apex + Vector2(240, 120)])
	_hud.draw_polyline(points, UiStyle.RULE, 1.5)


## A thin grey rule that fades out at both ends.
func _rule(from: Vector2, to: Vector2) -> void:
	var clear := Color(UiStyle.RULE, 0.0)
	_hud.draw_polyline_colors(PackedVector2Array([from, from.lerp(to, 0.5), to]),
			PackedColorArray([clear, UiStyle.RULE, clear]), 1.5)


## Ink-like dark edges framing a close-up.
func _draw_ink() -> void:
	var size_now := _ink.size
	for side: float in [0.0, 1.0]:
		var points := PackedVector2Array()
		var x0 := side * size_now.x
		var direction := 1.0 if side == 0.0 else -1.0
		points.append(Vector2(x0, 0))
		var y := 0.0
		while y <= size_now.y:
			var depth := 110.0 + sin(y * 0.031 + side * 2.0) * 40.0 + sin(y * 0.11) * 14.0
			points.append(Vector2(x0 + direction * depth, y))
			y += 30.0
		points.append(Vector2(x0, size_now.y))
		_ink.draw_colored_polygon(points, Color(0, 0, 0, 0.88))


func _layer(parent: Control, layer_size: Vector2) -> Control:
	var layer := Control.new()
	layer.size = layer_size
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	return layer


func _label(font_size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button

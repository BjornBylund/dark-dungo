## The combat sandbox screen. Drives a SandboxRun, plays its events back as
## short animations, and turns clicks and keys into skill choices.
## Layout is authored for 1920x1080 on a centred stage.
extends Control

const SANDBOX: SandboxDef = preload("res://content/sandbox.tres")
## Bundled rather than a system font so desktop and web builds look the same.
## Gelasio is metrically compatible with Georgia (SIL Open Font License).
const UI_FONT: FontFile = preload("res://art/fonts/gelasio/Gelasio.ttf")
const STAGE_SIZE := Vector2(1920, 1080)
const FIELD_CENTER_X := 960.0
const CENTER_GAP := 70.0
const FIELD_TOP := 330.0
const FLOOR_Y := 700.0

var _run: SandboxRun
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
var _closeup: Array[UnitView] = []
var _floats_per_view: Dictionary[int, int] = {}
## Run with `-- --autoplay` to let heroes pick their default skill and target (for demos and capture).
var _autoplay := "--autoplay" in OS.get_cmdline_user_args()

var _stage: Control
var _field: Control
var _overlay: ColorRect
var _fx: Control
var _wave_label: Label
var _round_label: Label
var _seed_label: Label
var _speed_button: Button
var _log_button: Button
var _actor_card: RichTextLabel
var _skill_bar: HBoxContainer
var _info: RichTextLabel
var _log_panel: PanelContainer
var _log: RichTextLabel
var _banner: Label
var _end_panel: PanelContainer
var _end_title: Label
var _end_text: Label
var _end_button: Button
var _end_action: Callable


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--speed="):
			_speed = maxf(float(arg.trim_prefix("--speed=")), 0.1)
	theme = _make_theme()
	_build()
	resized.connect(_center_stage)
	_center_stage()
	_new_run()


func _draw() -> void:
	var top := UiStyle.BACKGROUND_TOP
	var bottom := UiStyle.BACKGROUND_BOTTOM
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([top, top, bottom, bottom]))
	var floor_y := _stage.position.y + FLOOR_Y if _stage else FLOOR_Y
	draw_rect(Rect2(0, floor_y, size.x, size.y - floor_y), UiStyle.FLOOR)
	draw_line(Vector2(0, floor_y), Vector2(size.x, floor_y), UiStyle.PANEL_BORDER, 2.0)


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
	_seed_label.text = "Seed %d" % seed_value
	_log_line("[color=#d9b45a]New run, seed %d[/color]" % seed_value)
	_start_wave()


func _start_wave() -> void:
	var generation := _generation
	_end_panel.hide()
	_battle = _run.start_next_wave()
	_units.clear()
	for unit in _battle.all_units():
		_units[unit.uid] = unit
	_rebuild_views()
	var encounter := _run.sandbox.waves[_run.wave_index]
	_wave_label.text = "Wave %d/%d: %s" % [_run.wave_index + 1, _run.wave_count(), encounter.display_name]
	_round_label.text = ""
	_log_line("[color=#d9b45a]== Wave %d: %s ==[/color]" % [_run.wave_index + 1, encounter.display_name])
	_show_banner("Wave %d" % (_run.wave_index + 1))
	await _wait(1.0)
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
			_show_end("Defeat", "The party has fallen on wave %d." % (_run.wave_index + 1), "Try again", _new_run)


func _on_victory() -> void:
	var survivors := ", ".join(_battle.heroes.map(func(h: Combatant) -> String:
		return "%s %d/%d HP, %d stress" % [h.display_name, h.hp, h.max_hp, h.stress]))
	if _run.has_next_wave():
		_show_end("Wave %d cleared" % (_run.wave_index + 1), survivors, "Next wave", _start_wave)
	else:
		_show_end("Victory", "Every wave is cleared.\n" + survivors, "Play again", _new_run)


func _show_end(title: String, text: String, button: String, action: Callable) -> void:
	_set_active(null)
	_clear_player_ui()
	_actor_card.text = ""
	_end_title.text = title
	_end_text.text = text
	_end_button.text = button + "  (Enter)"
	_end_action = action
	_end_panel.show()
	if _autoplay:
		var generation := _generation
		await get_tree().create_timer(2.0).timeout
		if generation == _generation and _end_panel.visible:
			_end_action.call()


# --- Player turn ---

func _begin_player_turn() -> void:
	var actor := _battle.current
	_set_active(_views.get(actor.uid))
	_update_actor_card(actor)
	_clear_skill_bar()
	var actions := _battle.actions_for(actor)
	var preferred: SkillDef = null
	for i in actions.size():
		var skill := actions[i]
		var button := SkillButton.new()
		button.setup(skill, i + 1, _battle.can_use(actor, skill))
		button.pressed.connect(_select_skill.bind(skill))
		button.mouse_entered.connect(_show_info.bind(skill))
		button.mouse_exited.connect(func() -> void: _show_info(_selected))
		_skill_bar.add_child(button)
		if button.usable and preferred == null and skill.kind == SkillDef.Kind.ACTION:
			preferred = skill
		if button.usable and skill.id == _last_skill.get(actor.uid, &""):
			preferred = skill
	if preferred == null:
		preferred = BasicSkills.pass_turn
	_select_skill(preferred)
	if _autoplay:
		var generation := _generation
		var choice := AutoPlayer.sensible(_battle)
		await _wait(0.4)
		if generation != _generation:
			return
		_select_skill(choice[0])
		_focus_index = maxi(_targets.find(choice[1]), 0)
		_update_highlights()
		_show_info(choice[0])
		await _wait(0.9)
		if generation == _generation:
			_confirm(choice[1])


func _select_skill(skill: SkillDef) -> void:
	if _busy or _battle.state != Battle.State.AWAITING_INPUT or not _battle.can_use(_battle.current, skill):
		return
	_selected = skill
	for button: SkillButton in _skill_bar.get_children():
		button.set_pressed_no_signal(button.skill == skill)
	_targets = _battle.targets_for(_battle.current, skill)
	_targets.sort_custom(func(a: Combatant, b: Combatant) -> bool: return _views[a.uid].position.x < _views[b.uid].position.x)
	# Default focus: the actor for self and ally skills, otherwise the first living target.
	_focus_index = 0
	if skill.side != SkillDef.TargetSide.ENEMY and _battle.current in _targets:
		_focus_index = _targets.find(_battle.current)
	else:
		for i in _targets.size():
			if _targets[i].is_active():
				_focus_index = i
				break
	_update_highlights()
	_show_info(skill)


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
	_clear_skill_bar()
	_info.text = ""
	_update_highlights()


func _clear_skill_bar() -> void:
	for child in _skill_bar.get_children():
		_skill_bar.remove_child(child)
		child.queue_free()


func _focused_target() -> Combatant:
	if _targets.is_empty():
		return null
	return _targets[clampi(_focus_index, 0, _targets.size() - 1)]


func _update_highlights() -> void:
	var focused := _focused_target()
	for view: UnitView in _views.values():
		view.highlight = UnitView.Highlight.NONE
		view.focused = false
		view.queue_redraw()
	if _selected == null:
		return
	var actor := _battle.current
	for target in _targets:
		var view: UnitView = _views.get(target.uid)
		if view == null:
			continue
		view.highlight = UnitView.Highlight.ENEMY_TARGET if target.is_hero != actor.is_hero \
				else UnitView.Highlight.ALLY_TARGET
		view.focused = _selected.multi_target or target == focused


func _on_view_clicked(view: UnitView) -> void:
	if view.unit in _targets:
		_confirm(view.unit)


func _on_view_hovered(view: UnitView, inside: bool) -> void:
	if inside and view.unit in _targets:
		_focus_index = _targets.find(view.unit)
		_update_highlights()
		_show_info(_selected)


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
				_update_highlights()
				_show_info(_selected)
		_:
			if key >= KEY_1 and key <= KEY_9:
				var index := key - KEY_1
				if index < _skill_bar.get_child_count():
					_select_skill((_skill_bar.get_child(index) as SkillButton).skill)
				return
			return
	get_viewport().set_input_as_handled()


# --- Info panels ---

func _show_info(skill: SkillDef) -> void:
	if skill == null or _battle.current == null:
		_info.text = ""
		return
	var actor := _battle.current
	var text := "[b][font_size=22]%s[/font_size][/b]\n%s" % [skill.display_name, UiStyle.describe_skill(skill, actor)]
	var target := _focused_target() if skill == _selected else null
	if target and skill.kind == SkillDef.Kind.ACTION and (skill.deals_damage() or skill.heals() or skill.is_attack()):
		var preview := _battle.preview(actor, skill, target)
		var parts: Array[String] = []
		if skill.is_attack():
			parts.append("hit %s" % UiStyle.percent(preview.hit_chance))
		if skill.deals_damage():
			parts.append("%d-%d damage" % [preview.damage_min, preview.damage_max])
			parts.append("crit %s for %d" % [UiStyle.percent(preview.crit_chance), preview.crit_damage])
		if skill.heals():
			parts.append("heal %d-%d" % [preview.heal_min, preview.heal_max])
		text += "\n[color=#d9b45a]vs %s: %s[/color]" % [target.display_name, ", ".join(parts)]
	_info.text = text


func _update_actor_card(actor: Combatant) -> void:
	var lines: Array[String] = []
	lines.append("[b][font_size=26]%s[/font_size][/b]" % actor.display_name)
	var rank := _battle.rank_of(actor)
	lines.append("[color=#9a8c7a]%s%s[/color]" % [actor.def.role, ", rank %d" % rank if rank > 0 else ""])
	lines.append("HP %d/%d   Stress %d/%d   Speed %d" % [actor.hp, actor.max_hp, actor.stress, Rules.STRESS_MAX,
			actor.speed()])
	if actor.deaths_door:
		lines.append("[color=#e0533f]On Death's Door[/color]")
	var tokens: Array[String] = []
	for token: StringName in actor.tokens:
		tokens.append("%s x%d" % [UiStyle.token_name(token), actor.token_count(token)])
	if not tokens.is_empty():
		lines.append("Tokens: " + ", ".join(tokens))
	_actor_card.text = "\n".join(lines)


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
	_end_closeup()
	_refresh_views()
	_layout(true)
	if not events.is_empty():
		await _wait(0.2)


## Shows one event and returns how long to linger on it, in seconds at 1x speed.
func _apply_event(event: Dictionary) -> float:
	var view: UnitView = _views.get(event.uid)
	match event.type:
		&"round_start":
			_round_label.text = "Round %d" % event.round
			_show_banner("Round %d" % event.round, 0.7)
			return 0.5
		&"turn_start":
			_set_active(view)
			if _units.has(event.uid):
				_update_actor_card(_units[event.uid])
			return 0.15
		&"dazed":
			_float(view, "Dazed", UiStyle.token_color(Tokens.DAZE))
			return 0.5
		&"stunned":
			_set_active(view)
			_float(view, "Stunned", UiStyle.token_color(Tokens.STUN), 28)
			return 0.7
		&"skill":
			_start_closeup(event)
			_float(view, (event.skill as SkillDef).display_name, UiStyle.GOLD, 30)
			return 0.55
		&"miss":
			_float(view, "Dodged" if event.reason == &"dodge" else "Miss", UiStyle.TEXT, 28)
			return 0.35
		&"guarded":
			_float(view, "Guards", UiStyle.token_color(Tokens.GUARD))
			return 0.3
		&"damage":
			if view:
				view.set_hp(event.hp)
				_shake(view)
			var crit: bool = event.get("crit", false)
			var cause: StringName = event.get("cause", &"hit")
			var color: Color = UiStyle.DOT_COLORS.get(cause, UiStyle.CRIT if crit else UiStyle.HP.lightened(0.2))
			_float(view, ("CRIT %d" if crit else "%d") % event.amount, color, 40 if crit else 32)
			return 0.4
		&"heal":
			if view:
				view.set_hp(event.hp)
			if event.amount == 0:
				return 0.0
			_float(view, "+%d" % event.amount, UiStyle.HEAL, 32)
			return 0.3
		&"stress":
			if view:
				view.set_stress(event.stress)
			_float(view, "%+d Stress" % event.amount, UiStyle.STRESS)
			return 0.3
		&"stress_resisted":
			_float(view, "Stress resisted", UiStyle.STRESS)
			return 0.3
		&"token":
			if event.added > 0:
				_float(view, "+" + UiStyle.token_name(event.token), UiStyle.token_color(event.token), 22)
			for negated: StringName in event.negated:
				_float(view, "-" + UiStyle.token_name(negated), UiStyle.token_color(negated), 22)
			if view:
				view.refresh()
			return 0.2
		&"resisted":
			_float(view, "Resisted", UiStyle.TEXT_DIM)
			return 0.3
		&"dot_applied":
			_float(view, "%s %d" % [String(event.dot).capitalize(), event.amount], UiStyle.DOT_COLORS.get(event.dot, UiStyle.TEXT))
			if view:
				view.refresh()
			return 0.25
		&"cleansed":
			_float(view, "Cleansed", UiStyle.HEAL)
			if view:
				view.refresh()
			return 0.25
		&"immobile":
			_float(view, "Immobile", UiStyle.TEXT_DIM)
			return 0.25
		&"moved":
			_layout(true)
			return 0.25
		&"reposition":
			_float(view, "Repositions", UiStyle.TEXT_DIM)
			return 0.3
		&"pass":
			_set_active(view)
			_float(view, "Waits", UiStyle.TEXT_DIM)
			return 0.45
		&"deaths_door":
			_float(view, "DEATH'S DOOR", UiStyle.HP, 34)
			if view:
				view.refresh()
			return 0.8
		&"left_deaths_door":
			_float(view, "Saved", UiStyle.HEAL)
			return 0.3
		&"deathblow_resisted":
			_float(view, "Deathblow resisted", UiStyle.GOLD, 26)
			return 0.6
		&"deathblow":
			_float(view, "DEATHBLOW", UiStyle.HP, 36)
			return 0.6
		&"death_armor":
			_float(view, "Death Armor holds", Color("c0c0c0"))
			if view:
				view.refresh()
			return 0.45
		&"death":
			if view:
				view.refresh()
			_float(view, "Slain", UiStyle.HP, 30)
			return 0.7
		&"removed":
			if view:
				_views.erase(event.uid)
				var tween := view.create_tween()
				tween.tween_property(view, "modulate:a", 0.0, 0.3 / _speed)
				tween.tween_callback(view.queue_free)
			_layout(true)
			return 0.3
		&"meltdown":
			if view:
				view.set_hp(event.hp)
				view.set_stress(event.stress)
			_float(view, "MELTDOWN", UiStyle.STRESS, 40)
			return 1.0
		&"resolute":
			if view:
				view.set_stress(0)
			_float(view, "RESOLUTE", UiStyle.GOLD, 40)
			return 1.0
	return 0.0


func _start_closeup(event: Dictionary) -> void:
	_end_closeup()
	var involved: Array[UnitView] = []
	for uid: int in [event.uid] + event.targets:
		var view: UnitView = _views.get(uid)
		if view and view not in involved:
			involved.append(view)
	for view in involved:
		view.z_index = 5
		view.create_tween().tween_property(view, "scale", Vector2.ONE * 1.08, 0.15 / _speed)
	_overlay.create_tween().tween_property(_overlay, "color:a", 0.5, 0.15 / _speed)
	_closeup = involved


func _end_closeup() -> void:
	for view in _closeup:
		if is_instance_valid(view):
			view.z_index = 0
			view.create_tween().tween_property(view, "scale", Vector2.ONE, 0.15 / _speed)
	_closeup.clear()
	_overlay.create_tween().tween_property(_overlay, "color:a", 0.0, 0.2 / _speed)


func _float(view: UnitView, text: String, color: Color, font_size: int = 24) -> void:
	if view == null or not is_instance_valid(view):
		return
	var uid := view.unit.uid
	var stack: int = _floats_per_view.get(uid, 0)
	_floats_per_view[uid] = stack + 1
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 8)
	label.size = Vector2(320, font_size + 16)
	label.position = view.float_origin() - Vector2(160, 0) + Vector2(0, stack * 30)
	_fx.add_child(label)
	var duration := 1.1 / _speed
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 70.0, duration).set_ease(Tween.EASE_OUT) \
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


func _set_active(view: UnitView) -> void:
	for other: UnitView in _views.values():
		other.is_active_turn = other == view
		other.queue_redraw()


func _show_banner(text: String, seconds: float = 1.0) -> void:
	_banner.text = text
	_banner.modulate.a = 0.0
	var tween := _banner.create_tween()
	tween.tween_property(_banner, "modulate:a", 1.0, 0.2 / _speed)
	tween.tween_interval(seconds / _speed)
	tween.tween_property(_banner, "modulate:a", 0.0, 0.3 / _speed)


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
	for unit in _battle.all_units():
		var view: UnitView = _views.get(unit.uid)
		if view == null:
			continue
		var rank := _battle.rank_of(unit)
		var center := (_rank_center(rank, unit.is_hero) + _rank_center(rank + unit.size - 1, unit.is_hero)) / 2.0
		var target := Vector2(center - view.size.x / 2.0, FIELD_TOP)
		if animated:
			view.create_tween().tween_property(view, "position", target, 0.25 / _speed) \
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			view.position = target


func _rank_center(rank: int, hero: bool) -> float:
	var offset := CENTER_GAP + UnitView.SLOT_WIDTH / 2.0 + (rank - 1) * UnitView.SLOT_PITCH
	return FIELD_CENTER_X - offset if hero else FIELD_CENTER_X + offset


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
		# The close-up dimmer covers the whole window, including any letterbox bands.
		_overlay.position = -_stage.position
		_overlay.size = size
	queue_redraw()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage = Control.new()
	_stage.size = STAGE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)

	_field = Control.new()
	_field.size = STAGE_SIZE
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_field)
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.size = STAGE_SIZE
	_overlay.z_index = 3
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(_overlay)

	var top_bar := HBoxContainer.new()
	top_bar.position = Vector2(32, 18)
	top_bar.size = Vector2(STAGE_SIZE.x - 64, 44)
	top_bar.add_theme_constant_override("separation", 24)
	_stage.add_child(top_bar)
	_wave_label = _label(26, UiStyle.GOLD)
	_round_label = _label(22, UiStyle.TEXT)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_label = _label(16, UiStyle.TEXT_DIM)
	_log_button = _button("Log (L)", _toggle_log)
	_log_button.toggle_mode = true
	_speed_button = _button("Speed 1x (S)", _toggle_speed)
	var restart := _button("Restart (R)", _new_run)
	for node: Control in [_wave_label, _round_label, spacer, _seed_label, _log_button, _speed_button, restart]:
		top_bar.add_child(node)

	_banner = _label(56, UiStyle.GOLD)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(0, 120)
	_banner.size = Vector2(STAGE_SIZE.x, 80)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.modulate.a = 0.0
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_banner)

	var bottom := PanelContainer.new()
	bottom.position = Vector2(24, 800)
	bottom.size = Vector2(STAGE_SIZE.x - 48, 256)
	_stage.add_child(bottom)
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 20)
	bottom.add_child(bottom_row)
	_actor_card = _rich_text(Vector2(290, 0))
	_skill_bar = HBoxContainer.new()
	_skill_bar.add_theme_constant_override("separation", 6)
	_skill_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_skill_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info = _rich_text(Vector2(430, 0))
	for node: Control in [_actor_card, VSeparator.new(), _skill_bar, VSeparator.new(), _info]:
		bottom_row.add_child(node)

	_fx = Control.new()
	_fx.size = STAGE_SIZE
	_fx.z_index = 20
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_fx)

	_log_panel = PanelContainer.new()
	_log_panel.position = Vector2(STAGE_SIZE.x - 520, 76)
	_log_panel.size = Vector2(496, 700)
	_log_panel.z_index = 30
	_log_panel.hide()
	_stage.add_child(_log_panel)
	_log = _rich_text(Vector2.ZERO)
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.add_theme_font_size_override("bold_font_size", 14)
	_log_panel.add_child(_log)

	_end_panel = PanelContainer.new()
	_end_panel.z_index = 40
	_end_panel.position = Vector2(STAGE_SIZE.x / 2.0 - 320, 300)
	_end_panel.size = Vector2(640, 280)
	_end_panel.hide()
	_stage.add_child(_end_panel)
	var end_box := VBoxContainer.new()
	end_box.alignment = BoxContainer.ALIGNMENT_CENTER
	end_box.add_theme_constant_override("separation", 18)
	_end_panel.add_child(end_box)
	_end_title = _label(44, UiStyle.GOLD)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_text = _label(17, UiStyle.TEXT)
	_end_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_text.custom_minimum_size = Vector2(600, 0)
	_end_button = _button("", func() -> void: _end_action.call())
	_end_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_end_button.custom_minimum_size = Vector2(260, 48)
	for node: Control in [_end_title, _end_text, _end_button]:
		end_box.add_child(node)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


func _rich_text(minimum: Vector2) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = false
	text.scroll_active = true
	text.custom_minimum_size = minimum
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("normal_font_size", 17)
	text.add_theme_font_size_override("bold_font_size", 17)
	return text


func _make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = UI_FONT
	result.default_font_size = 18

	var panel := _box(UiStyle.PANEL, UiStyle.PANEL_BORDER, 2, 8)
	panel.set_content_margin_all(14)
	result.set_stylebox("panel", "PanelContainer", panel)
	result.set_stylebox("panel", "TooltipPanel", _box(Color("120e10f2"), UiStyle.PANEL_BORDER, 1, 4))
	result.set_color("font_color", "TooltipLabel", UiStyle.TEXT)
	result.set_font_size("font_size", "TooltipLabel", 15)

	result.set_stylebox("normal", "Button", _box(Color("2a2024"), UiStyle.PANEL_BORDER, 2, 6))
	result.set_stylebox("hover", "Button", _box(Color("3a2c2c"), UiStyle.GOLD.darkened(0.3), 2, 6))
	result.set_stylebox("pressed", "Button", _box(Color("4a3628"), UiStyle.GOLD, 3, 6))
	result.set_stylebox("hover_pressed", "Button", _box(Color("553e2c"), UiStyle.GOLD, 3, 6))
	result.set_stylebox("disabled", "Button", _box(Color("1a1416"), Color("2e2622"), 2, 6))
	result.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		result.set_color(state, "Button", UiStyle.TEXT)
	result.set_color("font_disabled_color", "Button", UiStyle.TEXT_DIM.darkened(0.3))
	result.set_color("font_color", "Label", UiStyle.TEXT)
	result.set_color("default_color", "RichTextLabel", UiStyle.TEXT)
	return result


func _box(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(8)
	return box

## One combatant on the battlefield, DD2-style: the figure standing on the
## ground line, and under its feet a status stack of DoT icons, HP bar, stress
## pips (heroes) and tokens. No name; that lives in the HUD and the tooltip.
## The local point FEET is where the feet touch the ground; scaling pivots there.
class_name UnitView
extends Control

signal clicked(view: UnitView)
## A right-click, which always opens the unit's details.
signal right_clicked(view: UnitView)
signal hovered(view: UnitView, inside: bool)

enum Highlight { NONE, ENEMY_TARGET, ALLY_TARGET }

## Space the figure may fill: [width, height] for size-1 and size-2 units.
const FIT_SMALL := Vector2(220, 380)
const FIT_LARGE := Vector2(480, 460)
const STACK_HEIGHT := 100.0
const HP_BAR_SMALL := 124.0
const HP_BAR_LARGE := 240.0
const HP_BAR_HEIGHT := 16.0
const TOKEN_SIZE := 22.0
const TOKEN_GAP := 6.0
const DOT_SIZE := 18.0

var unit: Combatant
## HP, stress, Death's Door and corpse as currently shown. The battle has
## already resolved the whole action when playback starts, so these follow the
## events instead of the combatant, or a unit killed by an attack would show as
## a corpse for the whole close-up.
var hp_shown: int
var stress_shown: int
var deaths_door_shown := false
var corpse_shown := false
var is_active_turn := false
var highlight := Highlight.NONE
var focused := false
## Its details are open; marked with pale brackets.
var inspecting := false
## Tokens the selected attack would use up on this unit; drawn with a gold square.
var consumed_tokens: Array[StringName] = []
## In a close-up the status stack and markers are hidden.
var closeup := false
## Drawn instead of the unit's sprite during a close-up: its attack pose for the
## skill in use, or its hurt pose once hit (see Poses). Null for the usual sprite.
var pose: Texture2D:
	set(value):
		pose = value
		queue_redraw()
var _pulse := 0.0

var feet: Vector2:
	get:
		return Vector2(size.x / 2.0, FIT_LARGE.y)


func setup(combatant: Combatant) -> void:
	unit = combatant
	size = Vector2(_fit_box().x, FIT_LARGE.y + STACK_HEIGHT)
	pivot_offset = feet
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: hovered.emit(self, true))
	mouse_exited.connect(func() -> void: hovered.emit(self, false))
	refresh()


## Catches up with the combatant completely, once its events have played.
func refresh() -> void:
	hp_shown = unit.hp
	stress_shown = unit.stress
	deaths_door_shown = unit.deaths_door
	corpse_shown = unit.is_corpse
	refresh_status()


## Tokens, DoTs or buffs changed mid-playback: redraws them and the tooltip
## without jumping ahead to HP, Death's Door or death that later events show.
func refresh_status() -> void:
	tooltip_text = UiStyle.describe_unit(unit)
	queue_redraw()


func set_deaths_door(value: bool) -> void:
	deaths_door_shown = value
	queue_redraw()


## The figure fades out in red; a corpse, if the unit leaves one, then fades in.
func play_death(corpse: bool, corpse_hp: int, speed: float) -> void:
	deaths_door_shown = false
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.25, 0.2, 0.0), 0.35 / speed)
	tween.tween_callback(func() -> void:
		corpse_shown = corpse
		hp_shown = corpse_hp
		refresh_status())
	if corpse:
		tween.tween_property(self, "modulate", Color.WHITE, 0.25 / speed)


func set_hp(value: int) -> void:
	hp_shown = value
	queue_redraw()


func set_stress(value: int) -> void:
	stress_shown = value
	queue_redraw()


## Where pop-ups start, in the parent's coordinates (follows scale and position).
func float_origin() -> Vector2:
	return _to_parent(feet - Vector2(0, _figure_height() * 0.8))


func _to_parent(point: Vector2) -> Vector2:
	return position + pivot_offset + (point - pivot_offset) * scale


func _has_point(point: Vector2) -> bool:
	return _figure_rect().grow(6.0).has_point(point) or _stack_rect().has_point(point)


func _process(delta: float) -> void:
	if highlight != Highlight.NONE or is_active_turn or deaths_door_shown:
		_pulse += delta
		queue_redraw()


## Clicks count on press; taps on release, so a long press (which swallows the
## release) can show the stat sheet without also choosing the unit.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed != Device.touch:
		clicked.emit(self)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		right_clicked.emit(self)
		accept_event()


# --- Geometry ---

func _fit_box() -> Vector2:
	return FIT_LARGE if unit.size > 1 else FIT_SMALL


func _figure_rect() -> Rect2:
	if corpse_shown:
		return Rect2(feet.x - size.x * 0.35, feet.y - 50, size.x * 0.7, 70)
	var texture := _sprite()
	var fit := _fit_box()
	var drawn: Vector2
	if texture:
		var scale_fit := minf(fit.x / texture.get_width(), fit.y / texture.get_height()) * unit.def.sprite_scale
		drawn = texture.get_size() * scale_fit
	else:
		drawn = Vector2(fit.x * 0.6, fit.y * 0.9)
	return Rect2(feet.x - drawn.x / 2.0, feet.y - drawn.y, drawn.x, drawn.y)


## The pose if one is set, otherwise the unit's sprite (null without art).
func _sprite() -> Texture2D:
	return pose if pose else unit.def.sprite


func _figure_height() -> float:
	return _figure_rect().size.y


func _stack_rect() -> Rect2:
	return Rect2(0, feet.y, size.x, STACK_HEIGHT)


func _bar_width() -> float:
	return HP_BAR_LARGE if unit.size > 1 else HP_BAR_SMALL


# --- Drawing ---

func _draw() -> void:
	var figure := _figure_rect()
	if not closeup:
		_draw_target_box(figure)
		_draw_active_glow()
	_draw_figure(figure)
	if closeup:
		return
	_draw_brackets()
	_draw_dots()
	_draw_hp_bar()
	if unit.is_hero and not corpse_shown:
		_draw_stress()
	if not corpse_shown:
		_draw_tokens()


func _draw_figure(figure: Rect2) -> void:
	# Floor shadow.
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.2))
	draw_circle(Vector2.ZERO, figure.size.x * 0.45, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	if corpse_shown:
		var corpse := StyleBoxFlat.new()
		corpse.bg_color = Color(0.16, 0.13, 0.12)
		corpse.border_color = Color(0.3, 0.26, 0.22)
		corpse.set_border_width_all(2)
		corpse.set_corner_radius_all(18)
		draw_style_box(corpse, figure)
		return
	var texture := _sprite()
	var tint := Color(1.0, 0.7, 0.7) if deaths_door_shown else Color.WHITE
	if texture:
		var rect := figure
		if not unit.is_hero:
			rect.size.x = -rect.size.x  # a negative width mirrors in place, so enemies face the heroes
		draw_texture_rect(texture, rect, false, tint)
		return
	# Coloured placeholder for units without art.
	var base := unit.def.color
	var body := StyleBoxFlat.new()
	body.bg_color = base.darkened(0.2)
	body.border_color = base.lightened(0.25)
	body.set_border_width_all(3)
	body.set_corner_radius_all(16)
	draw_style_box(body, figure)
	var facing := 1.0 if unit.is_hero else -1.0
	var head := Vector2(figure.get_center().x + facing * 12.0, figure.position.y + 56.0)
	draw_circle(head, 30.0, base.lightened(0.08))
	draw_circle(head + Vector2(facing * 14.0, -5.0), 5.0, Color("f2e6d0"))


## Translucent box behind the focused target, from the bracket up to 60% of its height.
func _draw_target_box(figure: Rect2) -> void:
	if highlight == Highlight.NONE or not focused:
		return
	var color := UiStyle.BLUE if highlight == Highlight.ENEMY_TARGET else UiStyle.GREEN
	var width := _bar_width() + 60.0
	var top := feet.y - figure.size.y * 0.6
	var box := Rect2(feet.x - width / 2.0, top, width, feet.y + 19.0 - top)
	draw_rect(box, Color(color, 0.22 + 0.06 * sin(_pulse * 4.0)))
	draw_rect(Rect2(box.position.x, box.end.y - 3.0, box.size.x, 3.0), Color(color.lightened(0.3), 0.8))


## Amber glow rising behind the unit whose turn it is.
func _draw_active_glow() -> void:
	if not is_active_turn:
		return
	var half := 80.0 if unit.size == 1 else 130.0
	var base := feet.y + 19.0
	var clear := Color(UiStyle.AMBER, 0.0)
	var warm := Color(UiStyle.AMBER, 0.3 + 0.05 * sin(_pulse * 3.0))
	draw_polygon(PackedVector2Array([
			Vector2(feet.x - half, base - 70), Vector2(feet.x + half, base - 70),
			Vector2(feet.x + half, base), Vector2(feet.x - half, base)]),
			PackedColorArray([clear, clear, warm, warm]))


## A horizontal line with outward chevron tips, just above the HP bar.
func _draw_brackets() -> void:
	var color: Color
	var half: float
	if is_active_turn:
		color = UiStyle.GOLD
		half = 80.0 if unit.size == 1 else 130.0
	elif highlight != Highlight.NONE:
		color = UiStyle.BLUE if highlight == Highlight.ENEMY_TARGET else UiStyle.GREEN
		if focused:
			color = color.lightened(0.3)
		half = _bar_width() / 2.0 + 30.0
	elif inspecting:
		color = UiStyle.TEXT
		half = _bar_width() / 2.0 + 30.0
	else:
		return
	var y := feet.y + 19.0
	draw_line(Vector2(feet.x - half, y), Vector2(feet.x + half, y), color, 3.0)
	for side: float in [-1.0, 1.0]:
		var tip := Vector2(feet.x + side * half, y)
		draw_polyline(PackedVector2Array([tip + Vector2(-side * 10, -8), tip + Vector2(side * 4, 0),
				tip + Vector2(-side * 10, 8)]), color, 3.0)


func _draw_dots() -> void:
	var icons: Array[StringName] = []
	for type: StringName in [&"bleed", &"blight", &"burn"]:
		if unit.dot_total(type) > 0:
			icons.append(type)
	var x := feet.x - (icons.size() * (DOT_SIZE + 4.0) - 4.0) / 2.0
	for type in icons:
		var icon := UiStyle.token_icon(type)
		if icon:
			draw_texture_rect(icon, Rect2(x, feet.y - 2.0, DOT_SIZE, DOT_SIZE), false)
		x += DOT_SIZE + 4.0


func _draw_hp_bar() -> void:
	var width := _bar_width()
	var top := feet.y + 25.0
	var height := HP_BAR_HEIGHT
	var left := feet.x - width / 2.0
	var slant := 6.0
	var frame := PackedVector2Array([Vector2(left, top), Vector2(left + width, top),
			Vector2(left + width - slant, top + height), Vector2(left + slant, top + height)])
	draw_colored_polygon(frame, UiStyle.HP_EMPTY)
	var max_hp := unit.def.corpse_hp if corpse_shown else unit.max_hp
	var fraction := clampf(float(hp_shown) / maxf(max_hp, 1), 0.0, 1.0)
	if deaths_door_shown:
		fraction = 0.0
	if fraction > 0.0:
		var fill_right := left + slant + (width - 2.0 * slant) * fraction
		draw_colored_polygon(PackedVector2Array([Vector2(left, top), Vector2(fill_right + slant, top),
				Vector2(fill_right, top + height), Vector2(left + slant, top + height)]),
				UiStyle.CORPSE_FILL if corpse_shown else UiStyle.HP_FILL)
	for quarter in [0.25, 0.5, 0.75]:
		var x: float = left + slant + (width - 2.0 * slant) * quarter
		draw_line(Vector2(x, top + 2), Vector2(x, top + height - 2), Color(0, 0, 0, 0.6), 1.0)
	var frame_color := UiStyle.HP_FRAME
	if deaths_door_shown:
		frame_color = UiStyle.DAMAGE.lerp(UiStyle.HP_FRAME, 0.5 + 0.5 * sin(_pulse * 3.0))
	var outline := frame.duplicate()
	outline.append(frame[0])
	draw_polyline(outline, frame_color, 2.0)
	# Buff and debuff summaries at the ends of the bar.
	var font := UiStyle.BODY_FONT
	if unit.buffs.any(func(buff: Dictionary) -> bool: return buff.amount > 0.0):
		draw_string(font, Vector2(left - 24, top + 13), "^^", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiStyle.GOLD)
	if unit.buffs.any(func(buff: Dictionary) -> bool: return buff.amount < 0.0):
		draw_string(font, Vector2(left + width + 6, top + 13), "vv", HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
				UiStyle.BLUE.lightened(0.2))


## 10 pips: 3 small then 7 large, filled white up to the current stress.
func _draw_stress() -> void:
	var widths: Array[float] = []
	for i in Rules.STRESS_MAX:
		widths.append(7.0 if i < 3 else 10.0)
	var total := 0.0
	for width in widths:
		total += width + 3.0
	var x := feet.x - (total - 3.0) / 2.0
	var middle := feet.y + 25.0 + HP_BAR_HEIGHT + 13.0
	for i in widths.size():
		var width: float = widths[i]
		var color := UiStyle.STRESS_ON if i < stress_shown else UiStyle.STRESS_OFF
		draw_rect(Rect2(x, middle - width / 2.0, width, width), color)
		x += width + 3.0


func _draw_tokens() -> void:
	var entries: Array[StringName] = []
	if deaths_door_shown:
		entries.append(&"death_armor")  # the skull marks Death's Door
	elif unit.death_armor > 0 and not unit.is_hero:
		entries.append(&"death_armor")
	for token: StringName in unit.tokens:
		entries.append(token)
	if entries.is_empty():
		return
	var top := feet.y + (67.0 if unit.is_hero else 50.0)
	var x := feet.x - (entries.size() * (TOKEN_SIZE + TOKEN_GAP) - TOKEN_GAP) / 2.0
	for id in entries:
		var rect := Rect2(x, top, TOKEN_SIZE, TOKEN_SIZE)
		var icon := UiStyle.token_icon(id)
		if icon:
			draw_texture_rect(icon, rect, false)
		if id in consumed_tokens:
			draw_rect(rect.grow(3.0), UiStyle.GOLD, false, 2.0)
		# One small diamond per stack beyond the first.
		var extra := unit.token_count(id) - 1 if Tokens.RULES.has(id) else 0
		for i in extra:
			draw_colored_polygon(UiStyle.diamond(Vector2(rect.get_center().x + (i - (extra - 1) / 2.0) * 7.0,
					rect.end.y + 5.0), 3.0), Color.WHITE)
		x += TOKEN_SIZE + TOKEN_GAP

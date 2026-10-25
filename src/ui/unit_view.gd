## Placeholder drawing of one combatant: tokens above, body, then name, HP bar
## and stress pips. Clicks and hovers are reported to the combat screen.
class_name UnitView
extends Control

signal clicked(view: UnitView)
signal hovered(view: UnitView, inside: bool)

enum Highlight { NONE, ENEMY_TARGET, ALLY_TARGET }

const SLOT_WIDTH := 150.0
const SLOT_PITCH := 180.0
const TOKEN_ROWS_HEIGHT := 44.0
const BODY_HEIGHT := 250.0
const HEIGHT := TOKEN_ROWS_HEIGHT + BODY_HEIGHT + 92.0
const CHIP_HEIGHT := 18.0

var unit: Combatant
## HP and stress as currently shown; events update them in step with the floating numbers.
var hp_shown: int
var stress_shown: int
var is_active_turn := false
var highlight := Highlight.NONE
var focused := false
var _pulse := 0.0


static func width_for(slots: int) -> float:
	return SLOT_WIDTH + (slots - 1) * SLOT_PITCH


func setup(combatant: Combatant) -> void:
	unit = combatant
	size = Vector2(width_for(combatant.size), HEIGHT)
	pivot_offset = Vector2(size.x / 2.0, TOKEN_ROWS_HEIGHT + BODY_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: hovered.emit(self, true))
	mouse_exited.connect(func() -> void: hovered.emit(self, false))
	refresh()


## Re-reads everything from the combatant.
func refresh() -> void:
	hp_shown = unit.hp
	stress_shown = unit.stress
	tooltip_text = UiStyle.describe_unit(unit)
	queue_redraw()


func set_hp(value: int) -> void:
	hp_shown = value
	queue_redraw()


func set_stress(value: int) -> void:
	stress_shown = value
	queue_redraw()


## Where floating text should start, in the parent's coordinates.
func float_origin() -> Vector2:
	return position + Vector2(size.x / 2.0, TOKEN_ROWS_HEIGHT + BODY_HEIGHT * 0.35)


func _process(delta: float) -> void:
	if highlight != Highlight.NONE or is_active_turn:
		_pulse += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()


func _draw() -> void:
	var font := get_theme_default_font()
	var width := size.x
	var body := Rect2(10, TOKEN_ROWS_HEIGHT, width - 20, BODY_HEIGHT)
	if unit.is_corpse:
		body = Rect2(22, TOKEN_ROWS_HEIGHT + BODY_HEIGHT - 64, width - 44, 64)

	if highlight != Highlight.NONE:
		var color := UiStyle.ENEMY_TARGET if highlight == Highlight.ENEMY_TARGET else UiStyle.ALLY_TARGET
		color.a = 0.55 + 0.35 * sin(_pulse * 5.0) if focused else 0.35 + 0.2 * sin(_pulse * 4.0)
		draw_rect(body.grow(9.0 if focused else 6.0), color, false, 4.0 if focused else 2.5)
	if is_active_turn:
		var bob := 4.0 * sin(_pulse * 4.0)
		var tip := Vector2(width / 2.0, TOKEN_ROWS_HEIGHT - 4 + bob)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-12, -16), tip + Vector2(12, -16)]), UiStyle.GOLD)

	_draw_body(body)
	_draw_tokens(font, width)
	_draw_status(font, width)


func _draw_body(body: Rect2) -> void:
	if unit.def.sprite and not unit.is_corpse:
		_draw_sprite(unit.def.sprite, body)
		return
	var base := Color(0.24, 0.21, 0.2) if unit.is_corpse else unit.def.color
	var style := StyleBoxFlat.new()
	style.bg_color = base.darkened(0.2)
	style.border_color = UiStyle.HP if unit.deaths_door else base.lightened(0.25)
	if is_active_turn:
		style.border_color = UiStyle.GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	draw_style_box(style, body)
	if unit.is_corpse:
		return
	# A head with an eye shows which way the unit faces.
	var facing := 1.0 if unit.is_hero else -1.0
	var head := Vector2(size.x / 2.0 + facing * 12.0, body.position.y + 52.0)
	draw_circle(head, 28.0, base.lightened(0.08))
	draw_circle(head + Vector2(facing * 13.0, -5.0), 4.5, Color("f2e6d0"))
	# Shoulders.
	var shoulders := Rect2(body.position.x + 22, body.position.y + 92, body.size.x - 44, 26)
	draw_rect(shoulders, base.lightened(0.04))


## Fits the sprite into the body slot, feet on the slot's bottom edge, with a
## floor shadow that turns into a gold ring on the unit's turn.
func _draw_sprite(texture: Texture2D, body: Rect2) -> void:
	var feet := Vector2(body.get_center().x, body.end.y)
	var ring := body.size.x * 0.45
	draw_set_transform(feet, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, ring, Color(0, 0, 0, 0.4))
	if is_active_turn:
		draw_arc(Vector2.ZERO, ring, 0.0, TAU, 48, UiStyle.GOLD, 4.0)
	elif unit.deaths_door:
		draw_arc(Vector2.ZERO, ring, 0.0, TAU, 48, UiStyle.HP, 4.0)
	draw_set_transform(Vector2.ZERO)

	var fit := minf(body.size.x / texture.get_width(), body.size.y / texture.get_height()) * unit.def.sprite_scale
	var drawn := texture.get_size() * fit
	var rect := Rect2(feet.x - drawn.x / 2.0, feet.y - drawn.y, drawn.x, drawn.y)
	if not unit.is_hero:
		# A negative width mirrors the texture in place so enemies face the heroes.
		rect.size.x = -rect.size.x
	var tint := Color(1.0, 0.7, 0.7) if unit.deaths_door else Color.WHITE
	draw_texture_rect(texture, rect, false, tint)


func _draw_tokens(font: Font, width: float) -> void:
	var chips: Array[Array] = []
	for token: StringName in unit.tokens:
		var label: String = UiStyle.TOKENS[token][0] if UiStyle.TOKENS.has(token) else String(token)
		var count := unit.token_count(token)
		chips.append([label + (str(count) if count > 1 else ""), UiStyle.token_color(token)])
	for dot: Array in [[&"bleed", "BLD"], [&"blight", "BLT"], [&"burn", "BRN"]]:
		var total := unit.dot_total(dot[0])
		if total > 0:
			chips.append(["%s %d" % [dot[1], total], UiStyle.DOT_COLORS[dot[0]]])
	if unit.death_armor > 0 and not unit.is_hero:
		chips.append(["DA%d" % unit.death_armor, Color("c0c0c0")])
	var x := 6.0
	var y := 2.0
	for chip in chips:
		var text: String = chip[0]
		var chip_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 10.0
		if x + chip_width > width - 6.0:
			x = 6.0
			y += CHIP_HEIGHT + 3.0
		var rect := Rect2(x, y, chip_width, CHIP_HEIGHT)
		var color: Color = chip[1]
		draw_rect(rect, Color(color, 0.22))
		draw_rect(rect, color, false, 1.0)
		draw_string(font, Vector2(x + 5.0, y + 13.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
		x += chip_width + 4.0


func _draw_status(font: Font, width: float) -> void:
	var top := TOKEN_ROWS_HEIGHT + BODY_HEIGHT + 8.0
	var name_text := unit.display_name + (" (corpse)" if unit.is_corpse else "")
	var font_size := 18
	while font_size > 11 and font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width - 4:
		font_size -= 1
	draw_string(font, Vector2(0, top + 18), name_text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, UiStyle.TEXT)

	var bar := Rect2(10, top + 28, width - 20, 16)
	draw_rect(bar, UiStyle.HP_BACK)
	var max_hp := unit.def.corpse_hp if unit.is_corpse else unit.max_hp
	var fraction := clampf(float(hp_shown) / maxf(max_hp, 1), 0.0, 1.0)
	var fill := Color(0.45, 0.42, 0.4) if unit.is_corpse else UiStyle.HP
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * fraction, bar.size.y)), fill)
	var hp_text := "DEATH'S DOOR" if unit.deaths_door else "%d / %d" % [hp_shown, max_hp]
	draw_string(font, bar.position + Vector2(0, 13), hp_text, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 12,
			UiStyle.TEXT)

	if not unit.is_hero or unit.is_corpse:
		return
	var pip_width := (bar.size.x - (Rules.STRESS_MAX - 1) * 3.0) / Rules.STRESS_MAX
	for i in Rules.STRESS_MAX:
		var pip := Rect2(bar.position.x + i * (pip_width + 3.0), top + 50, pip_width, 10)
		draw_rect(pip, UiStyle.STRESS if i < stress_shown else UiStyle.STRESS_BACK)

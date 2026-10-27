## A hero on the mission map's party panel: portrait, name, HP bar, stress pips
## and the tokens they will carry into the next fight. Narrower in the phone layout.
class_name MapHeroCard
extends Control

const SIZE := Vector2(290, 132)
const PHONE_SIZE := Vector2(214, 132)

var unit: Combatant
var caption := ""
var defeated := false


func setup(combatant: Combatant, label: String, is_defeated: bool = false) -> void:
	unit = combatant
	caption = label
	defeated = is_defeated
	custom_minimum_size = PHONE_SIZE if Device.phone else SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_style_box(UiStyle.card(), Rect2(Vector2.ZERO, size))
	var body := UiStyle.BODY_FONT
	draw_string(body, Vector2(0, 20), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14,
			UiStyle.DAMAGE if defeated else UiStyle.TEXT_DIM)
	var side := size.y - 40.0
	var portrait := Rect2(10, 30, side, side)
	UiStyle.draw_portrait(self, portrait, unit.def)
	var left := portrait.end.x + 10.0
	draw_string(UiStyle.DISPLAY_FONT, Vector2(left, 52), unit.display_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - left - 6,
			20 if Device.phone else 24, UiStyle.GOLD)
	var bar := Rect2(left, 64, size.x - left - 12, 12)
	draw_rect(bar, UiStyle.HP_EMPTY)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(unit.hp_fraction(), 0.0, 1.0), bar.size.y)), UiStyle.HP_FILL)
	draw_rect(bar, UiStyle.HP_FRAME, false, 1.0)
	draw_string(body, Vector2(left, 94), "%d / %d HP" % [unit.hp, unit.max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			UiStyle.TEXT)
	var pitch := minf(11.0, (size.x - left - 8.0) / Rules.STRESS_MAX)
	for i in Rules.STRESS_MAX:
		draw_rect(Rect2(left + i * pitch, 102, pitch - 3.0, 8), UiStyle.STRESS_ON if i < unit.stress else UiStyle.STRESS_OFF)
	var x := left
	for token: StringName in unit.tokens:
		var icon := UiStyle.token_icon(token)
		if icon:
			draw_texture_rect(icon, Rect2(x, 114, 16, 16), false)
			x += 18
	if defeated:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))

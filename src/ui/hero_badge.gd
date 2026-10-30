## A hero in a town list, DD1's roster card: a framed portrait with the level
## badge on its corner (and a gold diamond while a talent point waits), the
## name, stress pips and an optional status tag.
## Toggles to show selection.
class_name HeroBadge
extends BaseButton

const SIZE := Vector2(300, 66)

var hero: HeroRecord
var tag := ""
var tag_color := UiStyle.GREY
var dimmed := false


func setup(record: HeroRecord, tag_text: String = "", color: Color = UiStyle.GREY, dim: bool = false) -> void:
	hero = record
	tag = tag_text
	tag_color = color
	dimmed = dim
	custom_minimum_size = SIZE
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_on: bool) -> void: queue_redraw())


## Heroes can be dragged onto the Mission Board's lineup.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled:
		return null
	set_drag_preview(FormationSlot.drag_preview(hero))
	return {hero = hero}


func _draw() -> void:
	var tint := Color(1.9, 1.5, 1.05) if button_pressed else (Color(1.35, 1.2, 1.05) if is_hovered() else Color.WHITE)
	draw_style_box(UiStyle.card(tint), Rect2(Vector2.ZERO, size))
	var portrait := Rect2(7, 7, 52, 52)
	UiStyle.draw_portrait(self, portrait, hero.def)
	UiStyle.draw_level_badge(self, portrait.position + Vector2(6, portrait.size.y - 6), hero.level(), 12.0)
	if hero.talent_points() > 0:
		# A talent point waits: a gold diamond on the portrait's corner.
		var corner := portrait.position + Vector2(portrait.size.x - 5, 5)
		draw_colored_polygon(UiStyle.diamond(corner, 8.0), Color("140d0b"))
		draw_colored_polygon(UiStyle.diamond(corner, 6.0), UiStyle.GOLD)
	var display := UiStyle.DISPLAY_FONT
	var body := UiStyle.BODY_FONT
	draw_string(display, Vector2(70, 28), hero.display_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 150, 24,
			UiStyle.GOLD if button_pressed or is_hovered() else UiStyle.TEXT)
	draw_string(body, Vector2(70, 45), "Stress", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiStyle.TEXT_DIM)
	for i in Rules.STRESS_MAX:
		draw_rect(Rect2(112 + i * 9, 37, 7, 9), UiStyle.STRESS_ON if i < hero.stress else UiStyle.STRESS_OFF)
	if tag != "":
		# Beside the name, or beside the stress pips when a long name leaves no room.
		var name_end := 70.0 + display.get_string_size(hero.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		var tag_start := size.x - 10.0 - body.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(body, Vector2(0, 24 if name_end + 8.0 < tag_start else 46), tag, HORIZONTAL_ALIGNMENT_RIGHT,
				size.x - 10, 13, tag_color)
	if dimmed:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))

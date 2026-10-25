## A hero in a town list: portrait, name, level and role, stress pips and an
## optional status tag. Toggles to show selection.
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


func _draw() -> void:
	var border := UiStyle.GOLD if button_pressed else (UiStyle.GOLD.darkened(0.4) if is_hovered() else Color("3a3430"))
	draw_style_box(UiStyle.box(Color("1a1416") if not is_hovered() else Color("221a1b"), border,
			2 if button_pressed else 1, 3), Rect2(Vector2.ZERO, size))
	var portrait := Rect2(6, 6, 54, 54)
	draw_rect(portrait, Color("0c0a0a"))
	var sprite := hero.def.sprite
	if sprite:
		draw_texture_rect_region(sprite, portrait, UiStyle.portrait_region(sprite))
	else:
		draw_rect(portrait.grow(-6), hero.def.color)
	var display := UiStyle.DISPLAY_FONT
	var body := UiStyle.BODY_FONT
	draw_string(display, Vector2(70, 26), hero.display_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 150, 22, UiStyle.GOLD)
	draw_string(body, Vector2(70, 44), "Level %d  %s" % [hero.level(), hero.def.role], HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 80, 13, UiStyle.TEXT_DIM)
	for i in Rules.STRESS_MAX:
		draw_rect(Rect2(70 + i * 9, 51, 7, 7), UiStyle.STRESS_ON if i < hero.stress else UiStyle.STRESS_OFF)
	if tag != "":
		draw_string(body, Vector2(0, 24), tag, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 10, 13, tag_color)
	if dimmed:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.45))

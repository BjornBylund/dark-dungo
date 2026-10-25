## A skill in the skill bar: an icon square, or a diamond for Swap, Recover and
## Pass. Shows selection, cooldown, uses left and whether it can be used.
class_name SkillButton
extends BaseButton

const SQUARE := 82.0
const DIAMOND := 96.0
const FRAME := Color("0c0a0a")
const BORDER := Color("3a3430")

var skill: SkillDef
var hotkey: int
var usable: bool
var selected := false
var cooldown := 0
## Uses left this battle, or -1 for unlimited.
var uses_left := -1
var is_diamond := false


func setup(skill_def: SkillDef, key: int, can_use: bool, cooldown_turns: int, uses: int) -> void:
	skill = skill_def
	hotkey = key
	usable = can_use
	cooldown = cooldown_turns
	uses_left = uses
	is_diamond = skill.kind != SkillDef.Kind.ACTION or skill == BasicSkills.recover
	custom_minimum_size = Vector2(DIAMOND, DIAMOND) if is_diamond else Vector2(SQUARE, SQUARE)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disabled = not can_use
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not can_use:
		material = UiStyle.greyscale(0.4)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func _draw() -> void:
	var icon := UiStyle.skill_icon(skill)
	var border := UiStyle.GOLD.darkened(0.15) if is_hovered() and usable else BORDER
	if is_diamond:
		_draw_diamond(icon, border)
	else:
		_draw_square(icon, border)
	var font := UiStyle.DISPLAY_FONT
	if cooldown > 0:
		draw_string(font, Vector2(0, size.y / 2.0 + 16.0), str(cooldown), HORIZONTAL_ALIGNMENT_CENTER, size.x, 48,
				Color.WHITE)
	if uses_left >= 0:
		draw_circle(Vector2(size.x - 12, 12), 10.0, FRAME)
		draw_string(UiStyle.BODY_FONT, Vector2(size.x - 22, 17), str(uses_left), HORIZONTAL_ALIGNMENT_CENTER, 20,
				14, Color.WHITE)
	draw_string(UiStyle.BODY_FONT, Vector2(5, 14), str(hotkey), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(UiStyle.TEXT_DIM, 0.8))


func _draw_square(icon: Texture2D, border: Color) -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, FRAME)
	if icon:
		draw_texture_rect(icon, rect.grow(-3.0), false)
	if cooldown > 0:
		draw_rect(rect.grow(-3.0), Color(0, 0, 0, 0.55))
	draw_rect(rect, border, false, 2.0)
	if selected:
		# Gold L-corners on the bottom corners.
		for corner: Array in [[Vector2(0, size.y), 1.0], [Vector2(size.x, size.y), -1.0]]:
			var at: Vector2 = corner[0]
			var direction: float = corner[1]
			draw_polyline(PackedVector2Array([at + Vector2(0, -22), at, at + Vector2(direction * 22, 0)]),
					UiStyle.GOLD, 4.0)


func _draw_diamond(icon: Texture2D, border: Color) -> void:
	var center := size / 2.0
	var outer := UiStyle.diamond(center, size.x / 2.0 - 2.0)
	var inner_half := size.x / 2.0 - 9.0
	var inner := UiStyle.diamond(center, inner_half)
	draw_colored_polygon(outer, FRAME)
	if icon:
		UiStyle.draw_clipped(self, icon, inner, Rect2(center - Vector2(inner_half, inner_half),
				Vector2(inner_half, inner_half) * 2.0), Rect2(Vector2.ZERO, icon.get_size()))
	if cooldown > 0:
		draw_colored_polygon(inner, Color(0, 0, 0, 0.55))
	var outline := outer.duplicate()
	outline.append(outer[0])
	draw_polyline(outline, border, 2.0)
	if selected:
		draw_polyline(PackedVector2Array([outer[3], outer[2], outer[1]]), UiStyle.GOLD, 4.0)

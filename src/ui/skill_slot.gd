## A skill on the hero sheet, DD1-style: its icon lit in a gold frame when
## equipped, dimmed when learned but left at home, dark with a padlock when not
## learned yet, and its rank (1-5) as diamonds along the bottom.
class_name SkillSlot
extends BaseButton

const SIDE := 84.0
const FRAME := Color("0c0a0a")
const BRONZE := Color("6e5232")
const UNLEARNED := Color("2a2420")

var skill: SkillDef
var learned := false
var equipped := false
var rank := 1
## The one whose details show beside the grid.
var selected := false


func setup(skill_def: SkillDef, is_learned: bool, is_equipped: bool, skill_rank: int, is_selected: bool) -> void:
	skill = skill_def
	learned = is_learned
	equipped = is_equipped
	rank = skill_rank
	selected = is_selected
	custom_minimum_size = Vector2(SIDE, SIDE)
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	if equipped:
		draw_rect(rect.grow(3.0), Color(UiStyle.GOLD, 0.25))
	draw_rect(rect, FRAME)
	var icon := UiStyle.skill_icon(skill)
	var tint := Color.WHITE if equipped else (Color(0.6, 0.6, 0.6) if learned else Color(0.26, 0.26, 0.28))
	if icon:
		draw_texture_rect(icon, rect.grow(-4.0), false, tint)
	if not learned:
		UiStyle.draw_lock(self, size / 2.0 + Vector2(0, 4), size.y * 0.46)
	var border := UiStyle.GOLD if equipped else (BRONZE if learned else UNLEARNED)
	if is_hovered():
		border = border.lightened(0.35)
	draw_rect(rect, border, false, 3.0 if equipped else 2.0)
	if learned:
		# One diamond per rank, filled up to the skill's.
		var pitch := 11.0
		var left := size.x / 2.0 - pitch * 2.0
		for i in CampaignRules.MAX_RANK:
			var shape := UiStyle.diamond(Vector2(left + i * pitch, size.y - 9.0), 4.5)
			draw_colored_polygon(shape, FRAME)
			draw_colored_polygon(UiStyle.diamond(Vector2(left + i * pitch, size.y - 9.0), 3.0),
					UiStyle.GOLD if i < rank else Color(UiStyle.GOLD, 0.2))
	if selected:
		for corner: Array in [[Vector2(0, size.y), 1.0], [Vector2(size.x, size.y), -1.0]]:
			var at: Vector2 = corner[0]
			var direction: float = corner[1]
			draw_polyline(PackedVector2Array([at + Vector2(0, -22), at, at + Vector2(direction * 22, 0)]),
					UiStyle.TEXT, 4.0)

## A skill in the skill bar: hotkey, name, and DD-style rank pips showing
## where it can be used from and which ranks it reaches.
class_name SkillButton
extends Button

var skill: SkillDef
var hotkey: int
var usable: bool


func setup(skill_def: SkillDef, key: int, can_use: bool) -> void:
	skill = skill_def
	hotkey = key
	usable = can_use
	disabled = not can_use
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(124, 100)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _draw() -> void:
	var font := get_theme_default_font()
	var text_color := UiStyle.TEXT if usable else UiStyle.TEXT_DIM.darkened(0.3)
	draw_string(font, Vector2(8, 18), str(hotkey), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.TEXT_DIM)
	draw_string(font, Vector2(4, 44), skill.display_name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 15, text_color)
	match skill.kind:
		SkillDef.Kind.SWAP:
			_draw_caption(font, "move", text_color)
		SkillDef.Kind.PASS:
			_draw_caption(font, "+%d stress" % Rules.PASS_STRESS, text_color)
		SkillDef.Kind.ACTION:
			_draw_pips(text_color)


func _draw_caption(font: Font, caption: String, color: Color) -> void:
	draw_string(font, Vector2(4, 78), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 13, Color(color, 0.7))


## Left group: the user's ranks 4..1 (heroes face right). Right group: target ranks.
func _draw_pips(text_color: Color) -> void:
	var y := 76.0
	var spacing := 12.0
	var radius := 4.5
	var left := size.x / 2.0 - 4.0 * spacing - 6.0
	for i in 4:
		var rank := 4 - i
		var center := Vector2(left + i * spacing + radius, y)
		_pip(center, radius, rank in skill.launch_ranks, Color(text_color, 0.9))
	var right := size.x / 2.0 + 8.0
	if skill.side == SkillDef.TargetSide.SELF:
		draw_string(get_theme_default_font(), Vector2(right, y + 4), "self", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
				UiStyle.GOLD)
		return
	var ally := skill.side == SkillDef.TargetSide.ALLY
	var color := UiStyle.ALLY_TARGET if ally else UiStyle.ENEMY_TARGET
	var centers: Array[Vector2] = []
	for i in 4:
		var rank := 4 - i if ally else i + 1
		var center := Vector2(right + i * spacing + radius, y)
		if rank in skill.target_ranks:
			centers.append(center)
		_pip(center, radius, rank in skill.target_ranks, color)
	if skill.multi_target and centers.size() > 1:
		draw_line(centers.front(), centers.back(), color, 2.0)


func _pip(center: Vector2, radius: float, filled: bool, color: Color) -> void:
	if filled:
		draw_circle(center, radius, color)
	else:
		draw_arc(center, radius, 0.0, TAU, 12, Color(color, 0.35), 1.5)

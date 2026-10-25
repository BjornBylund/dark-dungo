## DD2 rank pips for a skill: 4 hexagons for the user's own ranks (drawn 4 to 1,
## gold where it can be used from), then 4 for the targets (enemy ranks 1 to 4
## in blue, or ally ranks 4 to 1 in green). Multi-target pips are joined.
class_name RankPips
extends Control

const RADIUS := 7.0
const PITCH := 18.0
const GROUP_GAP := 24.0

var skill: SkillDef


func _init() -> void:
	custom_minimum_size = Vector2(8.0 * PITCH + GROUP_GAP, PITCH)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_skill(value: SkillDef) -> void:
	skill = value
	queue_redraw()


func _draw() -> void:
	if skill == null or skill.kind != SkillDef.Kind.ACTION:
		return
	var y := size.y / 2.0
	var left := (size.x - custom_minimum_size.x) / 2.0 + PITCH / 2.0
	for i in 4:
		_hex(Vector2(left + i * PITCH, y), (4 - i) in skill.launch_ranks, UiStyle.GOLD)
	var start := left + 4.0 * PITCH + GROUP_GAP
	var ally := skill.side == SkillDef.TargetSide.ALLY
	var self_only := skill.side == SkillDef.TargetSide.SELF
	var color := UiStyle.GREEN if ally else UiStyle.BLUE
	var filled: Array[Vector2] = []
	for i in 4:
		var rank := 4 - i if ally else i + 1
		var center := Vector2(start + i * PITCH, y)
		var on := not self_only and rank in skill.target_ranks
		if on:
			filled.append(center)
		_hex(center, on, color)
	if skill.multi_target and filled.size() > 1:
		draw_line(filled.front(), filled.back(), color, 3.0)
		for center in filled:
			_hex(center, true, color)


func _hex(center: Vector2, filled: bool, color: Color) -> void:
	var points := PackedVector2Array()
	for k in 6:
		var angle := TAU * k / 6.0
		points.append(center + Vector2(cos(angle), sin(angle)) * RADIUS)
	if filled:
		draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		draw_polyline(points, Color(UiStyle.GREY, 0.6), 1.5)

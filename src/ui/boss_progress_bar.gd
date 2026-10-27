## A region's boss progress on the expedition map, like DD1's region progress:
## a framed bar that fills as missions there are completed, with the chosen
## quest's share shown ahead of it in pale gold and a skull at the end.
class_name BossProgressBar
extends Control

const SIZE := Vector2(220, 16)
const FRAME := 2.0

var filled := 0.0
var adds := 0.0


## `progress` and `quest_share` are fractions of the bar, 0 to 1.
func setup(progress: float, quest_share: float) -> void:
	filled = clampf(progress, 0.0, 1.0)
	adds = clampf(quest_share, 0.0, 1.0 - filled)
	custom_minimum_size = SIZE
	size = SIZE
	tooltip_text = "Boss progress %s" % UiStyle.percent(filled)
	if adds > 0.0:
		tooltip_text += ", %s after the chosen quest" % UiStyle.percent(filled + adds)
	queue_redraw()


func _draw() -> void:
	var skull_room := size.y + 4.0
	var bar := Rect2(Vector2.ZERO, Vector2(size.x - skull_room, size.y))
	draw_rect(bar, UiStyle.HP_EMPTY)
	var inner := bar.grow(-FRAME)
	draw_rect(Rect2(inner.position, Vector2(inner.size.x * filled, inner.size.y)), UiStyle.BLOOD)
	if adds > 0.0:
		draw_rect(Rect2(inner.position + Vector2(inner.size.x * filled, 0), Vector2(inner.size.x * adds, inner.size.y)),
				Color(UiStyle.GOLD, 0.8))
	draw_rect(bar, UiStyle.GOLD.darkened(0.35), false, FRAME)
	_skull(Vector2(size.x - size.y / 2.0, size.y / 2.0), size.y / 2.0)


func _skull(at: Vector2, radius: float) -> void:
	draw_circle(at + Vector2(0, -radius * 0.15), radius * 0.8, UiStyle.TEXT)
	draw_rect(Rect2(at + Vector2(-radius * 0.45, radius * 0.35), Vector2(radius * 0.9, radius * 0.6)), UiStyle.TEXT)
	draw_circle(at + Vector2(-radius * 0.32, -radius * 0.2), radius * 0.24, UiStyle.HP_EMPTY)
	draw_circle(at + Vector2(radius * 0.32, -radius * 0.2), radius * 0.24, UiStyle.HP_EMPTY)

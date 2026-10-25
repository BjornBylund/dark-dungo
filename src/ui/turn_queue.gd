## DD2's turn-order queue at the top right: diamond portraits of the units still
## to act this round, the one acting now on the right with a white V under it.
## Gold caps for heroes, blue for enemies.
class_name TurnQueue
extends Control

const SIZE := 80.0
const SHOWN := 4

var units: Array[Combatant] = []


func _init() -> void:
	custom_minimum_size = Vector2(SHOWN * (SIZE + 4.0), SIZE + 26.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_units(order: Array[Combatant]) -> void:
	units.assign(order.slice(0, SHOWN))
	queue_redraw()


func _draw() -> void:
	for i in units.size():
		var unit := units[i]
		var center := Vector2(size.x - SIZE / 2.0 - i * (SIZE + 4.0), SIZE / 2.0 + 2.0)
		var outer := UiStyle.diamond(center, SIZE / 2.0)
		var inner_half := SIZE / 2.0 - 6.0
		var inner := UiStyle.diamond(center, inner_half)
		draw_colored_polygon(outer, Color("0c0a0a"))
		var sprite := unit.def.sprite
		if sprite:
			UiStyle.draw_clipped(self, sprite, inner, Rect2(center - Vector2(inner_half, inner_half),
					Vector2(inner_half, inner_half) * 2.0), UiStyle.portrait_region(sprite), not unit.is_hero)
		else:
			draw_colored_polygon(inner, unit.def.color)
		var cap := UiStyle.GOLD if unit.is_hero else UiStyle.BLUE
		draw_polyline(PackedVector2Array([outer[3], outer[0], outer[1]]), cap, 4.0)
		draw_polyline(PackedVector2Array([outer[1], outer[2], outer[3]]), Color(UiStyle.GREY, 0.5), 1.5)
		if i == 0:
			var tip := outer[2] + Vector2(0, 16)
			draw_polyline(PackedVector2Array([tip + Vector2(-9, -8), tip, tip + Vector2(9, -8)]), Color.WHITE, 3.0)

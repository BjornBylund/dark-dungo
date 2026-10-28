## A trinket's square icon, or until it has art a placeholder amulet in its
## rarity's colour: a gem on a ring, hung from a cord.
class_name TrinketIcon
extends Control

var trinket: TrinketDef


func setup(item: TrinketDef, side: float = 48.0) -> void:
	trinket = item
	custom_minimum_size = Vector2(side, side)
	tooltip_text = "%s\n%s" % [trinket.display_name, UiStyle.trinket_kind(trinket)]
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var color: Color = UiStyle.RARITY_COLORS[trinket.rarity]
	draw_rect(rect, Color("150f11"))
	draw_rect(rect, color.darkened(0.3), false, 2.0)
	if trinket.icon:
		draw_texture_rect(trinket.icon, rect.grow(-3.0), false)
		return
	var center := size / 2.0 + Vector2(0, size.y * 0.08)
	var radius := size.x * 0.26
	draw_arc(Vector2(size.x / 2.0, 0), size.x * 0.32, PI * 0.15, PI * 0.85, 12, UiStyle.TEXT_DIM, 1.5)
	draw_circle(center, radius, color.darkened(0.45))
	draw_arc(center, radius, 0.0, TAU, 24, UiStyle.GOLD, 2.0)
	draw_circle(center, radius * 0.55, color)
	draw_circle(center - Vector2(radius, radius) * 0.22, radius * 0.16, Color(1, 1, 1, 0.7))

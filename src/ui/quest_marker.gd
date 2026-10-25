## A quest on the expedition map, like DD1's: a shield framed in the tier's
## colour (Apprentice green, Veteran orange, Champion red) with the mission
## level inside and one pip per length step below it. Toggles when chosen.
class_name QuestMarker
extends BaseButton

const SIZE := Vector2(64, 78)
const TIER_COLORS := [Color("6cbf5a"), Color("e08a2e"), Color("d0343a")]

var mission: Mission


func setup(quest: Mission) -> void:
	mission = quest
	custom_minimum_size = SIZE
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "%s, %d fights" % [mission.title(), mission.fights()]
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	toggled.connect(func(_on: bool) -> void: queue_redraw())


static func tier_color(tier: int) -> Color:
	return TIER_COLORS[tier]


func _draw() -> void:
	var color := tier_color(mission.tier)
	var shield := _shield(Rect2(Vector2(6, 4), size - Vector2(12, 8)))
	if button_pressed:
		draw_colored_polygon(_shield(Rect2(Vector2.ZERO, size)), Color(UiStyle.GOLD, 0.35))
	draw_colored_polygon(shield, Color("241b1d") if is_hovered() or button_pressed else Color("150f11"))
	var outline := shield.duplicate()
	outline.append(shield[0])
	draw_polyline(outline, UiStyle.GOLD if button_pressed else color, 4.0 if button_pressed else 3.0, true)
	draw_string(UiStyle.DISPLAY_FONT, Vector2(0, 42), str(mission.level()), HORIZONTAL_ALIGNMENT_CENTER, size.x, 30,
			color)
	var pips := int(mission.length) + 1
	for i in pips:
		draw_circle(Vector2(size.x / 2.0 + (i - (pips - 1) / 2.0) * 10.0, 54), 3.5, UiStyle.TEXT)


## A heater shield: flat top, straight sides, curving to a point.
func _shield(rect: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y)])
	var steps := 8
	for i in steps + 1:
		var t := float(i) / steps
		points.append(Vector2(rect.end.x - t * rect.size.x / 2.0,
				rect.position.y + rect.size.y * 0.45 + sin(t * PI / 2.0) * rect.size.y * 0.55))
	for i in range(steps - 1, -1, -1):
		var t := float(i) / steps
		points.append(Vector2(rect.position.x + t * rect.size.x / 2.0,
				rect.position.y + rect.size.y * 0.45 + sin(t * PI / 2.0) * rect.size.y * 0.55))
	return points

## A room on the mission map: a dark disc with the room's icon. Rooms the party
## can reach next glow gold, the current room has a gold ring (the party's
## token stands over it), rooms passed through carry a gold check, rooms left
## behind fade, and the rest are dimmed. A room not yet revealed shows a "?".
class_name RoomButton
extends BaseButton

enum State { AHEAD, REACHABLE, CURRENT, VISITED, PASSED_BY }

const SIZE := 76.0
const FINALE_SIZE := 104.0
const ICONS := [
	preload("res://art/rooms/fight.svg"), preload("res://art/rooms/event.svg"), preload("res://art/rooms/rest.svg"),
	preload("res://art/rooms/elite.svg"), preload("res://art/rooms/cache.svg"), preload("res://art/rooms/finale.svg"),
]
const RING_COLORS := {
	MapRoom.Type.FIGHT: Color("8a8a8a"), MapRoom.Type.EVENT: Color("4c78b5"), MapRoom.Type.REST: Color("f0b050"),
	MapRoom.Type.ELITE: Color("d0343a"), MapRoom.Type.CACHE: Color("c9a66b"), MapRoom.Type.FINALE: Color("d0343a"),
}

var room: MapRoom
var state := State.AHEAD
## Not yet revealed: drawn as a blank disc.
var unknown := false
var _pulse := 0.0


func setup(map_room: MapRoom, room_state: State, tooltip: String, is_unknown: bool = false) -> void:
	room = map_room
	state = room_state
	unknown = is_unknown
	var side := FINALE_SIZE if room.type == MapRoom.Type.FINALE else SIZE
	custom_minimum_size = Vector2(side, side)
	size = custom_minimum_size
	focus_mode = Control.FOCUS_NONE
	disabled = state != State.REACHABLE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if state == State.REACHABLE else Control.CURSOR_ARROW
	tooltip_text = tooltip
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func center() -> Vector2:
	return position + size / 2.0


func _process(delta: float) -> void:
	if state == State.REACHABLE:
		_pulse = fmod(_pulse + delta * 2.0, TAU)
		queue_redraw()


func _draw() -> void:
	var middle := size / 2.0
	var radius := size.x / 2.0 - 4.0
	var lit := state != State.AHEAD and state != State.PASSED_BY
	# Rooms left behind, never to be visited, fade into the dark.
	var fade := 0.4 if state == State.PASSED_BY else 1.0
	if state == State.REACHABLE:
		var glow := 0.35 + 0.25 * sin(_pulse)
		draw_circle(middle, radius + 9.0, Color(UiStyle.GOLD, glow * (1.4 if is_hovered() else 1.0)))
	draw_circle(middle, radius + 2.0, Color(0, 0, 0, 0.7 * fade))
	draw_circle(middle, radius, Color("1a1416") if lit else Color("110d0e", fade))
	if unknown:
		var mark := Color("6a5a4a", fade)
		draw_arc(middle, radius, 0.0, TAU, 40, Color(mark, 0.7 * fade), 3.0, true)
		draw_string(UiStyle.DISPLAY_FONT, Vector2(0, middle.y + radius * 0.4), "?", HORIZONTAL_ALIGNMENT_CENTER,
				size.x, int(radius * 1.15), mark)
		return
	var ring: Color = RING_COLORS[room.type]
	draw_arc(middle, radius, 0.0, TAU, 40, ring if lit else Color(ring, 0.45 * fade),
			4.0 if state == State.REACHABLE else 3.0, true)
	var icon: Texture2D = ICONS[room.type]
	var icon_side := radius * 1.3
	var tint := Color.WHITE if lit else Color(0.55, 0.55, 0.55, 0.75 * fade)
	if state == State.VISITED:
		tint = Color(0.6, 0.6, 0.6)
	draw_texture_rect(icon, Rect2(middle - Vector2(icon_side, icon_side) / 2.0, Vector2(icon_side, icon_side)), false, tint)
	if state == State.CURRENT:
		draw_arc(middle, radius + 6.0, 0.0, TAU, 40, UiStyle.GOLD, 3.0, true)
	if state == State.VISITED:
		_draw_check(middle + Vector2(radius, radius) * 0.68, radius * 0.32)


## A gold check in a dark disc, for a room the party has been through.
func _draw_check(center: Vector2, badge: float) -> void:
	draw_circle(center, badge, Color("1a1416"))
	draw_arc(center, badge, 0.0, TAU, 24, UiStyle.GOLD, 2.0, true)
	draw_polyline(PackedVector2Array([center + Vector2(-0.5, 0.05) * badge, center + Vector2(-0.12, 0.42) * badge,
			center + Vector2(0.5, -0.4) * badge]), UiStyle.GOLD, maxf(2.0, badge * 0.22), true)

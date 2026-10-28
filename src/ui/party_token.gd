## The party's marker on the mission map: the front hero's framed portrait on
## a pennant pole, pointing down at the room the party is in and bobbing
## gently. Where there is no room above a room it stands below it instead,
## pointing up. The pointer's tip is at TIP (or TIP_BELOW) from the top left.
class_name PartyToken
extends Control

const SIZE := Vector2(64, 92)
const TIP := Vector2(32, 92)
const TIP_BELOW := Vector2(32, 0)

var hero: UnitDef
## Standing below the room, pointing up.
var below := false
var _time := 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func tip() -> Vector2:
	return TIP_BELOW if below else TIP


func _process(delta: float) -> void:
	_time = fmod(_time + delta, TAU)
	queue_redraw()


func _draw() -> void:
	var bob := Vector2(0, sin(_time * 2.0) * 3.0)
	var portrait := Rect2(Vector2(6, 26 if below else 14) + bob, Vector2(52, 52))
	if not below:
		# The pennant on its pole, behind the portrait.
		var pole_top := Vector2(52, 0) + bob
		draw_line(pole_top, pole_top + Vector2(0, 20), Color("2a1c10"), 3.0)
		draw_colored_polygon(PackedVector2Array([pole_top, pole_top + Vector2(-16, 4), pole_top + Vector2(0, 9)]),
				UiStyle.BLOOD.lightened(0.15))
	draw_rect(portrait.grow(4.0), Color(0, 0, 0, 0.6))
	if hero:
		UiStyle.draw_portrait(self, portrait, hero)
	draw_rect(portrait.grow(1.0), UiStyle.GOLD, false, 2.0)
	var base_y := portrait.position.y - 4.0 if below else portrait.end.y + 4.0
	draw_colored_polygon(PackedVector2Array([Vector2(TIP.x - 12, base_y), Vector2(TIP.x + 12, base_y),
			tip() + bob * 0.5]), UiStyle.GOLD)

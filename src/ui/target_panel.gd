## Bottom-right panel for the hovered or focused target: name (blue for enemies,
## gold for heroes), type, speed, HP and the six-column resistance row. Columns
## the selected skill would roll against are lit up.
class_name TargetPanel
extends Control

const COLUMN := 70.0

var unit: Combatant
var tested: Array[StringName] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_unit(target: Combatant, tested_resists: Array[StringName]) -> void:
	unit = target
	tested.assign(tested_resists)
	queue_redraw()


func clear() -> void:
	unit = null
	queue_redraw()


func _draw() -> void:
	if unit == null:
		return
	var right := size.x - 30.0
	var display := UiStyle.DISPLAY_FONT
	var body := UiStyle.BODY_FONT
	var name_color := UiStyle.GOLD if unit.is_hero else UiStyle.BLUE.lightened(0.15)
	draw_string(display, Vector2(0, 40), unit.display_name, HORIZONTAL_ALIGNMENT_RIGHT, right, 32, name_color)
	if unit.is_corpse:
		draw_string(body, Vector2(0, 66), "Corpse", HORIZONTAL_ALIGNMENT_RIGHT, right, 17, UiStyle.GREY)

	var max_hp := unit.def.corpse_hp if unit.is_corpse else unit.max_hp
	var bar := Rect2(right - 160.0, 84.0, 160.0, 8.0)
	draw_rect(bar, UiStyle.HP_EMPTY)
	if not unit.deaths_door:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(unit.hp) / max_hp, 0.0, 1.0), bar.size.y)),
				UiStyle.CORPSE_FILL if unit.is_corpse else UiStyle.HP_FILL)
	draw_rect(bar, UiStyle.HP_FRAME, false, 1.0)
	var hp_text := "DEATH'S DOOR" if unit.deaths_door else "%d/%d" % [unit.hp, max_hp]
	draw_string(body, Vector2(0, 94), hp_text, HORIZONTAL_ALIGNMENT_RIGHT, bar.position.x - 12.0, 17, UiStyle.TEXT)
	draw_string(body, Vector2(0, 94), "SPD %d" % unit.speed(), HORIZONTAL_ALIGNMENT_RIGHT, bar.position.x - 100.0,
			17, UiStyle.TEXT_DIM)
	if unit.is_corpse:
		return

	UiStyle.draw_resists(self, Vector2(right - UiStyle.RESIST_COLUMNS.size() * COLUMN, 110), unit, tested, COLUMN)
	if unit.death_armor > 0 and not unit.is_hero:
		draw_string(body, Vector2(0, 214), "Death Armor %d" % unit.death_armor, HORIZONTAL_ALIGNMENT_RIGHT, right,
				16, UiStyle.TEXT_DIM)
	elif unit.is_hero:
		var deathblow := clampf(unit.resist(&"deathblow"), Rules.DEATHBLOW_MIN, Rules.DEATHBLOW_MAX)
		draw_string(body, Vector2(0, 214), "Deathblow resist %s" % UiStyle.percent(deathblow),
				HORIZONTAL_ALIGNMENT_RIGHT, right, 16, UiStyle.TEXT_DIM)

## The HIT / DMG / CRIT (or HEAL) preview under the skill bar, against the
## focused target, with a soft amber glow behind it.
class_name PreviewStrip
extends Control

const COLUMN := 130.0

## [[value text, label], ...]
var columns: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_columns(values: Array) -> void:
	columns = values
	queue_redraw()


func _draw() -> void:
	if columns.is_empty():
		return
	var center := Vector2(size.x / 2.0, size.y / 2.0)
	for k in 6:
		draw_set_transform(center, 0.0, Vector2(2.6, 1.0))
		draw_circle(Vector2.ZERO, 60.0 - k * 9.0, Color(UiStyle.AMBER, 0.035))
	draw_set_transform(Vector2.ZERO)
	var left := center.x - columns.size() * COLUMN / 2.0
	for i in columns.size():
		var x := left + i * COLUMN
		draw_string(UiStyle.DISPLAY_FONT, Vector2(x, center.y + 4), columns[i][0], HORIZONTAL_ALIGNMENT_CENTER, COLUMN,
				30, UiStyle.TEXT)
		draw_string(UiStyle.BODY_FONT, Vector2(x, center.y + 26), columns[i][1], HORIZONTAL_ALIGNMENT_CENTER, COLUMN,
				14, UiStyle.TEXT_DIM)

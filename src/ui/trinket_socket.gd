## One of a hero's trinket slots on their sheet: a bronze-rimmed socket holding
## the trinket worn there (TrinketIcon), or empty. Pressing a filled one takes
## the trinket off.
class_name TrinketSocket
extends BaseButton

const SIDE := 96.0

var trinket: TrinketDef


func setup(worn: TrinketDef) -> void:
	trinket = worn
	custom_minimum_size = Vector2(SIDE, SIDE)
	focus_mode = Control.FOCUS_NONE
	disabled = trinket == null
	if trinket:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		tooltip_text = "%s\nClick to take it off." % trinket.display_name
		var icon := TrinketIcon.new()
		icon.setup(trinket, SIDE - 16.0)
		icon.position = Vector2(8, 8)
		icon.size = Vector2(SIDE - 16.0, SIDE - 16.0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(icon)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color("060404"))
	draw_rect(rect.grow(-3.0), Color("140d0b"))
	var rim := Color("8a6a3e") if trinket else Color("3a2a1c")
	if trinket and is_hovered():
		rim = UiStyle.GOLD.lightened(0.2)
	draw_rect(rect.grow(-1.5), rim, false, 3.0)
	if trinket == null:
		# An empty setting: a faint ring where a trinket would sit.
		draw_arc(size / 2.0, size.x * 0.22, 0.0, TAU, 32, Color("3a2a1c"), 2.0)

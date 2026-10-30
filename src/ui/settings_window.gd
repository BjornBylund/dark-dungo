## The settings, over whatever screen is up: the Master, Music and Effects
## volumes (kept by Audio) and fullscreen. Each screen has a gear button for
## it (SettingsWindow.button()), and the title screen a Settings button. Esc,
## Close or a click outside the window closes it.
class_name SettingsWindow
extends Control

const GROUP := &"settings_window"
const ROWS := [[&"Master", "Master"], [&"Music", "Music"], [&"Effects", "Effects"]]
## What plays after a slider is let go, to hear the new level by.
const SAMPLES := {&"Master": &"chime", &"Effects": &"hit"}
const TRACK := Color("120e0b")
const RIM := Color("6e5232")
const FILL := Color("8a6a3a")

static var _gear: Texture2D
static var _knobs: Dictionary[Color, Texture2D] = {}

var _percents: Dictionary[StringName, Label] = {}


## A gear button that opens the settings.
static func button() -> Button:
	var gear := Button.new()
	gear.icon = gear_icon()
	gear.expand_icon = true
	gear.tooltip_text = "Settings"
	gear.focus_mode = Control.FOCUS_NONE
	gear.custom_minimum_size = Vector2(44, 44) if Device.phone else Vector2(36, 36)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear.add_theme_color_override("icon_normal_color", UiStyle.GREY)
	gear.add_theme_color_override("icon_hover_color", UiStyle.GOLD)
	gear.add_theme_color_override("icon_pressed_color", UiStyle.TEXT)
	gear.add_theme_color_override("icon_hover_pressed_color", UiStyle.GOLD)
	gear.pressed.connect(func() -> void: open(gear.get_tree()))
	return gear


## Opens the settings over everything, unless they're open already.
static func open(tree: SceneTree) -> void:
	if not tree.get_nodes_in_group(GROUP).is_empty():
		return
	var layer := CanvasLayer.new()
	layer.layer = 90
	layer.add_to_group(GROUP)
	tree.root.add_child(layer)
	layer.add_child(SettingsWindow.new())


## A white cog with eight rounded teeth, tinted by the button.
static func gear_icon() -> Texture2D:
	if _gear:
		return _gear
	var side := 64
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	for y in side:
		for x in side:
			var u := (x + 0.5) / side * 2.0 - 1.0
			var v := (y + 0.5) / side * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var outer := lerpf(0.62, 0.84, smoothstep(-0.15, 0.35, cos(8.0 * atan2(v, u))))
			var cover := clampf((outer - r) * side * 0.5 + 0.5, 0.0, 1.0) * clampf((r - 0.26) * side * 0.5 + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(1, 1, 1, cover))
	_gear = ImageTexture.create_from_image(image)
	return _gear


## A slider's diamond knob in `color`.
static func _knob(color: Color) -> Texture2D:
	if _knobs.has(color):
		return _knobs[color]
	var side := 22
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	for y in side:
		for x in side:
			var reach := absf(x + 0.5 - side / 2.0) + absf(y + 0.5 - side / 2.0)
			var cover := clampf(side / 2.0 - 1.0 - reach + 0.5, 0.0, 1.0)
			var edge := clampf(reach - (side / 2.0 - 4.0), 0.0, 1.0)
			image.set_pixel(x, y, Color(color.lerp(Color.BLACK, edge * 0.6), cover))
	_knobs[color] = ImageTexture.create_from_image(image)
	return _knobs[color]


func _ready() -> void:
	theme = UiStyle.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.frame(30.0))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	box.add_child(_label("Settings", 44, UiStyle.GOLD, UiStyle.DISPLAY_FONT))
	box.add_child(UiStyle.divider(440.0))
	for row: Array in ROWS:
		box.add_child(_volume_row(row[0], row[1]))
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	fullscreen.focus_mode = Control.FOCUS_NONE
	fullscreen.add_theme_font_size_override("font_size", 22)
	fullscreen.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	box.add_child(fullscreen)
	var close := Button.new()
	close.text = "Close" if Device.handheld else "Close (Esc)"
	close.theme_type_variation = &"ActionButton"
	close.custom_minimum_size = Vector2(160, 48)
	close.focus_mode = Control.FOCUS_NONE
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(_close)
	box.add_child(close)


## Keys don't reach the screen underneath while the settings are open.
func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_close()
	get_viewport().set_input_as_handled()


func _close() -> void:
	get_parent().queue_free()


func _volume_row(bus: StringName, title: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var name_label := _label(title, 22, UiStyle.TEXT)
	name_label.custom_minimum_size.x = 120
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = roundf(Audio.volume(bus) * 100.0)
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(360, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.add_theme_stylebox_override("slider", _bar(TRACK))
	slider.add_theme_stylebox_override("grabber_area", _bar(FILL))
	slider.add_theme_stylebox_override("grabber_area_highlight", _bar(FILL.lightened(0.2)))
	slider.add_theme_icon_override("grabber", _knob(UiStyle.GOLD))
	slider.add_theme_icon_override("grabber_highlight", _knob(UiStyle.GOLD.lightened(0.3)))
	slider.value_changed.connect(func(value: float) -> void:
		Audio.set_volume(bus, value / 100.0)
		_percents[bus].text = "%d%%" % roundi(value))
	slider.drag_ended.connect(func(_changed: bool) -> void:
		if SAMPLES.has(bus):
			Audio.play(SAMPLES[bus]))
	row.add_child(slider)
	var percent := _label("%d%%" % roundi(slider.value), 20, UiStyle.TEXT_DIM)
	percent.custom_minimum_size.x = 64
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_percents[bus] = percent
	row.add_child(percent)
	return row


func _bar(color: Color) -> StyleBoxFlat:
	var style := UiStyle.box(color, RIM, 1, 3)
	style.set_content_margin_all(0)
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	return style


func _label(text: String, font_size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

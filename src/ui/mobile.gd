## Autoload: phones, tablets and touch. At startup it works out the device
## (Device), switches phones to the phone layout's larger logical screen, and
## then shows "turn your phone sideways" while a handheld is held upright.
## A long press (half a second without moving) on anything with a tooltip shows
## that tooltip in a popup, in place of hovering with a mouse.
extends Node

const LONG_PRESS_SECONDS := 0.5
const LONG_PRESS_SLOP := 16.0

var _turn: Control
var _popup: Control
var _popup_title: Label
var _popup_text: RichTextLabel
## Bumped on every touch, so a long-press timer from an earlier touch does nothing.
var _press := 0
var _press_at := Vector2.ZERO
var _pressing := false
## After a long press, the release must not also click the control underneath.
var _swallow_release := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Device.handheld = OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile") \
			or "--phone" in args or "--touch" in args
	Device.touch = Device.handheld
	Device.phone = "--phone" in args or (OS.has_feature("web") and Device.handheld and _css_short_side() < Device.PHONE_SHORT_SIDE)
	if Device.phone:
		get_tree().root.content_scale_size = Device.PHONE_SCALE_SIZE
	_build()
	get_tree().root.size_changed.connect(_check_orientation)
	_check_orientation()


## Shows `text` (BBCode allowed) in a popup over everything; a tap anywhere closes it.
func show_info(title: String, text: String) -> void:
	_popup_title.text = title
	_popup_title.visible = title != ""
	_popup_text.text = text
	_popup.show()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		Device.touch = true
		if event.pressed:
			_press += 1
			_pressing = true
			_press_at = event.position
			_wait_for_long_press(_press)
		else:
			_pressing = false
	elif event is InputEventScreenDrag:
		if event.position.distance_to(_press_at) > LONG_PRESS_SLOP:
			_pressing = false
	elif event is InputEventMouseButton:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			Device.touch = false
		elif _swallow_release and not event.pressed:
			_swallow_release = false
			get_viewport().set_input_as_handled()


func _wait_for_long_press(press: int) -> void:
	await get_tree().create_timer(LONG_PRESS_SECONDS).timeout
	if press != _press or not _pressing or _popup.visible:
		return
	var tip := _tooltip_at(get_viewport().gui_get_hovered_control())
	if tip != "":
		_swallow_release = true
		show_info("", tip)


## The tooltip of the control under the finger, or of the nearest parent that has one.
func _tooltip_at(control: Control) -> String:
	while control:
		var tip := control.get_tooltip(control.get_local_mouse_position())
		if tip != "":
			return tip
		control = control.get_parent() as Control
	return ""


func _check_orientation() -> void:
	var view := get_tree().root.get_visible_rect().size
	_turn.visible = Device.handheld and view.y > view.x


static func _css_short_side() -> float:
	var short: Variant = JavaScriptBridge.eval("Math.min(window.screen.width, window.screen.height)", true)
	return float(short) if short != null else 10000.0


func _build() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_popup = Control.new()
	_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup.theme = UiStyle.make_theme()
	_popup.hide()
	_popup.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_popup.hide())
	layer.add_child(_popup)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(center)
	var panel := PanelContainer.new()
	var style := UiStyle.box(Color("0b0e14f4"), Color("4a4a52"), 1, 4)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_popup_title = Label.new()
	_popup_title.add_theme_font_override("font", UiStyle.DISPLAY_FONT)
	_popup_title.add_theme_font_size_override("font_size", 30)
	_popup_title.add_theme_color_override("font_color", UiStyle.GOLD)
	box.add_child(_popup_title)
	_popup_text = RichTextLabel.new()
	_popup_text.bbcode_enabled = true
	_popup_text.fit_content = true
	_popup_text.scroll_active = false
	_popup_text.custom_minimum_size = Vector2(560, 0)
	_popup_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_text.add_theme_font_size_override("normal_font_size", 20)
	box.add_child(_popup_text)
	var hint := Label.new()
	hint.text = "Tap anywhere to close"
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", UiStyle.TEXT_DIM)
	box.add_child(hint)

	_turn = ColorRect.new()
	(_turn as ColorRect).color = Color.BLACK
	_turn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_turn.hide()
	layer.add_child(_turn)
	var message := Label.new()
	message.text = "Turn your phone sideways"
	message.set_anchors_preset(Control.PRESET_FULL_RECT)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_override("font", UiStyle.DISPLAY_FONT)
	message.add_theme_font_size_override("font_size", 64)
	message.add_theme_color_override("font_color", UiStyle.GOLD)
	_turn.add_child(message)

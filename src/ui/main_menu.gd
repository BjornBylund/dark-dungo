## Title screen: continue or start a campaign, or open the combat sandbox.
## Launch options skip the menu: `-- --sandbox`, `-- --new-campaign`, `-- --continue`.
extends Control

var _continue: Button
var _new: Button
var _confirm_new := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--sandbox" in args:
		Game.play_sandbox.call_deferred()
		return
	if "--new-campaign" in args:
		Game.new_campaign.call_deferred()
		return
	if "--continue" in args and Game.has_save():
		Game.continue_campaign.call_deferred()
		return
	theme = UiStyle.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	var title := Label.new()
	title.text = "Darko Dungo"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiStyle.DISPLAY_FONT)
	title.add_theme_font_size_override("font_size", 110)
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 14)
	column.add_child(title)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	column.add_child(spacer)
	_continue = _menu_button("Continue", func() -> void:
		if not Game.continue_campaign():
			_continue.text = "Save could not be read"
			_continue.disabled = true)
	_continue.disabled = not Game.has_save()
	_new = _menu_button("New Campaign", _on_new)
	for button: Button in [_continue, _new, _menu_button("Combat Sandbox", Game.play_sandbox)]:
		column.add_child(button)
	if OS.has_feature("web"):
		var fullscreen := _menu_button("Fullscreen", _toggle_fullscreen)
		fullscreen.theme_type_variation = &""
		fullscreen.add_theme_font_size_override("font_size", 20)
		column.add_child(fullscreen)
	queue_redraw()


func _toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _draw() -> void:
	var background: Texture2D = Game.CAMPAIGN.town_background
	if background:
		var scale: float = maxf(size.x / background.get_width(), size.y / background.get_height())
		var drawn: Vector2 = background.get_size() * scale
		draw_texture_rect(background, Rect2((size - drawn) / 2.0, drawn), false)


func _menu_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"ActionButton"
	button.custom_minimum_size = Vector2(340, 56)
	button.add_theme_font_size_override("font_size", 22)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


func _on_new() -> void:
	if Game.has_save() and not _confirm_new:
		_confirm_new = true
		_new.text = "Replace your save? Click again"
		return
	Game.new_campaign()

## A dialogue scene played full screen over the town: the hamlet darkened behind,
## the cast standing tall with the speaker lit from below and the others in
## shadow, and a framed text box with the speaker's name. Text types out; a
## click, tap, Enter or Space shows it all, then moves on. Skip (or Esc) ends
## the scene. Emits `finished` once it is over.
class_name DialogueView
extends Control

signal finished

## Characters typed per second.
const TYPE_SPEED := 55.0
## Seconds a typed line stays up before autoplay moves on.
const AUTO_DELAY := 1.2
const NARRATOR_NAME := "The Ancestor"
const NARRATOR_TEXT := Color("d9c49a")
## Cast members who aren't speaking.
const SHADOW := Color(0.3, 0.28, 0.32)
## Everyone while the Ancestor speaks.
const LISTENING := Color(0.5, 0.47, 0.5)
const BACKDROP_TINT := Color(0.16, 0.14, 0.15)

var _scene: DialogueScene
var _line := -1
var _auto := false
var _done := false
var _backdrop: Texture2D
var _sprites: Array[TextureRect] = []
var _glow: TextureRect
var _title: Label
var _skip: Button
var _box: PanelContainer
var _name: Label
var _text: Label
## The arrow showing a line is typed out and a click moves on.
var _more: Control
var _typing: Tween


## Starts `scene` over `backdrop`. With `auto`, lines move on by themselves.
func play(scene: DialogueScene, backdrop: Texture2D, auto: bool = false) -> void:
	_scene = scene
	_backdrop = backdrop
	_auto = auto
	_build()
	resized.connect(_layout)
	_layout()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	_show_line(0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_advance()
		KEY_ESCAPE:
			_finish()
		_:
			return
	get_viewport().set_input_as_handled()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if _backdrop:
		# Cover the screen, keeping the picture's shape.
		var scale := maxf(size.x / _backdrop.get_width(), size.y / _backdrop.get_height())
		var drawn := _backdrop.get_size() * scale
		draw_texture_rect(_backdrop, Rect2((size - drawn) / 2.0, drawn), false, BACKDROP_TINT)
	# Darker towards the text box.
	var shade := PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.85), Color(0, 0, 0, 0.85)])
	draw_polygon(PackedVector2Array([Vector2(0, size.y * 0.45), Vector2(size.x, size.y * 0.45), size,
			Vector2(0, size.y)]), shade)


# --- Lines ---

## Shows the rest of a line being typed, or moves on to the next.
func _advance() -> void:
	if _done:
		return
	if _typing and _typing.is_running():
		_typing.kill()
		_text.visible_ratio = 1.0
		_typed()
		return
	_show_line(_line + 1)


func _show_line(index: int) -> void:
	if index >= _scene.texts.size():
		_finish()
		return
	_line = index
	var speaker := _scene.speakers[index]
	_name.text = speaker.display_name if speaker else NARRATOR_NAME
	_name.add_theme_color_override("font_color", speaker.color.lerp(Color.WHITE, 0.45) if speaker else UiStyle.GOLD)
	_text.add_theme_color_override("font_color", UiStyle.TEXT if speaker else NARRATOR_TEXT)
	_text.text = _scene.texts[index]
	_text.visible_ratio = 0.0
	_more.hide()
	_light(speaker)
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, _text.text.length() / TYPE_SPEED)
	_typing.finished.connect(_typed)


func _typed() -> void:
	_more.show()
	if _auto:
		var line := _line
		await get_tree().create_timer(AUTO_DELAY).timeout
		if is_inside_tree() and not _done and _line == line:
			_show_line(line + 1)


func _finish() -> void:
	if _done:
		return
	_done = true
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.3)
	await fade.finished
	finished.emit()


## Lights the speaker and puts the others in shadow; the Ancestor speaks to everyone.
func _light(speaker: UnitDef) -> void:
	for i in _sprites.size():
		var target := LISTENING if speaker == null else (Color.WHITE if _scene.cast[i] == speaker else SHADOW)
		create_tween().tween_property(_sprites[i], "modulate", target, 0.25)
	var index := _scene.cast.find(speaker)
	_glow.visible = index >= 0
	if index >= 0:
		_place_glow(_sprites[index])


# --- Layout ---

func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiStyle.make_theme()
	add_child(Atmosphere.new())

	_glow = TextureRect.new()
	var light := GradientTexture2D.new()
	light.fill = GradientTexture2D.FILL_RADIAL
	light.fill_from = Vector2(0.5, 0.5)
	light.fill_to = Vector2(0.5, 0.0)
	light.gradient = Gradient.new()
	light.gradient.set_color(0, Color(1.0, 0.72, 0.42, 0.42))
	light.gradient.set_color(1, Color(1.0, 0.6, 0.3, 0.0))
	_glow.texture = light
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_glow)

	for unit in _scene.cast:
		var sprite := TextureRect.new()
		sprite.texture = unit.sprite
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sprite.modulate = SHADOW
		add_child(sprite)
		_sprites.append(sprite)

	_title = _label(_scene.title, 30 if Device.phone else 46, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	add_child(_title)

	_skip = Button.new()
	_skip.text = "Skip"
	_skip.add_theme_font_size_override("font_size", 20 if Device.phone else 24)
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.pressed.connect(_finish)
	add_child(_skip)

	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 4 if Device.phone else 10)
	_box.add_child(column)
	_name = _label("", 26 if Device.phone else 40, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	column.add_child(_name)
	_text = _label("", 19 if Device.phone else 30, UiStyle.TEXT)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Laid out in full before typing, so words don't jump between rows.
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	column.add_child(_text)

	_more = Control.new()
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more.custom_minimum_size = Vector2(22, 14)
	_more.draw.connect(func() -> void:
		_more.draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(_more.size.x, 0),
				Vector2(_more.size.x / 2.0, _more.size.y)]), UiStyle.GOLD))
	add_child(_more)
	var blink := create_tween().set_loops()
	blink.tween_property(_more, "modulate:a", 0.25, 0.5)
	blink.tween_property(_more, "modulate:a", 1.0, 0.5)


## The cast stands above the text box, its feet behind it: one hero large on
## the left, two facing each other, more spread across the screen.
func _layout() -> void:
	var margin := 14.0 if Device.phone else 56.0
	var box_height := 150.0 if Device.phone else 230.0
	_box.position = Vector2(margin, size.y - box_height - margin * 0.5)
	_box.size = Vector2(size.x - margin * 2.0, box_height)
	_more.size = _more.custom_minimum_size
	_more.position = _box.position + _box.size - _more.size - Vector2(36, 30)
	_title.position = Vector2(margin, margin * 0.4)
	_skip.size = _skip.get_combined_minimum_size()
	_skip.position = Vector2(size.x - margin - _skip.size.x, margin * 0.5)
	var count := _sprites.size()
	var height := size.y * (0.8 if count == 1 else 0.6)
	var feet := _box.position.y + box_height * (0.6 if count == 1 else 0.3)
	for i in count:
		var texture := _sprites[i].texture
		var aspect := float(texture.get_width()) / texture.get_height() if texture else 0.55
		var center := size.x * (0.27 if count == 1 else lerpf(0.27, 0.73, i) if count == 2
				else lerpf(0.13, 0.87, float(i) / (count - 1)))
		# Everyone is drawn facing right; the second of two turns to face the first.
		_sprites[i].flip_h = count == 2 and i == 1
		_sprites[i].size = Vector2(height * aspect, height)
		_sprites[i].position = Vector2(center - height * aspect / 2.0, feet - height)
	var index := _scene.cast.find(_scene.speakers[maxi(_line, 0)])
	if index >= 0:
		_place_glow(_sprites[index])
	queue_redraw()


## The warm light rises from below the speaker.
func _place_glow(sprite: TextureRect) -> void:
	var glow_size := Vector2(sprite.size.y * 0.9, sprite.size.y * 0.75)
	_glow.size = glow_size
	_glow.position = sprite.position + Vector2(sprite.size.x / 2.0, sprite.size.y * 0.7) - glow_size / 2.0


func _label(text: String, font_size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if font:
		label.add_theme_font_override("font", font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

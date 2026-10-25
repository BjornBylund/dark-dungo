## One rank of the party lineup on the expedition screen, like DD1's embark
## slots: the hero standing in it, and each skill with gold pips for the ranks
## it can be used from (drawn 4 to 1, this slot's rank ringed). Skills that
## can't be used from this rank are dimmed. Heroes drag between slots and in
## from the roster; clicking a hero sends them back.
class_name FormationSlot
extends Control

signal dropped(hero: HeroRecord, rank: int)
signal clicked(rank: int)

const WIDTH := 200.0
const ICON := 34.0
const ICON_GAP := 7.0
const PIP_RADIUS := 3.5
const PIP_PITCH := 8.0
## Space under the figure for the name, level, skills, pips and summary.
const BELOW_FIGURE := 130.0

var rank := 1
var hero: HeroRecord
## Picked up on a touch screen, waiting for a slot to swap with.
var picked := false
var note := ""
var note_color := UiStyle.TEXT_DIM
var _figure := Rect2(8, 38, WIDTH - 16, 222)
var _drop_hover := false


func setup(slot_rank: int, record: HeroRecord, note_text: String = "", color: Color = UiStyle.TEXT_DIM,
		figure_height: float = 222.0) -> void:
	rank = slot_rank
	hero = record
	note = note_text
	note_color = color
	_figure.size.y = figure_height
	custom_minimum_size = Vector2(WIDTH, _figure.end.y + BELOW_FIGURE)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hero else Control.CURSOR_ARROW
	mouse_exited.connect(func() -> void: _set_drop_hover(false))


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_set_drop_hover(false)


## Clicks on a hero; on touch screens also taps on an empty slot, the target of a swap.
func _gui_input(event: InputEvent) -> void:
	if (hero or Device.touch) and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not event.pressed:
		clicked.emit(rank)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if hero == null:
		return null
	set_drag_preview(drag_preview(hero))
	return {hero = hero}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var ok: bool = data is Dictionary and data.get("hero") is HeroRecord
	_set_drop_hover(ok)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_set_drop_hover(false)
	dropped.emit(data.hero, rank)


func _get_tooltip(at_position: Vector2) -> String:
	if hero == null:
		return ""
	var index := _icon_at(at_position)
	if index < 0:
		return ""
	var skill := hero.def.skills[index]
	var ranks := ", ".join(skill.launch_ranks.map(func(r: int) -> String: return str(r)))
	return "%s\nUsable from rank %s" % [skill.display_name, ranks]


## A small portrait that follows the cursor while a hero is dragged.
static func drag_preview(record: HeroRecord) -> Control:
	var holder := Control.new()
	var picture := TextureRect.new()
	picture.size = Vector2(72, 72)
	picture.position = -picture.size / 2.0
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if record.def.sprite:
		var atlas := AtlasTexture.new()
		atlas.atlas = record.def.sprite
		atlas.region = UiStyle.portrait_region(record.def.sprite)
		picture.texture = atlas
	holder.add_child(picture)
	return holder


func _set_drop_hover(value: bool) -> void:
	if _drop_hover != value:
		_drop_hover = value
		queue_redraw()


func _draw() -> void:
	var display := UiStyle.DISPLAY_FONT
	var body := UiStyle.BODY_FONT
	draw_string(display, Vector2(0, 24), "Rank %d" % rank, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22,
			UiStyle.GOLD if hero else UiStyle.TEXT_DIM)
	var lit := _drop_hover or picked
	var border := UiStyle.GOLD if lit else Color("3a3430")
	draw_style_box(UiStyle.box(Color("241b1d") if picked else Color("120e0f"), border, 3 if picked else (2 if lit else 1),
			3), _figure.grow(4))
	if hero == null:
		draw_string(body, Vector2(0, _figure.get_center().y), "Empty", HORIZONTAL_ALIGNMENT_CENTER, size.x, 18,
				UiStyle.TEXT_DIM)
		return
	_draw_figure()
	var below := _figure.end.y
	draw_string(display, Vector2(0, below + 28), hero.display_name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22,
			UiStyle.GOLD)
	var level := "Level %d" % hero.level()
	draw_string(body, Vector2(0, below + 44), level + ("   " + note if note != "" else ""),
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, note_color if note != "" else UiStyle.TEXT_DIM)
	var usable := 0
	var attacks := 0
	for i in hero.def.skills.size():
		var skill := hero.def.skills[i]
		var here := rank in skill.launch_ranks
		usable += int(here)
		attacks += int(here and skill.is_attack())
		var icon_rect := _icon_rect(i)
		var icon := UiStyle.skill_icon(skill)
		if icon:
			draw_texture_rect(icon, icon_rect, false, Color.WHITE if here else Color(0.35, 0.35, 0.35, 0.7))
		draw_rect(icon_rect, UiStyle.GOLD if here else Color("3a3430"), false, 1.0)
		_draw_pips(skill, Vector2(icon_rect.get_center().x, icon_rect.end.y + 9.0))
	var summary := "%d of %d skills usable" % [usable, hero.def.skills.size()]
	if attacks == 0:
		summary = "No attacks from rank %d" % rank
	draw_string(body, Vector2(0, size.y - 6), summary, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14,
			UiStyle.DAMAGE if attacks == 0 else UiStyle.TEXT_DIM)


## The hero's figure fitted into the slot, feet on the bottom edge, as in combat.
func _draw_figure() -> void:
	var sprite := hero.def.sprite
	if sprite == null:
		var height := _figure.size.y * 0.75
		draw_rect(Rect2(_figure.get_center().x - height / 4.0, _figure.end.y - height, height / 2.0, height),
				hero.def.color)
		return
	var fit := minf(_figure.size.x / sprite.get_width(), _figure.size.y / sprite.get_height()) * hero.def.sprite_scale
	fit = minf(fit, _figure.size.y / sprite.get_height())
	var drawn := sprite.get_size() * fit
	draw_texture_rect(sprite, Rect2(_figure.get_center().x - drawn.x / 2.0, _figure.end.y - drawn.y, drawn.x, drawn.y),
			false)


## Four gold-or-empty pips for ranks 4 to 1; this slot's rank is ringed.
func _draw_pips(skill: SkillDef, center: Vector2) -> void:
	for i in 4:
		var pip_rank := 4 - i
		var point := center + Vector2((i - 1.5) * PIP_PITCH, 0)
		if pip_rank in skill.launch_ranks:
			draw_circle(point, PIP_RADIUS, UiStyle.GOLD)
		else:
			draw_circle(point, PIP_RADIUS, Color(UiStyle.GREY, 0.5), false, 1.0)
		if pip_rank == rank:
			draw_circle(point, PIP_RADIUS + 2.0, UiStyle.TEXT, false, 1.0)


func _icon_rect(index: int) -> Rect2:
	var count := hero.def.skills.size()
	var left := (size.x - count * ICON - (count - 1) * ICON_GAP) / 2.0
	return Rect2(left + index * (ICON + ICON_GAP), _figure.end.y + 52, ICON, ICON)


func _icon_at(point: Vector2) -> int:
	for i in hero.def.skills.size():
		if _icon_rect(i).grow(3).has_point(point):
			return i
	return -1

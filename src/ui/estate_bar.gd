## The band along the top of the town and expedition screens: the week, gold
## and heirlooms, then whatever buttons the screen adds on the right. The phone
## layout packs it tighter.
class_name EstateBar
extends Control

const HEIGHT := 64.0

var _band: ColorRect
var _week: Label
var _gold: Label
var _heirlooms: Dictionary[StringName, Label] = {}
var _row: HBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band = ColorRect.new()
	_band.color = Color(0, 0, 0, 0.75)
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10 if Device.phone else 18)
	add_child(_row)
	_week = _label(30 if Device.phone else 34, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	_row.add_child(_week)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(spacer)
	if not Device.phone:
		var gold_title := _label(18, UiStyle.TEXT_DIM)
		gold_title.text = "Gold"
		_row.add_child(gold_title)
	_gold = _label(26, UiStyle.GOLD if Device.phone else UiStyle.TEXT, UiStyle.DISPLAY_FONT)
	_row.add_child(_gold)
	for heirloom in CampaignRules.HEIRLOOMS:
		var icon := TextureRect.new()
		icon.texture = load("res://art/heirlooms/%s.svg" % heirloom)
		icon.custom_minimum_size = Vector2(30, 30) if Device.phone else Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = CampaignRules.HEIRLOOM_NAMES[heirloom]
		_row.add_child(icon)
		var count := _label(24, UiStyle.TEXT, UiStyle.DISPLAY_FONT)
		_heirlooms[heirloom] = count
		_row.add_child(count)
	fit_width(1920.0)


## Lays the band out across `width`: the stage's width on desktop, the screen's on phones.
func fit_width(width: float) -> void:
	size = Vector2(width, HEIGHT)
	_band.size = size
	var margin := 16.0 if Device.phone else 28.0
	_row.position = Vector2(margin, 8)
	_row.size = Vector2(width - 2.0 * margin, 48)


func add_button(button: Control) -> void:
	_row.add_child(button)


func refresh(campaign: Campaign) -> void:
	_week.text = "Week %d" % campaign.week
	_gold.text = UiStyle.gold_text(campaign.gold)
	for heirloom in CampaignRules.HEIRLOOMS:
		_heirlooms[heirloom].text = str(campaign.heirlooms[heirloom])


func _label(font_size: int, color: Color, font: Font = null) -> Label:
	var label := Label.new()
	if font:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

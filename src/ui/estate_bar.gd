## The band along the top of the town and expedition screens: the week, gold
## and heirlooms, then whatever buttons the screen adds on the right.
class_name EstateBar
extends Control

const HEIGHT := 64.0

var _week: Label
var _gold: Label
var _heirlooms: Dictionary[StringName, Label] = {}
var _row: HBoxContainer


func _init() -> void:
	size = Vector2(1920, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.75)
	band.size = size
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	_row = HBoxContainer.new()
	_row.position = Vector2(28, 8)
	_row.size = Vector2(size.x - 56, 48)
	_row.add_theme_constant_override("separation", 18)
	add_child(_row)
	_week = _label(34, UiStyle.GOLD, UiStyle.DISPLAY_FONT)
	_row.add_child(_week)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(spacer)
	var gold_title := _label(18, UiStyle.TEXT_DIM)
	gold_title.text = "Gold"
	_row.add_child(gold_title)
	_gold = _label(26, UiStyle.TEXT, UiStyle.DISPLAY_FONT)
	_row.add_child(_gold)
	for heirloom in CampaignRules.HEIRLOOMS:
		var icon := TextureRect.new()
		icon.texture = load("res://art/heirlooms/%s.svg" % heirloom)
		icon.custom_minimum_size = Vector2(34, 34)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.tooltip_text = CampaignRules.HEIRLOOM_NAMES[heirloom]
		_row.add_child(icon)
		var count := _label(24, UiStyle.TEXT, UiStyle.DISPLAY_FONT)
		_heirlooms[heirloom] = count
		_row.add_child(count)


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

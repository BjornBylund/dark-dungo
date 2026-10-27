## Fonts, colours, icons and text helpers shared by the combat UI.
## Colours follow DD2's palette (docs/research/darkest-dungeon-ui.md, A7).
class_name UiStyle
extends RefCounted

const DISPLAY_FONT: FontFile = preload("res://art/fonts/grenze_gotisch/GrenzeGotisch.ttf")
## Gelasio is metrically compatible with Georgia (SIL Open Font License).
const BODY_FONT: FontFile = preload("res://art/fonts/gelasio/Gelasio.ttf")

const TEXT := Color("e8dcc8")
const TEXT_DIM := Color("9a8c7a")
const GREY := Color("8a8a8a")
const RULE := Color(0.33, 0.33, 0.33, 0.6)
const GOLD := Color("c9a66b")
const BLUE := Color("4c78b5")
const GREEN := Color("4ccb7a")
const PALE_GREEN := Color("a8d8a0")
const AMBER := Color("f0b050")
const HP_FILL := Color("8e1020")
const HP_FRAME := Color("3a3a3a")
const HP_EMPTY := Color("050505")
const CORPSE_FILL := Color("6b5a4a")
const STRESS_ON := Color("f0f0f0")
const STRESS_OFF := Color("2e2e2e")
const DAMAGE := Color("d9262e")
const CRIT := Color("f08a24")
const STRESS_TEXT := Color("e6e0ff")

const DOT_COLORS := {
	&"bleed": Color("d9443a"),
	&"blight": Color("8fbf3a"),
	&"burn": Color("f08a2a"),
}

## The resistance row in the target panel: [resist id, label, colour].
const RESIST_COLUMNS := [
	[&"bleed", "BLD", Color("d9443a")],
	[&"blight", "BLGT", Color("8fbf3a")],
	[&"burn", "BURN", Color("f08a2a")],
	[&"stun", "STN", Color("e8c84a")],
	[&"move", "MOV", Color("b09070")],
	[&"debuff", "DBFF", Color("b070d0")],
]

const TOKEN_HELP := {
	Tokens.CRIT: "Next attack or heal is a guaranteed crit.",
	Tokens.DODGE: "50% to evade the next attack.",
	Tokens.DODGE_PLUS: "75% to evade the next attack.",
	Tokens.BLOCK: "Next hit deals 50% less damage.",
	Tokens.BLOCK_PLUS: "Next hit deals 75% less damage.",
	Tokens.STRENGTH: "Next attack deals 50% more damage.",
	Tokens.RIPOSTE: "Counter-attacks the next attacker.",
	Tokens.GUARD: "Attacks on this unit hit its guardian instead.",
	Tokens.SPEED: "Acts first next round.",
	Tokens.STEALTH: "Can't be targeted while others can.",
	Tokens.STUN: "Loses its next turn.",
	Tokens.DAZE: "Next turn is pushed to the end of the round.",
	Tokens.BLIND: "50% to miss the next attack.",
	Tokens.WEAK: "Next attack deals half damage.",
	Tokens.VULNERABLE: "Next hit taken deals 50% more damage.",
	Tokens.TAUNT: "Enemies must target this unit if they can.",
	Tokens.IMMOBILIZE: "Can't move or be moved.",
	Tokens.COMBO: "Some skills get bonus effects against it.",
}

## Icons for the built-in actions, which are made in code rather than loaded as content.
const BASIC_SKILL_ICONS := {
	&"swap": preload("res://art/skills/swap.svg"),
	&"pass": preload("res://art/skills/pass.svg"),
	&"recover": preload("res://art/skills/recover.svg"),
}

const GREYSCALE_SHADER: Shader = preload("res://src/ui/greyscale.gdshader")

# DD1-style frames (art/ui), drawn as 9-slices.
const FRAME_TEXTURE: Texture2D = preload("res://art/ui/frame.svg")
const PLATE_TEXTURE: Texture2D = preload("res://art/ui/plate.svg")
const CARD_TEXTURE: Texture2D = preload("res://art/ui/card.svg")
const DIVIDER_TEXTURE: Texture2D = preload("res://art/ui/divider.svg")
## DD1's red, for the main call to action and danger.
const BLOOD := Color("8e1b1b")

static var _token_icons := {}


## The shared theme, after DD1: Gelasio text, iron-and-bronze framed panels,
## quiet text buttons, and an "ActionButton" variation on a bronze-rimmed plate.
static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = BODY_FONT
	result.default_font_size = 18

	result.set_stylebox("panel", "PanelContainer", frame())
	result.set_stylebox("panel", "TooltipPanel", box(Color("0b0e14f0"), Color("4a4a52"), 1, 3))
	result.set_color("font_color", "TooltipLabel", TEXT)
	result.set_font_size("font_size", "TooltipLabel", 15)

	# Small, quiet buttons: text only, gold on hover.
	var flat := StyleBoxEmpty.new()
	flat.set_content_margin_all(4)
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		result.set_stylebox(state, "Button", flat)
	result.set_font_size("font_size", "Button", 15)
	result.set_color("font_color", "Button", GREY)
	result.set_color("font_hover_color", "Button", GOLD)
	result.set_color("font_pressed_color", "Button", TEXT)
	result.set_color("font_hover_pressed_color", "Button", GOLD)
	result.set_color("font_disabled_color", "Button", Color(GREY, 0.45))

	result.set_type_variation(&"ActionButton", &"Button")
	result.set_stylebox("normal", "ActionButton", plate())
	result.set_stylebox("hover", "ActionButton", plate(Color(1.5, 1.15, 0.95)))
	result.set_stylebox("pressed", "ActionButton", plate(Color(2.0, 1.5, 1.0)))
	result.set_stylebox("hover_pressed", "ActionButton", plate(Color(2.0, 1.5, 1.0)))
	result.set_stylebox("disabled", "ActionButton", plate(Color(0.55, 0.55, 0.55)))
	result.set_font_size("font_size", "ActionButton", 17)
	result.set_color("font_color", "ActionButton", TEXT)
	result.set_color("font_hover_color", "ActionButton", GOLD)
	result.set_color("font_pressed_color", "ActionButton", GOLD)
	result.set_color("font_hover_pressed_color", "ActionButton", GOLD)
	result.set_color("font_disabled_color", "ActionButton", Color(TEXT_DIM, 0.6))

	# DD1's blood-red plate for the main call to action, like Embark.
	result.set_type_variation(&"PrimaryButton", &"ActionButton")
	result.set_stylebox("normal", "PrimaryButton", plate(Color(2.4, 0.95, 0.85)))
	result.set_stylebox("hover", "PrimaryButton", plate(Color(3.0, 1.3, 1.0)))
	result.set_stylebox("pressed", "PrimaryButton", plate(Color(3.2, 1.6, 1.1)))
	result.set_stylebox("hover_pressed", "PrimaryButton", plate(Color(3.2, 1.6, 1.1)))
	result.set_stylebox("disabled", "PrimaryButton", plate(Color(0.9, 0.55, 0.5)))
	result.set_color("font_color", "PrimaryButton", Color("f2e6d0"))

	result.set_color("font_color", "Label", TEXT)
	result.set_color("default_color", "RichTextLabel", TEXT)
	return result


## A window or panel's iron-and-bronze frame, DD1's.
static func frame(margin: float = 18.0) -> StyleBoxTexture:
	return _nine_slice(FRAME_TEXTURE, 26, margin)


## A small card's thin bronze frame, for heroes and slots.
static func card(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := _nine_slice(CARD_TEXTURE, 12, 6.0)
	style.modulate_color = tint
	return style


## A button's bronze-rimmed plate; `tint` lights it for hover and press.
static func plate(tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := _nine_slice(PLATE_TEXTURE, 12, 0.0)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.modulate_color = tint
	return style


## The ornamental rule under a title.
static func divider(width: float = 420.0) -> TextureRect:
	var rule := TextureRect.new()
	rule.texture = DIVIDER_TEXTURE
	rule.custom_minimum_size = Vector2(width, 20)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rule.stretch_mode = TextureRect.STRETCH_SCALE
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


static func _nine_slice(texture: Texture2D, corner: int, margin: float) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = corner
	style.texture_margin_top = corner
	style.texture_margin_right = corner
	style.texture_margin_bottom = corner
	style.set_content_margin_all(margin)
	return style


static func box(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(8)
	return style


static func skill_icon(skill: SkillDef) -> Texture2D:
	return skill.icon if skill.icon else BASIC_SKILL_ICONS.get(skill.id)


## Icon for a token, DoT type (&"bleed", &"blight", &"burn") or &"death_armor",
## loaded from art/tokens/<id>.svg. Null when there is no file.
static func token_icon(id: StringName) -> Texture2D:
	if not _token_icons.has(id):
		var path := "res://art/tokens/%s.svg" % id
		_token_icons[id] = load(path) if ResourceLoader.exists(path) else null
	return _token_icons[id]


static func token_name(token: StringName) -> String:
	return Tokens.display_name(token)


## A material that draws a control in greyscale at the given brightness.
static func greyscale(brightness: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GREYSCALE_SHADER
	material.set_shader_parameter("brightness", brightness)
	return material


static func percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


## In the phone layout, wraps `content` in a vertical ScrollContainer that fills
## the space left in its parent box; elsewhere returns `content` unchanged.
static func scroll_on_phone(content: Control) -> Control:
	if not Device.phone:
		return content
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll


## [tag, colour] for where a hero is this week: wounded, at the Abbey or
## Tavern, away, or "" when free.
static func hero_status(hero: HeroRecord) -> Array:
	if hero.wounded:
		return ["WOUNDED", DAMAGE]
	if hero.away_weeks > 0:
		return ["AWAY", GREY]
	if hero.activity != &"":
		return ["AT THE %s" % CampaignRules.BUILDINGS[CampaignRules.ACTIVITIES[hero.activity].building].name.to_upper(),
				GOLD]
	return ["", GREY]


## [title, text] for the end of a mission, from Campaign.finish_mission()'s summary.
static func mission_summary(summary: Dictionary) -> Array:
	var lines: Array[String] = []
	var title := "Mission complete"
	match summary.outcome:
		MissionRun.Outcome.RETREATED:
			title = "Retreated"
		MissionRun.Outcome.FAILED:
			title = "Mission failed"
			lines.append("The whole party fell. No rewards.")
	if summary.gold > 0:
		lines.append("Gold +%s" % gold_text(summary.gold))
	for type: StringName in summary.heirlooms:
		if summary.heirlooms[type] > 0:
			lines.append("%s +%d" % [CampaignRules.HEIRLOOM_NAMES[type], summary.heirlooms[type]])
	if summary.xp > 0:
		lines.append("XP +%d" % summary.xp)
	for hero: HeroRecord in summary.level_ups:
		lines.append("%s reaches level %d!" % [hero.display_name, hero.level()])
	for line: String in summary.bonds:
		lines.append(line)
	if not summary.bonds.is_empty():
		lines.append("New bonds give both heroes -%d stress and +%d%% damage on their next mission together." % [
				CampaignRules.BOND_BOOST_STRESS, roundi(CampaignRules.BOND_BOOST_DAMAGE * 100)])
	for hero: HeroRecord in summary.wounded:
		lines.append("%s is wounded and sits out next week." % hero.display_name)
	if summary.recruit:
		lines.append("With the region's boss defeated, a new hero will join you in town.")
	if not summary.town.is_empty():
		lines.append("")
		lines.append("In town:")
		for line: String in summary.town:
			lines.append(line)
	return [title, "\n".join(lines)]


const _BOND_STATS := {&"resist_stress": "stress resist", &"crit": "crit", &"resolute": "Resolute chance"}


## "Bonds: +20% stress resist, +5% crit. Bond boost: +10% damage", or "" without any.
static func _bond_bonuses(unit: Combatant) -> String:
	var totals := {}
	for buff in unit.buffs:
		if buff.expiry == Combatant.BuffExpiry.BOND:
			totals[buff.stat] = totals.get(buff.stat, 0.0) + buff.amount
	var parts: Array[String] = []
	for stat: StringName in _BOND_STATS:
		if totals.has(stat):
			parts.append("+%s %s" % [percent(totals[stat]), _BOND_STATS[stat]])
	var text := "Bonds: " + ", ".join(parts) + "." if not parts.is_empty() else ""
	var boost := unit.stat(&"damage")
	if boost > 0.0:
		text += (" " if text != "" else "") + "Bond boost: +%s damage." % percent(boost)
	return text


## Gold with thousands separators: 12,500.
static func gold_text(amount: int) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if amount < 0 else "") + digits + grouped


## Draws a texture clipped to a diamond (or any convex polygon) inside `rect`.
static func draw_clipped(canvas: CanvasItem, texture: Texture2D, points: PackedVector2Array, rect: Rect2,
		source: Rect2, flip: bool = false, modulate: Color = Color.WHITE) -> void:
	var uvs := PackedVector2Array()
	var size := texture.get_size()
	for point in points:
		var t := (point - rect.position) / rect.size
		if flip:
			t.x = 1.0 - t.x
		uvs.append((source.position + t * source.size) / size)
	canvas.draw_colored_polygon(points, modulate, uvs, texture)


## A unit's portrait in a thin bronze frame, DD1's, for cards and lists.
static func draw_portrait(canvas: CanvasItem, rect: Rect2, def: UnitDef) -> void:
	canvas.draw_rect(rect, Color("0c0a0a"))
	if def.sprite:
		canvas.draw_texture_rect_region(def.sprite, rect, portrait_region(def.sprite))
	else:
		canvas.draw_rect(rect.grow(-rect.size.x * 0.15), def.color)
	canvas.draw_rect(rect, Color("060404"), false, 3.0)
	canvas.draw_rect(rect.grow(-1.5), Color("8a6a3e"), false, 1.5)


## DD1's resolve-level badge: the level in a small dark disc on a bronze ring.
static func draw_level_badge(canvas: CanvasItem, center: Vector2, level: int, radius: float = 11.0) -> void:
	canvas.draw_circle(center, radius, Color("8a6a3e"))
	canvas.draw_circle(center, radius - 2.0, Color("140d0b"))
	canvas.draw_string(DISPLAY_FONT, center + Vector2(-radius, radius * 0.45), str(level), HORIZONTAL_ALIGNMENT_CENTER,
			radius * 2.0, int(radius * 1.4), GOLD)


static var _portrait_regions := {}


## The top of the drawn figure in a unit's sprite (ignoring transparent margins), for portraits.
static func portrait_region(texture: Texture2D) -> Rect2:
	if not _portrait_regions.has(texture):
		var used := Rect2(Vector2.ZERO, texture.get_size())
		var image := texture.get_image()
		if image:
			if image.is_compressed():
				image.decompress()
			used = Rect2(image.get_used_rect())
		var side := minf(used.size.x, used.size.y * 0.6)
		_portrait_regions[texture] = Rect2(used.get_center().x - side / 2.0, used.position.y, side, side)
	return _portrait_regions[texture]


static func diamond(center: Vector2, half: float) -> PackedVector2Array:
	return PackedVector2Array([center + Vector2(0, -half), center + Vector2(half, 0),
			center + Vector2(0, half), center + Vector2(-half, 0)])


static func icon_bbcode(id: StringName, size: int = 20) -> String:
	var path := "res://art/tokens/%s.svg" % id
	return "[img=%dx%d]%s[/img]" % [size, size, path] if ResourceLoader.exists(path) else ""


static func effect_bbcode(effect: EffectDef) -> String:
	match effect.kind:
		EffectDef.Kind.TOKEN:
			if not effect.token_pool.is_empty():
				return " or ".join(effect.token_pool.map(func(t: StringName) -> String:
					return "%s %s" % [icon_bbcode(t), token_name(t)]))
			var stacks := " x%d" % effect.stacks if effect.stacks > 1 else ""
			return "%s %s%s" % [icon_bbcode(effect.token), token_name(effect.token), stacks]
		EffectDef.Kind.DOT:
			return "%s [color=#%s]%s %d[/color] (%d Turns)" % [icon_bbcode(effect.dot),
					DOT_COLORS.get(effect.dot, TEXT).to_html(false), String(effect.dot).capitalize(),
					effect.amount, effect.duration]
		EffectDef.Kind.MOVE:
			return ("Pull %d" if effect.amount > 0 else "Knockback %d") % absi(effect.amount)
		EffectDef.Kind.CLEANSE_DOTS:
			return "Cure Bleed, Blight and Burn"
		EffectDef.Kind.CLEANSE_NEGATIVE:
			return "Clear negative tokens"
		EffectDef.Kind.GUARD:
			return "%s Guard x%d" % [icon_bbcode(Tokens.GUARD), effect.stacks]
	return ""


## Skill details in DD2's order: numbers, Target lines, Self lines, then
## conditional bonuses. Cooldowns and uses are shown on the icon.
static func skill_bbcode(skill: SkillDef) -> String:
	var lines: Array[String] = []
	var numbers: Array[String] = []
	if skill.deals_damage():
		numbers.append("DMG: %d-%d" % [skill.damage_min, skill.damage_max])
		numbers.append("CRIT: %s" % percent(skill.crit_chance))
	if skill.heal_max > 0:
		numbers.append("HEAL: %d-%d" % [skill.heal_min, skill.heal_max])
	if skill.heal_fraction > 0.0:
		numbers.append("HEAL: %s HP" % percent(skill.heal_fraction))
	if not numbers.is_empty():
		lines.append("   ".join(numbers))

	var target_parts: Array[String] = []
	if skill.side != SkillDef.TargetSide.SELF:
		for effect in skill.effects:
			target_parts.append(effect_bbcode(effect))
		if skill.stress != 0:
			target_parts.append("Stress %+d" % skill.stress)
	var self_parts: Array[String] = []
	if skill.side == SkillDef.TargetSide.SELF:
		for effect in skill.effects:
			self_parts.append(effect_bbcode(effect))
		if skill.stress != 0:
			self_parts.append("Stress %+d" % skill.stress)
	for effect in skill.self_effects:
		self_parts.append(effect_bbcode(effect))
	if skill.self_move != 0:
		self_parts.append(("Forward %d" if skill.self_move > 0 else "Back %d") % absi(skill.self_move))
	if skill.self_stress != 0:
		self_parts.append("Stress %+d" % skill.self_stress)
	if skill.self_damage > 0:
		self_parts.append("[color=#%s]-%d HP[/color]" % [DAMAGE.to_html(false), skill.self_damage])
	if skill.kind == SkillDef.Kind.SWAP:
		self_parts.append("Trade places with a nearby ally")
	if skill.kind == SkillDef.Kind.PASS:
		self_parts.append("Stress %+d" % Rules.PASS_STRESS)
	if not target_parts.is_empty():
		lines.append("[color=#%s]Target:[/color] %s" % [BLUE.lightened(0.25).to_html(false), ", ".join(target_parts)])
	if not self_parts.is_empty():
		lines.append("[color=#%s]Self:[/color] %s" % [GOLD.to_html(false), ", ".join(self_parts)])
	if skill.combo_damage_bonus > 0.0:
		lines.append("[color=#%s]+%s DMG when Target has %s Combo[/color]" % [PALE_GREEN.to_html(false),
				percent(skill.combo_damage_bonus), icon_bbcode(Tokens.COMBO)])
	if skill.low_hp_bonus > 0.0:
		lines.append("[color=#%s]+%s DMG below half HP[/color]" % [PALE_GREEN.to_html(false),
				percent(skill.low_hp_bonus)])
	if skill.multi_target:
		lines.append("[color=#%s]Hits every target in range[/color]" % PALE_GREEN.to_html(false))
	return "\n".join(lines)


## Multi-line stat sheet for a unit tooltip.
static func describe_unit(unit: Combatant) -> String:
	var lines: Array[String] = []
	lines.append(unit.display_name)
	if unit.is_corpse:
		lines.append("Corpse: %d HP, decays in %d rounds" % [unit.hp, unit.corpse_rounds])
		return "\n".join(lines)
	var hp_line := "HP %d/%d   Speed %d" % [unit.hp, unit.max_hp, unit.speed()]
	if unit.is_hero:
		hp_line += "   Stress %d/%d" % [unit.stress, Rules.STRESS_MAX]
	lines.append(hp_line)
	if unit.deaths_door:
		lines.append("On Death's Door")
	var bond_lines := _bond_bonuses(unit)
	if bond_lines != "":
		lines.append(bond_lines)
	for token: StringName in unit.tokens:
		lines.append("%s x%d: %s" % [token_name(token), unit.token_count(token), TOKEN_HELP.get(token, "")])
	for dot in unit.dots:
		lines.append("%s %d (%d turns)" % [String(dot.type).capitalize(), dot.amount, dot.turns])
	return "\n".join(lines)

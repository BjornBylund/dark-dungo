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

const TOKEN_NAMES := {
	Tokens.CRIT: "Crit", Tokens.DODGE: "Dodge", Tokens.DODGE_PLUS: "Dodge+", Tokens.BLOCK: "Block",
	Tokens.BLOCK_PLUS: "Block+", Tokens.STRENGTH: "Strength", Tokens.RIPOSTE: "Riposte",
	Tokens.GUARD: "Guard", Tokens.SPEED: "Speed", Tokens.STEALTH: "Stealth", Tokens.STUN: "Stun",
	Tokens.DAZE: "Daze", Tokens.BLIND: "Blind", Tokens.WEAK: "Weak", Tokens.VULNERABLE: "Vulnerable",
	Tokens.TAUNT: "Taunt", Tokens.IMMOBILIZE: "Immobilize", Tokens.COMBO: "Combo",
}

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

static var _token_icons := {}


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
	return TOKEN_NAMES.get(token, String(token).capitalize())


## A material that draws a control in greyscale at the given brightness.
static func greyscale(brightness: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GREYSCALE_SHADER
	material.set_shader_parameter("brightness", brightness)
	return material


static func percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


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
	if skill.multi_target:
		lines.append("[color=#%s]Hits every target in range[/color]" % PALE_GREEN.to_html(false))
	return "\n".join(lines)


## Multi-line stat sheet for a unit tooltip.
static func describe_unit(unit: Combatant) -> String:
	var lines: Array[String] = []
	lines.append("%s - %s" % [unit.display_name, unit.def.role])
	if unit.is_corpse:
		lines.append("Corpse: %d HP, decays in %d rounds" % [unit.hp, unit.corpse_rounds])
		return "\n".join(lines)
	var hp_line := "HP %d/%d   Speed %d" % [unit.hp, unit.max_hp, unit.speed()]
	if unit.is_hero:
		hp_line += "   Stress %d/%d" % [unit.stress, Rules.STRESS_MAX]
	lines.append(hp_line)
	if unit.deaths_door:
		lines.append("On Death's Door")
	for token: StringName in unit.tokens:
		lines.append("%s x%d: %s" % [token_name(token), unit.token_count(token), TOKEN_HELP.get(token, "")])
	for dot in unit.dots:
		lines.append("%s %d (%d turns)" % [String(dot.type).capitalize(), dot.amount, dot.turns])
	return "\n".join(lines)

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
	Tokens.CONVICTION: "+1 each turn. Some of the Vestal's skills grow stronger with it, and spend it.",
	Tokens.TOXIC: "Whoever hits this hero gets Blight 2 per Toxic token.",
	Tokens.PAIN: "Heals 10% HP per token at the end of the turn, then goes.",
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
	var style := _nine_slice(PLATE_TEXTURE, 16, 0.0)
	style.content_margin_left = 18
	style.content_margin_right = 18
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


## An heirloom's icon, art/heirlooms/<bust|portrait|deed|crest>.svg.
static func heirloom_icon(heirloom: StringName) -> Texture2D:
	return load("res://art/heirlooms/%s.svg" % heirloom)


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
## `campaign` gives the boss progress after it.
static func mission_summary(summary: Dictionary, campaign: Campaign) -> Array:
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
	for trinket: TrinketDef in summary.get("trinkets", []):
		lines.append("Trinket: %s (%s)" % [trinket.display_name, CampaignRules.RARITY_NAMES[trinket.rarity]])
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
	if summary.get("opened", "") != "":
		lines.append("A new region is open: %s." % summary.opened)
	var region: RegionDef = summary.get("progress")
	if region:
		if campaign.boss_ready(region):
			lines.append("%s awaits in %s." % [region.boss.display_name, region.display_name])
		else:
			lines.append("Boss progress in %s: %s" % [region.display_name, percent(campaign.boss_progress(region))])
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
	var boost := 0.0
	for buff in unit.buffs:
		if buff.stat == &"damage" and buff.expiry == Combatant.BuffExpiry.RUN:
			boost += buff.amount
	if boost > 0.0:
		text += (" " if text != "" else "") + "Bond boost: +%s damage." % percent(boost)
	return text


# --- Trinkets ---

## DD2's rarity colours, lightened to read on dark panels; Ancestral's is ours.
const RARITY_COLORS := [Color("a3a8ab"), Color("6fb4b6"), Color("d8b46e"), Color("e07a3a")]
const _TRINKET_STATS := {
	&"damage": "damage", &"crit": "crit", &"max_hp": "max HP", &"resolute": "Resolute chance at max stress",
	&"heal_received": "healing received", &"heal_power": "to healing skills", &"damage_taken": "damage taken",
}
## Stats where less is better.
const _LOWER_IS_BETTER: Array[String] = ["damage_taken", "dot_received_", "dot_duration_received"]
const _TRIGGER_NAMES := {
	TrinketTrigger.When.COMBAT_START: "Combat Start", TrinketTrigger.When.ROUND_START: "Round Start",
	TrinketTrigger.When.ROUND_END: "Round End", TrinketTrigger.When.TURN_START: "Turn Start",
	TrinketTrigger.When.TURN_END: "Turn End", TrinketTrigger.When.DEATHS_DOOR_ENTER: "On Entering Death's Door",
	TrinketTrigger.When.DEATHS_DOOR_LEAVE: "On Leaving Death's Door", TrinketTrigger.When.WHEN_MOVED: "When Moving",
	TrinketTrigger.When.WHEN_MOVED_BY_ENEMY: "When Moved by an Enemy",
}


## A trinket's lines, each [text, upside]: stats, conditional stats, triggers.
static func trinket_effects(trinket: TrinketDef) -> Array[Array]:
	var result: Array[Array] = []
	for stat: StringName in trinket.stats:
		result.append([trinket_stat_text(stat, trinket.stats[stat]), _upside(stat, trinket.stats[stat])])
	for bonus in trinket.bonuses:
		var conditions: Array[String] = []
		if not bonus.if_skills.is_empty():
			conditions.append(_skill_names(bonus.if_skills, trinket.hero))
		if bonus.if_token != &"":
			conditions.append("If %s%s" % ["no " if bonus.lacks else "", token_name(bonus.if_token)])
		if bonus.if_target != &"":
			conditions.append("If Target has %s" % token_name(bonus.if_target))
		if bonus.if_hp_below > 0.0:
			conditions.append("If HP < %s" % percent(bonus.if_hp_below))
		result.append(["%s: %s" % [", ".join(conditions), trinket_stat_text(bonus.stat, bonus.amount)],
				_upside(bonus.stat, bonus.amount)])
	for trigger in trinket.triggers:
		result.append([_trigger_text(trigger, trinket.hero), not trigger.malus])
	return result


## A trinket stat in words: "+15% damage", "-1 speed", "+1 Burn dealt".
static func trinket_stat_text(stat: StringName, amount: float) -> String:
	var name := String(stat)
	for kind in ["dealt", "received"]:
		if name.begins_with("dot_%s_" % kind):
			return "%+d %s %s" % [roundi(amount), name.trim_prefix("dot_%s_" % kind).capitalize(), kind]
	if name.begins_with("dot_duration_received"):
		var dot := name.trim_prefix("dot_duration_received").trim_prefix("_")
		return "%+d %s duration received" % [roundi(amount), dot.capitalize() if dot != "" else "DoT"]
	match stat:
		&"regen_dealt":
			return "%+d Regeneration dealt" % roundi(amount)
		&"damage_flat":
			return "%+d DMG" % roundi(amount)
	return buff_text(stat, amount)


static func _upside(stat: StringName, amount: float) -> bool:
	for prefix in _LOWER_IS_BETTER:
		if String(stat).begins_with(prefix):
			return amount < 0.0
	return amount > 0.0


## "Apply on Hit: Weak (15%)", "Each Hero on Combat Start: Block+",
## "Turn Start: If First in Turn Order: Blind".
static func _trigger_text(trigger: TrinketTrigger, hero: UnitDef = null) -> String:
	var other := trigger.to == TrinketTrigger.To.OTHER
	var when: String
	match trigger.when:
		TrinketTrigger.When.ON_HIT:
			when = "Apply on Hit" if other else "Gain on Hit"
		TrinketTrigger.When.ON_MISS:
			when = "Apply on Miss" if other else "Gain on Miss"
		TrinketTrigger.When.ON_CRIT:
			when = "Apply on Crit" if other else "Gain on Crit"
		TrinketTrigger.When.WHEN_HIT:
			when = "Apply to Attacker When Hit" if other else "Gain When Hit"
		TrinketTrigger.When.WHEN_MISSED:
			when = "Apply to Attacker When Missed" if other else "Gain When Missed"
		TrinketTrigger.When.ON_RESIST:
			when = "Gain on %s Resist" % String(trigger.if_resist).capitalize()
		TrinketTrigger.When.ON_SKILL:
			var skills := _skill_names(trigger.if_skills, hero) if not trigger.if_skills.is_empty() else "Ally"
			when = ("Target: %s" if other else "Self: %s") % skills
		_:
			when = _TRIGGER_NAMES[trigger.when]
	match trigger.to:
		TrinketTrigger.To.EACH_ALLY:
			when = "Each Hero on " + when
		TrinketTrigger.To.ALLIES_BEHIND:
			when += ": All Allies Behind"
		TrinketTrigger.To.ALLY_BEHIND:
			when += ": Ally Behind"
		TrinketTrigger.To.RANDOM_ALLY:
			when += ": Random Ally"
	var conditions: Array[String] = [when]
	if trigger.if_rank > 0:
		conditions.append("If Rank = %d" % trigger.if_rank)
	if trigger.if_first:
		conditions.append("If First in Turn Order")
	if trigger.if_speed_at_most > 0:
		conditions.append("If Speed <= %d" % trigger.if_speed_at_most)
	if trigger.if_speed_at_least > 0:
		conditions.append("If Speed >= %d" % trigger.if_speed_at_least)
	if trigger.if_token != &"":
		conditions.append("If %s%s" % ["no " if trigger.lacks else "", token_name(trigger.if_token)])
	var effects: Array[String] = []
	for effect in trigger.effects:
		var text := _trinket_effect_text(effect)
		effects.append(text + (" (%s)" % percent(effect.chance) if effect.chance < 1.0 else ""))
	return "%s: %s" % [": ".join(conditions), (" or " if trigger.pick_one else ", ").join(effects)]


## A trigger's payload in DD2's words.
static func _trinket_effect_text(effect: EffectDef) -> String:
	match effect.kind:
		EffectDef.Kind.TOKEN:
			if effect.token_pool == Tokens.RANDOM_POSITIVE:
				return "Add 1 Positive Token"
			if effect.token_pool == Tokens.RANDOM_NEGATIVE:
				return "Add 1 Negative Token"
			return token_name(effect.token) + (" x%d" % effect.stacks if effect.stacks > 1 else "")
		EffectDef.Kind.DOT:
			return "%s %d" % [String(effect.dot).capitalize(), effect.amount]
		EffectDef.Kind.REGEN:
			return "Regeneration %d" % effect.amount
		EffectDef.Kind.STRESS:
			return "%+d Stress" % effect.amount
		EffectDef.Kind.MOVE:
			return ("Forward %d" if effect.amount > 0 else "Back %d") % absi(effect.amount)
		EffectDef.Kind.HEAL:
			return "Heal %s" % (percent(effect.stat_amount) if effect.stat_amount > 0.0 else str(effect.amount))
		EffectDef.Kind.DAMAGE:
			return "%d DMG" % effect.amount
		EffectDef.Kind.CONVERT:
			return "Convert %s to %s" % [token_name(effect.token), token_name(effect.token_to)]
		EffectDef.Kind.REMOVE_ONE, EffectDef.Kind.STEAL_ONE:
			var verb := "Remove" if effect.kind == EffectDef.Kind.REMOVE_ONE else "Steal"
			var what := "Positive" if effect.token_pool == Tokens.POSITIVE else "Negative" \
					if effect.token_pool == Tokens.NEGATIVE else _token_list(effect.token_pool)
			return "%s 1 %s Token" % [verb, what]
		EffectDef.Kind.BUFF:
			return "%s (%d turns)" % [trinket_stat_text(effect.stat, effect.stat_amount), effect.duration]
		EffectDef.Kind.GUARD:
			return "Guard x%d" % effect.stacks
	return _effect_text(effect)


## The skills' names, from the hero's class when there is one.
static func _skill_names(ids: Array[StringName], hero: UnitDef = null) -> String:
	return " or ".join(ids.map(func(id: StringName) -> String:
		if hero:
			for skill in hero.skills:
				if skill.id == id:
					return skill.display_name
		return String(id).capitalize()))


## The effects coloured: upsides pale green, drawbacks red, joined by `separator`.
static func trinket_bbcode(trinket: TrinketDef, separator: String = ", ") -> String:
	return separator.join(trinket_effects(trinket).map(func(effect: Array) -> String:
		return "[color=#%s]%s[/color]" % [(PALE_GREEN if effect[1] else DAMAGE.lightened(0.2)).to_html(false), effect[0]]))


## "Rare", or "Rare, Crusader only".
static func trinket_kind(trinket: TrinketDef) -> String:
	var text: String = CampaignRules.RARITY_NAMES[trinket.rarity]
	return text + (", %s only" % trinket.hero.display_name if trinket.hero else "")


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


## Height of the resistance row draw_resists draws.
const RESIST_ROW_HEIGHT := 76.0


## The six resistance columns (name, icon, percent) of `unit` from `at`, each
## `column` wide; those in `tested` are lit up.
static func draw_resists(canvas: CanvasItem, at: Vector2, unit: Combatant, tested: Array[StringName] = [],
		column: float = 70.0) -> void:
	for i in RESIST_COLUMNS.size():
		var entry: Array = RESIST_COLUMNS[i]
		var id: StringName = entry[0]
		var x := at.x + i * column
		if id in tested:
			canvas.draw_rect(Rect2(x + 4, at.y, column - 8, RESIST_ROW_HEIGHT), Color(GOLD, 0.16))
			canvas.draw_rect(Rect2(x + 4, at.y, column - 8, RESIST_ROW_HEIGHT), Color(GOLD, 0.6), false, 1.0)
		canvas.draw_string(BODY_FONT, Vector2(x, at.y + 18), entry[1], HORIZONTAL_ALIGNMENT_CENTER, column, 14, entry[2])
		var icon_id: StringName = &"immobilize" if id == &"move" else (&"weak" if id == &"debuff" else id)
		var icon := token_icon(icon_id)
		if icon:
			canvas.draw_texture_rect(icon, Rect2(x + column / 2.0 - 11.0, at.y + 26, 22, 22), false)
		canvas.draw_string(BODY_FONT, Vector2(x, at.y + 70), percent(unit.resist(id)), HORIZONTAL_ALIGNMENT_CENTER, column,
				17, TEXT)


## A padlock for something closed: a bronze shackle over a dark iron body,
## `height` tall around `center`.
static func draw_lock(canvas: CanvasItem, center: Vector2, height: float) -> void:
	var bronze := Color("8a6a3e")
	var iron := Color("060404")
	var width := height * 0.8
	var body := Rect2(center.x - width / 2.0, center.y - height * 0.1, width, height * 0.6)
	var shackle := Vector2(center.x, body.position.y + 2.0)
	canvas.draw_arc(shackle, width * 0.3, PI, TAU, 20, iron, height * 0.16)
	canvas.draw_arc(shackle, width * 0.3, PI, TAU, 20, bronze, height * 0.1)
	canvas.draw_rect(body.grow(2.0), iron)
	canvas.draw_rect(body, Color("2a1c14"))
	canvas.draw_rect(body.grow(-2.0), bronze, false, 2.0)
	var hole := body.get_center() - Vector2(0, height * 0.05)
	canvas.draw_circle(hole, height * 0.06, iron)
	canvas.draw_rect(Rect2(hole.x - height * 0.025, hole.y, height * 0.05, height * 0.15), iron)


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


## One effect, with its chance and conditions: "50%: Stun vs Combo".
static func effect_bbcode(effect: EffectDef, tier_name: String = "") -> String:
	var text := _effect_text(effect)
	if text == "":
		return ""
	if effect.chance < 1.0:
		text = "%s: %s" % [percent(effect.chance), text]
	if effect.on_crit_only:
		text += " on a crit"
	if effect.requires_target_token != &"":
		text += " vs %s" % token_name(effect.requires_target_token)
	if effect.requires_user_token != &"":
		text += " %s %s" % ["without" if effect.user_lacks else "with", token_name(effect.requires_user_token)]
	if effect.min_tier > 0:
		text += " at %d %s" % [effect.min_tier, tier_name]
	return text


static func _effect_text(effect: EffectDef) -> String:
	match effect.kind:
		EffectDef.Kind.TOKEN:
			if not effect.token_pool.is_empty():
				return " or ".join(effect.token_pool.map(func(t: StringName) -> String:
					return "%s %s" % [icon_bbcode(t), token_name(t)]))
			var stacks := " x%d" % effect.stacks if effect.stacks > 1 else ""
			return "%s %s%s" % [icon_bbcode(effect.token), token_name(effect.token), stacks]
		EffectDef.Kind.DOT:
			var crit := " (%d on a crit)" % effect.crit_duration if effect.crit_duration > 0 else ""
			return "%s [color=#%s]%s %d[/color] (%d Turns%s)" % [icon_bbcode(effect.dot),
					DOT_COLORS.get(effect.dot, TEXT).to_html(false), String(effect.dot).capitalize(),
					effect.amount, effect.duration, crit]
		EffectDef.Kind.MOVE:
			return ("Pull %d" if effect.amount > 0 else "Knockback %d") % absi(effect.amount)
		EffectDef.Kind.CLEANSE_DOTS:
			return "Cure Bleed, Blight and Burn"
		EffectDef.Kind.CLEANSE_NEGATIVE:
			return "Clear negative tokens"
		EffectDef.Kind.GUARD:
			return "%s Guard x%d" % [icon_bbcode(Tokens.GUARD), effect.stacks]
		EffectDef.Kind.REMOVE_TOKENS:
			return "Remove " + ", ".join(effect.token_pool.map(func(t: StringName) -> String: return token_name(t)))
		EffectDef.Kind.BUFF:
			return "%s (%d rounds)" % [buff_text(effect.stat, effect.stat_amount), effect.duration]
		EffectDef.Kind.REGEN:
			return "[color=#%s]Regen %d[/color] (%d Turns)" % [PALE_GREEN.to_html(false), effect.amount, effect.duration]
		EffectDef.Kind.SHUFFLE:
			return "Shuffle"
		EffectDef.Kind.EXTRA_TURN:
			return "An extra turn"
		EffectDef.Kind.STEAL_DOTS:
			return "Take over their Bleed, Blight and Burn"
		EffectDef.Kind.CLEANSE_POSITIVE:
			return "Remove positive tokens"
		EffectDef.Kind.STRESS:
			return "Stress %+d%s" % [effect.amount, " if %d+" % effect.min_stress if effect.min_stress > 0 else ""]
		EffectDef.Kind.CONSECRATE:
			return "Consecration of %s on their rank (%d rounds): %s each turn" % [String(effect.token).capitalize(),
					effect.duration, " or ".join(effect.token_pool.map(func(t: StringName) -> String: return token_name(t)))]
	return ""


## A stat change in words: "+2 speed", "-20% healing received", "+20% Burn
## piercing", "can't gain Block", "+1 Block each turn".
static func buff_text(stat: StringName, amount: float) -> String:
	var name := String(stat)
	if name.begins_with("blocks_"):
		return "Can't gain %s" % token_name(StringName(name.trim_prefix("blocks_")))
	if name.begins_with("gain_"):
		return "+%d %s each turn" % [roundi(amount), token_name(StringName(name.trim_prefix("gain_")))]
	if name.begins_with("pierce_"):
		return "+%s %s piercing" % [percent(amount), name.trim_prefix("pierce_").capitalize()]
	match stat:
		&"speed":
			return "%+d speed" % roundi(amount)
		&"pull_each_turn":
			return "Pulled %d each turn" % roundi(amount)
		&"pain_on_damage":
			return "Pain each time he is hurt"
	var label: String = _TRINKET_STATS.get(stat, "")
	if label == "" and name.begins_with("resist_"):
		var kind := name.trim_prefix("resist_")
		label = "death blow resist" if kind == "deathblow" else "%s resist" % kind
	return "%s%s %s" % ["+" if amount > 0.0 else "-", percent(absf(amount)), label if label != "" else name]


## Skill details in DD2's order: numbers, Target lines, Self lines, then
## conditional bonuses. Cooldowns and uses are shown on the icon.
static func skill_bbcode(skill: SkillDef) -> String:
	var lines: Array[String] = []
	var numbers: Array[String] = []
	var tier_name := " / ".join(skill.tier_tokens.map(func(t: StringName) -> String: return token_name(t)))
	if skill.damage_from_dots > 0.0:
		numbers.append("DMG: %s of the target's remaining DoT damage" % percent(skill.damage_from_dots))
	elif skill.deals_damage():
		numbers.append("DMG: %d-%d" % [skill.damage_min, skill.damage_max])
		numbers.append("CRIT: %s" % percent(skill.crit_chance))
	if skill.heal_max > 0:
		numbers.append("HEAL: %d-%d" % [skill.heal_min, skill.heal_max])
	if not skill.tier_heal.is_empty():
		numbers.append("HEAL: %s HP by %s" % [" / ".join(skill.tier_heal.map(func(v: float) -> String: return percent(v))),
				tier_name])
	elif skill.heal_fraction > 0.0:
		numbers.append("HEAL: %s HP" % percent(skill.heal_fraction))
	if not numbers.is_empty():
		lines.append("   ".join(numbers))

	var target_parts: Array[String] = []
	if skill.side != SkillDef.TargetSide.SELF:
		for effect in skill.effects:
			target_parts.append(effect_bbcode(effect, tier_name))
		if skill.stress != 0:
			target_parts.append("Stress %+d" % skill.stress)
	if skill.targets_corpse:
		target_parts.append("a corpse, which it clears")
		for effect in skill.neighbor_effects:
			target_parts.append("next to it: " + effect_bbcode(effect, tier_name))
	var self_parts: Array[String] = []
	if skill.side == SkillDef.TargetSide.SELF:
		for effect in skill.effects:
			self_parts.append(effect_bbcode(effect, tier_name))
		if skill.stress != 0:
			self_parts.append("Stress %+d" % skill.stress)
	if skill.self_move != 0:
		self_parts.append(("Forward %d" if skill.self_move > 0 else "Back %d") % absi(skill.self_move))
	for effect in skill.self_effects:
		self_parts.append(effect_bbcode(effect, tier_name))
	if skill.self_stress != 0:
		self_parts.append("Stress %+d" % skill.self_stress)
	if skill.self_heal_fraction > 0.0:
		var below := " if below %s HP" % percent(skill.self_heal_below) if skill.self_heal_below < 1.0 else ""
		self_parts.append("[color=#%s]Heal %s HP%s[/color]" % [PALE_GREEN.to_html(false), percent(skill.self_heal_fraction),
				below])
	if skill.self_heal_per_hit > 0.0:
		self_parts.append("[color=#%s]Heal %s HP per target hit[/color]" % [PALE_GREEN.to_html(false),
				percent(skill.self_heal_per_hit)])
	if skill.combo_self_heal > 0.0:
		self_parts.append("[color=#%s]Heal %s HP vs Combo[/color]" % [PALE_GREEN.to_html(false),
				percent(skill.combo_self_heal)])
	if skill.kill_stress != 0:
		self_parts.append("Stress %+d on a kill" % skill.kill_stress)
	if skill.self_damage > 0:
		self_parts.append("[color=#%s]-%d HP[/color]" % [DAMAGE.to_html(false), skill.self_damage])
	if skill.self_damage_fraction > 0.0:
		self_parts.append("[color=#%s]-%s HP[/color]" % [DAMAGE.to_html(false), percent(skill.self_damage_fraction)])
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
	var green := "[color=#%s]%%s[/color]" % PALE_GREEN.to_html(false)
	if skill.combo_crit_bonus > 0.0:
		lines.append(green % ("+%s CRIT vs Combo" % percent(skill.combo_crit_bonus)))
	if skill.combo_pierce > 0.0:
		lines.append(green % ("+%s resistance piercing vs Combo" % percent(skill.combo_pierce)))
	if skill.ends_combo:
		lines.append(green % "Ends Combo")
	if not skill.ignore_tokens.is_empty():
		lines.append(green % ("Ignores " + _token_list(skill.ignore_tokens)))
	if not skill.ignore_tokens_if_stealthed.is_empty():
		lines.append(green % ("With Stealth, ignores " + _token_list(skill.ignore_tokens_if_stealthed)))
	for count in skill.tier_damage.size():
		if skill.tier_damage[count] > 0.0 and (count == 0 or skill.tier_damage[count] != skill.tier_damage[count - 1]):
			lines.append(green % ("+%s DMG at %d %s" % [percent(skill.tier_damage[count]), count, tier_name]))
	if skill.tier_ignore_from > 0:
		lines.append(green % ("At %d %s, ignores %s" % [skill.tier_ignore_from, tier_name,
				_token_list(skill.tier_ignore_tokens)]))
	if skill.tier_spend_from > 0:
		lines.append(green % ("Spends all %s at %d or more" % [tier_name, skill.tier_spend_from]))
	if skill.heal_below < 1.0:
		lines.append(green % ("Heals only below %s HP" % percent(skill.heal_below)))
	if skill.heal_per_buff_token > 0.0:
		lines.append(green % ("+%s HP healed per positive token" % percent(skill.heal_per_buff_token)))
	if skill.clears_corpses:
		lines.append(green % "Clears every enemy corpse")
	if skill.multi_target:
		lines.append(green % "Hits every target in range")
	var limits := usage_text(skill)
	if limits != "":
		lines.append("[color=#%s]%s[/color]" % [GOLD.to_html(false), limits])
	return "\n".join(lines)


## BBCode text without its tags, for tooltips.
static func plain(bbcode: String) -> String:
	return RegEx.create_from_string("\\[[^\\]]*\\]").sub(bbcode, "", true)


static func _token_list(tokens: Array[StringName]) -> String:
	return ", ".join(tokens.map(func(t: StringName) -> String: return token_name(t)))


## "Cooldown 2 turns, 1 use per battle, only below 40% HP", or "" for a skill with no limits.
static func usage_text(skill: SkillDef) -> String:
	var parts: Array[String] = []
	if skill.cooldown > 0:
		parts.append("Cooldown %d turn%s" % [skill.cooldown, "" if skill.cooldown == 1 else "s"])
	if skill.uses_per_battle > 0:
		parts.append("%d use%s per battle" % [skill.uses_per_battle, "" if skill.uses_per_battle == 1 else "s"])
	match skill.condition:
		SkillDef.Condition.SELF_HP_BELOW:
			parts.append("only below %s HP" % percent(skill.condition_value))
		SkillDef.Condition.SELF_HAS_ANY:
			parts.append("needs " + " or ".join(skill.condition_tokens.map(func(t: StringName) -> String:
				return token_name(t))))
		SkillDef.Condition.TARGET_HP_BELOW:
			parts.append("target below %s HP" % percent(skill.condition_value))
		SkillDef.Condition.TARGET_HAS_TOKEN:
			parts.append("target with %s" % token_name(skill.condition_token))
		SkillDef.Condition.TARGET_HAS_ANY:
			var needs := " or ".join(skill.condition_tokens.map(func(t: StringName) -> String: return token_name(t)))
			if skill.condition_value > 0.0:
				needs += " or below %s HP" % percent(skill.condition_value)
			parts.append("target with " + needs)
		SkillDef.Condition.TARGET_STRESS_AT_LEAST:
			parts.append("target at %d+ stress" % roundi(skill.condition_value))
		SkillDef.Condition.TARGET_ON_CONSECRATION:
			parts.append("allies on a Consecration")
	return ", ".join(parts)


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

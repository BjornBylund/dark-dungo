## Colours, labels and text helpers shared by the combat UI. Placeholder look until there is art.
class_name UiStyle
extends RefCounted

const BACKGROUND_TOP := Color("15111a")
const BACKGROUND_BOTTOM := Color("261c1f")
const FLOOR := Color("1d1517")
const PANEL := Color("1a1418e6")
const PANEL_BORDER := Color("5a4636")
const TEXT := Color("e8dcc8")
const TEXT_DIM := Color("9a8c7a")
const GOLD := Color("d9b45a")
const HP := Color("b3332e")
const HP_BACK := Color("3a1a1a")
const STRESS := Color("c9b8ff")
const STRESS_BACK := Color("2c2440")
const HEAL := Color("6fd38a")
const ENEMY_TARGET := Color("e0533f")
const ALLY_TARGET := Color("5fc7a0")
const CRIT := Color("ffd25e")

const DOT_COLORS := {
	&"bleed": Color("d9443a"),
	&"blight": Color("8fbf3a"),
	&"burn": Color("f08a2a"),
}

## Token id -> [short label, colour].
const TOKENS := {
	Tokens.CRIT: ["CRT", Color("ffd25e")],
	Tokens.DODGE: ["DDG", Color("8fd0ff")],
	Tokens.DODGE_PLUS: ["DDG+", Color("5fb8ff")],
	Tokens.BLOCK: ["BLK", Color("9fb3c8")],
	Tokens.BLOCK_PLUS: ["BLK+", Color("c8dcf0")],
	Tokens.STRENGTH: ["STR", Color("f0a050")],
	Tokens.RIPOSTE: ["RIP", Color("e0c070")],
	Tokens.GUARD: ["GRD", Color("a0c0a0")],
	Tokens.SPEED: ["SPD", Color("80e0d0")],
	Tokens.STEALTH: ["STL", Color("8080a0")],
	Tokens.STUN: ["STUN", Color("ffe070")],
	Tokens.DAZE: ["DAZE", Color("e0d090")],
	Tokens.BLIND: ["BLND", Color("b070d0")],
	Tokens.WEAK: ["WEAK", Color("c06080")],
	Tokens.VULNERABLE: ["VULN", Color("e06060")],
	Tokens.TAUNT: ["TNT", Color("e08040")],
	Tokens.IMMOBILIZE: ["IMMO", Color("a08060")],
	Tokens.COMBO: ["CMB", Color("f070c0")],
}

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


static func token_name(token: StringName) -> String:
	return TOKEN_NAMES.get(token, String(token).capitalize())


static func token_color(token: StringName) -> Color:
	return TOKENS[token][1] if TOKENS.has(token) else TEXT


static func percent(value: float) -> String:
	return "%d%%" % roundi(value * 100.0)


## "1-2" or "1, 3" style rank list.
static func ranks(list: Array[int]) -> String:
	if list.is_empty():
		return "-"
	var sorted := list.duplicate()
	sorted.sort()
	if sorted.back() - sorted.front() == sorted.size() - 1 and sorted.size() > 1:
		return "%d-%d" % [sorted.front(), sorted.back()]
	return ", ".join(sorted.map(func(rank: int) -> String: return str(rank)))


static func describe_effect(effect: EffectDef) -> String:
	match effect.kind:
		EffectDef.Kind.TOKEN:
			if not effect.token_pool.is_empty():
				return " or ".join(effect.token_pool.map(func(t: StringName) -> String: return token_name(t)))
			return token_name(effect.token) + (" x%d" % effect.stacks if effect.stacks > 1 else "")
		EffectDef.Kind.DOT:
			return "%s %d for %d turns" % [String(effect.dot).capitalize(), effect.amount, effect.duration]
		EffectDef.Kind.MOVE:
			return ("Pull forward %d" if effect.amount > 0 else "Knock back %d") % absi(effect.amount)
		EffectDef.Kind.CLEANSE_DOTS:
			return "Cure bleed, blight and burn"
		EffectDef.Kind.CLEANSE_NEGATIVE:
			return "Remove negative tokens"
		EffectDef.Kind.GUARD:
			return "Guard x%d" % effect.stacks
	return ""


## Multi-line summary of what a skill does, for the info panel.
static func describe_skill(skill: SkillDef, unit: Combatant) -> String:
	var lines: Array[String] = []
	if skill.description != "":
		lines.append(skill.description)
	if skill.kind == SkillDef.Kind.ACTION:
		var where := "Use from %s" % ranks(skill.launch_ranks)
		match skill.side:
			SkillDef.TargetSide.SELF:
				where += " on self"
			SkillDef.TargetSide.ALLY:
				where += " on %s ally ranks %s" % ["all" if skill.multi_target else "one", ranks(skill.target_ranks)]
			SkillDef.TargetSide.ENEMY:
				where += " on %s enemy ranks %s" % ["all" if skill.multi_target else "one", ranks(skill.target_ranks)]
		lines.append(where)
	var numbers: Array[String] = []
	if skill.deals_damage():
		numbers.append("%d-%d damage" % [skill.damage_min, skill.damage_max])
		numbers.append("crit %s" % percent(skill.crit_chance))
	if skill.heal_max > 0:
		numbers.append("heal %d-%d" % [skill.heal_min, skill.heal_max])
	if skill.heal_fraction > 0.0:
		numbers.append("heal %s HP" % percent(skill.heal_fraction))
	if skill.stress != 0:
		numbers.append("%+d stress" % skill.stress)
	if skill.combo_damage_bonus > 0.0:
		numbers.append("+%s damage vs Combo" % percent(skill.combo_damage_bonus))
	if not numbers.is_empty():
		lines.append(", ".join(numbers))
	var effects: Array[String] = []
	for effect in skill.effects:
		effects.append(describe_effect(effect))
	if not effects.is_empty():
		lines.append("Target: " + ", ".join(effects))
	var self_parts: Array[String] = []
	for effect in skill.self_effects:
		self_parts.append(describe_effect(effect))
	if skill.self_move != 0:
		self_parts.append(("move forward %d" if skill.self_move > 0 else "move back %d") % absi(skill.self_move))
	if skill.self_stress != 0:
		self_parts.append("%+d stress" % skill.self_stress)
	if not self_parts.is_empty():
		lines.append("Self: " + ", ".join(self_parts))
	var limits: Array[String] = []
	if skill.cooldown > 0:
		limits.append("cooldown %d" % skill.cooldown)
	if skill.uses_per_battle > 0:
		limits.append("%d of %d uses left" % [unit.uses_left(skill), skill.uses_per_battle])
	if unit.cooldown_left(skill) > 0:
		limits.append("ready in %d turn%s" % [unit.cooldown_left(skill), "" if unit.cooldown_left(skill) == 1 else "s"])
	if not limits.is_empty():
		lines.append(", ".join(limits))
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
	var resists: Array[String] = []
	for kind: String in ["stun", "bleed", "blight", "burn", "move", "debuff"]:
		resists.append("%s %s" % [kind.capitalize(), percent(unit.resist(kind))])
	if unit.is_hero:
		resists.append("Deathblow %s" % percent(clampf(unit.resist(&"deathblow"), Rules.DEATHBLOW_MIN, Rules.DEATHBLOW_MAX)))
	lines.append("Resist: " + ", ".join(resists))
	if unit.death_armor > 0:
		lines.append("Death Armor %d" % unit.death_armor)
	if unit.deaths_door:
		lines.append("On Death's Door")
	for token: StringName in unit.tokens:
		lines.append("%s x%d: %s" % [token_name(token), unit.token_count(token), TOKEN_HELP.get(token, "")])
	for dot in unit.dots:
		lines.append("%s %d (%d turns)" % [String(dot.type).capitalize(), dot.amount, dot.turns])
	return "\n".join(lines)

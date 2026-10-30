## The sound effect for each battle event the combat screen plays back: the
## swing, shot or spell of a skill, the blow landing (a crit, or a clang when
## Block takes most of it), DoTs, tokens, stress, Death's Door and deaths.
class_name CombatSounds
extends RefCounted

const DOTS: Array[StringName] = [&"bleed", &"blight", &"burn"]
const SKILL_SOUNDS := {
	SkillDef.Sound.BLADE: &"swing",
	SkillDef.Sound.SHOT: &"shot",
	SkillDef.Sound.SPELL: &"cast",
}


## The Audio sound for `event`, empty for none. `unit` is the event's unit, if it has one.
static func of(event: Dictionary, unit: Combatant) -> StringName:
	match event.type:
		&"skill":
			return SKILL_SOUNDS[skill_sound(event.skill)]
		&"damage":
			var cause: StringName = event.get("cause", &"hit")
			if cause != &"hit":
				return cause if cause in DOTS else &"hit"
			if event.get("crit", false):
				return &"crit"
			return &"block" if blocked_most(event) else &"hit"
		&"miss":
			return &"miss"
		&"guarded", &"deathblow_resisted":
			return &"guard"
		&"heal":
			return &"heal" if event.amount > 0 else &""
		&"cleansed", &"left_deaths_door", &"regen_applied":
			return &"heal"
		&"stress":
			if event.amount > 0:
				return &"stress"
			return &"relief" if event.amount < 0 else &""
		&"stress_resisted", &"resisted", &"immobile":
			return &"resist"
		&"token":
			if event.added > 0:
				return &"debuff" if Tokens.is_negative(event.token) else &"buff"
			return &"resist" if not event.negated.is_empty() else &""
		&"buffed":
			return &"buff" if event.amount > 0 else &"debuff"
		&"dot_applied":
			return event.dot if event.dot in DOTS else &"debuff"
		&"stunned":
			return &"stun"
		&"dazed":
			return &"debuff"
		&"moved", &"reposition":
			return &"move"
		&"extra_turn":
			return &"buff"
		&"consecrated":
			return &"chime"
		&"death_armor":
			return &"block"
		&"deaths_door":
			return &"deaths_door"
		&"deathblow":
			return &"deathblow"
		&"death":
			return &"fallen" if unit and unit.is_hero else &"slain"
		&"meltdown", &"toxic":
			return &"meltdown"
		&"resolute":
			return &"resolute"
	return &""


## How `skill` sounds: its own choice, or worked out from what it does and its ranks.
static func skill_sound(skill: SkillDef) -> SkillDef.Sound:
	if skill.sound != SkillDef.Sound.FROM_RANKS:
		return skill.sound
	if not skill.is_attack():
		return SkillDef.Sound.SPELL
	if not 1 in skill.launch_ranks and (3 in skill.target_ranks or 4 in skill.target_ranks):
		return SkillDef.Sound.SHOT
	return SkillDef.Sound.BLADE


## Whether Block took about half of a hit's damage or more (the damage rounds up).
static func blocked_most(event: Dictionary) -> bool:
	var unblocked: int = maxi(1, roundi(event.base * event.attack_mod * (Rules.WEAK_MULTIPLIER if event.weak else 1.0)))
	return event.amount <= unblocked * 0.6

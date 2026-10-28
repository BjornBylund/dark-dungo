## The balance tool's static numbers: what a skill or unit does on paper,
## before any simulation. Effects that can be resisted are measured against
## the other side's average resistances, heal shares against the own side's
## average max HP. Units count the skills they take into a fight: a hero's
## first five (the default loadout), every skill for an enemy.
## Left out: skill ranks, gear, tokens, Combo bonuses and other conditional
## effects, and anything that depends on what the target holds.
class_name BalanceStats
extends RefCounted

## Fight length the per-round numbers assume, so cooldowns and use limits count.
const ROUNDS := 6
const RESISTS: Array[StringName] = [&"stun", &"bleed", &"blight", &"burn", &"move", &"debuff", &"deathblow", &"stress"]


## What one side's skills are measured against.
class Versus:
	## Resist kind -> the other side's average base resistance.
	var resists: Dictionary[StringName, float] = {}
	## The own side's average max HP, for heals given as a share of it.
	var ally_hp := 0.0


## `side` against `other`: the other side's average resistances, the own side's average HP.
static func versus(side: Array[UnitDef], other: Array[UnitDef]) -> Versus:
	var result := Versus.new()
	for kind in RESISTS:
		var total := 0.0
		for unit in other:
			total += unit.base_resist(kind)
		result.resists[kind] = total / other.size() if not other.is_empty() else 0.0
	var hp := 0.0
	for unit in side:
		hp += unit.max_hp
	result.ally_hp = hp / side.size() if not side.is_empty() else 0.0
	return result


## The skills a unit fights with when nobody picks: a hero's first five, all of an enemy's.
static func fighting_skills(unit: UnitDef, is_hero: bool) -> Array[SkillDef]:
	return unit.skills.slice(0, Rules.SKILL_SLOTS) if is_hero else unit.skills


## One skill's numbers. Per use: `average` (the damage roll's midpoint),
## `damage` (expected over every target, crits included, plus `dot`, the
## expected DoT damage after resistance), `heal` and `stress` (to its targets,
## negative for relief). Per round with its cooldown and use limit: `damage_rd`,
## `heal_rd`, `stress_rd`. `stun` and `move`: the chance one sticks on a target.
static func skill(skill: SkillDef, versus: Versus, owner_hp: int) -> Dictionary:
	var targets := target_count(skill)
	var crit := skill.crit_chance if skill.deals_damage() else 0.0
	var hit := 0.0
	var average := 0.0
	if skill.deals_damage() and skill.damage_from_dots <= 0.0:
		average = (skill.damage_min + skill.damage_max) / 2.0
		hit = ((1.0 - crit) * average + crit * skill.damage_max * Rules.CRIT_DAMAGE_MULTIPLIER) * targets
	var dot := 0.0
	var heal := 0.0
	var stress := float(skill.stress) * targets
	var stun := 0.0
	var move := 0.0
	var on_enemies := skill.side == SkillDef.TargetSide.ENEMY
	for effect in skill.effects:
		if not _counts(effect):
			continue
		var odds := effect.chance * (crit if effect.on_crit_only else 1.0)
		match effect.kind:
			EffectDef.Kind.DOT:
				var turns := (1.0 - crit) * effect.duration + crit * (effect.crit_duration if effect.crit_duration > 0
						else effect.duration)
				var sticks := odds * _lands(effect.dot, effect, versus, crit, on_enemies)
				dot += effect.amount * turns * sticks * targets
			EffectDef.Kind.TOKEN:
				var stun_share := 1.0 if effect.token == Tokens.STUN else 0.0
				if not effect.token_pool.is_empty():
					stun_share = float(effect.token_pool.count(Tokens.STUN)) / effect.token_pool.size()
				if stun_share > 0.0 and on_enemies:
					stun = maxf(stun, odds * stun_share * _lands(&"stun", effect, versus, crit, true))
			EffectDef.Kind.MOVE, EffectDef.Kind.SHUFFLE:
				if on_enemies:
					move = maxf(move, odds * _lands(&"move", effect, versus, crit, true))
			EffectDef.Kind.HEAL:
				heal += odds * (effect.amount + effect.stat_amount * versus.ally_hp) * targets
			EffectDef.Kind.REGEN:
				heal += odds * effect.amount * effect.duration * targets
			EffectDef.Kind.STRESS:
				stress += odds * effect.amount * targets
	if skill.heals() and not on_enemies:
		var share := skill.heal_fraction if skill.tier_heal.is_empty() else skill.tier_heal[0]
		var rolled := (skill.heal_min + skill.heal_max) / 2.0 + share * versus.ally_hp
		heal += rolled * (1.0 + Rules.HEAL_CRIT_CHANCE * (Rules.HEAL_CRIT_MULTIPLIER - 1.0)) * targets
	heal += (skill.self_heal_fraction + skill.self_heal_per_hit * targets) * owner_hp
	return {
		average = average, damage = hit + dot, dot = dot, heal = heal, stress = stress, stun = stun, move = move,
		damage_rd = _alone(skill, hit + dot), heal_rd = _alone(skill, heal), stress_rd = _alone(skill, stress),
	}


## A unit's numbers: `turn` (the most expected damage in one turn), and per
## round over a fight, picking each turn the ready skill that does the most of
## it: `damage_rd`, `heal_rd` and `stress_rd` (each as if the unit spent every
## turn on it; heroes' stress is relief, so negative). `stun` and `move`: its
## best chance to make one stick. `skills`: the numbers of each fighting skill.
static func unit(unit: UnitDef, is_hero: bool, versus: Versus) -> Dictionary:
	var skills := fighting_skills(unit, is_hero)
	var numbers := {}
	var turn := 0.0
	var stun := 0.0
	var move := 0.0
	for each in skills:
		numbers[each] = skill(each, versus, unit.max_hp)
		turn = maxf(turn, numbers[each].damage)
		stun = maxf(stun, numbers[each].stun)
		move = maxf(move, numbers[each].move)
	var stress_sign := -1.0 if is_hero else 1.0
	return {
		turn = turn, stun = stun, move = move, skills = numbers,
		damage_rd = rotation(skills, numbers, func(n: Dictionary) -> float: return n.damage, unit.turns_per_round),
		heal_rd = rotation(skills, numbers, func(n: Dictionary) -> float: return n.heal, unit.turns_per_round),
		stress_rd = stress_sign * rotation(skills, numbers, func(n: Dictionary) -> float:
				return stress_sign * n.stress, unit.turns_per_round),
	}


## The average per round when, each turn for ROUNDS rounds, the unit uses the
## ready skill with the highest `value` (skipping ones worth nothing), so
## cooldowns and use limits count.
static func rotation(skills: Array[SkillDef], numbers: Dictionary, value: Callable, turns_per_round: int = 1) -> float:
	var ready_at := {}
	var used := {}
	var total := 0.0
	for turn in ROUNDS * turns_per_round:
		var best: SkillDef = null
		var best_value := 0.0
		for each in skills:
			var worth: float = value.call(numbers[each])
			if worth <= best_value or ready_at.get(each, 0) > turn:
				continue
			if each.uses_per_battle > 0 and used.get(each, 0) >= each.uses_per_battle:
				continue
			best = each
			best_value = worth
		if best:
			total += best_value
			ready_at[best] = turn + best.cooldown + 1
			used[best] = used.get(best, 0) + 1
	return total / ROUNDS


## Units the skill reaches: every rank in range for a multi-target skill (one
## unit per rank), else one.
static func target_count(skill: SkillDef) -> int:
	if skill.multi_target and skill.side != SkillDef.TargetSide.SELF:
		return maxi(1, skill.target_ranks.size())
	return 1


## "12→234", "1234→self": the ranks a skill is used from and reaches.
static func ranks_text(skill: SkillDef) -> String:
	var reach := "self" if skill.side == SkillDef.TargetSide.SELF else _ranks(skill.target_ranks)
	return "%s→%s" % [_ranks(skill.launch_ranks), reach]


## The ranks any of the skills are used from and reach.
static func unit_ranks_text(skills: Array[SkillDef]) -> String:
	var launch: Array[int] = []
	var reach: Array[int] = []
	for each in skills:
		for rank in each.launch_ranks:
			if rank not in launch:
				launch.append(rank)
		if each.side != SkillDef.TargetSide.SELF:
			for rank in each.target_ranks:
				if rank not in reach:
					reach.append(rank)
	return "%s→%s" % [_ranks(launch), _ranks(reach) if not reach.is_empty() else "self"]


static func _ranks(ranks: Array[int]) -> String:
	var sorted := ranks.duplicate()
	sorted.sort()
	return "".join(sorted.map(func(rank: int) -> String: return str(rank)))


## The skill's per-round amount if the unit used only it, whenever it's ready.
static func _alone(skill: SkillDef, amount: float) -> float:
	var only: Array[SkillDef] = [skill]
	return signf(amount) * rotation(only, {skill: absf(amount)}, func(n: float) -> float: return n)


## Whether an effect counts on paper: not ones that need a token or tier tokens.
static func _counts(effect: EffectDef) -> bool:
	return effect.requires_target_token == &"" and effect.requires_user_token == &"" and effect.min_tier == 0


## The chance an effect gets past the target's resistance: its own side's
## effects always do, a crit pierces some.
static func _lands(kind: StringName, effect: EffectDef, versus: Versus, crit: float, on_enemies: bool) -> float:
	if not on_enemies or effect.ignore_resist:
		return 1.0
	var resist: float = versus.resists.get(kind, 0.0)
	return (1.0 - crit) * (1.0 - clampf(resist, 0.0, 1.0)) \
			+ crit * (1.0 - clampf(resist - Rules.CRIT_RESIST_PIERCE, 0.0, 1.0))

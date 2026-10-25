## DD2-style enemy decisions: a forced skill if one is usable, otherwise a
## weighted pick among usable skills (DD2's weights are all equal), then a
## target that respects Taunt and Stealth and avoids corpses when it can.
class_name EnemyAI
extends RefCounted


## Returns {skill: SkillDef, target: Combatant}, or {} when nothing is usable.
static func choose(battle: Battle, unit: Combatant) -> Dictionary:
	var usable: Array[SkillDef] = []
	for skill in unit.def.skills:
		if battle.can_use(unit, skill):
			usable.append(skill)
	if usable.is_empty():
		return {}
	var forced := usable.filter(func(skill: SkillDef) -> bool: return skill.ai_forced)
	var chosen: SkillDef
	if forced.is_empty():
		chosen = _weighted_pick(usable, battle.rng)
	else:
		chosen = forced[battle.rng.randi_range(0, forced.size() - 1)]
	return {skill = chosen, target = _pick_target(battle, unit, chosen)}


static func _weighted_pick(skills: Array[SkillDef], rng: RandomNumberGenerator) -> SkillDef:
	var total := 0.0
	for skill in skills:
		total += maxf(skill.ai_weight, 0.0)
	if total <= 0.0:
		return skills[rng.randi_range(0, skills.size() - 1)]
	var roll := rng.randf() * total
	for skill in skills:
		roll -= maxf(skill.ai_weight, 0.0)
		if roll < 0.0:
			return skill
	return skills.back()


static func _pick_target(battle: Battle, unit: Combatant, skill: SkillDef) -> Combatant:
	var targets: Array = battle.targets_for(unit, skill)
	var living := targets.filter(func(target: Combatant) -> bool: return target.is_active())
	if not living.is_empty():
		targets = living
	match skill.ai_target:
		SkillDef.TargetPreference.LOWEST_HP:
			targets = _best(targets, func(target: Combatant) -> float: return -target.hp_fraction())
		SkillDef.TargetPreference.HIGHEST_STRESS:
			targets = _best(targets, func(target: Combatant) -> float: return target.stress)
		SkillDef.TargetPreference.HAS_COMBO:
			var comboed := targets.filter(func(target: Combatant) -> bool: return target.has_token(Tokens.COMBO))
			if not comboed.is_empty():
				targets = comboed
	return targets[battle.rng.randi_range(0, targets.size() - 1)]


## The targets with the highest score; ties are all kept for a random pick.
static func _best(targets: Array, score: Callable) -> Array:
	var best_score := -INF
	var best: Array = []
	for target in targets:
		var value: float = score.call(target)
		if value > best_score:
			best_score = value
			best = [target]
		elif value == best_score:
			best.append(target)
	return best

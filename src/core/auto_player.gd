## Scripted hero players, used by --autoplay and by the balance simulation.
## Each returns [skill, target] for `battle.current`.
class_name AutoPlayer
extends RefCounted


## Heal the badly hurt, calm the badly stressed, otherwise hit hardest on the weakest foe.
static func sensible(battle: Battle) -> Array:
	var actor := battle.current
	var usable := _usable(battle)
	for skill in usable:
		if skill.heals() and skill.side == SkillDef.TargetSide.ALLY:
			var hurt := battle.targets_for(actor, skill).filter(func(h: Combatant) -> bool: return h.hp_fraction() < 0.5)
			if not hurt.is_empty():
				hurt.sort_custom(func(a: Combatant, b: Combatant) -> bool: return a.hp_fraction() < b.hp_fraction())
				return [skill, hurt[0]]
	for skill in usable:
		if skill.stress < 0:
			var stressed := battle.targets_for(actor, skill).filter(func(h: Combatant) -> bool: return h.stress >= 5)
			if not stressed.is_empty():
				return [skill, stressed[0]]
	var best: Array = []
	var best_value := 0.0
	for skill in usable:
		if not skill.deals_damage():
			continue
		for target in battle.targets_for(actor, skill):
			if not target.is_active():
				continue
			var preview := battle.preview(actor, skill, target)
			var value: float = preview.hit_chance * (preview.damage_min + preview.damage_max) / 2.0
			value *= 1.5 if skill.multi_target else 1.0
			value *= 2.0 if target.hp <= preview.damage_max else 1.0
			if value > best_value:
				best_value = value
				best = [skill, target]
	if not best.is_empty():
		return best
	return random(battle)


## Any usable skill on any valid target, preferring real skills over Swap and Pass.
static func random(battle: Battle) -> Array:
	var options := _usable(battle).filter(func(s: SkillDef) -> bool: return s.kind == SkillDef.Kind.ACTION)
	if options.is_empty():
		options = _usable(battle)
	var skill: SkillDef = options[battle.rng.randi_range(0, options.size() - 1)]
	var targets := battle.targets_for(battle.current, skill)
	return [skill, targets[battle.rng.randi_range(0, targets.size() - 1)]]


static func _usable(battle: Battle) -> Array[SkillDef]:
	var actor := battle.current
	var usable: Array[SkillDef] = []
	for skill in battle.actions_for(actor):
		if battle.can_use(actor, skill):
			usable.append(skill)
	return usable

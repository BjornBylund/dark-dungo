## Scripted hero players, used by --autoplay, the map auto-player and the
## balance tools. Each returns [skill, target] for `battle.current`.
class_name AutoPlayer
extends RefCounted

## Past this round heroes value everything but damage far less (healing,
## Block, Guard, buffs...) and fight, so defending can't drag a fight on forever.
const HEAL_UNTIL_ROUND := 20
## HP one point of stress is worth.
const STRESS_HP := 1.5
## Rounds a token or buff is counted for, at most.
const LASTS := 3
## Rounds of an enemy's threat that wearing down its HP is counted against.
const WEAR_ROUNDS := 3.0
## Share of an expected hit one Block or Dodge stack is worth: less than the
## half it stops, as the hit may never come or be ignored.
const GUARD_SHARE := 0.4
## What ending the fight is worth, in HP, on top of the last enemy's threat.
const FIGHT_OVER := 20.0


## The usable skill and target worth the most, in HP: damage dealt and kills
## (a kill is worth the turns the enemy loses), healing where it's missing,
## stress relieved, harm prevented by Block, Dodge, Guard and Stealth, enemy
## turns spoiled by Stun, Blind and Weak, Combo set up for the party, buffs,
## debuffs, DoTs, and costs like self-damage, stress or moving out of range.
static func best(battle: Battle) -> Array:
	var view := View.new(battle)
	var best_choice: Array = []
	var best_value := -INF
	for skill in _usable(battle):
		var targets := battle.targets_for(view.actor, skill)
		if skill.multi_target and skill.kind == SkillDef.Kind.ACTION:
			targets = targets.slice(0, 1)
		for target in targets:
			var value := view.value(skill, target)
			if value > best_value:
				best_value = value
				best_choice = [skill, target]
	return best_choice if not best_choice.is_empty() else random(battle)


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


## The battle as the bot sees it on one turn: how hard each enemy hits, how
## likely each hero is to be hit, and what the actor's own attacks are worth.
class View:
	var battle: Battle
	var actor: Combatant
	## Enemy -> the damage (and stress, as HP) it is expected to deal per round.
	var threat := {}
	## The average enemy's best single hit on a hero.
	var incoming := 0.0
	## Enemy attacks expected per round.
	var attacks := 0.0
	## Whether anyone in the party can cash in a Combo.
	var combo_users := false
	## What everything but damage counts for: less once the fight has gone on long.
	var support_weight := 1.0
	var _living := 0
	var _taunting: Array[Combatant] = []
	## Unit -> hit_of(unit).
	var _hits := {}

	func _init(fight: Battle) -> void:
		battle = fight
		actor = fight.current
		var hits := 0.0
		var count := 0
		for enemy in battle.enemies:
			if not enemy.is_active():
				continue
			threat[enemy] = _threat(enemy)
			hits += hit_of(enemy)
			count += 1
			attacks += enemy.def.turns_per_round
		incoming = hits / count if count > 0 else 0.0
		for hero in battle.heroes:
			if not hero.is_active():
				continue
			_living += 1
			if hero.has_token(Tokens.TAUNT):
				_taunting.append(hero)
			for skill in hero.skills:
				if skill.combo_damage_bonus > 0.0 or skill.combo_crit_bonus > 0.0:
					combo_users = true
				for effect in skill.effects:
					if effect.requires_target_token == Tokens.COMBO:
						combo_users = true
		support_weight = 1.0 if battle.round_number <= HEAL_UNTIL_ROUND else 0.3

	## A unit's best expected single hit, from its skills' numbers.
	func hit_of(unit: Combatant) -> float:
		if not _hits.has(unit):
			var best := 0.0
			for skill in unit.skills:
				if skill.deals_damage() and skill.damage_from_dots <= 0.0:
					var average := (skill.damage_min + skill.damage_max) / 2.0
					best = maxf(best, average * (1.0 + unit.damage_bonus) * (1.0 + skill.crit_chance * 0.5))
			_hits[unit] = best
		return _hits[unit]

	func _threat(enemy: Combatant) -> float:
		var best := 0.0
		for skill in enemy.skills:
			var targets := maxi(1, skill.target_ranks.size()) if skill.multi_target else 1
			var harm := 0.0
			if skill.deals_damage() and skill.damage_from_dots <= 0.0:
				harm += (skill.damage_min + skill.damage_max) / 2.0 * (1.0 + enemy.damage_bonus)
			harm += maxf(0.0, skill.stress) * STRESS_HP
			best = maxf(best, harm * targets)
		return best * enemy.def.turns_per_round

	## How likely `hero` is to be attacked while a token on them lasts.
	func hit_odds(hero: Combatant) -> float:
		var share := 1.0 / maxi(1, _living)
		if not _taunting.is_empty():
			share = 1.0 / _taunting.size() if hero in _taunting else 0.1
		return clampf(share * attacks * 1.5, 0.0, 1.0)

	func value(skill: SkillDef, target: Combatant) -> float:
		match skill.kind:
			SkillDef.Kind.PASS:
				return -STRESS_HP * Rules.PASS_STRESS - 1.0
			SkillDef.Kind.SWAP:
				return _swap_value(target)
		if skill.targets_corpse:
			return _weigh(0.0, 1.0 + _corpse_value(skill, target) + _self_value(skill, 0.0, target))
		var damage := 0.0
		var support := 0.0
		var crit := 0.0
		for unit in _affected(skill, target):
			var part := _target_value(skill, unit)
			damage += part.damage
			support += part.support
			crit = maxf(crit, part.crit)
		return _weigh(damage, support + _self_value(skill, crit, target))

	## Damage at full worth, everything else (costs too) at support_weight.
	func _weigh(damage: float, support: float) -> float:
		return damage + support * support_weight

	## The units a skill reaches with `primary` chosen: every living one in range for multi-target skills.
	func _affected(skill: SkillDef, primary: Combatant) -> Array[Combatant]:
		var result: Array[Combatant] = []
		if not skill.multi_target or skill.side == SkillDef.TargetSide.SELF:
			result.append(primary)
			return result
		var pool := battle.opponents_of(actor) if skill.side == SkillDef.TargetSide.ENEMY else battle.side_of(actor)
		for unit in pool:
			if unit.is_active() and battle.covers_rank(unit, skill.target_ranks):
				result.append(unit)
		return result

	## {damage, support, crit}: what the skill does to one target, split into the
	## damage it deals (DoTs too) and everything else.
	func _target_value(skill: SkillDef, target: Combatant) -> Dictionary:
		var preview := battle.preview(actor, skill, target)
		var hit: float = preview.hit_chance
		var crit: float = preview.crit_chance
		var foe := target.is_hero != actor.is_hero
		var damage := 0.0
		var support := 0.0
		if skill.deals_damage() and foe:
			damage += _damage_value(skill, target, preview)
			if skill.can_be_riposted and target.has_token(Tokens.RIPOSTE) and target.def.riposte_skill:
				damage -= hit_of(target) * 0.7
		if skill.heals() and not foe and (skill.heal_below >= 1.0 or target.hp_fraction() < skill.heal_below):
			var healed: float = (preview.heal_min + preview.heal_max) / 2.0 * (1.0 + crit * (Rules.HEAL_CRIT_MULTIPLIER - 1.0))
			support += _heal_value(target, healed)
		if skill.stress != 0 and not foe:
			support += _relief_value(target, -skill.stress)
		var pierce := Rules.SKILL_RANK_PIERCE * (actor.skill_rank(skill) - 1)
		for effect in skill.effects:
			if not _allowed(effect, skill, target):
				continue
			var odds := effect.chance * (crit if effect.on_crit_only else 1.0) * (hit if foe else 1.0)
			var worth := odds * _effect_value(effect, target, crit, pierce)
			if foe and effect.kind in [EffectDef.Kind.DOT, EffectDef.Kind.DAMAGE]:
				damage += worth
			else:
				support += worth
		return {damage = damage, support = support, crit = crit}

	## Whether an effect would apply, as Battle._effect_allowed decides: the
	## token it needs on `target` and the user, and enough tier tokens.
	## (Whether it needs a crit is weighed by the crit chance instead.)
	func _allowed(effect: EffectDef, skill: SkillDef, target: Combatant) -> bool:
		if effect.requires_target_token != &"" and not target.has_token(effect.requires_target_token):
			return false
		if effect.requires_user_token != &"" and actor.has_token(effect.requires_user_token) == effect.user_lacks:
			return false
		var tier := 0
		for token in skill.tier_tokens:
			tier += actor.token_count(token)
		return tier >= effect.min_tier

	func _damage_value(skill: SkillDef, target: Combatant, preview: Dictionary) -> float:
		var hit: float = preview.hit_chance
		var crit: float = preview.crit_chance
		var low: float = preview.damage_min
		var high: float = preview.damage_max
		var expected: float = hit * ((1.0 - crit) * (low + high) / 2.0 + crit * preview.crit_damage)
		if target.is_corpse:
			return 0.25 * minf(expected, target.hp)
		var danger: float = threat.get(target, 0.0)
		if target.deaths_door:
			# Each hit strips a Death Armor token, and the last one kills.
			var finishing := 1.0 if skill.execution >= target.death_armor else 0.4
			return hit * danger * 1.5 * finishing
		var kill := 0.0
		if high >= target.hp:
			kill = hit * (crit + (1.0 - crit) * clampf((high - target.hp + 1.0) / (high - low + 1.0), 0.0, 1.0))
		elif preview.crit_damage >= target.hp:
			kill = hit * crit
		# Enemies with Death Armor go to Death's Door instead of dying.
		var lasting := 0.4 if target.death_armor > 0 else 1.0
		var dealt := minf(expected, target.hp)
		# Every hit brings the kill closer: its share of the enemy's HP, of the turns it has left.
		var wear := dealt / maxf(1.0, target.max_hp) * danger * WEAR_ROUNDS
		# Killing the last enemy ends the fight, which is worth more than any cost of getting there.
		var ending := FIGHT_OVER if threat.size() == 1 and target in threat else 0.0
		return dealt + wear + kill * (danger + ending) * lasting

	func _heal_value(target: Combatant, amount: float) -> float:
		var missing := target.max_hp - target.hp
		if missing <= 0:
			return 0.0
		var urgency := 2.0 if target.deaths_door else 1.3 if target.hp_fraction() < 0.35 else 1.0
		return minf(amount, missing) * urgency

	## Stress taken off a hero, or with a negative `amount`, put on them (a cost).
	func _relief_value(target: Combatant, amount: float) -> float:
		if amount < 0.0:
			return amount * STRESS_HP
		if target.stress <= 0:
			return 0.0
		var urgency := 2.0 if target.stress >= 6 else 1.0
		return minf(amount, target.stress) * STRESS_HP * urgency

	## The chance an effect on an enemy gets past its resistance (allies never resist).
	func _lands(target: Combatant, kind: StringName, crit: float, pierce: float, ignore: bool) -> float:
		if target.is_hero == actor.is_hero or ignore or kind == &"":
			return 1.0
		var resist := target.resist(kind) - pierce - actor.stat(StringName("pierce_%s" % kind))
		return (1.0 - crit) * (1.0 - clampf(resist, 0.0, 1.0)) \
				+ crit * (1.0 - clampf(resist - Rules.CRIT_RESIST_PIERCE, 0.0, 1.0))

	func _effect_value(effect: EffectDef, target: Combatant, crit: float, pierce: float) -> float:
		var foe := target.is_hero != actor.is_hero
		match effect.kind:
			EffectDef.Kind.TOKEN:
				var pool: Array = effect.token_pool if not effect.token_pool.is_empty() else [effect.token]
				var total := 0.0
				for token: StringName in pool:
					total += _token_value(token, effect.stacks, target) \
							* _lands(target, Tokens.resist_of(token), crit, pierce, effect.ignore_resist)
				return total / pool.size()
			EffectDef.Kind.DOT:
				if not foe:
					return 0.0
				var damage := effect.amount * effect.duration * _lands(target, effect.dot, crit, pierce, effect.ignore_resist)
				return minf(damage, target.hp) * 0.9
			EffectDef.Kind.MOVE, EffectDef.Kind.SHUFFLE:
				return 0.2 * threat.get(target, 0.0) * _lands(target, &"move", crit, pierce, effect.ignore_resist) if foe else 0.0
			EffectDef.Kind.CLEANSE_DOTS:
				var left := 0.0
				for dot in target.dots:
					left += dot.amount * dot.turns
				return minf(left, target.hp) if not foe else 0.0
			EffectDef.Kind.CLEANSE_NEGATIVE:
				return _tokens_worth(target, Tokens.NEGATIVE) if not foe else 0.0
			EffectDef.Kind.CLEANSE_POSITIVE, EffectDef.Kind.REMOVE_TOKENS:
				var pool: Array[StringName] = effect.token_pool
				if effect.kind == EffectDef.Kind.CLEANSE_POSITIVE:
					pool = Tokens.POSITIVE
				return _tokens_worth(target, pool) * (1.0 if foe else -1.0)
			EffectDef.Kind.REMOVE_ONE, EffectDef.Kind.STEAL_ONE:
				var held := effect.token_pool.filter(func(t: StringName) -> bool: return target.has_token(t))
				return (_tokens_worth(target, effect.token_pool) / maxi(1, held.size())) * (1.0 if foe else -1.0)
			EffectDef.Kind.GUARD:
				# Guarding moves the hits onto the guard, so it only pays when the guard is the sturdier one.
				if target == actor:
					return 0.0
				var sturdier := actor.hp_fraction() - target.hp_fraction() \
						+ 0.25 * (actor.token_count(Tokens.BLOCK) + actor.token_count(Tokens.BLOCK_PLUS))
				return hit_odds(target) * incoming * mini(effect.stacks, 2) * maxf(0.0, sturdier) * 0.8
			EffectDef.Kind.BUFF:
				var odds := 1.0
				if foe and (effect.stat_amount < 0.0 or effect.stat == &"pull_each_turn"):
					odds = _lands(target, &"debuff", crit, pierce, effect.ignore_resist)
				return odds * _buff_value(effect.stat, effect.stat_amount, mini(effect.duration, LASTS), target)
			EffectDef.Kind.REGEN:
				return 0.0 if foe else _heal_value(target, effect.amount * effect.duration * 0.8)
			EffectDef.Kind.HEAL:
				return 0.0 if foe else _heal_value(target, effect.amount + effect.stat_amount * target.max_hp)
			EffectDef.Kind.DAMAGE:
				return minf(effect.amount, target.hp) if foe else -effect.amount
			EffectDef.Kind.STRESS:
				return 0.0 if foe else _relief_value(target, -effect.amount)
			EffectDef.Kind.EXTRA_TURN:
				return hit_of(target) if not foe else -threat.get(target, 0.0)
			EffectDef.Kind.CONSECRATE:
				return 1.5 * mini(effect.duration, LASTS)
			EffectDef.Kind.CONVERT:
				return 1.0
		return 0.0

	## What `stacks` more of a token on `target` are worth to the party: none
	## past its limit, less when it already has some.
	func _token_value(token: StringName, stacks: int, target: Combatant) -> float:
		var room := mini(stacks, Tokens.limit(token) - target.token_count(token))
		if room <= 0:
			return 0.0
		return _token_worth(token, target) * room * (0.6 if target.has_token(token) else 1.0)

	## What one stack of a token on `target` is worth to the party: negative
	## for good tokens on enemies and bad ones on heroes.
	func _token_worth(token: StringName, target: Combatant) -> float:
		var foe := target.is_hero != actor.is_hero
		var danger: float = threat.get(target, hit_of(target))
		var mine := hit_of(actor)
		var each := 0.0
		match token:
			Tokens.STUN:
				each = danger
			Tokens.DAZE:
				each = 0.25 * danger
			Tokens.BLIND, Tokens.WEAK:
				each = 0.5 * danger if foe else -0.5 * hit_of(target)
			Tokens.VULNERABLE:
				each = 0.5 * mine if foe else -0.5 * incoming * hit_odds(target)
			Tokens.COMBO:
				each = (0.4 if combo_users else 0.15) * mine
			Tokens.BLOCK, Tokens.DODGE:
				each = GUARD_SHARE * incoming * hit_odds(target)
			Tokens.BLOCK_PLUS, Tokens.DODGE_PLUS:
				each = 1.5 * GUARD_SHARE * incoming * hit_odds(target)
			Tokens.STEALTH:
				each = 0.6 * incoming * hit_odds(target)
			Tokens.STRENGTH:
				each = 0.5 * hit_of(target)
			Tokens.CRIT:
				each = 0.6 * hit_of(target)
			Tokens.RIPOSTE:
				each = 0.6 * hit_odds(target) * (hit_of(target) if target.def.riposte_skill else 0.0)
			Tokens.SPEED:
				each = 0.15 * hit_of(target)
			Tokens.TAUNT:
				if foe:
					return 0.0
				# Worth it on a sturdy hero, a liability on a frail one.
				var sturdy := target.hp_fraction() + 0.3 * (target.token_count(Tokens.BLOCK) + target.token_count(Tokens.BLOCK_PLUS))
				return incoming * 0.4 * (sturdy - 0.6)
			Tokens.IMMOBILIZE:
				each = 0.3
			_:
				each = 1.0
		if foe and not Tokens.is_negative(token) and token != Tokens.COMBO:
			return -absf(each)
		if not foe and Tokens.is_negative(token):
			return -absf(each)
		return each

	## What taking every stack of `pool`'s tokens off `target` is worth to the party.
	func _tokens_worth(target: Combatant, pool: Array[StringName]) -> float:
		var total := 0.0
		for token in pool:
			total += absf(_token_worth(token, target)) * target.token_count(token)
		return total

	func _buff_value(stat: StringName, amount: float, rounds: int, target: Combatant) -> float:
		var ally := target.is_hero == actor.is_hero
		var side := 1.0 if ally else -1.0
		var base: float = hit_of(target) if ally else threat.get(target, 0.0)
		var name := String(stat)
		var worth := 0.0
		match stat:
			&"damage":
				worth = amount * base
			&"crit":
				worth = amount * 0.5 * base
			&"speed":
				worth = amount * 0.05 * base
			&"damage_taken":
				return (-amount * incoming * hit_odds(target) if ally else amount * hit_of(actor)) * rounds
			&"heal_received", &"heal_power":
				worth = amount * 4.0
			_:
				if name.begins_with("resist_"):
					worth = amount * incoming * 0.3
				elif name.begins_with("pierce_"):
					worth = amount * base * 0.2
				else:
					worth = amount * 0.5
		return worth * side * rounds

	## The actor's own part: tokens and buffs on itself, its costs, and where a
	## move leaves it. `target` stands in for what the targets held, for self
	## effects that need a token on them.
	func _self_value(skill: SkillDef, crit: float, target: Combatant) -> float:
		var total := 0.0
		for effect in skill.self_effects:
			if not _allowed(effect, skill, target):
				continue
			total += effect.chance * (crit if effect.on_crit_only else 1.0) * _effect_value(effect, actor, 0.0, 0.0)
		if skill.self_heal_fraction > 0.0 and (skill.self_heal_below >= 1.0 or actor.hp_fraction() < skill.self_heal_below):
			total += _heal_value(actor, skill.self_heal_fraction * actor.max_hp)
		var cost := skill.self_damage + skill.self_damage_fraction * actor.max_hp
		if cost > 0.0:
			total -= cost * (2.0 if actor.hp_fraction() < 0.4 else 1.0)
		if skill.self_stress > 0:
			total -= skill.self_stress * STRESS_HP
		if skill.self_move != 0:
			var rank := battle.rank_of(actor)
			var after := clampi(rank - skill.self_move, 1, battle.side_of(actor).size())
			total += (_useful_from(actor, after) - _useful_from(actor, rank)) * 0.5 * hit_of(actor)
		return total

	## How many of a unit's skills would have something to do from `rank`: ally
	## and self skills, and attacks that reach a living enemy.
	func _useful_from(unit: Combatant, rank: int) -> int:
		var count := 0
		for skill in unit.skills:
			if rank not in skill.launch_ranks:
				continue
			if skill.side != SkillDef.TargetSide.ENEMY or battle.opponents_of(unit).any(func(foe: Combatant) -> bool:
					return foe.is_active() and battle.covers_rank(foe, skill.target_ranks)):
				count += 1
		return count

	## Swapping is worth the skills it brings into use for the two heroes, and costs a turn.
	func _swap_value(other: Combatant) -> float:
		var mine := battle.rank_of(actor)
		var theirs := battle.rank_of(other)
		var gain := _useful_from(actor, theirs) - _useful_from(actor, mine) \
				+ _useful_from(other, mine) - _useful_from(other, theirs)
		return gain * 0.5 * maxf(hit_of(actor), 1.0) - 1.0

	## Clearing a corpse brings the enemies behind it forward, and its neighbours take the skill's effects.
	func _corpse_value(skill: SkillDef, corpse: Combatant) -> float:
		var side := battle.side_of(corpse)
		var index := side.find(corpse)
		var total := 0.0
		for i in [index - 1, index + 1]:
			if i >= 0 and i < side.size() and side[i].is_active():
				for effect in skill.neighbor_effects:
					total += effect.chance * _effect_value(effect, side[i], 0.0, 0.0)
		return total

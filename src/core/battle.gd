## One fight between the party and an enemy group, following DD2's rules.
## Pure logic: no nodes, no timing, no drawing.
##
## Drive it with advance() until `state` is AWAITING_INPUT, then submit() the
## player's choice for `current`. Both return the events that happened, in
## order, for the presentation layer to play back. Every random roll comes from
## `rng`, so a seed plus the player's choices replays a fight exactly.
##
## Events are dictionaries with `type` and `uid` (the unit concerned, 0 for none):
##   round_start {round}            turn_start                    dazed / stunned
##   skill {skill, targets, crit, crit_roll, crit_chance, riposte}
##   miss {reason, roll, chance}    guarded {protected}           reposition / pass
##   damage {amount, hp, crit, cause, base, attack_mod, defense_mod, weak}
##   heal {amount, hp, crit}        stress {amount, stress}       stress_resisted {roll, chance}
##   token {token, added, negated}  token_expired {token}         resisted {what, roll, chance}
##   dot_applied {dot, amount, turns}   cleansed {what}           immobile
##   moved {rank}                   deaths_door                   left_deaths_door
##   deathblow_resisted {roll, chance}  deathblow {roll, chance}  death_armor {remaining}
##   death {corpse, hp}             removed {reason}              meltdown {hp, stress} / resolute
##   battle_end {victory}
class_name Battle
extends RefCounted

enum State { RUNNING, AWAITING_INPUT, VICTORY, DEFEAT }

var state := State.RUNNING
var round_number := 0
## Index 0 stands in rank 1. Corpses keep their slot until they decay or are destroyed.
var heroes: Array[Combatant] = []
var enemies: Array[Combatant] = []
## The unit whose turn it is, or null between turns.
var current: Combatant
var rng: RandomNumberGenerator
## [helper, helped] for each skill a hero used on another hero, in order. The
## campaign turns them into bond points.
var helps: Array[Array] = []

## The Vestal's consecrated hero ranks: rank -> {name, tokens (one is gained at
## each turn start by whoever stands there), rounds left}.
var consecrations: Dictionary = {}

## Remaining turns this round: {unit: Combatant, delayed: bool, extra: bool}.
## An extra turn (Encore) skips the turn-start effects and DoTs.
var _queue: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _used_this_turn: StringName
## The unit acting first this round, for "If First in Turn Order" triggers.
var _first_this_round: Combatant
## How deep triggers are firing other triggers; capped so they can't loop.
var _trigger_depth := 0


func _init(party: Array[Combatant], foes: Array[Combatant], random: RandomNumberGenerator) -> void:
	heroes.assign(party)
	enemies.assign(foes)
	rng = random


# --- Driving the battle ---

## Plays out turns until something happened: a round started, a turn was
## skipped or taken by an enemy, or a hero needs the player's input.
func advance() -> Array[Dictionary]:
	_events = []
	while state == State.RUNNING and _events.is_empty():
		if _queue.is_empty():
			if round_number > 0:
				_end_round()
			_start_round()
		else:
			_take_turn(_queue.pop_front())
	return _events


## Resolves the current hero's chosen skill. Invalid choices are refused with no events.
func submit(skill: SkillDef, target: Combatant) -> Array[Dictionary]:
	_events = []
	if state != State.AWAITING_INPUT:
		push_error("Battle.submit called while not awaiting input")
		return _events
	if not can_use(current, skill) or target not in targets_for(current, skill):
		push_error("Invalid choice: %s on %s" % [skill.id, target.display_name if target else "nothing"])
		return _events
	state = State.RUNNING
	var actor := current
	_use_skill(actor, skill, target)
	_end_turn(actor)
	return _events


# --- Queries for the UI and the AI ---

func all_units() -> Array[Combatant]:
	var units: Array[Combatant] = []
	units.append_array(heroes)
	units.append_array(enemies)
	return units


func side_of(unit: Combatant) -> Array[Combatant]:
	return heroes if unit.is_hero else enemies


func opponents_of(unit: Combatant) -> Array[Combatant]:
	return enemies if unit.is_hero else heroes


## Front rank a unit occupies (1-4), or -1 if it is no longer on the field.
func rank_of(unit: Combatant) -> int:
	var rank := 1
	for other in side_of(unit):
		if other == unit:
			return rank
		rank += other.size
	return -1


func covers_rank(unit: Combatant, ranks: Array[int]) -> bool:
	var first := rank_of(unit)
	if first < 0:
		return false
	for rank in range(first, first + unit.size):
		if rank in ranks:
			return true
	return false


## Units still to act this round, in order, starting with the one acting now.
func turn_order() -> Array[Combatant]:
	var order: Array[Combatant] = []
	if current:
		order.append(current)
	for entry in _queue:
		var unit: Combatant = entry.unit
		if unit.is_active():
			order.append(unit)
	return order


## Every action the unit could take this turn, usable or not.
func actions_for(unit: Combatant) -> Array[SkillDef]:
	var actions: Array[SkillDef] = []
	actions.assign(unit.skills)
	if unit.is_hero:
		actions.append(BasicSkills.swap)
		if can_use(unit, BasicSkills.recover):
			actions.append(BasicSkills.recover)
		actions.append(BasicSkills.pass_turn)
	return actions


func can_use(unit: Combatant, skill: SkillDef) -> bool:
	if not unit.is_active():
		return false
	if unit.cooldown_left(skill) > 0 or unit.uses_left(skill) <= 0:
		return false
	if skill.kind == SkillDef.Kind.ACTION and not covers_rank(unit, skill.launch_ranks):
		return false
	if not _condition_met(unit, skill):
		return false
	return not targets_for(unit, skill).is_empty()


## Units the player (or AI) may pick as the primary target. For multi-target
## skills, picking any of them hits all units in the skill's target ranks.
func targets_for(unit: Combatant, skill: SkillDef) -> Array[Combatant]:
	var result: Array[Combatant] = []
	match skill.kind:
		SkillDef.Kind.PASS:
			result.append(unit)
		SkillDef.Kind.SWAP:
			if unit.has_token(Tokens.IMMOBILIZE):
				return result
			var side := side_of(unit)
			var index := side.find(unit)
			for offset in unit.def.swap_offsets:
				var other_index := index + offset
				if other_index >= 0 and other_index < side.size() \
						and not side[other_index].has_token(Tokens.IMMOBILIZE):
					result.append(side[other_index])
		SkillDef.Kind.ACTION:
			match skill.side:
				SkillDef.TargetSide.SELF:
					result.append(unit)
				SkillDef.TargetSide.ALLY:
					for ally in side_of(unit):
						if ally.is_active() and covers_rank(ally, skill.target_ranks) \
								and (skill.can_target_self or ally != unit) and _target_condition_met(ally, skill):
							result.append(ally)
				SkillDef.TargetSide.ENEMY:
					for foe in opponents_of(unit):
						if skill.targets_corpse and not foe.is_corpse:
							continue
						if covers_rank(foe, skill.target_ranks) and _target_condition_met(foe, skill):
							result.append(foe)
					if not skill.multi_target and not skill.targets_corpse:
						var sees_stealth := Tokens.STEALTH in _ignored_tokens(unit, skill, _tier_count(unit, skill))
						result = _apply_stealth_and_taunt(result, sees_stealth)
	return result


## What the UI shows before committing: hit and crit chance, damage and heal ranges.
func preview(actor: Combatant, skill: SkillDef, target: Combatant) -> Dictionary:
	var result := {
		hit_chance = 1.0, crit_chance = 0.0,
		damage_min = 0, damage_max = 0, crit_damage = 0,
		heal_min = 0, heal_max = 0,
	}
	if skill.kind != SkillDef.Kind.ACTION or skill.targets_corpse:
		return result
	var tier := _tier_count(actor, skill)
	var ignored := _ignored_tokens(actor, skill, tier)
	if skill.is_attack():
		if actor.has_token(Tokens.BLIND):
			result.hit_chance *= 1.0 - Rules.BLIND_MISS_CHANCE
		if target.has_token(Tokens.DODGE_PLUS) and Tokens.DODGE_PLUS not in ignored:
			result.hit_chance *= 1.0 - Rules.DODGE_PLUS_CHANCE
		elif target.has_token(Tokens.DODGE) and not target.has_token(Tokens.DODGE_PLUS) and Tokens.DODGE not in ignored:
			result.hit_chance *= 1.0 - Rules.DODGE_CHANCE
	if skill.damage_from_dots > 0.0:
		var left := 0.0
		for dot in target.dots:
			left += dot.amount * dot.turns
		result.damage_min = maxi(1, roundi(left * skill.damage_from_dots))
		result.damage_max = result.damage_min
		return result
	var can_crit := skill.deals_damage() or skill.heals()
	result.crit_chance = 1.0 if can_crit and actor.has_token(Tokens.CRIT) else _crit_chance(actor, skill, target)
	if result.crit_chance > 0.0 and skill.combo_crit_bonus > 0.0 and target.has_token(Tokens.COMBO):
		result.crit_chance = minf(1.0, result.crit_chance + skill.combo_crit_bonus)
	if skill.deals_damage():
		var combo := skill.combo_damage_bonus if target.has_token(Tokens.COMBO) else 0.0
		var scale := _attack_mod(actor, skill, actor.has_token(Tokens.STRENGTH), combo + _tier_value(skill.tier_damage, tier),
				target) \
				* maxf(_defense_mod(target, false, ignored), 0.0) \
				* (Rules.WEAK_MULTIPLIER if actor.has_token(Tokens.WEAK) else 1.0)
		result.damage_min = maxi(1, roundi(skill.damage_min * scale))
		result.damage_max = maxi(1, roundi(skill.damage_max * scale))
		result.crit_damage = maxi(1, roundi(skill.damage_max * Rules.CRIT_DAMAGE_MULTIPLIER * scale))
	if skill.heals():
		var share := skill.heal_fraction if skill.tier_heal.is_empty() else _tier_value(skill.tier_heal, tier)
		var bonus := share * target.max_hp
		var power := _skill_power(actor, skill)
		result.heal_min = roundi((skill.heal_min + bonus) * power)
		result.heal_max = roundi((skill.heal_max + bonus) * power)
	return result


# --- Rounds and turns ---

func _start_round() -> void:
	round_number += 1
	if round_number == 1:
		for unit in all_units():
			_fire(unit, TrinketTrigger.When.COMBAT_START)
	var order: Array[Dictionary] = []
	for unit in all_units():
		if not unit.is_active():
			continue
		var bonus := Rules.SPEED_TOKEN_BONUS if unit.speed_bonus_next_round else 0
		unit.speed_bonus_next_round = false
		for turn in unit.def.turns_per_round:
			order.append({
				unit = unit,
				delayed = false,
				key = unit.speed() + bonus + rng.randi_range(0, Rules.ROUND_SPEED_ROLL_MAX)
						- turn * Rules.EXTRA_TURN_SPEED_PENALTY,
				tie = rng.randf(),
			})
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.key > b.key or (a.key == b.key and a.tie > b.tie))
	_separate_repeat_turns(order)
	_queue = order
	_first_this_round = order[0].unit if not order.is_empty() else null
	_emit(&"round_start", null, {round = round_number})
	for unit in all_units():
		if unit.is_active():
			_fire(unit, TrinketTrigger.When.ROUND_START)


## DD2 never gives a unit two turns in a row from the normal initiative order.
## A repeat swaps with the next different turn, or failing that the previous one.
func _separate_repeat_turns(order: Array[Dictionary]) -> void:
	for i in range(1, order.size()):
		var unit: Combatant = order[i].unit
		if unit != order[i - 1].unit:
			continue
		var moved := i
		var other := -1
		for j in range(i + 1, order.size()):
			if order[j].unit != unit:
				other = j
				break
		if other < 0 and i >= 2 and order[i - 2].unit != unit:
			moved = i - 1
			other = i - 2
		if other >= 0:
			var swap := order[moved]
			order[moved] = order[other]
			order[other] = swap


func _end_round() -> void:
	for unit in all_units():
		if unit.is_active():
			_fire(unit, TrinketTrigger.When.ROUND_END)
	for unit in all_units():
		if unit.is_active():
			if unit.has_token(Tokens.SPEED):
				unit.remove_token(Tokens.SPEED, unit.token_count(Tokens.SPEED))
				unit.speed_bonus_next_round = true
			unit.tick_round_buffs()
		elif unit.is_corpse:
			unit.corpse_rounds -= 1
			if unit.corpse_rounds <= 0:
				_remove_unit(unit, &"decayed")
	for rank: int in consecrations.keys():
		consecrations[rank].rounds -= 1
		if consecrations[rank].rounds <= 0:
			consecrations.erase(rank)


func _take_turn(entry: Dictionary) -> void:
	var unit: Combatant = entry.unit
	if not unit.is_active():
		return
	var extra: bool = entry.get("extra", false)
	if unit.has_token(Tokens.DAZE) and not entry.delayed and not extra:
		unit.remove_token(Tokens.DAZE)
		_emit(&"dazed", unit)
		_queue.append({unit = unit, delayed = true})
		return
	current = unit
	_emit(&"turn_start", unit)
	if not extra:
		unit.remove_buffs(Combatant.BuffExpiry.TURN_START)
		_turn_start_effects(unit)
		_tick_dots(unit)
	if not unit.is_active() or state != State.RUNNING:
		current = null
		return
	if unit.consume_token(Tokens.STUN):
		_emit(&"stunned", unit)
		unit.add_buff(&"resist_stun", Rules.STUN_RECOVERY_RESIST, Combatant.BuffExpiry.TURN_START)
		_end_turn(unit)
		return
	if unit.is_hero:
		state = State.AWAITING_INPUT
		return
	_enemy_act(unit)
	_end_turn(unit)


## Class tokens gained each turn (the Vestal's Conviction), tokens from timed
## "gain_<token>" buffs, a consecrated rank's token, and timed pulls.
func _turn_start_effects(unit: Combatant) -> void:
	for token: StringName in unit.def.turn_start_tokens:
		_give_token(unit, token, unit.def.turn_start_tokens[token])
	for buff in unit.buffs.duplicate():
		if String(buff.stat).begins_with("gain_"):
			_give_token(unit, StringName(String(buff.stat).trim_prefix("gain_")), roundi(buff.amount))
	if unit.is_hero and consecrations.has(rank_of(unit)):
		var tokens: Array = consecrations[rank_of(unit)].tokens
		_give_token(unit, tokens[rng.randi_range(0, tokens.size() - 1)], 1)
	var pull := roundi(unit.stat(&"pull_each_turn"))
	if pull != 0 and not unit.has_token(Tokens.IMMOBILIZE):
		_move(unit, pull)
	_fire(unit, TrinketTrigger.When.TURN_START)


func _end_turn(unit: Combatant) -> void:
	if unit.is_active() and state == State.RUNNING:
		_fire(unit, TrinketTrigger.When.TURN_END)
	if unit.is_active() and state == State.RUNNING and unit.has_token(Tokens.PAIN):
		# Pain heals the Flagellant at his turn end, then it is gone. It can't crit.
		_heal(unit, roundi(unit.max_hp * Rules.PAIN_HEAL * unit.token_count(Tokens.PAIN)), false)
		unit.remove_token(Tokens.PAIN, unit.token_count(Tokens.PAIN))
	if unit.is_active() and state == State.RUNNING:
		unit.tick_cooldowns(_used_this_turn)
		for token in unit.tick_tokens_turn_end():
			_emit(&"token_expired", unit, {token = token})
	_used_this_turn = &""
	current = null


## DoT damage, then Regen healing, at the holder's turn start.
func _tick_dots(unit: Combatant) -> void:
	var total := unit.dot_total()
	if total > 0:
		var cause := &"bleed"
		for type: StringName in [&"blight", &"burn"]:
			if unit.dot_total(type) > unit.dot_total(cause):
				cause = type
		unit.tick_dots()
		_damage(unit, {amount = total, cause = cause})
	if unit.regens.is_empty() or not unit.is_active():
		return
	var regen := 0
	for entry in unit.regens:
		regen += entry.amount
		entry.turns -= 1
	unit.regens.assign(unit.regens.filter(func(entry: Dictionary) -> bool: return entry.turns > 0))
	_heal(unit, regen, false)


func _enemy_act(unit: Combatant) -> void:
	var choice := EnemyAI.choose(self, unit)
	if not choice.is_empty():
		_use_skill(unit, choice.skill, choice.target)
		return
	# Nothing usable: step towards the nearest rank some skill launches from.
	var rank := rank_of(unit)
	var nearest := 0
	for skill in unit.skills:
		for launch in skill.launch_ranks:
			if nearest == 0 or absi(launch - rank) < absi(nearest - rank):
				nearest = launch
	if nearest != 0 and nearest != rank and not unit.has_token(Tokens.IMMOBILIZE):
		_emit(&"reposition", unit)
		_move(unit, 1 if nearest < rank else -1)
	else:
		_emit(&"pass", unit)


# --- Using skills ---

func _use_skill(actor: Combatant, skill: SkillDef, target: Combatant) -> void:
	_used_this_turn = skill.id
	if skill.cooldown > 0:
		actor.cooldowns[skill.id] = skill.cooldown
	if skill.uses_per_battle > 0:
		actor.uses[skill.id] = actor.uses.get(skill.id, 0) + 1
	match skill.kind:
		SkillDef.Kind.SWAP:
			_emit(&"skill", actor, {skill = skill, targets = [target.uid]})
			_swap(actor, target)
		SkillDef.Kind.PASS:
			_emit(&"skill", actor, {skill = skill, targets = [actor.uid]})
			_add_stress(actor, Rules.PASS_STRESS)
		SkillDef.Kind.ACTION:
			_resolve(actor, skill, target, false)
	_check_end()


func _resolve(actor: Combatant, skill: SkillDef, primary: Combatant, is_riposte: bool) -> void:
	if skill.targets_corpse:
		_resolve_on_corpse(actor, skill, primary)
		return
	var targets := _affected(actor, skill, primary)
	var attack := skill.is_attack()
	var damaging := skill.deals_damage()
	# Damage from the target's DoTs (Cause of Death) ignores tokens and crits.
	var rolled := damaging and skill.damage_from_dots <= 0.0
	var tier := _tier_count(actor, skill)
	var ignored := _ignored_tokens(actor, skill, tier)

	# A Crit token guarantees a crit on the next attack or heal.
	var crit := false
	var crit_roll := -1.0
	var crit_chance := _crit_chance(actor, skill, primary) if rolled or not damaging else 0.0
	if crit_chance > 0.0 and skill.combo_crit_bonus > 0.0 and primary.has_token(Tokens.COMBO):
		crit_chance += skill.combo_crit_bonus
	var pierce := Rules.SKILL_RANK_PIERCE * (actor.skill_rank(skill) - 1)
	if (rolled or skill.heals()) and actor.consume_token(Tokens.CRIT):
		crit = true
		crit_chance = 1.0
	elif crit_chance > 0.0:
		crit_roll = rng.randf()
		crit = crit_roll < crit_chance
	# Blind is rolled once per skill use; Strength and Weak are spent even on a miss.
	var blind_roll := rng.randf() if attack and actor.consume_token(Tokens.BLIND) else -1.0
	var strength := rolled and actor.consume_token(Tokens.STRENGTH)
	var weak := rolled and actor.consume_token(Tokens.WEAK)

	_emit(&"skill", actor, {
		skill = skill, targets = targets.map(func(t: Combatant) -> int: return t.uid),
		crit = crit, crit_roll = crit_roll, crit_chance = crit_chance, riposte = is_riposte,
	})
	if actor.is_hero:
		for target in targets:
			if target.is_hero and target != actor:
				helps.append([actor, target])

	var hit_living := false
	var hits := 0
	var killed := false
	# Tokens the targets held as the skill reached them, before it ends their Combo.
	var held: Dictionary = {}
	var crit_victims: Array[Combatant] = []
	var riposter: Combatant = null
	for aimed_at in targets:
		if state != State.RUNNING:
			break
		var target := aimed_at
		if attack and not skill.multi_target:
			target = _redirect_guard(aimed_at, Tokens.GUARD in ignored)
			if target.has_token(Tokens.TAUNT):
				target.remove_token(Tokens.TAUNT)
		if attack and _misses(target, blind_roll, ignored):
			_fire(actor, TrinketTrigger.When.ON_MISS, target, skill)
			_fire(target, TrinketTrigger.When.WHEN_MISSED, actor, skill)
			continue
		if target.is_active():
			hit_living = true
			hits += 1
		var tokens := target.tokens.duplicate()
		held.merge(tokens)
		var target_pierce := pierce + (skill.combo_pierce if tokens.has(Tokens.COMBO) else 0.0)
		var consumed_combo := false
		if damaging:
			var combo := 0.0
			if skill.combo_damage_bonus > 0.0 and target.consume_token(Tokens.COMBO):
				combo = skill.combo_damage_bonus
				consumed_combo = true
			var was_active := target.is_active()
			var was_corpse := target.is_corpse
			_damage(target, _roll_damage(actor, skill, target, crit, strength, weak, combo, tier, ignored))
			# Destroying a corpse counts as a kill, as in DD2 since v2.02.
			killed = killed or (was_active and target.dead) or (was_corpse and not target.is_corpse)
			if attack:
				_toxic_backlash(actor, target)
		if skill.heals() and target.is_active() and (skill.heal_below >= 1.0 or target.hp_fraction() < skill.heal_below):
			_heal(target, _roll_heal(actor, skill, target, crit, tier), crit)
		if skill.stress != 0:
			_add_stress(target, skill.stress)
		for effect in skill.effects:
			if _effect_allowed(effect, actor, crit, tokens, tier):
				_apply_effect(actor, target, effect, crit, consumed_combo, target_pierce)
		if skill.ends_combo and target.has_token(Tokens.COMBO):
			target.remove_token(Tokens.COMBO)
		if attack:
			_fire(actor, TrinketTrigger.When.ON_HIT, target, skill)
			if target.is_active():
				_fire(target, TrinketTrigger.When.WHEN_HIT, actor, skill)
		if crit:
			_fire(actor, TrinketTrigger.When.ON_CRIT, target, skill)
		if crit and attack and target.is_hero and target.is_active():
			crit_victims.append(target)
		if riposter == null and not is_riposte and attack and damaging and skill.can_be_riposted \
				and target.is_active() and target.has_token(Tokens.RIPOSTE) and target.def.riposte_skill:
			riposter = target

	# Even the fight's last kill relieves stress, which outlasts the fight.
	if skill.kill_stress != 0 and killed:
		_add_stress(actor, skill.kill_stress)
	if state != State.RUNNING:
		return
	if not is_riposte:
		_fire_skill(actor, skill, targets)
	if actor.is_active():
		_self_part(actor, skill, crit, held, tier)
		if skill.self_heal_per_hit > 0.0 and hits > 0:
			_self_heal(actor, skill.self_heal_per_hit * hits)
		if skill.combo_self_heal > 0.0 and held.has(Tokens.COMBO):
			_self_heal(actor, skill.combo_self_heal)
	if skill.clears_corpses:
		_clear_corpses(opponents_of(actor))
	if crit and hit_living:
		_crit_stress(actor, crit_victims)
	if riposter and actor.is_active() and riposter.is_active() and state == State.RUNNING:
		riposter.consume_token(Tokens.RIPOSTE)
		_resolve(riposter, riposter.def.riposte_skill, actor, true)


## What the skill does to its user once the targets are dealt with: moving
## first (so a skill can move and then root its user), then its own effects,
## stress, healing and costs, and spending its tier tokens.
func _self_part(actor: Combatant, skill: SkillDef, crit: bool, held: Dictionary, tier: int) -> void:
	if skill.self_move != 0:
		_move(actor, skill.self_move)
	for effect in skill.self_effects:
		if _effect_allowed(effect, actor, crit, held, tier):
			_apply_effect(actor, actor, effect, false, false)
	if skill.self_stress != 0:
		_add_stress(actor, skill.self_stress)
	if skill.self_heal_fraction > 0.0 and (skill.self_heal_below >= 1.0 or actor.hp_fraction() < skill.self_heal_below):
		_self_heal(actor, skill.self_heal_fraction)
	_hurt_self(actor, skill.self_damage + roundi(actor.max_hp * skill.self_damage_fraction))
	if skill.tier_spend_from > 0 and tier >= skill.tier_spend_from:
		for token in skill.tier_tokens:
			actor.remove_token(token, actor.token_count(token))


func _self_heal(actor: Combatant, share: float) -> void:
	_heal(actor, roundi(share * actor.max_hp * maxf(0.0, 1.0 + actor.stat(&"heal_received"))), false)


## A skill aimed at an enemy corpse (Dead of Night, Fester) clears it; its
## neighbour effects reach the units just in front of and behind it, and the
## user's own part follows.
func _resolve_on_corpse(actor: Combatant, skill: SkillDef, corpse: Combatant) -> void:
	_emit(&"skill", actor, {skill = skill, targets = [corpse.uid], crit = false, crit_roll = -1.0, crit_chance = 0.0,
			riposte = false})
	var side := side_of(corpse)
	var index := side.find(corpse)
	var neighbors: Array[Combatant] = []
	for i in [index - 1, index + 1]:
		if i >= 0 and i < side.size() and side[i].is_active():
			neighbors.append(side[i])
	_remove_unit(corpse, &"destroyed")
	for unit in neighbors:
		for effect in skill.neighbor_effects:
			_apply_effect(actor, unit, effect, false, false)
	if actor.is_active():
		_self_part(actor, skill, false, {}, _tier_count(actor, skill))


func _clear_corpses(side: Array[Combatant]) -> void:
	for unit in side.duplicate():
		if unit.is_corpse:
			_remove_unit(unit, &"destroyed")


## Whether an effect's conditions hold: a crit, a token the target held, the
## user holding or lacking a token, enough tier tokens.
func _effect_allowed(effect: EffectDef, actor: Combatant, crit: bool, target_tokens: Dictionary, tier: int) -> bool:
	if effect.on_crit_only and not crit:
		return false
	if effect.requires_target_token != &"" and target_tokens.get(effect.requires_target_token, 0) <= 0:
		return false
	if effect.requires_user_token != &"" and actor.has_token(effect.requires_user_token) == effect.user_lacks:
		return false
	return tier >= effect.min_tier


## How many of the skill's tier tokens the user holds (the Vestal's Conviction).
func _tier_count(actor: Combatant, skill: SkillDef) -> int:
	var count := 0
	for token in skill.tier_tokens:
		count += actor.token_count(token)
	return count


## Target tokens this use of the skill ignores: its own list, more while the
## user holds Stealth, and more at enough tier tokens.
func _ignored_tokens(actor: Combatant, skill: SkillDef, tier: int) -> Array[StringName]:
	var result: Array[StringName] = skill.ignore_tokens.duplicate()
	if actor.has_token(Tokens.STEALTH):
		result.append_array(skill.ignore_tokens_if_stealthed)
	if skill.tier_ignore_from > 0 and tier >= skill.tier_ignore_from:
		result.append_array(skill.tier_ignore_tokens)
	return result


# --- Trinket triggers ---

## Runs the unit's trinket triggers for `when`. `other` is the event's other
## unit (who was hit or missed, the attacker, who moved it), `skill` the skill
## involved, `resist` what was resisted.
func _fire(unit: Combatant, when: TrinketTrigger.When, other: Combatant = null, skill: SkillDef = null,
		resist: StringName = &"") -> void:
	if unit.triggers.is_empty() or _trigger_depth > 2 or state != State.RUNNING:
		return
	_trigger_depth += 1
	for trigger in unit.triggers:
		if trigger.when == when and _trigger_holds(unit, trigger, other, skill, resist):
			for recipient in _recipients(unit, trigger, other):
				_trigger_effects(unit, recipient, trigger)
	_trigger_depth -= 1


## "Target: <skill>" and "Self: <skill>" lines: those for the skill's target
## reach each target, the rest fire once.
func _fire_skill(actor: Combatant, skill: SkillDef, targets: Array[Combatant]) -> void:
	if actor.triggers.is_empty() or _trigger_depth > 2:
		return
	_trigger_depth += 1
	for trigger in actor.triggers:
		if trigger.when != TrinketTrigger.When.ON_SKILL:
			continue
		if trigger.to == TrinketTrigger.To.OTHER:
			for target in targets:
				if _trigger_holds(actor, trigger, target, skill, &""):
					_trigger_effects(actor, target, trigger)
		elif _trigger_holds(actor, trigger, targets[0] if not targets.is_empty() else null, skill, &""):
			for recipient in _recipients(actor, trigger, null):
				_trigger_effects(actor, recipient, trigger)
	_trigger_depth -= 1


func _trigger_holds(unit: Combatant, trigger: TrinketTrigger, other: Combatant, skill: SkillDef,
		resist: StringName) -> bool:
	if trigger.if_rank > 0 and rank_of(unit) != trigger.if_rank:
		return false
	if trigger.if_token != &"" and unit.has_status(trigger.if_token) == trigger.lacks:
		return false
	if trigger.if_first and _first_this_round != unit:
		return false
	if trigger.if_speed_at_most > 0 and unit.speed() > trigger.if_speed_at_most:
		return false
	if trigger.if_speed_at_least > 0 and unit.speed() < trigger.if_speed_at_least:
		return false
	if not trigger.if_skills.is_empty() and (skill == null or skill.id not in trigger.if_skills):
		return false
	if trigger.if_ally_target and (other == null or other == unit or other.is_hero != unit.is_hero):
		return false
	return trigger.if_resist == &"" or trigger.if_resist == resist


func _recipients(unit: Combatant, trigger: TrinketTrigger, other: Combatant) -> Array[Combatant]:
	var result: Array[Combatant] = []
	var side := side_of(unit)
	var index := side.find(unit)
	match trigger.to:
		TrinketTrigger.To.SELF:
			result.append(unit)
		TrinketTrigger.To.OTHER:
			if other and other.is_active():
				result.append(other)
		TrinketTrigger.To.EACH_ALLY:
			result.assign(side.filter(func(ally: Combatant) -> bool: return ally.is_active()))
		TrinketTrigger.To.ALLIES_BEHIND:
			result.assign(side.slice(index + 1).filter(func(ally: Combatant) -> bool: return ally.is_active()))
		TrinketTrigger.To.ALLY_BEHIND:
			if index + 1 < side.size() and side[index + 1].is_active():
				result.append(side[index + 1])
		TrinketTrigger.To.RANDOM_ALLY:
			var others := side.filter(func(ally: Combatant) -> bool: return ally != unit and ally.is_active())
			if not others.is_empty():
				result.append(others[rng.randi_range(0, others.size() - 1)])
	return result


## Each effect rolls its own chance; "X or Y" lines stop at the first that lands.
func _trigger_effects(unit: Combatant, recipient: Combatant, trigger: TrinketTrigger) -> void:
	for effect in trigger.effects:
		if effect.chance < 1.0 and rng.randf() >= effect.chance:
			continue
		_apply_effect(unit, recipient, effect, false, false, 0.0, false)
		if trigger.pick_one:
			break


## The Flagellant's Toxic tokens Blight whoever hits him: 2 per token, 3 turns.
func _toxic_backlash(attacker: Combatant, target: Combatant) -> void:
	var toxic := target.token_count(Tokens.TOXIC)
	if toxic <= 0 or attacker == target or not attacker.is_active():
		return
	if _resisted(target, attacker, &"blight", false, false, &"blight"):
		return
	var amount := toxic * Rules.TOXIC_BLIGHT_PER_TOKEN
	attacker.dots.append({type = &"blight", amount = amount, turns = Rules.DOT_DURATION})
	_emit(&"dot_applied", attacker, {dot = &"blight", amount = amount, turns = Rules.DOT_DURATION})


## Units a skill affects once `primary` is chosen.
func _affected(actor: Combatant, skill: SkillDef, primary: Combatant) -> Array[Combatant]:
	var result: Array[Combatant] = []
	if skill.multi_target and skill.side != SkillDef.TargetSide.SELF:
		var pool := opponents_of(actor) if skill.side == SkillDef.TargetSide.ENEMY else side_of(actor)
		for unit in pool:
			if covers_rank(unit, skill.target_ranks) and (skill.side == SkillDef.TargetSide.ENEMY or unit.is_active()) \
					and _target_condition_met(unit, skill):
				result.append(unit)
	else:
		result.append(primary)
	return result


func _crit_chance(actor: Combatant, skill: SkillDef, target: Combatant = null) -> float:
	var rank_bonus := Rules.SKILL_RANK_CRIT * (actor.skill_rank(skill) - 1)
	if skill.heals() and not skill.deals_damage():
		return Rules.HEAL_CRIT_CHANCE + rank_bonus
	if not skill.deals_damage() and skill.crit_chance <= 0.0:
		return 0.0
	return skill.crit_chance + actor.crit_bonus + actor.stat(&"crit", target, skill) + rank_bonus


## Damage or healing multiplier from the skill's rank.
func _skill_power(actor: Combatant, skill: SkillDef) -> float:
	return 1.0 + Rules.SKILL_RANK_POWER * (actor.skill_rank(skill) - 1)


## A skill that ignores Guard still spends a Guard stack, as in DD2.
func _redirect_guard(target: Combatant, ignore: bool = false) -> Combatant:
	var guardian := target.guarded_by
	if guardian == null or not guardian.is_active() or not target.has_token(Tokens.GUARD):
		return target
	target.remove_token(Tokens.GUARD)
	if ignore:
		return target
	_emit(&"guarded", guardian, {protected = target.uid})
	return guardian


## Blind (attacker, rolled once per skill use) then Dodge+ / Dodge (target).
## Dodge tokens are spent whether or not they work, or ignored ones.
func _misses(target: Combatant, blind_roll: float, ignored: Array[StringName] = []) -> bool:
	if blind_roll >= 0.0 and blind_roll < Rules.BLIND_MISS_CHANCE:
		_emit(&"miss", target, {reason = &"blind", roll = blind_roll, chance = Rules.BLIND_MISS_CHANCE})
		return true
	var token := Tokens.DODGE_PLUS if target.has_token(Tokens.DODGE_PLUS) else Tokens.DODGE
	if not target.has_token(token):
		return false
	target.remove_token(token)
	if token in ignored:
		return false
	var chance := Rules.DODGE_PLUS_CHANCE if token == Tokens.DODGE_PLUS else Rules.DODGE_CHANCE
	var roll := rng.randf()
	if roll < chance:
		_emit(&"miss", target, {reason = &"dodge", roll = roll, chance = chance})
		return true
	return false


## DD2 damage: base roll (max x1.5 on a crit) x attacker mods x defender mods,
## then Weak halves it last. Block/Block+ and Vulnerable are spent on the hit.
## A skill dealing a share of the target's DoTs skips all of that.
func _roll_damage(actor: Combatant, skill: SkillDef, target: Combatant, crit: bool, strength: bool,
		weak: bool, combo: float, tier: int = 0, ignored: Array[StringName] = []) -> Dictionary:
	if skill.damage_from_dots > 0.0:
		var left := 0.0
		for dot in target.dots:
			left += dot.amount * dot.turns
		return {amount = maxi(1, roundi(left * skill.damage_from_dots)), crit = false, execution = skill.execution,
				cause = &"hit", base = left, attack_mod = 1.0, defense_mod = 1.0, weak = false}
	var base: float
	if crit:
		base = skill.damage_max * Rules.CRIT_DAMAGE_MULTIPLIER
	else:
		base = rng.randi_range(skill.damage_min, skill.damage_max)
	base += actor.stat(&"damage_flat", target, skill)
	var attack_mod := _attack_mod(actor, skill, strength, combo + _tier_value(skill.tier_damage, tier), target)
	var defense_mod := _defense_mod(target, true, ignored)
	var amount := base * attack_mod * maxf(defense_mod, 0.0)
	if weak:
		amount *= Rules.WEAK_MULTIPLIER
	return {
		amount = maxi(1, roundi(amount)), crit = crit, execution = skill.execution, cause = &"hit",
		base = base, attack_mod = attack_mod, defense_mod = defense_mod, weak = weak,
	}


## Sum of the attacker's damage modifiers: tokens, Combo bonus, low-HP bonus,
## gear or tier, buffs (some only against `target`), and skill rank.
func _attack_mod(actor: Combatant, skill: SkillDef, strength: bool, combo: float, target: Combatant = null) -> float:
	var desperate := skill.low_hp_bonus if actor.hp_fraction() < 0.5 else 0.0
	return combo + desperate + (Rules.STRENGTH_BONUS if strength else 0.0) + actor.damage_bonus \
			+ actor.stat(&"damage", target, skill) + _skill_power(actor, skill)


## Sum of the defender's damage-received modifiers. `spend` consumes the
## tokens; ignored Block tokens are spent without reducing anything.
func _defense_mod(target: Combatant, spend: bool, ignored: Array[StringName] = []) -> float:
	var mod := 1.0 + target.stat(&"damage_taken")
	if target.has_token(Tokens.BLOCK_PLUS):
		if Tokens.BLOCK_PLUS not in ignored:
			mod -= Rules.BLOCK_PLUS_REDUCTION
		if spend:
			target.remove_token(Tokens.BLOCK_PLUS)
	elif target.has_token(Tokens.BLOCK):
		if Tokens.BLOCK not in ignored:
			mod -= Rules.BLOCK_REDUCTION
		if spend:
			target.remove_token(Tokens.BLOCK)
	if target.has_token(Tokens.VULNERABLE):
		mod += Rules.VULNERABLE_BONUS
		if spend:
			target.remove_token(Tokens.VULNERABLE)
	return mod


## The skill's heal on `target`: its HP share (by tier tokens when it has
## tiers), more for each positive token the target holds when the skill says so.
func _roll_heal(actor: Combatant, skill: SkillDef, target: Combatant, crit: bool, tier: int = 0) -> int:
	var share := skill.heal_fraction if skill.tier_heal.is_empty() else _tier_value(skill.tier_heal, tier)
	if skill.heal_per_buff_token > 0.0:
		for token: StringName in target.tokens:
			if not Tokens.is_negative(token):
				share += skill.heal_per_buff_token * target.token_count(token)
	var amount := (rng.randi_range(skill.heal_min, skill.heal_max) + share * target.max_hp) \
			* _skill_power(actor, skill) * maxf(0.0, 1.0 + actor.stat(&"heal_power")) \
			* maxf(0.0, 1.0 + target.stat(&"heal_received"))
	if crit:
		amount *= Rules.HEAL_CRIT_MULTIPLIER
	return roundi(amount)


## The entry for `count` tier tokens, the last one beyond the end, or 0 for no tiers.
static func _tier_value(values: Array[float], count: int) -> float:
	return values[mini(count, values.size() - 1)] if not values.is_empty() else 0.0


# --- Damage, death and healing ---

## Applies info.amount damage. The rest of `info` (crit, execution, cause and
## the damage breakdown) is passed through into the damage event.
func _damage(target: Combatant, info: Dictionary) -> void:
	var amount: int = info.amount
	var event := info.duplicate()
	var execution: int = info.get("execution", 0)

	if target.is_corpse:
		target.hp -= amount
		event.hp = maxi(target.hp, 0)
		_emit(&"damage", target, event)
		if target.hp <= 0:
			_remove_unit(target, &"destroyed")
		return

	if target.deaths_door:
		event.hp = 0
		_emit(&"damage", target, event)
		if target.is_hero:
			_deathblow_check(target)
		elif execution >= target.death_armor:
			_kill(target)
		else:
			target.death_armor -= 1
			_emit(&"death_armor", target, {remaining = target.death_armor})
		return

	target.hp -= amount
	event.hp = maxi(target.hp, 0)
	_emit(&"damage", target, event)
	_took_damage(target)
	if target.hp > 0:
		return
	target.hp = 0
	if target.is_hero or execution < target.death_armor:
		_enter_deaths_door(target)
	else:
		_kill(target)


## Self-inflicted damage from a skill's cost. Stops at 1 HP, so it never brings
## the user to Death's Door, and ignores tokens.
func _hurt_self(unit: Combatant, amount: int) -> void:
	amount = mini(amount, unit.hp - 1)
	if amount <= 0:
		return
	unit.hp -= amount
	_emit(&"damage", unit, {amount = amount, hp = unit.hp, cause = &"self"})
	_took_damage(unit)


## While More! MORE! lasts, the Flagellant gains Pain each time he is hurt.
func _took_damage(unit: Combatant) -> void:
	if unit.stat(&"pain_on_damage") > 0.0:
		_give_token(unit, Tokens.PAIN, 1)


func _deathblow_check(hero: Combatant) -> void:
	var chance := clampf(hero.resist(&"deathblow"), Rules.DEATHBLOW_MIN, Rules.DEATHBLOW_MAX)
	var roll := rng.randf()
	if roll < chance:
		hero.add_buff(&"resist_deathblow", Rules.DEATHBLOW_SURVIVE_PENALTY, Combatant.BuffExpiry.COMBAT)
		_emit(&"deathblow_resisted", hero, {roll = roll, chance = chance})
	else:
		_emit(&"deathblow", hero, {roll = roll, chance = chance})
		_kill(hero)


func _enter_deaths_door(unit: Combatant) -> void:
	unit.deaths_door = true
	unit.add_buff(&"speed", Rules.DEATHS_DOOR_SPEED, Combatant.BuffExpiry.DEATHS_DOOR)
	_emit(&"deaths_door", unit)
	if unit.def.deaths_door_weak:
		_give_token(unit, Tokens.WEAK, Rules.DEATHS_DOOR_WEAK)
	_fire(unit, TrinketTrigger.When.DEATHS_DOOR_ENTER)
	if unit.is_hero:
		_maybe_stress(unit, Rules.STRESS_DEATHS_DOOR, Rules.STRESS_DEATHS_DOOR_CHANCE)
		for ally in _other_heroes(unit):
			_maybe_stress(ally, Rules.STRESS_DEATHS_DOOR, Rules.STRESS_ALLY_DEATHS_DOOR_CHANCE)


func _kill(unit: Combatant) -> void:
	unit.dead = true
	unit.deaths_door = false
	unit.clear_tokens()
	unit.dots.clear()
	unit.remove_buffs(Combatant.BuffExpiry.DEATHS_DOOR)
	for other in all_units():
		if other.guarded_by == unit:
			other.remove_token(Tokens.GUARD, other.token_count(Tokens.GUARD))
	var leaves_corpse := unit.def.corpse_hp > 0
	if leaves_corpse:
		unit.is_corpse = true
		unit.hp = unit.def.corpse_hp
		unit.corpse_rounds = Rules.CORPSE_ROUNDS
	_emit(&"death", unit, {corpse = leaves_corpse, hp = unit.hp if leaves_corpse else 0})
	if not leaves_corpse:
		_remove_unit(unit, &"died")
	if unit.is_hero:
		for ally in _other_heroes(unit):
			_add_stress(ally, Rules.STRESS_ALLY_DIED)
	_check_end()


func _remove_unit(unit: Combatant, reason: StringName) -> void:
	side_of(unit).erase(unit)
	unit.is_corpse = false
	_emit(&"removed", unit, {reason = reason})


func _heal(target: Combatant, amount: int, crit: bool) -> void:
	var before := target.hp
	var left := target.heal(amount)
	if left:
		_emit(&"left_deaths_door", target)
	_emit(&"heal", target, {amount = target.hp - before, crit = crit, hp = target.hp})
	if left:
		_fire(target, TrinketTrigger.When.DEATHS_DOOR_LEAVE)


# --- Stress ---

func _add_stress(unit: Combatant, amount: int) -> void:
	if not unit.is_hero or not unit.is_active() or amount == 0:
		return
	if amount > 0:
		var chance := unit.resist(&"stress")
		if chance > 0.0:
			var roll := rng.randf()
			if roll < chance:
				_emit(&"stress_resisted", unit, {roll = roll, chance = chance})
				return
	var before := unit.stress
	unit.stress = clampi(unit.stress + amount, 0, Rules.STRESS_MAX)
	if unit.stress == before:
		return
	_emit(&"stress", unit, {amount = unit.stress - before, stress = unit.stress})
	if unit.stress >= Rules.STRESS_MAX:
		_overstress(unit)


func _maybe_stress(unit: Combatant, amount: int, chance: float) -> void:
	if unit.is_hero and unit.is_active() and rng.randf() < chance:
		_add_stress(unit, amount)


func _crit_stress(actor: Combatant, victims: Array[Combatant]) -> void:
	if actor.is_hero:
		_maybe_stress(actor, Rules.STRESS_CRIT_LANDED, Rules.STRESS_CRIT_LANDED_CHANCE)
		for ally in _other_heroes(actor):
			_maybe_stress(ally, Rules.STRESS_CRIT_LANDED, Rules.STRESS_ALLY_CRIT_LANDED_CHANCE)
	for victim in victims:
		_maybe_stress(victim, Rules.STRESS_CRIT_RECEIVED, Rules.STRESS_CRIT_RECEIVED_CHANCE)
		for ally in _other_heroes(victim):
			_maybe_stress(ally, Rules.STRESS_CRIT_RECEIVED, Rules.STRESS_ALLY_CRIT_RECEIVED_CHANCE)


## At 10 stress: 80% Meltdown, 20% Resolute, or the Flagellant's Toxic. All are one-off events.
func _overstress(hero: Combatant) -> void:
	var hp_before := hero.hp
	var was_at_deaths_door := hero.deaths_door
	match hero.overstress(rng):
		&"meltdown":
			_emit(&"meltdown", hero, {hp = hero.hp, stress = hero.stress})
			return
		&"toxic":
			_emit(&"toxic", hero, {hp = hero.hp, stress = hero.stress})
			_emit(&"token", hero, {token = Tokens.TOXIC, added = 1, negated = []})
			if was_at_deaths_door and not hero.deaths_door:
				_emit(&"left_deaths_door", hero)
			if hero.hp != hp_before:
				_emit(&"heal" if hero.hp > hp_before else &"damage", hero,
						{amount = absi(hero.hp - hp_before), crit = false, hp = hero.hp, cause = &"self"})
			return
	_emit(&"resolute", hero, {stress = 0})
	if was_at_deaths_door and not hero.deaths_door:
		_emit(&"left_deaths_door", hero)
	_emit(&"heal", hero, {amount = hero.hp - hp_before, crit = false, hp = hero.hp})


# --- Effects, tokens and movement ---

## pierce lowers the target's resistance, from the source skill's rank.
func _apply_effect(source: Combatant, target: Combatant, effect: EffectDef, crit: bool,
		consumed_combo: bool, pierce: float = 0.0, roll_chance: bool = true) -> void:
	if not target.is_active():
		return
	if roll_chance and effect.chance < 1.0 and rng.randf() >= effect.chance:
		return
	match effect.kind:
		EffectDef.Kind.TOKEN:
			var token := effect.token
			if not effect.token_pool.is_empty():
				token = effect.token_pool[rng.randi_range(0, effect.token_pool.size() - 1)]
			# A skill that spends a Combo does not put it straight back.
			if token == Tokens.COMBO and consumed_combo:
				return
			if token == Tokens.RIPOSTE and target.def.riposte_skill == null:
				return
			if _resisted(source, target, Tokens.resist_of(token), crit, effect.ignore_resist, token, pierce):
				return
			_give_token(target, token, effect.stacks)
		EffectDef.Kind.DOT:
			if _resisted(source, target, effect.dot, crit, effect.ignore_resist, effect.dot, pierce):
				return
			# Trinkets add to what the source deals and the target receives.
			var amount := maxi(1, effect.amount + roundi(source.stat(StringName("dot_dealt_%s" % effect.dot))
					+ target.stat(StringName("dot_received_%s" % effect.dot))))
			var turns := effect.crit_duration if crit and effect.crit_duration > 0 else effect.duration
			turns = maxi(1, turns + roundi(target.stat(&"dot_duration_received")
					+ target.stat(StringName("dot_duration_received_%s" % effect.dot))))
			target.dots.append({type = effect.dot, amount = amount, turns = turns})
			_emit(&"dot_applied", target, {dot = effect.dot, amount = amount, turns = turns})
		EffectDef.Kind.MOVE:
			if target.has_token(Tokens.IMMOBILIZE):
				_emit(&"immobile", target)
				return
			if _resisted(source, target, &"move", crit, effect.ignore_resist, &"move", pierce):
				return
			_move(target, effect.amount, source)
		EffectDef.Kind.CLEANSE_DOTS:
			if not target.dots.is_empty():
				target.dots.clear()
				_emit(&"cleansed", target, {what = &"dots"})
		EffectDef.Kind.CLEANSE_NEGATIVE:
			var removed := false
			for token in target.tokens.keys():
				if Tokens.is_negative(token):
					target.remove_token(token, target.token_count(token))
					removed = true
			if removed:
				_emit(&"cleansed", target, {what = &"tokens"})
		EffectDef.Kind.GUARD:
			if target == source:
				return
			# A new guard replaces any existing one.
			target.remove_token(Tokens.GUARD, target.token_count(Tokens.GUARD))
			_give_token(target, Tokens.GUARD, effect.stacks)
			target.guarded_by = source
		EffectDef.Kind.REMOVE_TOKENS:
			for token in effect.token_pool:
				if target.has_token(token):
					target.remove_token(token, target.token_count(token))
					_emit(&"token_removed", target, {token = token})
		EffectDef.Kind.CLEANSE_POSITIVE:
			for token in target.tokens.keys():
				if not Tokens.is_negative(token):
					target.remove_token(token, target.token_count(token))
					_emit(&"token_removed", target, {token = token})
		EffectDef.Kind.BUFF:
			var resist := &"move" if effect.stat == &"pull_each_turn" else &"debuff"
			if effect.stat_amount < 0.0 or effect.stat == &"pull_each_turn":
				if _resisted(source, target, resist, crit, effect.ignore_resist, effect.stat, pierce):
					return
			target.add_buff(effect.stat, effect.stat_amount, Combatant.BuffExpiry.ROUNDS, effect.duration)
			_emit(&"buffed", target, {stat = effect.stat, amount = effect.stat_amount, rounds = effect.duration})
		EffectDef.Kind.REGEN:
			var amount := effect.amount + roundi(source.stat(&"regen_dealt"))
			target.regens.append({amount = amount, turns = effect.duration})
			_emit(&"regen_applied", target, {amount = amount, turns = effect.duration})
		EffectDef.Kind.SHUFFLE:
			var side := side_of(target)
			if side.size() < 2 or target.has_token(Tokens.IMMOBILIZE):
				return
			if _resisted(source, target, &"move", crit, effect.ignore_resist, &"move", pierce):
				return
			var from := side.find(target)
			var to := rng.randi_range(0, side.size() - 2)
			_move(target, from - (to if to < from else to + 1), source)
		EffectDef.Kind.EXTRA_TURN:
			_queue.push_front({unit = target, delayed = false, extra = true})
			_emit(&"extra_turn", target)
		EffectDef.Kind.STEAL_DOTS:
			if target.dots.is_empty() or source == target:
				return
			for dot in target.dots:
				source.dots.append(dot)
				_emit(&"dot_applied", source, {dot = dot.type, amount = dot.amount, turns = dot.turns})
			target.dots.clear()
			_emit(&"cleansed", target, {what = &"dots"})
		EffectDef.Kind.STRESS:
			if target.stress >= effect.min_stress:
				_add_stress(target, effect.amount)
		EffectDef.Kind.CONSECRATE:
			var rank := rank_of(target)
			consecrations[rank] = {name = effect.token, tokens = effect.token_pool, rounds = effect.duration}
			_emit(&"consecrated", target, {name = effect.token, rank = rank, rounds = effect.duration})
		EffectDef.Kind.HEAL:
			_heal(target, effect.amount + roundi(target.max_hp * effect.stat_amount), false)
		EffectDef.Kind.DAMAGE:
			_damage(target, {amount = effect.amount, cause = &"trinket"})
		EffectDef.Kind.CONVERT:
			var count := target.token_count(effect.token)
			if count > 0:
				target.remove_token(effect.token, count)
				_emit(&"token_removed", target, {token = effect.token})
				_give_token(target, effect.token_to, count)
		EffectDef.Kind.REMOVE_ONE, EffectDef.Kind.STEAL_ONE:
			var held := effect.token_pool.filter(func(token: StringName) -> bool: return target.has_token(token))
			if held.is_empty():
				return
			var token: StringName = held[rng.randi_range(0, held.size() - 1)]
			target.remove_token(token)
			_emit(&"token_removed", target, {token = token})
			if effect.kind == EffectDef.Kind.STEAL_ONE and source != target:
				_give_token(source, token, 1)


## Resistance roll for something an opponent inflicts. Self- and ally-applied
## effects are never resisted. A crit pierces 20% resistance, skill ranks pierce more.
func _resisted(source: Combatant, target: Combatant, kind: StringName, crit: bool, ignore: bool,
		what: StringName, pierce: float = 0.0) -> bool:
	if kind == &"" or ignore or source.is_hero == target.is_hero:
		return false
	var chance := target.resist(kind) - pierce - (Rules.CRIT_RESIST_PIERCE if crit else 0.0) \
			- source.stat(StringName("pierce_%s" % kind))
	if chance <= 0.0:
		return false
	var roll := rng.randf()
	if roll >= chance:
		return false
	_emit(&"resisted", target, {what = what, roll = roll, chance = chance})
	_fire(target, TrinketTrigger.When.ON_RESIST, source, null, kind)
	return true


func _give_token(target: Combatant, token: StringName, stacks: int) -> void:
	if token == Tokens.DAZE:
		if target.has_token(Tokens.STUN):
			return
		if target.has_token(Tokens.DAZE):
			target.remove_token(Tokens.DAZE)
			token = Tokens.STUN
	var result := target.add_token(token, stacks)
	if result.added > 0 or not result.negated.is_empty():
		_emit(&"token", target, {token = token, added = result.added, negated = result.negated})


## Moves a unit `distance` slots: positive is forward (towards rank 1). `by`
## is whoever moved it, if not itself.
func _move(unit: Combatant, distance: int, by: Combatant = null) -> void:
	var side := side_of(unit)
	var from := side.find(unit)
	var to := clampi(from - distance, 0, side.size() - 1)
	if from < 0 or to == from:
		return
	side.remove_at(from)
	side.insert(to, unit)
	_emit(&"moved", unit, {rank = rank_of(unit)})
	_fire(unit, TrinketTrigger.When.WHEN_MOVED, by)
	if by and by.is_hero != unit.is_hero:
		_fire(unit, TrinketTrigger.When.WHEN_MOVED_BY_ENEMY, by)


func _swap(unit: Combatant, other: Combatant) -> void:
	var side := side_of(unit)
	var a := side.find(unit)
	var b := side.find(other)
	side[a] = other
	side[b] = unit
	_emit(&"moved", unit, {rank = rank_of(unit)})
	_emit(&"moved", other, {rank = rank_of(other)})
	_fire(unit, TrinketTrigger.When.WHEN_MOVED)
	_fire(other, TrinketTrigger.When.WHEN_MOVED)


# --- Targeting helpers ---

## Stealthed units can't be picked while anything else can, unless the skill
## ignores Stealth; taunting units must be picked if the skill can reach them.
func _apply_stealth_and_taunt(candidates: Array[Combatant], sees_stealth: bool = false) -> Array[Combatant]:
	var visible: Array[Combatant] = []
	visible.assign(candidates.filter(func(u: Combatant) -> bool: return sees_stealth or not u.has_token(Tokens.STEALTH)))
	var result := visible if not visible.is_empty() else candidates
	var taunting: Array[Combatant] = []
	taunting.assign(result.filter(func(u: Combatant) -> bool: return u.has_token(Tokens.TAUNT)))
	return taunting if not taunting.is_empty() else result


func _condition_met(unit: Combatant, skill: SkillDef) -> bool:
	match skill.condition:
		SkillDef.Condition.SELF_HP_BELOW:
			return unit.hp_fraction() < skill.condition_value
		SkillDef.Condition.SELF_LACKS_TOKEN:
			return not unit.has_token(skill.condition_token)
		SkillDef.Condition.ANY_ALLY_HP_BELOW:
			for ally in side_of(unit):
				if ally != unit and ally.is_active() and ally.hp_fraction() < skill.condition_value:
					return true
			return false
		SkillDef.Condition.SELF_HAS_ANY:
			return skill.condition_tokens.any(func(token: StringName) -> bool: return unit.has_token(token))
	return true


func _target_condition_met(target: Combatant, skill: SkillDef) -> bool:
	match skill.condition:
		SkillDef.Condition.TARGET_HP_BELOW:
			return target.is_active() and target.hp_fraction() < skill.condition_value
		SkillDef.Condition.TARGET_HAS_TOKEN:
			return target.has_token(skill.condition_token)
		SkillDef.Condition.TARGET_HAS_ANY:
			if not target.is_active():
				return false
			for token in skill.condition_tokens:
				if (target.dot_total(token) > 0) if token in [&"bleed", &"blight", &"burn"] else target.has_token(token):
					return true
			return skill.condition_value > 0.0 and target.hp_fraction() < skill.condition_value
		SkillDef.Condition.TARGET_STRESS_AT_LEAST:
			return target.is_active() and target.stress >= skill.condition_value
		SkillDef.Condition.TARGET_ON_CONSECRATION:
			return target.is_active() and consecrations.has(rank_of(target))
	return true


func _other_heroes(hero: Combatant) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for other in heroes:
		if other != hero and other.is_active():
			result.append(other)
	return result


# --- Ending ---

func _check_end() -> void:
	if state == State.VICTORY or state == State.DEFEAT:
		return
	if not enemies.any(func(u: Combatant) -> bool: return u.is_active()):
		_finish(true)
	elif not heroes.any(func(u: Combatant) -> bool: return u.is_active()):
		_finish(false)


## Clears one-battle state. After a win, heroes are healed up to 20% HP,
## which also lifts them off Death's Door.
func _finish(victory: bool) -> void:
	state = State.VICTORY if victory else State.DEFEAT
	_queue.clear()
	current = null
	heroes.assign(heroes.filter(func(hero: Combatant) -> bool: return hero.is_active()))
	enemies.assign(enemies.filter(func(unit: Combatant) -> bool: return unit.is_active()))
	for hero in heroes:
		hero.clear_battle_state()
		var floor_hp := ceili(hero.max_hp * Rules.BATTLE_END_MIN_HP)
		if victory and hero.hp < floor_hp:
			_heal(hero, floor_hp - hero.hp, false)
	_emit(&"battle_end", null, {victory = victory})


func _emit(type: StringName, unit: Combatant, data: Dictionary = {}) -> void:
	var event := data.duplicate()
	event.type = type
	event.uid = unit.uid if unit else 0
	_events.append(event)

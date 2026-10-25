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

## Remaining turns this round: {unit: Combatant, delayed: bool}.
var _queue: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _used_this_turn: StringName


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
	actions.assign(unit.def.skills)
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
						if covers_rank(foe, skill.target_ranks) and _target_condition_met(foe, skill):
							result.append(foe)
					if not skill.multi_target:
						result = _apply_stealth_and_taunt(result)
	return result


## What the UI shows before committing: hit and crit chance, damage and heal ranges.
func preview(actor: Combatant, skill: SkillDef, target: Combatant) -> Dictionary:
	var result := {
		hit_chance = 1.0, crit_chance = 0.0,
		damage_min = 0, damage_max = 0, crit_damage = 0,
		heal_min = 0, heal_max = 0,
	}
	if skill.kind != SkillDef.Kind.ACTION:
		return result
	if skill.is_attack():
		if actor.has_token(Tokens.BLIND):
			result.hit_chance *= 1.0 - Rules.BLIND_MISS_CHANCE
		if target.has_token(Tokens.DODGE_PLUS):
			result.hit_chance *= 1.0 - Rules.DODGE_PLUS_CHANCE
		elif target.has_token(Tokens.DODGE):
			result.hit_chance *= 1.0 - Rules.DODGE_CHANCE
	var can_crit := skill.deals_damage() or skill.heals()
	result.crit_chance = 1.0 if can_crit and actor.has_token(Tokens.CRIT) else _crit_chance(skill)
	if skill.deals_damage():
		var combo := skill.combo_damage_bonus if target.has_token(Tokens.COMBO) else 0.0
		var scale := _attack_mod(actor.has_token(Tokens.STRENGTH), combo) \
				* maxf(_defense_mod(target, false), 0.0) \
				* (Rules.WEAK_MULTIPLIER if actor.has_token(Tokens.WEAK) else 1.0)
		result.damage_min = maxi(1, roundi(skill.damage_min * scale))
		result.damage_max = maxi(1, roundi(skill.damage_max * scale))
		result.crit_damage = maxi(1, roundi(skill.damage_max * Rules.CRIT_DAMAGE_MULTIPLIER * scale))
	if skill.heals():
		var bonus := skill.heal_fraction * target.max_hp
		result.heal_min = roundi(skill.heal_min + bonus)
		result.heal_max = roundi(skill.heal_max + bonus)
	return result


# --- Rounds and turns ---

func _start_round() -> void:
	round_number += 1
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
	_emit(&"round_start", null, {round = round_number})


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
			if unit.has_token(Tokens.SPEED):
				unit.remove_token(Tokens.SPEED, unit.token_count(Tokens.SPEED))
				unit.speed_bonus_next_round = true
			unit.tick_round_buffs()
		elif unit.is_corpse:
			unit.corpse_rounds -= 1
			if unit.corpse_rounds <= 0:
				_remove_unit(unit, &"decayed")


func _take_turn(entry: Dictionary) -> void:
	var unit: Combatant = entry.unit
	if not unit.is_active():
		return
	if unit.has_token(Tokens.DAZE) and not entry.delayed:
		unit.remove_token(Tokens.DAZE)
		_emit(&"dazed", unit)
		_queue.append({unit = unit, delayed = true})
		return
	current = unit
	_emit(&"turn_start", unit)
	unit.remove_buffs(Combatant.BuffExpiry.TURN_START)
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


func _end_turn(unit: Combatant) -> void:
	if unit.is_active() and state == State.RUNNING:
		unit.tick_cooldowns(_used_this_turn)
		for token in unit.tick_tokens_turn_end():
			_emit(&"token_expired", unit, {token = token})
	_used_this_turn = &""
	current = null


func _tick_dots(unit: Combatant) -> void:
	var total := unit.dot_total()
	if total <= 0:
		return
	var cause := &"bleed"
	for type: StringName in [&"blight", &"burn"]:
		if unit.dot_total(type) > unit.dot_total(cause):
			cause = type
	unit.tick_dots()
	_damage(unit, {amount = total, cause = cause})


func _enemy_act(unit: Combatant) -> void:
	var choice := EnemyAI.choose(self, unit)
	if not choice.is_empty():
		_use_skill(unit, choice.skill, choice.target)
		return
	# Nothing usable: step towards the nearest rank some skill launches from.
	var rank := rank_of(unit)
	var nearest := 0
	for skill in unit.def.skills:
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
	var targets := _affected(actor, skill, primary)
	var attack := skill.is_attack()
	var damaging := skill.deals_damage()

	# A Crit token guarantees a crit on the next attack or heal.
	var crit := false
	var crit_roll := -1.0
	var crit_chance := _crit_chance(skill)
	if (damaging or skill.heals()) and actor.consume_token(Tokens.CRIT):
		crit = true
		crit_chance = 1.0
	elif crit_chance > 0.0:
		crit_roll = rng.randf()
		crit = crit_roll < crit_chance
	# Blind is rolled once per skill use; Strength and Weak are spent even on a miss.
	var blind_roll := rng.randf() if attack and actor.consume_token(Tokens.BLIND) else -1.0
	var strength := damaging and actor.consume_token(Tokens.STRENGTH)
	var weak := damaging and actor.consume_token(Tokens.WEAK)

	_emit(&"skill", actor, {
		skill = skill, targets = targets.map(func(t: Combatant) -> int: return t.uid),
		crit = crit, crit_roll = crit_roll, crit_chance = crit_chance, riposte = is_riposte,
	})

	var hit_living := false
	var crit_victims: Array[Combatant] = []
	var riposter: Combatant = null
	for aimed_at in targets:
		if state != State.RUNNING:
			break
		var target := aimed_at
		if attack and not skill.multi_target:
			target = _redirect_guard(aimed_at)
			if target.has_token(Tokens.TAUNT):
				target.remove_token(Tokens.TAUNT)
		if attack and _misses(target, blind_roll):
			continue
		if target.is_active():
			hit_living = true
		var consumed_combo := false
		if damaging:
			var combo := 0.0
			if skill.combo_damage_bonus > 0.0 and target.consume_token(Tokens.COMBO):
				combo = skill.combo_damage_bonus
				consumed_combo = true
			_damage(target, _roll_damage(skill, target, crit, strength, weak, combo))
		if skill.heals() and target.is_active():
			_heal(target, _roll_heal(skill, target, crit), crit)
		if skill.stress != 0:
			_add_stress(target, skill.stress)
		for effect in skill.effects:
			_apply_effect(actor, target, effect, crit, consumed_combo)
		if crit and attack and target.is_hero and target.is_active():
			crit_victims.append(target)
		if riposter == null and not is_riposte and attack and damaging and skill.can_be_riposted \
				and target.is_active() and target.has_token(Tokens.RIPOSTE) and target.def.riposte_skill:
			riposter = target

	if state != State.RUNNING:
		return
	if actor.is_active():
		for effect in skill.self_effects:
			_apply_effect(actor, actor, effect, false, false)
		if skill.self_move != 0:
			_move(actor, skill.self_move)
		if skill.self_stress != 0:
			_add_stress(actor, skill.self_stress)
	if crit and hit_living:
		_crit_stress(actor, crit_victims)
	if riposter and actor.is_active() and riposter.is_active() and state == State.RUNNING:
		riposter.consume_token(Tokens.RIPOSTE)
		_resolve(riposter, riposter.def.riposte_skill, actor, true)


## Units a skill affects once `primary` is chosen.
func _affected(actor: Combatant, skill: SkillDef, primary: Combatant) -> Array[Combatant]:
	var result: Array[Combatant] = []
	if skill.multi_target and skill.side != SkillDef.TargetSide.SELF:
		var pool := opponents_of(actor) if skill.side == SkillDef.TargetSide.ENEMY else side_of(actor)
		for unit in pool:
			if covers_rank(unit, skill.target_ranks) and (skill.side == SkillDef.TargetSide.ENEMY or unit.is_active()):
				result.append(unit)
	else:
		result.append(primary)
	return result


func _crit_chance(skill: SkillDef) -> float:
	if skill.heals() and not skill.deals_damage():
		return Rules.HEAL_CRIT_CHANCE
	return skill.crit_chance


func _redirect_guard(target: Combatant) -> Combatant:
	var guardian := target.guarded_by
	if guardian == null or not guardian.is_active() or not target.has_token(Tokens.GUARD):
		return target
	target.remove_token(Tokens.GUARD)
	_emit(&"guarded", guardian, {protected = target.uid})
	return guardian


## Blind (attacker, rolled once per skill use) then Dodge+ / Dodge (target).
## Dodge tokens are spent whether or not they work.
func _misses(target: Combatant, blind_roll: float) -> bool:
	if blind_roll >= 0.0 and blind_roll < Rules.BLIND_MISS_CHANCE:
		_emit(&"miss", target, {reason = &"blind", roll = blind_roll, chance = Rules.BLIND_MISS_CHANCE})
		return true
	var token := Tokens.DODGE_PLUS if target.has_token(Tokens.DODGE_PLUS) else Tokens.DODGE
	if not target.has_token(token):
		return false
	target.remove_token(token)
	var chance := Rules.DODGE_PLUS_CHANCE if token == Tokens.DODGE_PLUS else Rules.DODGE_CHANCE
	var roll := rng.randf()
	if roll < chance:
		_emit(&"miss", target, {reason = &"dodge", roll = roll, chance = chance})
		return true
	return false


## DD2 damage: base roll (max x1.5 on a crit) x attacker mods x defender mods,
## then Weak halves it last. Block/Block+ and Vulnerable are spent on the hit.
func _roll_damage(skill: SkillDef, target: Combatant, crit: bool, strength: bool, weak: bool,
		combo: float) -> Dictionary:
	var base: float
	if crit:
		base = skill.damage_max * Rules.CRIT_DAMAGE_MULTIPLIER
	else:
		base = rng.randi_range(skill.damage_min, skill.damage_max)
	var attack_mod := _attack_mod(strength, combo)
	var defense_mod := _defense_mod(target, true)
	var amount := base * attack_mod * maxf(defense_mod, 0.0)
	if weak:
		amount *= Rules.WEAK_MULTIPLIER
	return {
		amount = maxi(1, roundi(amount)), crit = crit, execution = skill.execution, cause = &"hit",
		base = base, attack_mod = attack_mod, defense_mod = defense_mod, weak = weak,
	}


func _attack_mod(strength: bool, combo: float) -> float:
	return 1.0 + combo + (Rules.STRENGTH_BONUS if strength else 0.0)


## Sum of the defender's damage-received modifiers. `spend` consumes the tokens.
func _defense_mod(target: Combatant, spend: bool) -> float:
	var mod := 1.0
	if target.has_token(Tokens.BLOCK_PLUS):
		mod -= Rules.BLOCK_PLUS_REDUCTION
		if spend:
			target.remove_token(Tokens.BLOCK_PLUS)
	elif target.has_token(Tokens.BLOCK):
		mod -= Rules.BLOCK_REDUCTION
		if spend:
			target.remove_token(Tokens.BLOCK)
	if target.has_token(Tokens.VULNERABLE):
		mod += Rules.VULNERABLE_BONUS
		if spend:
			target.remove_token(Tokens.VULNERABLE)
	return mod


func _roll_heal(skill: SkillDef, target: Combatant, crit: bool) -> int:
	var amount := rng.randi_range(skill.heal_min, skill.heal_max) + skill.heal_fraction * target.max_hp
	if crit:
		amount *= Rules.HEAL_CRIT_MULTIPLIER
	return roundi(amount)


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
	if target.hp > 0:
		return
	target.hp = 0
	if target.is_hero or execution < target.death_armor:
		_enter_deaths_door(target)
	else:
		_kill(target)


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
	_give_token(unit, Tokens.WEAK, Rules.DEATHS_DOOR_WEAK)
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
	if target.deaths_door and amount > 0:
		target.deaths_door = false
		target.remove_buffs(Combatant.BuffExpiry.DEATHS_DOOR)
		_emit(&"left_deaths_door", target)
	var before := target.hp
	target.hp = mini(target.max_hp, target.hp + amount)
	_emit(&"heal", target, {amount = target.hp - before, crit = crit, hp = target.hp})


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


## At 10 stress: 80% Meltdown, 20% Resolute. Both are one-off events.
func _overstress(hero: Combatant) -> void:
	if rng.randf() < Rules.MELTDOWN_CHANCE:
		hero.stress = Rules.MELTDOWN_STRESS
		if hero.hp > 0:
			hero.hp = mini(hero.hp, maxi(1, roundi(hero.max_hp * Rules.MELTDOWN_HP_FRACTION)))
		hero.add_buff(&"resist_deathblow", Rules.MELTDOWN_DEATHBLOW, Combatant.BuffExpiry.RUN)
		hero.add_buff(&"resist_stress", Rules.OVERSTRESS_STRESS_RESIST, Combatant.BuffExpiry.ROUNDS,
				Rules.OVERSTRESS_BUFF_ROUNDS)
		_emit(&"meltdown", hero, {hp = hero.hp, stress = hero.stress})
	else:
		hero.stress = 0
		hero.add_buff(&"resist_deathblow", Rules.RESOLUTE_DEATHBLOW, Combatant.BuffExpiry.RUN)
		hero.add_buff(&"resist_debuff", Rules.RESOLUTE_DEBUFF_RESIST, Combatant.BuffExpiry.ROUNDS,
				Rules.OVERSTRESS_BUFF_ROUNDS)
		hero.add_buff(&"resist_stress", Rules.OVERSTRESS_STRESS_RESIST, Combatant.BuffExpiry.ROUNDS,
				Rules.OVERSTRESS_BUFF_ROUNDS)
		_emit(&"resolute", hero, {stress = 0})
		_heal(hero, roundi(hero.max_hp * Rules.RESOLUTE_HEAL_FRACTION), false)


# --- Effects, tokens and movement ---

func _apply_effect(source: Combatant, target: Combatant, effect: EffectDef, crit: bool,
		consumed_combo: bool) -> void:
	if not target.is_active():
		return
	if effect.chance < 1.0 and rng.randf() >= effect.chance:
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
			if _resisted(source, target, Tokens.resist_of(token), crit, effect.ignore_resist, token):
				return
			_give_token(target, token, effect.stacks)
		EffectDef.Kind.DOT:
			if _resisted(source, target, effect.dot, crit, effect.ignore_resist, effect.dot):
				return
			target.dots.append({type = effect.dot, amount = effect.amount, turns = effect.duration})
			_emit(&"dot_applied", target, {dot = effect.dot, amount = effect.amount, turns = effect.duration})
		EffectDef.Kind.MOVE:
			if target.has_token(Tokens.IMMOBILIZE):
				_emit(&"immobile", target)
				return
			if _resisted(source, target, &"move", crit, effect.ignore_resist, &"move"):
				return
			_move(target, effect.amount)
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


## Resistance roll for something an opponent inflicts. Self- and ally-applied
## effects are never resisted. A crit pierces 20% resistance.
func _resisted(source: Combatant, target: Combatant, kind: StringName, crit: bool, ignore: bool,
		what: StringName) -> bool:
	if kind == &"" or ignore or source.is_hero == target.is_hero:
		return false
	var chance := target.resist(kind) - (Rules.CRIT_RESIST_PIERCE if crit else 0.0)
	if chance <= 0.0:
		return false
	var roll := rng.randf()
	if roll >= chance:
		return false
	_emit(&"resisted", target, {what = what, roll = roll, chance = chance})
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


## Moves a unit `distance` slots: positive is forward (towards rank 1).
func _move(unit: Combatant, distance: int) -> void:
	var side := side_of(unit)
	var from := side.find(unit)
	var to := clampi(from - distance, 0, side.size() - 1)
	if from < 0 or to == from:
		return
	side.remove_at(from)
	side.insert(to, unit)
	_emit(&"moved", unit, {rank = rank_of(unit)})


func _swap(unit: Combatant, other: Combatant) -> void:
	var side := side_of(unit)
	var a := side.find(unit)
	var b := side.find(other)
	side[a] = other
	side[b] = unit
	_emit(&"moved", unit, {rank = rank_of(unit)})
	_emit(&"moved", other, {rank = rank_of(other)})


# --- Targeting helpers ---

## Stealthed units can't be picked while anything else can; taunting units
## must be picked if the skill can reach them.
func _apply_stealth_and_taunt(candidates: Array[Combatant]) -> Array[Combatant]:
	var visible: Array[Combatant] = []
	visible.assign(candidates.filter(func(u: Combatant) -> bool: return not u.has_token(Tokens.STEALTH)))
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
	return true


func _target_condition_met(target: Combatant, skill: SkillDef) -> bool:
	match skill.condition:
		SkillDef.Condition.TARGET_HP_BELOW:
			return target.is_active() and target.hp_fraction() < skill.condition_value
		SkillDef.Condition.TARGET_HAS_TOKEN:
			return target.has_token(skill.condition_token)
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

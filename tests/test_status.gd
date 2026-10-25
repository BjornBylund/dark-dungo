extends TestCase


## Plays `rounds` rounds. The hero uses `first_skill` on its first `uses` turns and passes after.
func _play(battle: Battle, rounds: int, first_skill: SkillDef, uses: int = 1) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var used := 0
	while battle.round_number <= rounds and battle.state != Battle.State.VICTORY:
		events.append_array(Fixtures.until_input(battle))
		if battle.state != Battle.State.AWAITING_INPUT or battle.round_number > rounds:
			break
		var skill := first_skill if used < uses else BasicSkills.pass_turn
		var target := battle.enemies[0] if skill == first_skill else battle.current
		events.append_array(battle.submit(skill, target))
		used += 1
	return events


func _dot_ticks(events: Array[Dictionary]) -> Array:
	return Fixtures.of_type(events, &"damage").filter(func(e: Dictionary) -> bool: return e.cause == &"bleed") \
			.map(func(e: Dictionary) -> int: return e.amount)


func test_dot_ticks_at_turn_start_for_three_turns() -> void:
	var bleed := Fixtures.debuff([EffectDef.make_dot(&"bleed", 2)])
	var battle := Fixtures.duel(bleed)
	var events := _play(battle, 5, bleed)
	assert_eq(_dot_ticks(events), [2, 2, 2])


func test_dot_instances_stack_and_expire_separately() -> void:
	var bleed := Fixtures.debuff([EffectDef.make_dot(&"bleed", 2)])
	var battle := Fixtures.duel(bleed)
	var events := _play(battle, 5, bleed, 2)
	assert_eq(_dot_ticks(events), [2, 4, 4, 2])


func test_stun_skips_the_turn_and_grants_stun_resist() -> void:
	var stun := Fixtures.debuff([EffectDef.make_token(Tokens.STUN)])
	var battle := Fixtures.duel(stun)
	Fixtures.until_input(battle)
	battle.submit(stun, battle.enemies[0])
	var events := Fixtures.until_input(battle)
	var dummy := battle.enemies[0]
	assert_eq(Fixtures.of_type(events, &"stunned").size(), 1)
	assert_false(dummy.has_token(Tokens.STUN))
	assert_eq(dummy.resist(&"stun"), Rules.STUN_RECOVERY_RESIST)


func test_resistance_roll_matches_resist_value() -> void:
	var resisted := 0
	for seed_value in 400:
		var result := Fixtures.hit_once(Fixtures.debuff([EffectDef.make_dot(&"bleed", 2)]),
				func(_hero: Combatant, target: Combatant) -> void: target.def.resist_bleed = 0.5, seed_value)
		if result.target.dots.is_empty():
			resisted += 1
	assert_between(resisted / 400.0, 0.42, 0.58, "resist rate at 50%")


func test_crit_pierces_twenty_percent_resist() -> void:
	var resisted := 0
	for seed_value in 400:
		var result := Fixtures.hit_once(Fixtures.debuff([EffectDef.make_dot(&"bleed", 2)]),
				func(hero: Combatant, target: Combatant) -> void:
					target.def.resist_bleed = 0.5
					hero.add_token(Tokens.CRIT), seed_value)
		if result.target.dots.is_empty():
			resisted += 1
	# A Crit token only applies to attacks and heals, so this skill does not crit.
	assert_between(resisted / 400.0, 0.42, 0.58, "no pierce without a crit")

	resisted = 0
	var skill := Fixtures.attack(1, 1)
	skill.effects.append(EffectDef.make_dot(&"bleed", 2))
	for seed_value in 400:
		var result := Fixtures.hit_once(skill, func(hero: Combatant, target: Combatant) -> void:
			target.def.resist_bleed = 0.5
			hero.add_token(Tokens.CRIT), seed_value)
		if result.target.dots.is_empty():
			resisted += 1
	assert_between(resisted / 400.0, 0.22, 0.38, "resist rate 50% - 20% pierce")


func test_knockback_moves_target_back() -> void:
	var push := Fixtures.attack(1, 1)
	push.effects.append(EffectDef.make_move(-1))
	var hero := Fixtures.unit("Hero", 30, 50, [push])
	var battle := Fixtures.battle([hero], [Fixtures.unit("Front"), Fixtures.unit("Back")])
	Fixtures.until_input(battle)
	var front := battle.enemies[0]
	battle.submit(push, front)
	assert_eq(battle.rank_of(front), 2)


func test_self_applied_negative_tokens_are_not_resisted() -> void:
	var skill := SkillDef.new()
	skill.id = &"taunt"
	skill.side = SkillDef.TargetSide.SELF
	skill.self_effects.append(EffectDef.make_token(Tokens.TAUNT, 2))
	var hero_def := Fixtures.unit("Hero", 30, 50, [skill])
	hero_def.resist_debuff = 5.0
	var battle := Fixtures.battle([hero_def], [Fixtures.unit("Dummy")])
	Fixtures.until_input(battle)
	battle.submit(skill, battle.heroes[0])
	assert_eq(battle.heroes[0].token_count(Tokens.TAUNT), 2)

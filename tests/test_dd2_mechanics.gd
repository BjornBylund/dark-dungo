## The DD2 hero mechanics beyond plain tokens and DoTs: ignored tokens, Combo
## payoffs, tier tokens (Conviction), consecrations, corpse skills, Regen,
## timed buffs, extra turns, the Flagellant's Toxic and Pain.
extends TestCase


func _effect(kind: EffectDef.Kind) -> EffectDef:
	return EffectDef.make(kind)


## A hero acting first against a passive dummy, at the hero's first turn.
func _duel(skill: SkillDef, dummy_hp: int = 100, seed_value: int = 1) -> Battle:
	var battle := Fixtures.duel(skill, dummy_hp, seed_value)
	Fixtures.until_input(battle)
	return battle


func test_ignored_block_is_spent_without_reducing_damage() -> void:
	var skill := Fixtures.attack(10, 10)
	skill.ignore_tokens.assign([Tokens.BLOCK])
	var battle := _duel(skill)
	var dummy := battle.enemies[0]
	dummy.add_token(Tokens.BLOCK, 2)
	battle.submit(skill, dummy)
	assert_eq(dummy.hp, 90)
	assert_eq(dummy.token_count(Tokens.BLOCK), 1, "one Block is still spent")


func test_ignored_dodge_never_dodges() -> void:
	var skill := Fixtures.attack(1, 1)
	skill.ignore_tokens.assign([Tokens.DODGE_PLUS])
	for seed_value in 20:
		var battle := _duel(skill, 100, seed_value)
		var dummy := battle.enemies[0]
		dummy.add_token(Tokens.DODGE_PLUS)
		battle.submit(skill, dummy)
		assert_eq(dummy.hp, 99)
		assert_false(dummy.has_token(Tokens.DODGE_PLUS))


func test_stealth_ignoring_skills_can_pick_a_stealthed_target() -> void:
	var skill := Fixtures.attack(1, 1)
	var battle := Fixtures.battle([Fixtures.unit("Hero", 30, 50, [skill])],
			[Fixtures.unit("Front", 30, 0), Fixtures.unit("Hidden", 30, 0)])
	Fixtures.until_input(battle)
	battle.enemies[1].add_token(Tokens.STEALTH)
	assert_false(battle.enemies[1] in battle.targets_for(battle.heroes[0], skill))
	skill.ignore_tokens.assign([Tokens.STEALTH])
	assert_true(battle.enemies[1] in battle.targets_for(battle.heroes[0], skill))


func test_combo_payoffs_need_the_combo_and_end_it() -> void:
	var skill := Fixtures.attack(1, 1)
	skill.ends_combo = true
	skill.effects.assign([EffectDef.make_token(Tokens.STUN)])
	skill.effects[0].requires_target_token = Tokens.COMBO
	skill.effects[0].ignore_resist = true
	var battle := _duel(skill)
	var dummy := battle.enemies[0]
	battle.submit(skill, dummy)
	assert_false(dummy.has_token(Tokens.STUN), "no stun without Combo")
	battle = _duel(skill)
	dummy = battle.enemies[0]
	dummy.add_token(Tokens.COMBO)
	battle.submit(skill, dummy)
	assert_true(dummy.has_token(Tokens.STUN))
	assert_false(dummy.has_token(Tokens.COMBO), "the hit ends Combo")


func test_combo_raises_crit_chance() -> void:
	var skill := Fixtures.attack(1, 1, 0.1)
	skill.combo_crit_bonus = 0.5
	var battle := _duel(skill)
	var dummy := battle.enemies[0]
	var hero := battle.heroes[0]
	assert_almost_eq(battle.preview(hero, skill, dummy).crit_chance, 0.1)
	dummy.add_token(Tokens.COMBO)
	assert_almost_eq(battle.preview(hero, skill, dummy).crit_chance, 0.6)


func test_conviction_builds_each_turn_strengthens_skills_and_is_spent() -> void:
	var skill := Fixtures.attack(10, 10)
	skill.tier_tokens.assign([Tokens.CONVICTION])
	skill.tier_damage.assign([0.0, 0.0, 1.0])
	skill.tier_spend_from = 2
	var vestal := Fixtures.unit("Vestal", 30, 50, [skill])
	vestal.turn_start_tokens = {Tokens.CONVICTION: 1}
	var battle := Fixtures.battle([vestal], [Fixtures.unit("Dummy", 100, 0)])
	Fixtures.until_input(battle)
	var hero := battle.heroes[0]
	assert_eq(hero.token_count(Tokens.CONVICTION), 1, "+1 at the turn start")
	battle.submit(skill, battle.enemies[0])
	assert_eq(battle.enemies[0].hp, 90, "no bonus at 1")
	assert_eq(hero.token_count(Tokens.CONVICTION), 1, "not spent below 2")
	Fixtures.until_input(battle)
	assert_eq(hero.token_count(Tokens.CONVICTION), 2)
	battle.submit(skill, battle.enemies[0])
	assert_eq(battle.enemies[0].hp, 70, "+100% at 2")
	assert_eq(hero.token_count(Tokens.CONVICTION), 0, "spent at 2")


func test_tier_heals_scale_with_tokens() -> void:
	var heal := Fixtures.attack(0, 0)
	heal.side = SkillDef.TargetSide.ALLY
	heal.tier_tokens.assign([Tokens.CONVICTION])
	heal.tier_heal.assign([0.2, 0.2, 0.3, 0.4])
	var battle := Fixtures.battle([Fixtures.unit("Healer", 100, 50, [heal])], [Fixtures.unit("Dummy", 100, 0)])
	Fixtures.until_input(battle)
	var healer := battle.heroes[0]
	healer.hp = 10
	healer.add_token(Tokens.CONVICTION, 3)
	var preview := battle.preview(healer, heal, healer)
	assert_eq(preview.heal_min, 40)


func test_a_consecrated_rank_gives_its_occupant_a_token_each_turn() -> void:
	var bless := Fixtures.attack(0, 0)
	bless.side = SkillDef.TargetSide.ALLY
	var consecrate := _effect(EffectDef.Kind.CONSECRATE)
	consecrate.token = &"light"
	consecrate.token_pool.assign([Tokens.STRENGTH])
	consecrate.duration = 3
	bless.effects.assign([consecrate])
	var battle := _duel(bless)
	var hero := battle.heroes[0]
	battle.submit(bless, hero)
	assert_true(battle.consecrations.has(1))
	assert_false(hero.has_token(Tokens.STRENGTH))
	Fixtures.until_input(battle)
	assert_true(hero.has_token(Tokens.STRENGTH), "gained at the next turn start")
	var mantra := Fixtures.attack(0, 0)
	mantra.side = SkillDef.TargetSide.ALLY
	mantra.condition = SkillDef.Condition.TARGET_ON_CONSECRATION
	assert_eq(battle.targets_for(hero, mantra), [hero] as Array[Combatant])
	for i in 3:
		battle._end_round()
	assert_false(battle.consecrations.has(1), "it runs out")
	assert_true(battle.targets_for(hero, mantra).is_empty())


func test_corpse_skills_clear_the_corpse_and_reach_its_neighbours() -> void:
	var fester := Fixtures.attack(0, 0)
	fester.targets_corpse = true
	var blight := EffectDef.make_dot(&"blight", 3)
	blight.ignore_resist = true
	fester.neighbor_effects.assign([blight])
	var front := Fixtures.unit("Front", 30, 0)
	var dead := Fixtures.unit("Dead", 30, 0)
	dead.corpse_hp = 10
	var back := Fixtures.unit("Back", 30, 0)
	var battle := Fixtures.battle([Fixtures.unit("Hero", 30, 50, [fester])], [front, dead, back])
	Fixtures.until_input(battle)
	assert_true(battle.targets_for(battle.heroes[0], fester).is_empty(), "needs a corpse")
	var corpse := battle.enemies[1]
	battle._kill(corpse)
	assert_eq(battle.targets_for(battle.heroes[0], fester), [corpse] as Array[Combatant])
	battle.submit(fester, corpse)
	assert_false(corpse in battle.enemies, "the corpse is cleared")
	assert_eq(battle.enemies[0].dot_total(&"blight"), 3)
	assert_eq(battle.enemies[1].dot_total(&"blight"), 3)


func test_damage_from_dots_ignores_modifiers() -> void:
	var cause := Fixtures.attack(0, 0)
	cause.damage_from_dots = 1.0
	var battle := _duel(cause)
	var dummy := battle.enemies[0]
	dummy.dots.append({type = &"bleed", amount = 3, turns = 3})
	dummy.add_token(Tokens.BLOCK_PLUS)
	battle.submit(cause, dummy)
	assert_eq(dummy.hp, 91)


func test_the_flagellant_turns_toxic_at_max_stress_and_blights_attackers() -> void:
	var cooldown := Fixtures.attack(1, 1)
	cooldown.cooldown = 3
	var flagellant := Fixtures.unit("Flagellant", 50, 50, [cooldown])
	flagellant.overstress = &"toxic"
	var battle := Fixtures.battle([flagellant], [Fixtures.unit("Dummy", 100, 0)])
	Fixtures.until_input(battle)
	var hero := battle.heroes[0]
	hero.cooldowns[cooldown.id] = 2
	hero.stress = 9
	battle._add_stress(hero, 1)
	assert_eq(hero.stress, Rules.TOXIC_STRESS)
	assert_eq(hero.hp, 15, "HP set to 30%")
	assert_eq(hero.token_count(Tokens.TOXIC), 1)
	assert_eq(hero.cooldown_left(cooldown), 0, "cooldowns reset")
	var attacker := battle.enemies[0]
	battle._toxic_backlash(attacker, hero)
	assert_eq(attacker.dot_total(&"blight"), Rules.TOXIC_BLIGHT_PER_TOKEN)


func test_pain_heals_at_turn_end_then_goes() -> void:
	var lash := Fixtures.attack(1, 1)
	lash.self_damage = 10
	var battle := _duel(lash)
	var hero := battle.heroes[0]
	hero.add_buff(&"pain_on_damage", 1.0, Combatant.BuffExpiry.ROUNDS, 2)
	battle.submit(lash, battle.enemies[0])
	assert_false(hero.has_token(Tokens.PAIN), "spent at the turn end")
	assert_eq(hero.hp, 20 + roundi(30 * Rules.PAIN_HEAL), "the self-hurt gave Pain, which healed")


func test_heroes_without_deaths_door_weak() -> void:
	var battle := _duel(Fixtures.attack(1, 1))
	var hero := battle.heroes[0]
	hero.def.deaths_door_weak = false
	battle._enter_deaths_door(hero)
	assert_false(hero.has_token(Tokens.WEAK))


func test_a_kill_can_relieve_stress() -> void:
	var finale := Fixtures.attack(50, 50)
	finale.kill_stress = -2
	var battle := _duel(finale, 10)
	battle.heroes[0].stress = 5
	battle.submit(finale, battle.enemies[0])
	assert_eq(battle.heroes[0].stress, 3)


func test_regen_heals_at_each_turn_start() -> void:
	var regen := Fixtures.attack(0, 0)
	regen.side = SkillDef.TargetSide.SELF
	var effect := _effect(EffectDef.Kind.REGEN)
	effect.amount = 2
	effect.duration = 2
	regen.effects.assign([effect])
	var battle := _duel(regen)
	var hero := battle.heroes[0]
	hero.hp = 10
	battle.submit(regen, hero)
	for turn in 3:
		Fixtures.until_input(battle)
		battle.submit(BasicSkills.pass_turn, hero)
	assert_eq(hero.hp, 14, "2 a turn for 2 turns")


func test_timed_buffs_change_stats_and_block_tokens() -> void:
	var hero := Combatant.new(Fixtures.unit("Hero", 30, 4), true)
	hero.add_buff(&"speed", -2.0, Combatant.BuffExpiry.ROUNDS, 2)
	hero.add_buff(&"blocks_block", 1.0, Combatant.BuffExpiry.ROUNDS, 2)
	assert_eq(hero.speed(), 2)
	assert_eq(hero.add_token(Tokens.BLOCK).added, 0)
	hero.tick_round_buffs()
	hero.tick_round_buffs()
	assert_eq(hero.speed(), 4)
	assert_eq(hero.add_token(Tokens.BLOCK).added, 1)


func test_an_extra_turn_acts_next() -> void:
	var encore := Fixtures.attack(0, 0)
	encore.side = SkillDef.TargetSide.ALLY
	encore.can_target_self = false
	encore.effects.assign([_effect(EffectDef.Kind.EXTRA_TURN)])
	var battle := Fixtures.battle([Fixtures.unit("Jester", 30, 50, [encore]), Fixtures.unit("Ally", 30, 0)],
			[Fixtures.unit("Dummy", 100, 0)])
	Fixtures.until_input(battle)
	var ally := battle.heroes[1]
	battle.submit(encore, ally)
	Fixtures.until_input(battle)
	assert_eq(battle.current, ally)


func test_dots_can_be_taken_over_and_targets_shuffled() -> void:
	var suffer := Fixtures.attack(0, 0)
	suffer.side = SkillDef.TargetSide.ALLY
	suffer.effects.assign([_effect(EffectDef.Kind.STEAL_DOTS)])
	var battle := Fixtures.battle([Fixtures.unit("Flagellant", 30, 50, [suffer]), Fixtures.unit("Ally", 30, 0)],
			[Fixtures.unit("Dummy", 100, 0)])
	Fixtures.until_input(battle)
	var ally := battle.heroes[1]
	ally.dots.append({type = &"bleed", amount = 3, turns = 3})
	battle.submit(suffer, ally)
	assert_eq(ally.dot_total(), 0)
	assert_eq(battle.heroes[0].dot_total(&"bleed"), 3)
	var moved := 0
	for seed_value in 20:
		var shuffle := Fixtures.attack(0, 0)
		var effect := _effect(EffectDef.Kind.SHUFFLE)
		effect.ignore_resist = true
		shuffle.effects.assign([effect])
		var fight := Fixtures.battle([Fixtures.unit("Doctor", 30, 50, [shuffle])],
				[Fixtures.unit("A", 30, 0), Fixtures.unit("B", 30, 0), Fixtures.unit("C", 30, 0)], seed_value)
		Fixtures.until_input(fight)
		var target := fight.enemies[0]
		fight.submit(shuffle, target)
		moved += int(fight.enemies.find(target) != 0)
	assert_eq(moved, 20, "always to another rank")


func test_conditional_heals_and_costs() -> void:
	var absinthe := Fixtures.attack(0, 0)
	absinthe.side = SkillDef.TargetSide.SELF
	absinthe.self_heal_fraction = 0.5
	absinthe.self_heal_below = 0.33
	absinthe.self_damage_fraction = 0.1
	var battle := _duel(absinthe)
	var hero := battle.heroes[0]
	hero.hp = 20
	battle.submit(absinthe, hero)
	assert_eq(hero.hp, 17, "no heal above a third, but the 10% cost")
	battle = _duel(absinthe)
	hero = battle.heroes[0]
	hero.hp = 5
	battle.submit(absinthe, hero)
	assert_eq(hero.hp, 5 + 15 - 3)

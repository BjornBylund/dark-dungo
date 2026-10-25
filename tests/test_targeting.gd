extends TestCase


func _uids(units: Array) -> Array:
	return units.map(func(u: Combatant) -> int: return u.uid)


func _hero_against(skill: SkillDef, enemy_defs: Array) -> Battle:
	var battle := Fixtures.battle([Fixtures.unit("Hero", 30, 50, [skill])], enemy_defs)
	Fixtures.until_input(battle)
	return battle


func test_taunt_forces_single_target_attacks() -> void:
	var battle := _hero_against(Fixtures.attack(1, 1), [Fixtures.unit("A"), Fixtures.unit("B")])
	battle.enemies[1].add_token(Tokens.TAUNT)
	var targets := battle.targets_for(battle.current, battle.current.def.skills[0])
	assert_eq(_uids(targets), _uids([battle.enemies[1]]))


func test_taunt_is_spent_when_it_redirects_an_attack() -> void:
	var battle := _hero_against(Fixtures.attack(1, 1), [Fixtures.unit("A"), Fixtures.unit("B")])
	var taunter := battle.enemies[1]
	taunter.add_token(Tokens.TAUNT, 2)
	battle.submit(battle.current.def.skills[0], taunter)
	assert_eq(taunter.token_count(Tokens.TAUNT), 1)


func test_stealth_hides_unless_it_is_the_only_target() -> void:
	var battle := _hero_against(Fixtures.attack(1, 1), [Fixtures.unit("A"), Fixtures.unit("B")])
	battle.enemies[0].add_token(Tokens.STEALTH)
	var skill := battle.current.def.skills[0]
	assert_eq(_uids(battle.targets_for(battle.current, skill)), _uids([battle.enemies[1]]))
	battle.enemies[1].add_token(Tokens.STEALTH)
	assert_eq(battle.targets_for(battle.current, skill).size(), 2)


func test_multi_target_skills_hit_stealthed_units() -> void:
	var skill := Fixtures.attack(1, 1)
	skill.multi_target = true
	skill.target_ranks.assign([1, 2])
	var battle := _hero_against(skill, [Fixtures.unit("A"), Fixtures.unit("B")])
	battle.enemies[0].add_token(Tokens.STEALTH)
	var events := battle.submit(skill, battle.enemies[1])
	assert_eq(Fixtures.of_type(events, &"damage").size(), 2)


func test_launch_ranks_gate_skills() -> void:
	var skill := Fixtures.attack(1, 1)
	skill.launch_ranks.assign([3, 4])
	var battle := _hero_against(skill, [Fixtures.unit("A")])
	assert_false(battle.can_use(battle.current, skill))


func test_large_units_cover_two_ranks() -> void:
	var big := Fixtures.unit("Big")
	big.size = 2
	var skill := Fixtures.attack(1, 1)
	skill.target_ranks.assign([2])
	var battle := _hero_against(skill, [big, Fixtures.unit("Small")])
	assert_eq(_uids(battle.targets_for(battle.current, skill)), _uids([battle.enemies[0]]))
	assert_eq(battle.rank_of(battle.enemies[1]), 3)


func test_swap_trades_places_within_offsets() -> void:
	var a := Fixtures.unit("A", 30, 50)
	var b := Fixtures.unit("B", 30, 0)
	var c := Fixtures.unit("C", 30, 0)
	var battle := Fixtures.battle([a, b, c], [Fixtures.unit("Foe")])
	Fixtures.until_input(battle)
	var first := battle.heroes[0]
	var targets := battle.targets_for(first, BasicSkills.swap)
	assert_eq(_uids(targets), _uids([battle.heroes[1]]), "default offsets are -1 and +1")
	battle.submit(BasicSkills.swap, battle.heroes[1])
	assert_eq(battle.rank_of(first), 2)


func test_guard_redirects_attacks_to_the_guardian() -> void:
	var foe_attack := Fixtures.attack(5, 5)
	foe_attack.target_ranks.assign([2])
	var guard := SkillDef.new()
	guard.id = &"guard"
	guard.side = SkillDef.TargetSide.ALLY
	guard.can_target_self = false
	var guard_effect := EffectDef.make(EffectDef.Kind.GUARD)
	guard_effect.stacks = 2
	guard.effects.append(guard_effect)
	var battle := Fixtures.battle(
			[Fixtures.unit("Guardian", 30, 50, [guard]), Fixtures.unit("Ward", 30, 0)],
			[Fixtures.unit("Foe", 30, 40, [foe_attack])])
	Fixtures.until_input(battle)
	var guardian := battle.heroes[0]
	var ward := battle.heroes[1]
	battle.submit(guard, ward)
	var events := Fixtures.until_input(battle)
	assert_eq(Fixtures.of_type(events, &"guarded").size(), 1)
	assert_eq(ward.hp, 30)
	assert_eq(guardian.hp, 25)


func test_riposte_counters_the_attacker() -> void:
	var counter := Fixtures.attack(3, 3)
	var foe := Fixtures.unit("Foe", 30, 0)
	foe.riposte_skill = counter
	var battle := _hero_against(Fixtures.attack(1, 1), [foe])
	var enemy := battle.enemies[0]
	enemy.add_token(Tokens.RIPOSTE)
	var events := battle.submit(battle.current.def.skills[0], enemy)
	assert_eq(battle.heroes[0].hp, 27)
	assert_false(enemy.has_token(Tokens.RIPOSTE))
	assert_eq(Fixtures.of_type(events, &"skill").size(), 2)


func test_enemy_ai_respects_taunt() -> void:
	for seed_value in 30:
		var foe_attack := Fixtures.attack(1, 1)
		var battle := Fixtures.battle(
				[Fixtures.unit("A", 30, 0), Fixtures.unit("B", 30, 0)],
				[Fixtures.unit("Foe", 30, 50, [foe_attack])], seed_value)
		battle.heroes[1].add_token(Tokens.TAUNT, 3)
		var events := Fixtures.until_input(battle)
		var hits := Fixtures.of_type(events, &"damage")
		assert_eq(hits[0].uid, battle.heroes[1].uid, "seed %d" % seed_value)

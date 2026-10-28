extends TestCase


func _versus(resists: Dictionary = {}, ally_hp: float = 40.0) -> BalanceStats.Versus:
	var result := BalanceStats.Versus.new()
	result.resists.assign(resists)
	result.ally_hp = ally_hp
	return result


func _skill(damage: int, cooldown: int = 0) -> SkillDef:
	var skill := Fixtures.attack(damage, damage)
	skill.cooldown = cooldown
	return skill


func test_expected_damage_counts_crits_at_one_and_a_half_times_max() -> void:
	var numbers := BalanceStats.skill(Fixtures.attack(4, 6, 0.1), _versus(), 30)
	assert_almost_eq(numbers.average, 5.0)
	assert_almost_eq(numbers.damage, 0.9 * 5.0 + 0.1 * 9.0)


func test_multi_target_skills_count_one_unit_per_rank_in_range() -> void:
	var skill := _skill(4)
	skill.multi_target = true
	skill.target_ranks.assign([1, 2, 3])
	assert_almost_eq(BalanceStats.skill(skill, _versus(), 30).damage, 12.0)


func test_dots_count_their_whole_duration_after_resistance() -> void:
	var skill := Fixtures.debuff([EffectDef.make_dot(&"bleed", 2, 3)])
	var numbers := BalanceStats.skill(skill, _versus({&"bleed": 0.5}), 30)
	assert_almost_eq(numbers.dot, 3.0)
	assert_almost_eq(numbers.damage, 3.0)


func test_effects_that_need_a_token_are_left_out() -> void:
	var dot := EffectDef.make_dot(&"bleed", 2, 3)
	dot.requires_target_token = Tokens.COMBO
	assert_almost_eq(BalanceStats.skill(Fixtures.debuff([dot]), _versus(), 30).dot, 0.0)


func test_a_cooldown_spreads_the_damage_over_the_rounds() -> void:
	var numbers := BalanceStats.skill(_skill(6, 1), _versus(), 30)
	assert_almost_eq(numbers.damage_rd, 6.0 * 3 / BalanceStats.ROUNDS, "used on turns 1, 3 and 5")


func test_a_use_limit_caps_the_damage_per_round() -> void:
	var skill := _skill(6)
	skill.uses_per_battle = 1
	assert_almost_eq(BalanceStats.skill(skill, _versus(), 30).damage_rd, 6.0 / BalanceStats.ROUNDS)


func test_units_use_the_best_ready_skill_each_turn() -> void:
	var big := _skill(10, 2)
	var small := _skill(4)
	var unit := Fixtures.unit("Bruiser", 30, 0, [small, big])
	var numbers := BalanceStats.unit(unit, false, _versus())
	assert_almost_eq(numbers.turn, 10.0)
	assert_almost_eq(numbers.damage_rd, (10.0 + 4 + 4 + 10 + 4 + 4) / BalanceStats.ROUNDS)


func test_two_turns_a_round_double_the_rate() -> void:
	var unit := Fixtures.unit("Twin", 30, 0, [_skill(5)])
	unit.turns_per_round = 2
	assert_almost_eq(BalanceStats.unit(unit, false, _versus()).damage_rd, 10.0)


func test_heroes_count_only_their_first_five_skills() -> void:
	var skills: Array = []
	for i in 5:
		skills.append(_skill(1))
	skills.append(_skill(20))
	var hero := Fixtures.unit("Hero", 30, 0, skills)
	assert_almost_eq(BalanceStats.unit(hero, true, _versus()).turn, 1.0)
	assert_almost_eq(BalanceStats.unit(hero, false, _versus()).turn, 20.0, "enemies use them all")


func test_stun_sticks_past_the_average_stun_resistance() -> void:
	var skill := Fixtures.debuff([EffectDef.make_token(Tokens.STUN)])
	assert_almost_eq(BalanceStats.skill(skill, _versus({&"stun": 0.4}), 30).stun, 0.6)


func test_heal_shares_use_the_own_sides_average_hp_and_heal_crits() -> void:
	var skill := SkillDef.new()
	skill.side = SkillDef.TargetSide.ALLY
	skill.heal_fraction = 0.2
	var expected := 8.0 * (1.0 + Rules.HEAL_CRIT_CHANCE * (Rules.HEAL_CRIT_MULTIPLIER - 1.0))
	assert_almost_eq(BalanceStats.skill(skill, _versus({}, 40.0), 30).heal, expected)


func test_hero_stress_relief_counts_as_negative() -> void:
	var cry := SkillDef.new()
	cry.side = SkillDef.TargetSide.ALLY
	cry.stress = -2
	var hero := Fixtures.unit("Bard", 30, 0, [cry])
	assert_almost_eq(BalanceStats.unit(hero, true, _versus()).stress_rd, -2.0)


func test_versus_averages_the_other_sides_resistances_and_the_own_sides_hp() -> void:
	var a := Fixtures.unit("A", 20)
	a.resist_stun = 0.2
	var b := Fixtures.unit("B", 40)
	b.resist_stun = 0.6
	var heroes: Array[UnitDef] = [a, b]
	var versus := BalanceStats.versus(heroes, heroes)
	assert_almost_eq(versus.resists[&"stun"], 0.4)
	assert_almost_eq(versus.ally_hp, 30.0)


func test_ranks_text() -> void:
	var skill := Fixtures.attack(1, 2)
	skill.launch_ranks.assign([2, 1])
	skill.target_ranks.assign([3, 4])
	assert_eq(BalanceStats.ranks_text(skill), "12→34")
	skill.side = SkillDef.TargetSide.SELF
	assert_eq(BalanceStats.ranks_text(skill), "12→self")


func test_every_real_unit_has_numbers() -> void:
	var library := BalanceLibrary.new()
	var heroes_versus := BalanceStats.versus(library.heroes, library.enemies)
	for hero in library.heroes:
		assert_true(BalanceStats.unit(hero, true, heroes_versus).damage_rd > 0.0, hero.display_name)
	var enemies_versus := BalanceStats.versus(library.enemies, library.heroes)
	for enemy in library.enemies:
		var numbers := BalanceStats.unit(enemy, false, enemies_versus)
		assert_true(numbers.damage_rd > 0.0 or numbers.stress_rd > 0.0, enemy.display_name)

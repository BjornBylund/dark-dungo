extends TestCase


func _solo_hero(stress: int, seed_value: int = 1) -> Battle:
	var battle := Fixtures.battle([Fixtures.unit("Hero", 40, 50)], [Fixtures.unit("Dummy")], seed_value)
	battle.heroes[0].stress = stress
	Fixtures.until_input(battle)
	return battle


func test_pass_costs_two_stress() -> void:
	var battle := _solo_hero(0)
	battle.submit(BasicSkills.pass_turn, battle.current)
	assert_eq(battle.heroes[0].stress, Rules.PASS_STRESS)


func test_ten_stress_is_meltdown_or_resolute() -> void:
	var meltdowns := 0
	for seed_value in 400:
		var battle := _solo_hero(9, seed_value)
		var hero := battle.heroes[0]
		var events := battle.submit(BasicSkills.pass_turn, hero)
		if not Fixtures.of_type(events, &"meltdown").is_empty():
			meltdowns += 1
			assert_eq(hero.stress, Rules.MELTDOWN_STRESS)
			assert_eq(hero.hp, 4, "HP down to 10%")
			assert_eq(hero.resist(&"deathblow"), 0.6 + Rules.MELTDOWN_DEATHBLOW)
		else:
			assert_eq(Fixtures.of_type(events, &"resolute").size(), 1)
			assert_eq(hero.stress, 0)
	assert_between(meltdowns / 400.0, 0.74, 0.86, "meltdown rate")


func test_ally_death_stresses_the_party() -> void:
	var deaths := 0
	for seed_value in 40:
		var killer := Fixtures.unit("Killer", 100, 50, [Fixtures.attack(100, 100)])
		var victim := Fixtures.unit("Victim", 30, 0)
		victim.size = 1
		var battle := Fixtures.battle([victim, Fixtures.unit("Witness", 30, 0)], [killer], seed_value)
		var doomed := battle.heroes[0]
		var witness := battle.heroes[1]
		doomed.deaths_door = true
		battle.heroes[1].add_token(Tokens.STEALTH, 2)
		var events := Fixtures.until_input(battle)
		if Fixtures.of_type(events, &"death").is_empty():
			continue
		deaths += 1
		assert_eq(witness.stress, Rules.STRESS_ALLY_DIED, "seed %d" % seed_value)
	assert_true(deaths > 0, "some seed should fail the deathblow check")

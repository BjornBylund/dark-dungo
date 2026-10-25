extends TestCase


## A hero facing a fast enemy that hits for `damage` every turn.
func _hero_vs_brute(hero_hp: int, damage: int, seed_value: int = 1) -> Battle:
	var hero := Fixtures.unit("Hero", hero_hp, 0, [Fixtures.attack(1, 1)])
	var brute := Fixtures.unit("Brute", 500, 50, [Fixtures.attack(damage, damage)])
	return Fixtures.battle([hero], [brute], seed_value)


func test_hero_at_zero_hp_enters_deaths_door() -> void:
	var battle := _hero_vs_brute(10, 50)
	var events := Fixtures.until_input(battle)
	var hero := battle.heroes[0]
	assert_eq(Fixtures.of_type(events, &"deaths_door").size(), 1)
	assert_true(hero.deaths_door)
	assert_eq(hero.hp, 0)
	assert_eq(hero.token_count(Tokens.WEAK), Rules.DEATHS_DOOR_WEAK)
	assert_eq(hero.speed(), Rules.DEATHS_DOOR_SPEED)


func test_deathblow_survival_matches_resist_and_decays() -> void:
	var first_survived := 0
	var second_survived := 0
	var second_checks := 0
	for seed_value in 400:
		var battle := _hero_vs_brute(10, 50, seed_value)
		Fixtures.until_input(battle)
		var hero := battle.heroes[0]
		battle.submit(hero.def.skills[0], battle.enemies[0])
		var events := Fixtures.until_input(battle)
		if Fixtures.of_type(events, &"deathblow_resisted").is_empty():
			continue
		first_survived += 1
		assert_eq(hero.resist(&"deathblow"), 0.6 + Rules.DEATHBLOW_SURVIVE_PENALTY, "penalty after surviving")
		battle.submit(hero.def.skills[0], battle.enemies[0])
		events = Fixtures.until_input(battle)
		second_checks += 1
		if not Fixtures.of_type(events, &"deathblow_resisted").is_empty():
			second_survived += 1
	assert_between(first_survived / 400.0, 0.52, 0.68, "first check at 60%")
	assert_between(float(second_survived) / second_checks, 0.40, 0.60, "second check at 50%")


func test_healing_lifts_hero_off_deaths_door_but_keeps_weak() -> void:
	var heal := SkillDef.new()
	heal.id = &"heal"
	heal.side = SkillDef.TargetSide.SELF
	heal.heal_min = 5
	heal.heal_max = 5
	var hero := Fixtures.unit("Hero", 10, 0, [heal])
	var brute := Fixtures.unit("Brute", 500, 50, [Fixtures.attack(50, 50)])
	var battle := Fixtures.battle([hero], [brute])
	Fixtures.until_input(battle)
	var unit := battle.heroes[0]
	battle.submit(heal, unit)
	assert_false(unit.deaths_door)
	assert_true(unit.hp >= 5)
	assert_eq(unit.speed(), 0, "speed penalty removed")
	assert_true(unit.has_token(Tokens.WEAK), "Weak stays")


func test_enemy_leaves_corpse_that_holds_its_rank_then_decays() -> void:
	var hero := Fixtures.unit("Hero", 30, 50, [Fixtures.attack(100, 100)])
	var victim := Fixtures.unit("Victim", 10)
	victim.corpse_hp = 5
	var battle := Fixtures.battle([hero], [victim, Fixtures.unit("Behind", 1000)])
	Fixtures.until_input(battle)
	var corpse := battle.enemies[0]
	var behind := battle.enemies[1]
	var events := battle.submit(hero.skills[0], corpse)
	assert_true(Fixtures.of_type(events, &"death")[0].corpse)
	assert_true(corpse.is_corpse)
	assert_eq(battle.rank_of(behind), 2, "corpse holds rank 1")
	for round in 3:
		Fixtures.until_input(battle)
		battle.submit(BasicSkills.pass_turn, battle.current)
	Fixtures.until_input(battle)
	assert_eq(battle.rank_of(behind), 1, "corpse decayed after 3 rounds")


func test_hitting_a_corpse_destroys_it() -> void:
	var hero := Fixtures.unit("Hero", 30, 50, [Fixtures.attack(100, 100)])
	var victim := Fixtures.unit("Victim", 10)
	victim.corpse_hp = 5
	var battle := Fixtures.battle([hero], [victim, Fixtures.unit("Behind", 1000)])
	Fixtures.until_input(battle)
	battle.submit(hero.skills[0], battle.enemies[0])
	Fixtures.until_input(battle)
	var events := battle.submit(hero.skills[0], battle.enemies[0])
	assert_eq(Fixtures.of_type(events, &"removed")[0].reason, &"destroyed")
	assert_eq(battle.enemies.size(), 1)


func test_death_armor_absorbs_lethal_hits() -> void:
	var hero := Fixtures.unit("Hero", 30, 50, [Fixtures.attack(100, 100)])
	var tough := Fixtures.unit("Tough", 10)
	tough.death_armor = 1
	var battle := Fixtures.battle([hero], [tough, Fixtures.unit("Other", 1000)])
	var enemy := battle.enemies[0]
	for expected: Array in [[true, 1], [true, 0], [false, 0]]:
		Fixtures.until_input(battle)
		battle.submit(hero.skills[0], enemy)
		assert_eq([enemy.is_active(), enemy.death_armor], expected)


func test_execution_bypasses_death_armor() -> void:
	var skill := Fixtures.attack(100, 100)
	skill.execution = 1
	var hero := Fixtures.unit("Hero", 30, 50, [skill])
	var tough := Fixtures.unit("Tough", 10)
	tough.death_armor = 1
	var battle := Fixtures.battle([hero], [tough])
	Fixtures.until_input(battle)
	battle.submit(skill, battle.enemies[0])
	assert_eq(battle.state, Battle.State.VICTORY)


func test_victory_heals_heroes_up_to_twenty_percent() -> void:
	var hero := Fixtures.unit("Hero", 50, 0, [Fixtures.attack(100, 100)])
	var brute := Fixtures.unit("Brute", 10, 50, [Fixtures.attack(100, 100)])
	var battle := Fixtures.battle([hero], [brute])
	Fixtures.until_input(battle)
	var unit := battle.heroes[0]
	assert_true(unit.deaths_door)
	battle.submit(hero.skills[0], battle.enemies[0])
	assert_eq(battle.state, Battle.State.VICTORY)
	assert_eq(unit.hp, 10)
	assert_false(unit.deaths_door)
	assert_true(unit.tokens.is_empty(), "battle tokens cleared")

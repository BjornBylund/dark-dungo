extends TestCase


func test_damage_bonus_and_skill_rank_add_to_attack_mods() -> void:
	var result := Fixtures.hit_once(Fixtures.attack(10, 10), func(hero: Combatant, _target: Combatant) -> void:
		hero.damage_bonus = 0.2
		hero.skill_ranks[&"attack"] = 3)
	assert_eq(result.damage.amount, 14, "10 x (1 + 0.2 gear + 0.2 rank)")


func test_skill_rank_raises_healing() -> void:
	var heal := SkillDef.new()
	heal.id = &"heal"
	heal.side = SkillDef.TargetSide.SELF
	heal.heal_min = 10
	heal.heal_max = 10
	var hero := Fixtures.unit("Hero", 100, 50, [heal])
	var battle := Fixtures.battle([hero], [Fixtures.unit("Dummy")])
	Fixtures.until_input(battle)
	var unit := battle.heroes[0]
	unit.hp = 10
	unit.skill_ranks[&"heal"] = 5
	var events := battle.submit(heal, unit)
	var amount: int = Fixtures.of_type(events, &"heal")[0].amount
	assert_true(amount == 14 or amount == 21, "10 x 1.4, or x1.5 on a heal crit")


func test_skill_rank_pierces_resistance() -> void:
	for seed_value in 50:
		var result := Fixtures.hit_once(Fixtures.debuff([EffectDef.make_dot(&"bleed", 2)]),
				func(hero: Combatant, target: Combatant) -> void:
					target.def.resist_bleed = 0.3
					hero.skill_ranks[&"debuff"] = 4, seed_value)
		assert_false(result.target.dots.is_empty(), "rank 4 pierces 30%%, seed %d" % seed_value)


func test_low_hp_bonus_only_below_half_hp() -> void:
	var skill := Fixtures.attack(10, 10)
	skill.low_hp_bonus = 0.5
	assert_eq(Fixtures.hit_once(skill).damage.amount, 10)
	var result := Fixtures.hit_once(skill, func(hero: Combatant, _target: Combatant) -> void: hero.hp = 10)
	assert_eq(result.damage.amount, 15)


func test_self_damage_stops_at_one_hp() -> void:
	var skill := Fixtures.attack(1, 1)
	skill.self_damage = 5
	var result := Fixtures.hit_once(skill)
	assert_eq(result.hero.hp, 25)
	var hurt := Fixtures.of_type(result.events, &"damage").filter(func(e: Dictionary) -> bool:
		return e.get("cause") == &"self")
	assert_eq(hurt.size(), 1)
	result = Fixtures.hit_once(skill, func(hero: Combatant, _target: Combatant) -> void: hero.hp = 3)
	assert_eq(result.hero.hp, 1)
	assert_false(result.hero.deaths_door)


func test_crit_bonus_adds_to_skill_crit_chance() -> void:
	var battle := Fixtures.duel(Fixtures.attack(4, 8, 0.1))
	Fixtures.until_input(battle)
	var hero := battle.heroes[0]
	hero.crit_bonus = 0.05
	hero.skill_ranks[&"attack"] = 3
	var preview := battle.preview(hero, hero.def.skills[0], battle.enemies[0])
	assert_between(preview.crit_chance, 0.169, 0.171)

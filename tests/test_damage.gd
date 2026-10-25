extends TestCase


func test_plain_hit_rolls_within_range() -> void:
	for seed_value in 100:
		var result := Fixtures.hit_once(Fixtures.attack(3, 6), Callable(), seed_value)
		assert_between(result.damage.amount, 3, 6, "seed %d" % seed_value)


func test_block_halves_and_is_spent() -> void:
	var result := Fixtures.hit_once(Fixtures.attack(10, 10), func(_hero: Combatant, target: Combatant) -> void:
		target.add_token(Tokens.BLOCK, 2))
	assert_eq(result.damage.amount, 5)
	assert_eq(result.target.token_count(Tokens.BLOCK), 1, "one Block spent")


func test_block_plus_is_spent_before_block() -> void:
	var result := Fixtures.hit_once(Fixtures.attack(10, 10), func(_hero: Combatant, target: Combatant) -> void:
		target.add_token(Tokens.BLOCK)
		target.add_token(Tokens.BLOCK_PLUS))
	assert_eq(result.damage.amount, 3, "10 x 0.25 = 2.5 rounds to 3")
	assert_true(result.target.has_token(Tokens.BLOCK), "Block kept")
	assert_false(result.target.has_token(Tokens.BLOCK_PLUS), "Block+ spent")


func test_attack_and_defense_mods_multiply() -> void:
	var result := Fixtures.hit_once(Fixtures.attack(10, 10), func(hero: Combatant, target: Combatant) -> void:
		hero.add_token(Tokens.STRENGTH)
		target.add_token(Tokens.VULNERABLE))
	assert_eq(result.damage.amount, 23, "10 x 1.5 x 1.5 = 22.5")


func test_weak_halves_after_everything_else() -> void:
	var result := Fixtures.hit_once(Fixtures.attack(10, 10), func(hero: Combatant, target: Combatant) -> void:
		hero.add_token(Tokens.WEAK)
		target.add_token(Tokens.BLOCK))
	assert_eq(result.damage.amount, 3, "10 x 0.5 x 0.5 = 2.5")


func test_crit_deals_max_times_one_and_a_half() -> void:
	var result := Fixtures.hit_once(Fixtures.attack(4, 8), func(hero: Combatant, _target: Combatant) -> void:
		hero.add_token(Tokens.CRIT))
	assert_eq(result.damage.amount, 12)
	assert_true(result.damage.crit)


func test_damage_is_at_least_one() -> void:
	var result := Fixtures.hit_once(Fixtures.attack(1, 1), func(hero: Combatant, target: Combatant) -> void:
		hero.add_token(Tokens.WEAK)
		target.add_token(Tokens.BLOCK_PLUS))
	assert_eq(result.damage.amount, 1)


func test_combo_bonus_spends_combo_and_does_not_reapply() -> void:
	var skill := Fixtures.attack(10, 10)
	skill.combo_damage_bonus = 0.5
	skill.effects.append(EffectDef.make_token(Tokens.COMBO))
	var result := Fixtures.hit_once(skill, func(_hero: Combatant, target: Combatant) -> void:
		target.add_token(Tokens.COMBO))
	assert_eq(result.damage.amount, 15)
	assert_false(result.target.has_token(Tokens.COMBO), "Combo spent, not re-applied")


func test_combo_skill_applies_combo_when_target_has_none() -> void:
	var skill := Fixtures.attack(10, 10)
	skill.combo_damage_bonus = 0.5
	skill.effects.append(EffectDef.make_token(Tokens.COMBO))
	var result := Fixtures.hit_once(skill)
	assert_eq(result.damage.amount, 10)
	assert_true(result.target.has_token(Tokens.COMBO))


func test_strength_is_spent_on_a_miss() -> void:
	for seed_value in 20:
		var result := Fixtures.hit_once(Fixtures.attack(10, 10), func(hero: Combatant, target: Combatant) -> void:
			hero.add_token(Tokens.STRENGTH)
			target.add_token(Tokens.DODGE_PLUS), seed_value)
		assert_false(result.hero.has_token(Tokens.STRENGTH), "seed %d" % seed_value)
		assert_true(result.damage.is_empty() or result.damage.amount == 15, "seed %d" % seed_value)


func test_preview_matches_modifiers() -> void:
	var battle := Fixtures.duel(Fixtures.attack(4, 8))
	Fixtures.until_input(battle)
	var hero := battle.heroes[0]
	var dummy := battle.enemies[0]
	hero.add_token(Tokens.STRENGTH)
	dummy.add_token(Tokens.DODGE)
	var preview := battle.preview(hero, hero.def.skills[0], dummy)
	assert_eq(preview.damage_min, 6)
	assert_eq(preview.damage_max, 12)
	assert_eq(preview.crit_damage, 18)
	assert_eq(preview.hit_chance, 0.5)

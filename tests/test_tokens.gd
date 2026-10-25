extends TestCase


func _unit() -> Combatant:
	return Combatant.new(Fixtures.unit("Unit"), false)


func test_opposite_tokens_cancel_instead_of_stacking() -> void:
	var unit := _unit()
	unit.add_token(Tokens.BLOCK)
	var result := unit.add_token(Tokens.VULNERABLE)
	assert_false(unit.has_token(Tokens.BLOCK))
	assert_false(unit.has_token(Tokens.VULNERABLE))
	assert_eq(result.added, 0)
	assert_eq(result.negated.size(), 1)


func test_vulnerable_cancels_block_plus_before_block() -> void:
	var unit := _unit()
	unit.add_token(Tokens.BLOCK)
	unit.add_token(Tokens.BLOCK_PLUS)
	unit.add_token(Tokens.VULNERABLE)
	assert_true(unit.has_token(Tokens.BLOCK))
	assert_false(unit.has_token(Tokens.BLOCK_PLUS))


func test_stacks_stop_at_the_limit() -> void:
	var unit := _unit()
	unit.add_token(Tokens.BLOCK, 5)
	unit.add_token(Tokens.STRENGTH, 5)
	assert_eq(unit.token_count(Tokens.BLOCK), 3)
	assert_eq(unit.token_count(Tokens.STRENGTH), 2)


func test_one_shared_timer_per_token_type() -> void:
	var unit := _unit()
	unit.add_token(Tokens.BLOCK)
	unit.tick_tokens_turn_end()
	unit.add_token(Tokens.BLOCK)
	unit.tick_tokens_turn_end()
	assert_eq(unit.token_count(Tokens.BLOCK), 2, "still there after 2 turns")
	var expired := unit.tick_tokens_turn_end()
	assert_false(unit.has_token(Tokens.BLOCK), "gone after 3 turns, later stack did not refresh")
	assert_eq(expired.size(), 1)


func test_stealth_loses_one_stack_per_turn() -> void:
	var unit := _unit()
	unit.add_token(Tokens.STEALTH, 2)
	unit.tick_tokens_turn_end()
	assert_eq(unit.token_count(Tokens.STEALTH), 1)
	unit.tick_tokens_turn_end()
	assert_false(unit.has_token(Tokens.STEALTH))


func test_stun_waits_until_consumed() -> void:
	var unit := _unit()
	unit.add_token(Tokens.STUN)
	for i in 5:
		unit.tick_tokens_turn_end()
	assert_true(unit.has_token(Tokens.STUN))


func test_dodge_misses_about_half_the_time() -> void:
	var misses := 0
	for seed_value in 400:
		var result := Fixtures.hit_once(Fixtures.attack(5, 5), func(_hero: Combatant, target: Combatant) -> void:
			target.add_token(Tokens.DODGE), seed_value)
		if result.damage.is_empty():
			misses += 1
		assert_false(result.target.has_token(Tokens.DODGE), "Dodge spent either way")
	assert_between(misses / 400.0, 0.42, 0.58, "dodge rate")


func test_dodge_plus_misses_about_three_quarters() -> void:
	var misses := 0
	for seed_value in 400:
		var result := Fixtures.hit_once(Fixtures.attack(5, 5), func(_hero: Combatant, target: Combatant) -> void:
			target.add_token(Tokens.DODGE_PLUS), seed_value)
		if result.damage.is_empty():
			misses += 1
	assert_between(misses / 400.0, 0.67, 0.83, "dodge+ rate")


func test_blind_misses_about_half_the_time() -> void:
	var misses := 0
	for seed_value in 400:
		var result := Fixtures.hit_once(Fixtures.attack(5, 5), func(hero: Combatant, _target: Combatant) -> void:
			hero.add_token(Tokens.BLIND), seed_value)
		if result.damage.is_empty():
			misses += 1
		assert_false(result.hero.has_token(Tokens.BLIND), "Blind spent either way")
	assert_between(misses / 400.0, 0.42, 0.58, "blind rate")


func test_second_daze_becomes_stun() -> void:
	var result := Fixtures.hit_once(Fixtures.debuff([EffectDef.make_token(Tokens.DAZE)]),
			func(_hero: Combatant, target: Combatant) -> void: target.add_token(Tokens.DAZE))
	assert_true(result.target.has_token(Tokens.STUN))
	assert_false(result.target.has_token(Tokens.DAZE))

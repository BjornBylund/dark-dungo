extends TestCase


func _turn_order(events: Array[Dictionary]) -> Array:
	return Fixtures.of_type(events, &"turn_start").map(func(e: Dictionary) -> int: return e.uid)


func test_speed_beats_the_random_roll_when_far_apart() -> void:
	for seed_value in 50:
		var battle := Fixtures.battle([Fixtures.unit("Slow", 30, 2)], [Fixtures.unit("Fast", 30, 9)], seed_value)
		var events := Fixtures.until_input(battle)
		assert_eq(_turn_order(events)[0], battle.enemies[0].uid, "seed %d" % seed_value)


func test_close_speeds_are_decided_by_the_roll() -> void:
	var hero_first := 0
	for seed_value in 200:
		var battle := Fixtures.battle([Fixtures.unit("Hero", 30, 4)], [Fixtures.unit("Foe", 30, 4)], seed_value)
		var events := Fixtures.until_input(battle)
		if _turn_order(events)[0] == battle.heroes[0].uid:
			hero_first += 1
	assert_between(hero_first / 200.0, 0.35, 0.65)


func test_speed_token_acts_first_next_round() -> void:
	var battle := Fixtures.battle([Fixtures.unit("Slow", 30, 0)], [Fixtures.unit("Fast", 30, 9)])
	Fixtures.until_input(battle)
	var hero := battle.heroes[0]
	hero.add_token(Tokens.SPEED)
	battle.submit(BasicSkills.pass_turn, hero)
	var events := Fixtures.until_input(battle)
	assert_eq(_turn_order(events)[0], hero.uid)


func test_daze_moves_the_turn_to_the_end_of_the_round() -> void:
	var battle := Fixtures.battle([Fixtures.unit("Hero", 30, 50)],
			[Fixtures.unit("Dazed", 30, 40), Fixtures.unit("Slow", 30, 0)])
	Fixtures.until_input(battle)
	var dazed := battle.enemies[0]
	dazed.add_token(Tokens.DAZE)
	battle.submit(BasicSkills.pass_turn, battle.current)
	var events := Fixtures.until_input(battle)
	var order := _turn_order(events)
	assert_eq(order, [battle.enemies[1].uid, dazed.uid, battle.heroes[0].uid])


func test_extra_turns_are_never_back_to_back() -> void:
	for seed_value in 50:
		var twice := Fixtures.unit("Twice", 30, 5)
		twice.turns_per_round = 2
		var battle := Fixtures.battle([Fixtures.unit("Hero", 30, 5)], [twice], seed_value)
		var events := Fixtures.until_input(battle)
		if battle.state == Battle.State.AWAITING_INPUT:
			events.append_array(battle.submit(BasicSkills.pass_turn, battle.current))
			events.append_array(Fixtures.until_input(battle))
		var order := _turn_order(events)
		for i in range(1, mini(order.size(), 3)):
			assert_ne(order[i], order[i - 1], "seed %d order %s" % [seed_value, order])

extends TestCase


func _waiting_for(hero: UnitDef, foes: Array, allies: Array = []) -> Battle:
	var battle := Fixtures.battle([hero] + allies, foes)
	Fixtures.until_input(battle)
	return battle


func test_finishes_off_a_dangerous_enemy_over_chipping_a_healthy_one() -> void:
	var hit := Fixtures.attack(6, 6)
	var hero := Fixtures.unit("Hero", 30, 50, [hit])
	var weak_but_deadly := Fixtures.unit("Assassin", 30, 0, [Fixtures.attack(10, 12)])
	var sturdy := Fixtures.unit("Wall", 60, 0, [Fixtures.attack(1, 2)])
	var battle := _waiting_for(hero, [sturdy, weak_but_deadly])
	battle.enemies[1].hp = 5
	var choice := AutoPlayer.best(battle)
	assert_eq(choice[1].display_name, "Assassin")


func test_finishes_the_last_enemy_even_at_a_cost() -> void:
	var lash := Fixtures.attack(4, 6)
	lash.self_damage = 6
	var hero := Fixtures.unit("Hero", 50, 50, [lash])
	var battle := _waiting_for(hero, [Fixtures.unit("Spitter", 15, 0, [Fixtures.attack(1, 1)])])
	battle.heroes[0].hp = 12
	battle.enemies[0].hp = 2
	assert_eq(AutoPlayer.best(battle)[0], lash, "attacks rather than passing")


func test_heals_an_ally_on_deaths_door_over_a_small_hit() -> void:
	var heal := SkillDef.new()
	heal.id = &"heal"
	heal.side = SkillDef.TargetSide.ALLY
	heal.heal_min = 6
	heal.heal_max = 6
	var hero := Fixtures.unit("Healer", 30, 50, [Fixtures.attack(2, 3), heal])
	var ally := Fixtures.unit("Ally", 30, 0)
	var battle := _waiting_for(hero, [Fixtures.unit("Foe", 40, 0, [Fixtures.attack(4, 6)])], [ally])
	var hurt := battle.heroes[1]
	hurt.hp = 0
	hurt.deaths_door = true
	var choice := AutoPlayer.best(battle)
	assert_eq(choice[0], heal)
	assert_eq(choice[1], hurt)


func test_stuns_the_enemy_that_hits_hardest() -> void:
	var stun := Fixtures.debuff([EffectDef.make_token(Tokens.STUN)])
	var hero := Fixtures.unit("Hero", 30, 50, [stun, Fixtures.attack(1, 1)])
	var battle := _waiting_for(hero, [Fixtures.unit("Pup", 40, 0, [Fixtures.attack(1, 2)]),
			Fixtures.unit("Ogre", 40, 0, [Fixtures.attack(12, 14)])])
	var choice := AutoPlayer.best(battle)
	assert_eq(choice[0], stun)
	assert_eq(choice[1].display_name, "Ogre")


func test_guards_only_from_the_sturdier_side() -> void:
	var guard := SkillDef.new()
	guard.id = &"guard"
	guard.side = SkillDef.TargetSide.ALLY
	guard.can_target_self = false
	guard.effects.assign([EffectDef.make(EffectDef.Kind.GUARD)])
	guard.effects[0].stacks = 2
	var hero := Fixtures.unit("Guard", 40, 50, [guard, Fixtures.attack(4, 5)])
	var ally := Fixtures.unit("Ward", 40, 0)
	var foe := Fixtures.unit("Foe", 60, 0, [Fixtures.attack(8, 10)])
	var battle := _waiting_for(hero, [foe], [ally])
	battle.heroes[0].hp = 10
	assert_eq(AutoPlayer.best(battle)[0].id, &"attack", "a hurt guard attacks instead")
	battle.heroes[0].hp = 40
	battle.heroes[1].hp = 8
	assert_eq(AutoPlayer.best(battle)[0], guard, "a healthy guard covers a hurt ally")


func test_always_picks_something_usable() -> void:
	var sandbox: SandboxDef = load("res://content/sandbox.tres")
	var run := SandboxRun.new(sandbox, 3)
	var battle := run.start_next_wave()
	for turn in 60:
		Fixtures.until_input(battle)
		if battle.state != Battle.State.AWAITING_INPUT:
			break
		var choice := AutoPlayer.best(battle)
		assert_true(battle.can_use(battle.current, choice[0]), choice[0].display_name)
		assert_true(choice[1] in battle.targets_for(battle.current, choice[0]), "a valid target")
		battle.submit(choice[0], choice[1])

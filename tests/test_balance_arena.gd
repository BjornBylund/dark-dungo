extends TestCase

const NO_SAVE := "user://balance_arena_test_missing.json"
const TEMP_SAVE := "user://balance_arena_test.json"


func _arena() -> Array:
	var library := BalanceLibrary.new()
	return [library, BalanceArena.loaded(library, NO_SAVE)]


func test_starts_with_four_heroes_against_the_first_boss() -> void:
	var made := _arena()
	var library: BalanceLibrary = made[0]
	var arena: BalanceArena = made[1]
	assert_eq(arena.slots.size(), 4)
	assert_eq(arena.slots[0].hero, library.campaign.starting_heroes[0])
	assert_eq(arena.slots[0].skills.size(), Rules.SKILL_SLOTS)
	assert_eq(arena.encounter, library.campaign.regions[0].boss)
	assert_eq(arena.preset.name, "Base")
	assert_eq(arena.title, arena.encounter.display_name)


func test_the_fight_uses_the_setup() -> void:
	var made := _arena()
	var library: BalanceLibrary = made[0]
	var arena: BalanceArena = made[1]
	var hero: UnitDef = arena.slots[0].hero
	arena.slots[0].skills = [hero.skills[10]]
	var trinket: TrinketDef = library.trinkets.filter(func(t: TrinketDef) -> bool: return t.hero == null)[0]
	arena.slots[0].trinkets = [trinket]
	arena.hp = 0.5
	arena.stress = 4
	arena.preset = library.targets.preset_named("Veteran")
	var battle := arena.battle(7)
	var first := battle.heroes[0]
	assert_eq(first.skills, [hero.skills[10]] as Array[SkillDef], "the chosen loadout")
	assert_eq(first.hp, roundi(first.max_hp * 0.5), "starting HP")
	assert_eq(first.stress, 4)
	assert_true(first.max_hp > hero.max_hp, "Veteran gear adds HP")
	assert_almost_eq(battle.enemies[0].damage_bonus, CampaignRules.ENEMY_DAMAGE_BONUS[CampaignRules.Tier.VETERAN])
	assert_eq(battle.enemies.size(), arena.encounter.enemies.size())


func test_plays_up_to_its_goal_and_keeps_the_last_finished_run() -> void:
	var arena: BalanceArena = _arena()[1]
	arena.restart(6)
	while not arena.is_done():
		arena.step(5)
	assert_eq(arena.played(), 6)
	var win := arena.rate("wins")
	assert_true(arena.heroes.has(arena.slots[0].hero))
	assert_true(arena.usage(arena.slots[0].hero, arena.slots[0].skills[0]) >= 0.0)
	arena.restart(6)
	assert_eq(arena.played(), 0)
	assert_almost_eq(arena.previous.win, win)
	arena.restart(6)
	assert_almost_eq(arena.previous.win, win, "an unfinished run doesn't replace it")


func test_the_same_setup_plays_the_same() -> void:
	var arena: BalanceArena = _arena()[1]
	arena.restart(3)
	while not arena.is_done():
		arena.step(5)
	var first := arena.totals.duplicate()
	arena.restart(3)
	while not arena.is_done():
		arena.step(5)
	assert_eq(arena.totals, first)


func test_the_setup_is_kept_between_sessions() -> void:
	var made := _arena()
	var library: BalanceLibrary = made[0]
	var arena: BalanceArena = made[1]
	var hero: UnitDef = library.heroes[3]
	arena.slots[1] = {hero = hero, skills = [hero.skills[2], hero.skills[7]], trinkets = []}
	arena.encounter = library.encounters[2]
	arena.preset = library.targets.preset_named("Champion")
	arena.hp = 0.35
	arena.stress = 6
	arena.save_setup(TEMP_SAVE)
	var again := BalanceArena.loaded(library, TEMP_SAVE)
	DirAccess.remove_absolute(TEMP_SAVE)
	assert_eq(again.slots[1].hero, hero)
	assert_eq(again.slots[1].skills, [hero.skills[2], hero.skills[7]] as Array[SkillDef])
	assert_eq(again.encounter, library.encounters[2])
	assert_eq(again.preset.name, "Champion")
	assert_almost_eq(again.hp, 0.35)
	assert_eq(again.stress, 6)


func test_an_empty_party_or_encounter_plays_nothing() -> void:
	var arena: BalanceArena = _arena()[1]
	for slot in arena.slots:
		slot.hero = null
	arena.restart()
	assert_false(arena.is_ready())
	assert_true(arena.is_done())

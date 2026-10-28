extends TestCase

const TINY := {encounter = 2, skill = 1, trinket = 1}


func _sweep(counts: Dictionary = TINY, preset_name: String = "Base") -> Array:
	var library := BalanceLibrary.new()
	return [library, BalanceSweep.of(library, library.targets.preset_named(preset_name), BalanceSweep.Size.QUICK, counts)]


func test_the_plan_covers_every_encounter_skill_and_trinket() -> void:
	var made := _sweep()
	var library: BalanceLibrary = made[0]
	var sweep: BalanceSweep = made[1]
	var skills := 0
	for hero in library.heroes:
		skills += hero.skills.size()
	assert_eq(sweep.fight_count(), library.encounters.size() * 2 + skills * 2 + library.trinkets.size() * 2)


func test_paired_fights_differ_only_in_what_they_measure() -> void:
	var sweep: BalanceSweep = _sweep()[1]
	var checked := 0
	for i in sweep._plan.size():
		var job: Dictionary = sweep._plan[i]
		if job.group == &"sweep" or not job.with:
			continue
		var with := sweep._setup(job)
		var without := sweep._setup(sweep._plan[i + 1])
		assert_eq(with.party, without.party, "same line-up")
		assert_eq(with.encounter, without.encounter, "same encounter")
		var at: int = with.party.find(job.hero)
		for p in with.party.size():
			if p == at and job.group == &"skill":
				assert_true(job.subject in with.loadouts[p] and job.subject not in without.loadouts[p], "skill swapped out")
				var differing: Array = with.loadouts[p].filter(func(s: SkillDef) -> bool: return s not in without.loadouts[p])
				assert_eq(differing.size(), 1, "only the measured skill differs")
			elif p == at and job.group == &"trinket":
				assert_true(job.subject in with.trinkets[p] and job.subject not in without.trinkets[p], "trinket taken off")
			else:
				assert_eq(with.loadouts[p], without.loadouts[p], "other heroes' skills alike")
				assert_eq(with.trinkets[p], without.trinkets[p], "other heroes' trinkets alike")
		checked += 1
		if checked >= 40:
			break


func test_loadouts_are_five_of_the_heros_own_skills() -> void:
	var sweep: BalanceSweep = _sweep()[1]
	var setup := sweep._setup(sweep._plan[0])
	assert_eq(setup.party.size(), 4)
	for p in setup.party.size():
		assert_eq(setup.loadouts[p].size(), Rules.SKILL_SLOTS)
		for skill: SkillDef in setup.loadouts[p]:
			assert_true(skill in setup.party[p].skills)


func test_presets_with_trinkets_dress_every_hero_in_ones_they_may_wear() -> void:
	var sweep: BalanceSweep = _sweep(TINY, "Apprentice")[1]
	var setup := sweep._setup(sweep._plan[0])
	for p in setup.party.size():
		assert_eq(setup.trinkets[p].size(), CampaignRules.TRINKET_SLOTS)
		for trinket: TrinketDef in setup.trinkets[p]:
			assert_true(trinket.hero == null or trinket.hero == setup.party[p], trinket.display_name)


func test_the_same_content_plays_out_the_same() -> void:
	var first: BalanceSweep = _sweep()[1]
	var second: BalanceSweep = _sweep()[1]
	for i in 3:
		var a := first.fight(first._plan[i])
		var b := second.fight(second._plan[i])
		assert_eq([a.win, a.rounds, a.lost], [b.win, b.rounds, b.lost], "fight %d" % i)


func test_results_are_keyed_by_the_librarys_own_content() -> void:
	var made := _sweep({encounter = 2, skill = 1, trinket = 0})
	var library: BalanceLibrary = made[0]
	var sweep: BalanceSweep = made[1]
	sweep.start(0)
	var results := sweep.results()
	assert_eq(results.played, sweep.fight_count())
	for encounter in library.encounters:
		assert_eq(results.encounters[encounter].n, 2, encounter.display_name)
	for hero in library.heroes:
		for skill in hero.skills:
			assert_true(results.pairs.has(skill), "%s measured" % skill.display_name)
	assert_true(results.heroes.has(library.heroes[0]))
	assert_true(results.usage.has(library.enemies[0].skills[0]))


func test_unsaved_edits_are_what_gets_simulated() -> void:
	var library := BalanceLibrary.new()
	var enemy := library.enemies[0]
	library.set_value(enemy, enemy, &"max_hp", 999)
	var sweep := BalanceSweep.of(library, library.targets.preset_named("Base"), BalanceSweep.Size.QUICK, TINY)
	assert_eq(sweep._copy.enemies[0].max_hp, 999)
	library.undo()
	assert_eq(sweep._copy.enemies[0].max_hp, 999, "the copy keeps what was there at the start")
	assert_eq(sweep.version, library.version - 1)


func test_worker_processes_play_the_same_fights() -> void:
	var made := _sweep({encounter = 1, skill = 0, trinket = 0})
	var sweep: BalanceSweep = made[1]
	sweep.start(2)
	sweep.wait()
	var results := sweep.results()
	assert_eq(results.played, sweep.fight_count(), "every fight came back")
	var here: BalanceSweep = _sweep({encounter = 1, skill = 0, trinket = 0})[1]
	here.start(0)
	var expected := here.results()
	for encounter: Resource in expected.encounters:
		var got: Dictionary = results.encounters[encounter]
		var want: Dictionary = expected.encounters[encounter]
		var name: String = encounter.get(&"display_name")
		assert_eq([got.n, got.wins, got.deaths, got.rounds], [want.n, want.wins, want.deaths, want.rounds], name)
		assert_almost_eq(got.lost, want.lost, name + " HP lost")

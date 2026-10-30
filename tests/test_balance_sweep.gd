extends TestCase

const TINY := {encounter = 2, skill = 1, trinket = 1, talent = 1}


func _sweep(counts: Dictionary = TINY, preset_name: String = "Base") -> Array:
	var library := BalanceLibrary.new()
	return [library, BalanceSweep.of(library, library.targets.preset_named(preset_name), BalanceSweep.Size.QUICK, counts)]


func test_the_plan_covers_every_encounter_skill_trinket_and_talent() -> void:
	var made := _sweep()
	var library: BalanceLibrary = made[0]
	var sweep: BalanceSweep = made[1]
	var skills := 0
	var talents := 0
	for hero in library.heroes:
		skills += hero.skills.size()
		talents += hero.talents.size()
	assert_eq(sweep.fight_count(), library.encounters.size() * 2 + skills * 2 + library.trinkets.size() * 2 + talents * 2)


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
			elif p == at and job.group == &"talent":
				assert_true(job.subject in with.talents[p] and job.subject not in without.talents[p], "talent swapped")
				var others: Array = without.talents[p].filter(func(t: TalentDef) -> bool: return t not in with.talents[p])
				assert_eq(others.size(), 1, "for one other talent")
				assert_eq(job.hero.talents.find(others[0]) / 3, job.hero.talents.find(job.subject) / 3, "of its row")
			else:
				assert_eq(with.loadouts[p], without.loadouts[p], "other heroes' skills alike")
				assert_eq(with.trinkets[p], without.trinkets[p], "other heroes' trinkets alike")
				assert_eq(with.talents[p], without.talents[p], "other heroes' talents alike")
		checked += 1
	assert_true(checked > 0)


func test_heroes_take_a_talent_on_each_row_their_level_opens() -> void:
	var base: BalanceSweep = _sweep(TINY, "Base")[1]
	var setup := base._setup(base._plan[0])
	for p in setup.party.size():
		assert_eq(setup.talents[p].size(), 0, "level 0: no talents")
	var veteran: BalanceSweep = _sweep(TINY, "Veteran")[1]
	setup = veteran._setup(veteran._plan[0])
	var rows := CampaignRules.TALENT_LEVELS.filter(func(at: int) -> bool: return veteran.preset.level >= at).size()
	for p in setup.party.size():
		var hero: UnitDef = setup.party[p]
		assert_eq(setup.talents[p].size(), rows)
		for row in rows:
			assert_eq(hero.talents.find(setup.talents[p][row]) / 3, row, "one from each open row")
	var record := BalanceSweep.record(setup.party[0], setup.loadouts[0], [], veteran.preset, setup.talents[0])
	assert_eq(record.chosen_talents().size(), rows, "the record takes them")


func test_talents_are_measured_on_copies_as_edited() -> void:
	var library := BalanceLibrary.new()
	var talent := library.talents[0]
	library.set_value(talent, talent, &"display_name", "Edited")
	var sweep := BalanceSweep.of(library, library.targets.preset_named("Base"), BalanceSweep.Size.QUICK, TINY)
	var copied: TalentDef = sweep._copy.heroes[library.heroes.find(library.hero_of(talent))].talents[0]
	assert_ne(copied, talent, "a copy")
	assert_eq(copied.display_name, "Edited")
	assert_eq(sweep._copy.original[copied], talent)
	library.undo()


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
	var made := _sweep({encounter = 2, skill = 1, trinket = 0, talent = 1})
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
	for talent in library.talents:
		assert_true(results.pairs.has(talent), "%s measured" % talent.display_name)
	assert_true(results.heroes.has(library.heroes[0]))
	assert_true(results.usage.has(library.enemies[0].skills[0]))


func test_unsaved_edits_are_what_gets_simulated() -> void:
	var library := BalanceLibrary.new()
	var enemy := library.enemies[0]
	library.set_value(enemy, enemy, &"max_hp", 999)
	var sweep := BalanceSweep.of(library, library.targets.preset_named("Base"), BalanceSweep.Size.QUICK, TINY)
	assert_eq(sweep._copy.enemies[0].max_hp, 999)
	assert_eq(sweep.state, library.state())
	library.undo()
	assert_eq(sweep._copy.enemies[0].max_hp, 999, "the copy keeps what was there at the start")
	assert_ne(sweep.state, library.state(), "the content moved on")


func test_worker_processes_play_the_same_fights() -> void:
	var counts := {encounter = 1, skill = 0, trinket = 0, talent = 0}
	var made := _sweep(counts, "Veteran")
	var sweep: BalanceSweep = made[1]
	sweep.start(2)
	sweep.wait()
	var results := sweep.results()
	assert_eq(results.played, sweep.fight_count(), "every fight came back")
	var here: BalanceSweep = _sweep(counts, "Veteran")[1]
	here.start(0)
	var expected := here.results()
	for encounter: Resource in expected.encounters:
		var got: Dictionary = results.encounters[encounter]
		var want: Dictionary = expected.encounters[encounter]
		var name: String = encounter.get(&"display_name")
		assert_eq([got.n, got.wins, got.deaths, got.rounds], [want.n, want.wins, want.deaths, want.rounds], name)
		assert_almost_eq(got.lost, want.lost, name + " HP lost")

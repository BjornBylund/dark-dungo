## Checks the campaign's content and plays missions with random parties from the
## whole cast, printing how often each class's parties complete them.
extends TestCase

const CAMPAIGN_PATH := "res://content/campaign.tres"
const RUNS := 160
const MAX_ROUNDS := 60


func _def() -> CampaignDef:
	return load(CAMPAIGN_PATH)


func _cast() -> Array[UnitDef]:
	var cast: Array[UnitDef] = []
	cast.append_array(_def().starting_heroes)
	cast.append_array(_def().arrivals)
	return cast


func test_cast_has_eight_heroes_with_five_skills_and_art() -> void:
	var cast := _cast()
	assert_eq(cast.size(), 8)
	for hero in cast:
		assert_eq(hero.skills.size(), 5, hero.display_name)
		assert_true(hero.sprite != null, hero.display_name + " sprite")
		for skill in hero.skills:
			assert_true(skill.icon != null, "%s/%s icon" % [hero.display_name, skill.id])


func test_every_hero_can_act_from_every_rank() -> void:
	for hero in _cast():
		for rank in range(1, 5):
			var usable := hero.skills.any(func(skill: SkillDef) -> bool: return rank in skill.launch_ranks)
			assert_true(usable, "%s from rank %d" % [hero.display_name, rank])


func test_encounters_fit_in_four_ranks() -> void:
	var groups: Array[EncounterDef] = []
	groups.append_array(_def().encounters)
	groups.append_array(_def().finales)
	assert_true(groups.size() >= 5)
	for group in groups:
		var ranks := 0
		for enemy in group.enemies:
			ranks += enemy.size
		assert_true(ranks <= Rules.RANKS, group.display_name)


func test_random_parties_finish_apprentice_missions() -> void:
	var stalled := 0
	var completed := 0
	var by_class := {}
	for seed_value in RUNS:
		var campaign := Campaign.create(_def(), seed_value)
		for hero in campaign.heroes:
			hero.arrived = true
			hero.recruited = true
		var pool := campaign.roster()
		var party: Array[HeroRecord] = []
		while party.size() < 4:
			var pick := pool[campaign.rng.randi_range(0, pool.size() - 1)]
			if pick not in party:
				party.append(pick)
		var mission := campaign._make_mission(CampaignRules.Tier.APPRENTICE, CampaignRules.Length.MEDIUM)
		campaign.board.append(mission)
		var run := campaign.embark(mission, party)
		while run.has_next_fight():
			var battle := run.start_next_fight()
			while battle.state != Battle.State.VICTORY and battle.state != Battle.State.DEFEAT:
				if battle.round_number > MAX_ROUNDS:
					stalled += 1
					break
				battle.advance()
				if battle.state == Battle.State.AWAITING_INPUT:
					var choice := AutoPlayer.sensible(battle)
					battle.submit(choice[0], choice[1])
			if battle.round_number > MAX_ROUNDS:
				break
			run.finish_fight()
		var won := run.outcome == MissionRun.Outcome.COMPLETED
		if won:
			completed += 1
		for hero in party:
			var entry: Array = by_class.get(hero.display_name, [0, 0])
			by_class[hero.display_name] = [entry[0] + int(won), entry[1] + 1]
	var rates: Array[String] = []
	for name: String in by_class:
		rates.append("%s %d%%" % [name, roundi(100.0 * by_class[name][0] / by_class[name][1])])
	print("        medium Apprentice, random parties: completed %d%%; by class: %s" % [
			roundi(100.0 * completed / RUNS), ", ".join(rates)])
	assert_eq(stalled, 0, "battles that hit %d rounds" % MAX_ROUNDS)

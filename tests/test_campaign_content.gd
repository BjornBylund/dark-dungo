## Checks the campaign's content and plays whole mission maps with random
## parties from the cast. The samples are small enough to keep the suite quick;
## for win rates use scripts/balance.ps1 and tools/balance_probe.gd.
extends TestCase

const CAMPAIGN_PATH := "res://content/campaign.tres"
const RUNS := 40
const MAX_ROUNDS := 60
const ELITE_RUNS := 20


func _def() -> CampaignDef:
	return load(CAMPAIGN_PATH)


func _cast() -> Array[UnitDef]:
	var cast: Array[UnitDef] = []
	cast.append_array(_def().starting_heroes)
	cast.append_array(_def().recruits)
	return cast


func test_cast_has_seven_heroes_with_eleven_skills_and_art() -> void:
	var cast := _cast()
	assert_eq(cast.size(), 7)
	for hero in cast:
		assert_eq(hero.skills.size(), 11, hero.display_name)
		assert_true(hero.sprite != null, hero.display_name + " sprite")
		for skill in hero.skills:
			assert_true(skill.icon != null, "%s/%s icon" % [hero.display_name, skill.id])


func test_every_hero_can_act_from_every_rank_with_the_starting_skills() -> void:
	for hero in _cast():
		var starting := hero.skills.slice(0, Rules.SKILL_SLOTS)
		for rank in range(1, 5):
			var usable := starting.any(func(skill: SkillDef) -> bool: return rank in skill.launch_ranks)
			assert_true(usable, "%s from rank %d" % [hero.display_name, rank])


func test_regions_have_fights_a_finale_and_a_place_on_the_map() -> void:
	var regions := _def().regions
	assert_eq(regions.size(), 3)
	for region in regions:
		assert_true(region.encounters.size() >= 2, "%s encounters" % region.id)
		assert_true(region.finales.size() >= 1, "%s finale" % region.id)
		assert_true(region.elites.size() >= 1, "%s elite" % region.id)
		assert_true(region.map_position != Vector2.ZERO, "%s map position" % region.id)
	assert_true(_def().expedition_background != null)


func test_events_have_text_and_working_choices() -> void:
	var cast := _cast()
	var all: Array[EventDef] = []
	all.append_array(_def().events)
	assert_eq(all.size(), 4, "shared events")
	for region in _def().regions:
		assert_eq(region.events.size(), 2, "%s events" % region.id)
		all.append_array(region.events)
	for event in all:
		assert_true(event.title != "" and event.text != "", "%s has text" % event.id)
		assert_true(event.choices.size() >= 2, "%s has choices" % event.id)
		for choice in event.choices:
			assert_true(choice.label != "" and choice.success_text != "", "%s/%s" % [event.id, choice.label])
			if choice.chance < 1.0:
				assert_true(choice.failure_text != "", "%s/%s failure text" % [event.id, choice.label])
			if choice.requires:
				assert_true(choice.requires in cast, "%s needs a hero in the cast" % event.id)
			for outcome in choice.success + choice.failure:
				if outcome.kind == EventOutcomeDef.Kind.TOKEN:
					assert_true(Tokens.RULES.has(outcome.token), "%s token" % event.id)


func test_encounters_fit_in_four_ranks() -> void:
	var groups: Array[EncounterDef] = []
	for region in _def().regions:
		groups.append_array(region.encounters)
		groups.append_array(region.elites)
		groups.append_array(region.finales)
	assert_true(groups.size() >= 5)
	for group in groups:
		var ranks := 0
		for enemy in group.enemies:
			ranks += enemy.size
		assert_true(ranks <= Rules.RANKS, group.display_name)


## Fresh random parties of level-0 heroes against each region's elite group at Apprentice.
func test_elite_fights_are_winnable() -> void:
	var cast := _cast()
	for region in _def().regions:
		var wins := 0
		for seed_value in ELITE_RUNS:
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var heroes: Array[Combatant] = []
			var picked: Array[UnitDef] = []
			while picked.size() < 4:
				var pick := cast[rng.randi_range(0, cast.size() - 1)]
				if pick not in picked:
					picked.append(pick)
					heroes.append(Growth.hero_combatant(HeroRecord.new(pick)))
			var enemies: Array[Combatant] = []
			for enemy in region.elites[0].enemies:
				enemies.append(Growth.enemy_combatant(enemy, CampaignRules.Tier.APPRENTICE))
			var battle := Battle.new(heroes, enemies, rng)
			while battle.state != Battle.State.VICTORY and battle.state != Battle.State.DEFEAT:
				assert_true(battle.round_number <= MAX_ROUNDS, "%s stalled" % region.id)
				if battle.round_number > MAX_ROUNDS:
					break
				battle.advance()
				if battle.state == Battle.State.AWAITING_INPUT:
					var choice := AutoPlayer.sensible(battle)
					battle.submit(choice[0], choice[1])
			wins += int(battle.state == Battle.State.VICTORY)
		assert_true(wins > 0, "nobody beats %s" % region.elites[0].display_name)


func test_random_parties_finish_apprentice_missions() -> void:
	var stalled := 0
	for seed_value in RUNS:
		var campaign := Campaign.create(_def(), seed_value)
		for hero in campaign.heroes:
			hero.recruited = true
		var pool := campaign.roster()
		var party: Array[HeroRecord] = []
		while party.size() < 4:
			var pick := pool[campaign.rng.randi_range(0, pool.size() - 1)]
			if pick not in party:
				party.append(pick)
		var region := campaign.def.regions[seed_value % campaign.def.regions.size()]
		var mission := campaign._make_mission(CampaignRules.Tier.APPRENTICE, CampaignRules.Length.MEDIUM, region)
		campaign.board.append(mission)
		var run := campaign.embark(mission, party)
		if not MapAutoPlayer.play(run, MAX_ROUNDS):
			stalled += 1
	assert_eq(stalled, 0, "battles that hit %d rounds" % MAX_ROUNDS)

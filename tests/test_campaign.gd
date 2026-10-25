extends TestCase

const HEROES := ["vanguard", "cutthroat", "marksman", "mender"]


func _def(arrivals: Array = []) -> CampaignDef:
	var def := CampaignDef.new()
	for id: String in HEROES:
		def.starting_heroes.append(load("res://content/heroes/%s.tres" % id))
	def.arrivals.assign(arrivals)
	def.regions.assign([
		_region(&"first", ["wave_1", "wave_2"], ["wave_3"]),
		_region(&"second", ["graveyard_watch", "rot_nest"], ["brute_and_bones"]),
	])
	return def


func _region(id: StringName, encounters: Array, finales: Array) -> RegionDef:
	var region := RegionDef.new()
	region.id = id
	for name: String in encounters:
		region.encounters.append(load("res://content/encounters/%s.tres" % name))
	for name: String in finales:
		region.finales.append(load("res://content/encounters/%s.tres" % name))
	return region


func _campaign(seed_value: int = 1, arrivals: Array = []) -> Campaign:
	return Campaign.create(_def(arrivals), seed_value)


## A mission whose tier and length are fixed, added to the board.
func _mission(campaign: Campaign, tier: int, length: int) -> Mission:
	var mission := campaign._make_mission(tier, length)
	campaign.board.append(mission)
	return mission


func _party(campaign: Campaign) -> Array[HeroRecord]:
	return campaign.roster().slice(0, 4)


## Plays fights with the sensible scripted player until the mission stops.
func _play(run: MissionRun, fights: int = 99) -> void:
	while run.has_next_fight() and fights > 0:
		var battle := run.start_next_fight()
		for i in 3000:
			if battle.state == Battle.State.VICTORY or battle.state == Battle.State.DEFEAT:
				break
			battle.advance()
			if battle.state == Battle.State.AWAITING_INPUT:
				var choice := AutoPlayer.sensible(battle)
				battle.submit(choice[0], choice[1])
		run.finish_fight()
		fights -= 1


## Heroes only pass, so the enemies win.
func _lose(run: MissionRun) -> void:
	var battle := run.start_next_fight()
	for i in 5000:
		if battle.state == Battle.State.DEFEAT or battle.state == Battle.State.VICTORY:
			break
		battle.advance()
		if battle.state == Battle.State.AWAITING_INPUT:
			battle.submit(BasicSkills.pass_turn, battle.current)
	run.finish_fight()


func _strengthen(party: Array[HeroRecord]) -> void:
	for hero in party:
		hero.weapon_rank = 5
		hero.armor_rank = 5


func test_new_campaign_starts_with_four_heroes_and_three_missions() -> void:
	var campaign := _campaign()
	assert_eq(campaign.week, 1)
	assert_eq(campaign.gold, CampaignRules.STARTING_GOLD)
	assert_eq(campaign.roster().size(), 4)
	assert_eq(campaign.board.size(), 2 * CampaignRules.MISSIONS_PER_REGION)
	for mission in campaign.board:
		assert_eq(mission.tier, CampaignRules.Tier.APPRENTICE)
		assert_eq(mission.fights(), CampaignRules.FIGHTS[mission.length])


func test_the_board_has_two_missions_per_region_at_both_ends_of_the_tiers() -> void:
	for seed_value in 30:
		var campaign := _campaign(seed_value)
		campaign.roster()[0].xp = CampaignRules.LEVEL_XP[3]
		campaign._refresh_board()
		for region in campaign.def.regions:
			assert_eq(campaign.board.filter(func(m: Mission) -> bool: return m.region == region).size(),
					CampaignRules.MISSIONS_PER_REGION, "seed %d" % seed_value)
		var tiers := campaign.board.map(func(m: Mission) -> int: return m.tier)
		assert_true(CampaignRules.Tier.CHAMPION in tiers, "seed %d has a Champion mission" % seed_value)
		assert_true(CampaignRules.Tier.APPRENTICE in tiers, "seed %d has an Apprentice mission" % seed_value)


func test_missions_fight_their_regions_enemies() -> void:
	var campaign := _campaign()
	for i in 20:
		campaign._refresh_board()
		for mission in campaign.board:
			for fight in mission.encounters:
				assert_true(fight in mission.region.encounters or fight in mission.region.finales,
						"%s in %s" % [fight.display_name, mission.region.id])


func test_levels_follow_the_dd1_xp_table() -> void:
	for pair: Array in [[0, 0], [1, 0], [2, 1], [7, 1], [8, 2], [24, 4], [48, 6], [100, 6]]:
		assert_eq(CampaignRules.level_for_xp(pair[0]), pair[1], "xp %d" % pair[0])


func test_mission_rewards_follow_the_tables() -> void:
	var campaign := _campaign()
	var mission := campaign._make_mission(CampaignRules.Tier.VETERAN, CampaignRules.Length.LONG)
	mission.heirloom = &"crest"
	assert_eq(mission.gold(), 11250)
	assert_eq(mission.xp(), 8)
	assert_eq(mission.heirloom_amount(), 12)
	assert_eq(mission.fight_gold() * mission.fights() + mission.completion_gold(), mission.gold())


func test_medium_and_long_missions_end_with_a_finale() -> void:
	var campaign := _campaign()
	var finale: EncounterDef = load("res://content/encounters/wave_3.tres")
	assert_eq(campaign._make_mission(0, CampaignRules.Length.MEDIUM).encounters.back(), finale)
	assert_ne(campaign._make_mission(0, CampaignRules.Length.SHORT).encounters.back(), finale)


func test_completing_a_mission_pays_everything_and_ends_the_week() -> void:
	for seed_value in 10:
		var campaign := _campaign(seed_value)
		var mission := _mission(campaign, CampaignRules.Tier.APPRENTICE, CampaignRules.Length.SHORT)
		var party := _party(campaign)
		_strengthen(party)
		var run := campaign.embark(mission, party)
		_play(run)
		if run.outcome != MissionRun.Outcome.COMPLETED:
			continue
		var summary := campaign.finish_mission()
		assert_eq(campaign.gold, CampaignRules.STARTING_GOLD + mission.gold())
		assert_eq(campaign.heirlooms[mission.heirloom], mission.heirloom_amount())
		assert_eq(summary.xp, mission.xp())
		assert_eq(campaign.week, 2)
		assert_eq(campaign.run, null)
		for hero in party:
			if hero not in run.defeated:
				assert_eq(hero.xp, mission.xp(), hero.display_name)
		return
	fail("no seed completed the mission")


func test_retreat_keeps_fight_gold_and_adds_stress() -> void:
	var campaign := _campaign(3)
	var mission := _mission(campaign, CampaignRules.Tier.APPRENTICE, CampaignRules.Length.MEDIUM)
	var party := _party(campaign)
	_strengthen(party)
	var run := campaign.embark(mission, party)
	_play(run, 1)
	assert_eq(run.outcome, MissionRun.Outcome.IN_PROGRESS)
	run.retreat()
	var stress_before := run.combatants.map(func(c: Combatant) -> int: return c.stress)
	campaign.finish_mission()
	assert_eq(campaign.gold, CampaignRules.STARTING_GOLD + mission.fight_gold())
	assert_eq(campaign.heirlooms[mission.heirloom], 0)
	for i in party.size():
		assert_eq(party[i].xp, 0)
		assert_eq(party[i].stress, mini(stress_before[i] + CampaignRules.RETREAT_STRESS, Rules.STRESS_MAX))


func test_party_wipe_pays_nothing_and_wounds_everyone() -> void:
	var campaign := _campaign(5)
	var mission := _mission(campaign, CampaignRules.Tier.APPRENTICE, CampaignRules.Length.SHORT)
	var party := _party(campaign)
	var run := campaign.embark(mission, party)
	_lose(run)
	assert_eq(run.outcome, MissionRun.Outcome.FAILED)
	var summary := campaign.finish_mission()
	assert_eq(summary.gold, 0)
	assert_eq(campaign.gold, CampaignRules.STARTING_GOLD)
	assert_eq(campaign.heirlooms[mission.heirloom], 0)
	assert_eq(campaign.week, 2)
	for hero in party:
		assert_true(hero.wounded, hero.display_name)
		assert_eq(campaign.eligibility(hero, campaign.board[0]), Campaign.Eligibility.WOUNDED)


func test_wounds_last_one_week_or_can_be_treated() -> void:
	var campaign := _campaign()
	var heroes := campaign.roster()
	heroes[0].wounded = true
	heroes[1].wounded = true
	assert_eq(campaign.treat(heroes[0]), "")
	assert_false(heroes[0].wounded)
	assert_eq(campaign.gold, CampaignRules.STARTING_GOLD - CampaignRules.WOUND_TREATMENT_PRICE)
	campaign._advance_week([])
	assert_false(heroes[1].wounded, "healed after sitting out a week")


func test_the_week_can_pass_only_when_nobody_can_go() -> void:
	var campaign := _campaign(1, [load("res://content/heroes/warden.tres")])
	var heroes := campaign.roster()
	for hero in heroes.slice(0, 3):
		hero.wounded = true
	assert_ne(campaign.wait_week(), "", "one hero can still go")
	heroes[3].stress = 5
	campaign.send_to_abbey(heroes[3], 0)
	assert_eq(campaign.wait_week(), "")
	assert_eq(campaign.week, 2)
	assert_eq(heroes[3].stress, 5 - campaign.abbey_relief(0))
	for hero in heroes:
		assert_false(hero.wounded, hero.display_name)
		hero.wounded = true
	assert_ne(campaign.wait_week(), "", "the Warden has arrived at the Stagecoach")


func test_will_not_go_and_underlevel_stress() -> void:
	var campaign := _campaign()
	var veteran := _mission(campaign, CampaignRules.Tier.VETERAN, CampaignRules.Length.SHORT)
	var apprentice := _mission(campaign, CampaignRules.Tier.APPRENTICE, CampaignRules.Length.SHORT)
	var heroes := campaign.roster()
	heroes[0].xp = CampaignRules.LEVEL_XP[2]
	assert_eq(campaign.eligibility(heroes[0], apprentice), Campaign.Eligibility.WILL_NOT_GO)
	assert_ne(campaign.can_embark(apprentice, heroes.slice(0, 1)), "")
	assert_eq(campaign.eligibility(heroes[1], apprentice), Campaign.Eligibility.OK, "level 0 suits Apprentice")
	assert_eq(campaign.eligibility(heroes[1], veteran), Campaign.Eligibility.UNDERLEVELED)
	campaign.embark(veteran, heroes.slice(1, 2))
	assert_eq(heroes[1].stress, 2 * CampaignRules.UNDERLEVEL_STRESS, "two levels below Veteran's 2")


func test_blacksmith_needs_building_level_hero_level_and_gold() -> void:
	var campaign := _campaign()
	var hero := campaign.roster()[0]
	assert_eq(campaign.upgrade_weapon(hero), "Upgrade the Weaponsmith first.")
	campaign.buildings[&"weaponsmith"] = 1
	assert_eq(campaign.upgrade_weapon(hero), "Needs hero level 1.")
	hero.xp = CampaignRules.LEVEL_XP[0]
	campaign.gold = 100
	assert_eq(campaign.upgrade_weapon(hero), "Not enough gold.")
	campaign.gold = 5000
	assert_eq(campaign.upgrade_weapon(hero), "")
	assert_eq(hero.weapon_rank, 2)
	assert_eq(campaign.gold, 5000 - CampaignRules.GEAR_COST[0])
	assert_eq(campaign.upgrade_armor(hero), "Upgrade the Armorsmith first.")


func test_guild_raises_skill_ranks() -> void:
	var campaign := _campaign()
	var hero := campaign.roster()[0]
	var skill := hero.def.skills[0]
	campaign.buildings[&"guild"] = 1
	hero.xp = CampaignRules.LEVEL_XP[0]
	assert_eq(campaign.upgrade_skill(hero, skill), "")
	assert_eq(hero.skill_rank(skill), 2)
	assert_eq(campaign.gold, CampaignRules.STARTING_GOLD - CampaignRules.SKILL_COST[0])
	assert_eq(campaign.upgrade_skill(hero, skill), "Upgrade the Guild first.")


func test_building_upgrades_spend_heirlooms() -> void:
	var campaign := _campaign()
	campaign.heirlooms[&"deed"] = 8
	campaign.heirlooms[&"crest"] = 8
	assert_eq(campaign.upgrade_building(&"weaponsmith"), "")
	assert_eq(campaign.buildings[&"weaponsmith"], 1)
	assert_eq(campaign.heirlooms[&"deed"], 0)
	assert_eq(campaign.upgrade_building(&"weaponsmith"), "Not enough Deeds.")


func test_abbey_relieves_stress_at_week_end_and_blocks_the_mission() -> void:
	var campaign := _campaign()
	var heroes := campaign.roster()
	heroes[0].stress = 6
	heroes[1].stress = 6
	assert_eq(campaign.send_to_abbey(heroes[0], 0), "")
	assert_eq(campaign.gold, CampaignRules.STARTING_GOLD - CampaignRules.ABBEY_PRICES[0])
	assert_eq(campaign.eligibility(heroes[0], campaign.board[0]), Campaign.Eligibility.BUSY)
	assert_eq(campaign.send_to_abbey(heroes[1], 0), "No free slot.")
	campaign._advance_week([])
	assert_eq(heroes[0].stress, 6 - CampaignRules.ABBEY_RELIEF[0][0])
	assert_eq(heroes[0].abbey_activity, -1)
	assert_eq(heroes[1].stress, 5, "idle heroes lose 1 stress")


func test_abbey_prices_and_upgrades() -> void:
	var campaign := _campaign()
	var hero := campaign.roster()[0]
	assert_eq(campaign.abbey_price(hero, 0), 1000)
	hero.xp = CampaignRules.LEVEL_XP[2]
	assert_eq(campaign.abbey_price(hero, 0), 1400)
	hero.xp = CampaignRules.LEVEL_XP[4]
	assert_eq(campaign.abbey_price(hero, 0), 1800)
	campaign.buildings[&"abbey"] = 3
	assert_eq(campaign.abbey_price(hero, 0), roundi(1800 * 0.85))
	assert_eq(campaign.abbey_relief(0), CampaignRules.ABBEY_RELIEF[1][0])
	assert_eq(campaign.abbey_slots(), 2)


func test_a_new_hero_arrives_each_week_at_the_stagecoach_level() -> void:
	var campaign := _campaign(1, [Fixtures.unit("First"), Fixtures.unit("Second")])
	assert_eq(campaign.stagecoach().size(), 0)
	campaign._advance_week([])
	assert_eq(campaign.stagecoach().size(), 1)
	assert_eq(campaign.stagecoach()[0].level(), 0)
	campaign.buildings[&"stagecoach"] = 2
	campaign._advance_week([])
	var second := campaign.stagecoach()[1]
	assert_eq(second.display_name, "Second")
	assert_eq(second.level(), 2)
	assert_eq(campaign.hire(second), "")
	assert_eq(campaign.roster().size(), 5)


func test_mission_tiers_unlock_with_hero_levels() -> void:
	var campaign := _campaign()
	assert_eq(campaign.available_tiers(), [0] as Array[int])
	campaign.roster()[0].xp = CampaignRules.LEVEL_XP[1]
	assert_eq(campaign.available_tiers().size(), 2)
	campaign.roster()[0].xp = CampaignRules.LEVEL_XP[3]
	assert_eq(campaign.available_tiers().size(), 3)


func test_save_and_load_round_trip() -> void:
	var campaign := _campaign(9)
	campaign.gold = 1234
	campaign.heirlooms[&"bust"] = 7
	campaign.buildings[&"guild"] = 2
	var hero := campaign.roster()[2]
	hero.xp = 9
	hero.weapon_rank = 3
	hero.skill_ranks[hero.def.skills[1].id] = 4
	campaign.send_to_abbey(campaign.roster()[1], 2)
	var party := _party(campaign)
	_strengthen(party)
	var run := campaign.embark(_mission(campaign, 0, CampaignRules.Length.LONG), party)
	_play(run, 1)
	var text := JSON.stringify(campaign.to_dict())
	var loaded := Campaign.from_dict(JSON.parse_string(text), campaign.def)
	assert_eq(JSON.stringify(loaded.to_dict()), text)
	assert_eq(loaded.run.fight_index, 1)
	assert_eq(loaded.run.combatants[0].hp, run.combatants[0].hp)
	assert_eq(loaded.rng.randi(), campaign.rng.randi(), "random sequence continues identically")


func test_saves_keep_each_missions_region() -> void:
	var campaign := Campaign.create(load("res://content/campaign.tres"), 4)
	var loaded := Campaign.from_dict(JSON.parse_string(JSON.stringify(campaign.to_dict())), campaign.def)
	assert_eq(loaded.board.size(), campaign.board.size())
	for i in campaign.board.size():
		assert_true(loaded.board[i].region != null)
		assert_eq(loaded.board[i].region, campaign.board[i].region)


func test_saves_from_before_regions_get_a_fresh_board() -> void:
	var campaign := _campaign(6)
	campaign.gold = 777
	var data: Dictionary = JSON.parse_string(JSON.stringify(campaign.to_dict()))
	data.version = 1
	for mission: Dictionary in data.board:
		mission.erase("region")
	var loaded := Campaign.from_dict(data, campaign.def)
	assert_eq(loaded.gold, 777)
	assert_eq(loaded.board.size(), campaign.board.size())
	for mission in loaded.board:
		assert_true(mission.region != null)


func test_hero_growth_reaches_the_combatant() -> void:
	var record := HeroRecord.new(load("res://content/heroes/vanguard.tres"))
	record.xp = CampaignRules.LEVEL_XP[1]
	record.weapon_rank = 3
	record.armor_rank = 3
	var unit := Growth.hero_combatant(record)
	assert_eq(unit.max_hp, 40 + 16)
	assert_eq(unit.hp, unit.max_hp)
	assert_between(unit.damage_bonus, 0.199, 0.201)
	assert_between(unit.crit_bonus, 0.0199, 0.0201)
	assert_eq(unit.speed(), record.def.speed + 1)
	assert_between(unit.resist(&"stun"), record.def.resist_stun + 0.199, record.def.resist_stun + 0.201)
	assert_eq(unit.resist(&"deathblow"), record.def.resist_deathblow)


func test_enemy_tiers_scale_hp_damage_and_crit() -> void:
	var unit := Growth.enemy_combatant(load("res://content/enemies/ghoul.tres"), CampaignRules.Tier.CHAMPION)
	assert_eq(unit.max_hp, 26 + 13)
	assert_eq(unit.damage_bonus, 0.5)
	assert_eq(unit.crit_bonus, 0.05)

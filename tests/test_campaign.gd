extends TestCase

const HEROES := ["vanguard", "cutthroat", "plaguebearer", "mender"]


func _def(recruits: Array = []) -> CampaignDef:
	var def := CampaignDef.new()
	for id: String in HEROES:
		def.starting_heroes.append(load("res://content/heroes/%s.tres" % id))
	def.recruits.assign(recruits)
	def.regions.assign([
		Fixtures.region(&"first", ["wave_1", "wave_2"], ["brute_and_bones"], ["wave_3"]),
		Fixtures.region(&"second", ["graveyard_watch", "rot_nest"], ["the_glutton"], ["brute_and_bones"]),
	])
	def.events.assign([Fixtures.spring_event()])
	return def


func _campaign(seed_value: int = 1, recruits: Array = []) -> Campaign:
	return Campaign.create(_def(recruits), seed_value)


## A mission whose tier and length are fixed, added to the board.
func _mission(campaign: Campaign, tier: int, length: int) -> Mission:
	var mission := campaign._make_mission(tier, length)
	campaign.board.append(mission)
	return mission


func _party(campaign: Campaign) -> Array[HeroRecord]:
	return campaign.roster().slice(0, 4)


## Enters the first room (always a fight) and plays it with the bot.
func _win_first_fight(run: MissionRun) -> void:
	run.enter(run.next_rooms()[0].id)
	var battle := run.start_fight()
	for i in 3000:
		if battle.state == Battle.State.VICTORY or battle.state == Battle.State.DEFEAT:
			break
		battle.advance()
		if battle.state == Battle.State.AWAITING_INPUT:
			var choice := AutoPlayer.best(battle)
			battle.submit(choice[0], choice[1])
	run.finish_fight()


## Enters the first room and only passes, so the enemies win.
func _lose(run: MissionRun) -> void:
	run.enter(run.next_rooms()[0].id)
	var battle := run.start_fight()
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


func test_new_campaign_starts_with_four_heroes_and_six_missions() -> void:
	var campaign := _campaign()
	assert_eq(campaign.week, 1)
	assert_eq(campaign.gold, CampaignRules.STARTING_GOLD)
	assert_eq(campaign.roster().size(), 4)
	assert_eq(campaign.board.size(), 2 * CampaignRules.MISSIONS_PER_REGION)
	for mission in campaign.board:
		assert_eq(mission.tier, CampaignRules.Tier.APPRENTICE)


func test_the_board_fills_the_open_regions_at_both_ends_of_the_tiers() -> void:
	# Missions per region as the regions open one by one.
	var expected := [[4, 0, 0], [2, 2, 0], [2, 2, 2]]
	for seed_value in 30:
		var campaign := _campaign(seed_value)
		campaign.roster()[0].xp = CampaignRules.LEVEL_XP[3]
		var regions := campaign.def.regions
		for opened in regions.size():
			if opened > 0:
				campaign.bosses_beaten[regions[opened - 1].id] = 1
			campaign._refresh_board()
			var label := "seed %d, %d open" % [seed_value, opened + 1]
			for i in regions.size():
				assert_eq(campaign.board.filter(func(m: Mission) -> bool: return m.region == regions[i]).size(),
						expected[opened][i], label)
			var tiers := campaign.board.map(func(m: Mission) -> int: return m.tier)
			assert_true(CampaignRules.Tier.CHAMPION in tiers, label + " has a Champion mission")
			assert_true(CampaignRules.Tier.APPRENTICE in tiers, label + " has an Apprentice mission")


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
	assert_eq(mission.fight_gold(), 11250 / 2 / 12)
	assert_eq(mission.fight_gold() * CampaignRules.FIGHT_SHARES[mission.length] + mission.completion_gold(),
			mission.gold())


func test_embarking_draws_the_missions_map() -> void:
	var campaign := _campaign()
	var mission := _mission(campaign, CampaignRules.Tier.APPRENTICE, CampaignRules.Length.MEDIUM)
	var run := campaign.embark(mission, _party(campaign))
	assert_eq(run.map.columns, CampaignRules.MAP_COLUMNS[CampaignRules.Length.MEDIUM])
	assert_eq(run.map.final_room().encounter, load("res://content/encounters/wave_3.tres"))


func test_heroes_setting_out_at_max_stress_melt_down_or_turn_resolute() -> void:
	var campaign := _campaign()
	var party := _party(campaign)
	party[0].stress = Rules.STRESS_MAX
	var run := campaign.embark(_mission(campaign, CampaignRules.Tier.APPRENTICE, CampaignRules.Length.SHORT), party)
	assert_true(run.combatants[0].stress < Rules.STRESS_MAX)
	assert_eq(run.setting_out.size(), 1, "only the hero at max stress")
	assert_true(run.setting_out[0].begins_with(party[0].display_name))


func test_completing_a_mission_pays_everything_and_ends_the_week() -> void:
	for seed_value in 10:
		var campaign := _campaign(seed_value)
		var mission := _mission(campaign, CampaignRules.Tier.APPRENTICE, CampaignRules.Length.SHORT)
		var party := _party(campaign)
		_strengthen(party)
		var run := campaign.embark(mission, party)
		MapAutoPlayer.play(run)
		if run.outcome != MissionRun.Outcome.COMPLETED:
			continue
		var earned := run.gold_earned
		var loot := run.heirlooms_earned.duplicate()
		var summary := campaign.finish_mission()
		assert_eq(summary.gold, earned + mission.completion_gold())
		assert_eq(campaign.gold, CampaignRules.STARTING_GOLD + summary.gold)
		assert_eq(campaign.heirlooms[mission.heirloom], mission.heirloom_amount() + loot.get(mission.heirloom, 0))
		assert_eq(summary.xp, mission.xp())
		assert_eq(campaign.week, 2)
		assert_eq(campaign.run, null)
		for hero in party:
			if hero not in run.defeated:
				assert_eq(hero.xp, mission.xp(), hero.display_name)
		return
	fail("no seed completed the mission")


func test_retreat_keeps_what_was_earned_and_adds_stress() -> void:
	var campaign := _campaign(3)
	var mission := _mission(campaign, CampaignRules.Tier.APPRENTICE, CampaignRules.Length.MEDIUM)
	var party := _party(campaign)
	_strengthen(party)
	var run := campaign.embark(mission, party)
	_win_first_fight(run)
	assert_eq(run.outcome, MissionRun.Outcome.IN_PROGRESS)
	assert_true(run.can_retreat())
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
	run.gold_earned = 500
	run.heirlooms_earned[&"bust"] = 3
	_lose(run)
	assert_eq(run.outcome, MissionRun.Outcome.FAILED)
	var summary := campaign.finish_mission()
	assert_eq(summary.gold, 0)
	assert_eq(campaign.gold, CampaignRules.STARTING_GOLD)
	assert_eq(campaign.heirlooms[&"bust"], 0)
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
	campaign.send(heroes[3], &"meditation")
	assert_eq(campaign.wait_week(), "")
	assert_eq(campaign.week, 2)
	assert_eq(heroes[3].stress, 5 - campaign.activity_relief(&"meditation"))
	for hero in heroes:
		assert_false(hero.wounded, hero.display_name)
		hero.wounded = true
	campaign.recruits_waiting = 1
	assert_ne(campaign.wait_week(), "", "a boss recruit can still join")


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
	assert_eq(campaign.upgrade_weapon(hero), "Upgrade Weaponsmithing first.")
	campaign.upgrades[&"weaponsmith"] = 1
	assert_eq(campaign.upgrade_weapon(hero), "Needs hero level 1.")
	hero.xp = CampaignRules.LEVEL_XP[0]
	campaign.gold = 100
	assert_eq(campaign.upgrade_weapon(hero), "Not enough gold.")
	campaign.gold = 5000
	assert_eq(campaign.upgrade_weapon(hero), "")
	assert_eq(hero.weapon_rank, 2)
	assert_eq(campaign.gold, 5000 - CampaignRules.GEAR_COST[0])
	assert_eq(campaign.upgrade_armor(hero), "Upgrade Armorsmithing first.")


func test_guild_raises_skill_ranks() -> void:
	var campaign := _campaign()
	var hero := campaign.roster()[0]
	var skill := hero.def.skills[0]
	campaign.upgrades[&"guild"] = 1
	hero.xp = CampaignRules.LEVEL_XP[0]
	assert_eq(campaign.upgrade_skill(hero, skill), "")
	assert_eq(hero.skill_rank(skill), 2)
	assert_eq(campaign.gold, CampaignRules.STARTING_GOLD - CampaignRules.SKILL_COST[0])
	assert_eq(campaign.upgrade_skill(hero, skill), "Upgrade Instructors first.")


func test_abbey_relieves_stress_at_week_end_and_blocks_the_mission() -> void:
	var campaign := _campaign()
	var heroes := campaign.roster()
	heroes[0].stress = 6
	heroes[1].stress = 6
	assert_eq(campaign.send(heroes[0], &"meditation"), "")
	assert_eq(campaign.gold, CampaignRules.STARTING_GOLD - CampaignRules.ACTIVITIES[&"meditation"].price)
	assert_eq(campaign.eligibility(heroes[0], campaign.board[0]), Campaign.Eligibility.BUSY)
	assert_eq(campaign.send(heroes[1], &"meditation"), "No free slot.")
	campaign._advance_week([])
	assert_eq(heroes[0].stress, 6 - CampaignRules.ACTIVITIES[&"meditation"].relief[0])
	assert_eq(heroes[0].activity, &"")
	assert_eq(heroes[1].stress, 5, "idle heroes lose 1 stress")


func test_activity_prices_follow_hero_level_and_upgrades() -> void:
	var campaign := _campaign()
	var hero := campaign.roster()[0]
	assert_eq(campaign.activity_price(hero, &"meditation"), 1000)
	hero.xp = CampaignRules.LEVEL_XP[2]
	assert_eq(campaign.activity_price(hero, &"meditation"), 1400)
	hero.xp = CampaignRules.LEVEL_XP[4]
	assert_eq(campaign.activity_price(hero, &"meditation"), 1800)
	campaign.upgrades[&"meditation"] = 3
	assert_eq(campaign.activity_price(hero, &"meditation"), roundi(1800 * 0.85))
	assert_eq(campaign.activity_relief(&"meditation"), CampaignRules.ACTIVITIES[&"meditation"].relief[1])
	assert_eq(campaign.activity_slots(&"meditation"), 2)
	assert_eq(campaign.activity_slots(&"prayer"), 1, "each activity upgrades on its own")


func test_heroes_who_havent_joined_stay_out_of_the_roster() -> void:
	var campaign := _campaign(1, [Fixtures.unit("Later")])
	assert_eq(campaign.roster().size(), HEROES.size())
	for week in 5:
		campaign._advance_week([])
	assert_eq(campaign.roster().size(), HEROES.size(), "nobody arrives on their own")
	assert_eq(campaign.recruit_choices().size(), 1)
	assert_ne(campaign.recruit(campaign.recruit_choices()[0]), "", "only after a boss")


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
	campaign.upgrades[&"guild"] = 2
	var hero := campaign.roster()[2]
	hero.xp = 9
	hero.weapon_rank = 3
	hero.skill_ranks[hero.def.skills[1].id] = 4
	var party := _party(campaign)
	_strengthen(party)
	var run := campaign.embark(_mission(campaign, 0, CampaignRules.Length.LONG), party)
	_win_first_fight(run)
	run.combatants[0].add_token(Tokens.BLOCK, 2)
	run.heirlooms_earned[&"deed"] = 2
	var text := JSON.stringify(campaign.to_dict())
	var loaded := Campaign.from_dict(JSON.parse_string(text), campaign.def)
	assert_eq(JSON.stringify(loaded.to_dict()), text)
	assert_eq(loaded.run.room_id, run.room_id)
	assert_eq(loaded.run.map.rooms.size(), run.map.rooms.size())
	assert_eq(loaded.run.combatants[0].hp, run.combatants[0].hp)
	assert_eq(loaded.run.combatants[0].token_count(Tokens.BLOCK), 2, "tokens carry into the next fight")
	assert_eq(loaded.run.heirlooms_earned[&"deed"], 2)
	assert_eq(loaded.rng.randi(), campaign.rng.randi(), "random sequence continues identically")


func test_missions_saved_before_maps_resume_on_a_fresh_map() -> void:
	var campaign := _campaign(8)
	var party := _party(campaign)
	var run := campaign.embark(_mission(campaign, 0, CampaignRules.Length.MEDIUM), party)
	run.combatants[1].hp = 9
	var data: Dictionary = JSON.parse_string(JSON.stringify(campaign.to_dict()))
	data.version = 2
	for key: String in ["map", "room_id", "room_done", "heirlooms_earned", "pending", "pending_kind"]:
		data.run.erase(key)
	data.run.fight_index = 1
	data.run.gold_earned = 300
	var loaded := Campaign.from_dict(data, campaign.def)
	assert_eq(loaded.run.room_id, -1)
	assert_eq(loaded.run.gold_earned, 300)
	assert_eq(loaded.run.combatants[1].hp, 9)
	assert_eq(loaded.run.map.columns, CampaignRules.MAP_COLUMNS[CampaignRules.Length.MEDIUM])


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


## Old saves may hold a hero whose class has since left the cast (the Arbalest).
func test_heroes_whose_class_left_the_cast_are_dropped_on_load() -> void:
	var campaign := Campaign.create(load("res://content/campaign.tres"), 7)
	campaign.embark(campaign.board[0], campaign.roster().slice(0, 2))
	var data: Dictionary = JSON.parse_string(JSON.stringify(campaign.to_dict()))
	var gone: Dictionary = data.heroes[0].duplicate()
	gone.def = "res://content/heroes/arbalest_that_left.tres"
	data.heroes.insert(0, gone)
	data.run.party = data.run.party.map(func(index: float) -> int: return int(index) + 1)
	var loaded := Campaign.from_dict(data, campaign.def)
	assert_eq(loaded.heroes.size(), campaign.heroes.size())
	assert_true(loaded.run != null, "a mission without them carries on")
	assert_eq(loaded.run.party[0].def, campaign.run.party[0].def)
	data.run.party.append(0)
	data.run.states.append(data.run.states[0])
	assert_eq(Campaign.from_dict(data, campaign.def).run, null, "a mission with them is abandoned")


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

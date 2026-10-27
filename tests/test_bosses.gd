## Region bosses: missions completed in a region open its boss mission, the
## first win lets a new hero join, and the boss returns a tier harder.
extends TestCase


func _def() -> CampaignDef:
	var def := CampaignDef.new()
	for id: String in ["vanguard", "cutthroat", "marksman", "mender"]:
		def.starting_heroes.append(load("res://content/heroes/%s.tres" % id))
	for id: String in ["minstrel", "penitent"]:
		def.recruits.append(load("res://content/heroes/%s.tres" % id))
	var region := Fixtures.region(&"first", ["wave_1", "wave_2"], ["brute_and_bones"], ["wave_3"])
	region.boss = load("res://content/encounters/the_glutton.tres")
	def.regions.assign([region])
	return def


## Finishes `mission` as a completed (or retreated) run.
func _finish(campaign: Campaign, mission: Mission, completed: bool = true) -> Dictionary:
	if mission not in campaign.board:
		campaign.board.append(mission)
	var run := campaign.embark(mission, campaign.roster().slice(0, 4))
	if completed:
		run.outcome = MissionRun.Outcome.COMPLETED
	else:
		run.retreat()
	return campaign.finish_mission()


func _ordinary(campaign: Campaign) -> Mission:
	return campaign._make_mission(CampaignRules.Tier.APPRENTICE, CampaignRules.Length.SHORT, campaign.def.regions[0])


func _boss_on_board(campaign: Campaign) -> Mission:
	for mission in campaign.board:
		if mission.boss:
			return mission
	return null


func test_completed_missions_open_the_regions_boss() -> void:
	var campaign := Campaign.create(_def(), 1)
	var region := campaign.def.regions[0]
	_finish(campaign, _ordinary(campaign), false)
	assert_eq(campaign.region_progress.get(region.id, 0), 0, "retreats don't count")
	for i in CampaignRules.BOSS_UNLOCK_MISSIONS - 1:
		_finish(campaign, _ordinary(campaign))
		assert_eq(_boss_on_board(campaign), null)
	_finish(campaign, _ordinary(campaign))
	var boss := _boss_on_board(campaign)
	assert_true(boss != null, "the boss mission appears")
	assert_eq(boss.length, CampaignRules.Length.LONG)
	assert_eq(boss.tier, CampaignRules.Tier.APPRENTICE)
	assert_eq(boss.heirloom_amount(), 2 * CampaignRules.heirloom_amount(boss.heirloom, boss.tier, boss.length))
	campaign._advance_week([])
	assert_true(_boss_on_board(campaign) != null, "it stays until beaten")


func test_a_boss_mission_ends_at_the_boss() -> void:
	var campaign := Campaign.create(_def(), 2)
	var region := campaign.def.regions[0]
	campaign.region_progress[region.id] = CampaignRules.BOSS_UNLOCK_MISSIONS
	campaign._refresh_board()
	var run := campaign.embark(_boss_on_board(campaign), campaign.roster().slice(0, 4))
	assert_eq(run.map.columns, CampaignRules.MAP_COLUMNS[CampaignRules.Length.LONG])
	assert_eq(run.map.final_room().encounter, region.boss)


func test_the_first_boss_win_lets_a_hero_join_at_level_1() -> void:
	var campaign := Campaign.create(_def(), 3)
	var region := campaign.def.regions[0]
	campaign.region_progress[region.id] = CampaignRules.BOSS_UNLOCK_MISSIONS
	campaign._refresh_board()
	var summary := _finish(campaign, _boss_on_board(campaign))
	assert_true(summary.recruit)
	assert_eq(campaign.recruits_waiting, 1)
	assert_eq(campaign.bosses_beaten[region.id], 1)
	assert_eq(campaign.region_progress[region.id], 0, "progress starts again")
	assert_eq(_boss_on_board(campaign), null)
	var hero := campaign.recruit_choices()[1]
	assert_eq(campaign.recruit(hero), "")
	assert_true(hero.recruited)
	assert_eq(hero.level(), 1)
	assert_eq(campaign.recruits_waiting, 0)
	assert_ne(campaign.recruit(campaign.recruit_choices()[0]), "", "one recruit per first win")


func test_the_boss_returns_a_tier_harder_without_another_recruit() -> void:
	var campaign := Campaign.create(_def(), 4)
	var region := campaign.def.regions[0]
	campaign.bosses_beaten[region.id] = 1
	campaign.region_progress[region.id] = CampaignRules.BOSS_UNLOCK_MISSIONS
	campaign._refresh_board()
	var boss := _boss_on_board(campaign)
	assert_eq(boss.tier, CampaignRules.Tier.VETERAN)
	var summary := _finish(campaign, boss)
	assert_false(summary.recruit)
	assert_eq(campaign.recruits_waiting, 0)
	campaign.bosses_beaten[region.id] = CampaignRules.TIER_NAMES.size()
	campaign.region_progress[region.id] = CampaignRules.BOSS_UNLOCK_MISSIONS
	campaign._refresh_board()
	assert_eq(_boss_on_board(campaign), null, "no boss after the Champion one")


func test_no_recruit_when_everyone_has_joined() -> void:
	var def := _def()
	def.recruits.clear()
	var campaign := Campaign.create(def, 5)
	campaign.region_progress[def.regions[0].id] = CampaignRules.BOSS_UNLOCK_MISSIONS
	campaign._refresh_board()
	assert_false(_finish(campaign, _boss_on_board(campaign)).recruit)


func test_boss_progress_survives_saving() -> void:
	var campaign := Campaign.create(_def(), 6)
	var region := campaign.def.regions[0]
	campaign.region_progress[region.id] = 2
	campaign.bosses_beaten[region.id] = 1
	campaign.recruits_waiting = 1
	campaign.region_progress[region.id] = CampaignRules.BOSS_UNLOCK_MISSIONS
	campaign._refresh_board()
	var loaded := Campaign.from_dict(JSON.parse_string(JSON.stringify(campaign.to_dict())), campaign.def)
	assert_eq(loaded.region_progress[region.id], CampaignRules.BOSS_UNLOCK_MISSIONS)
	assert_eq(loaded.bosses_beaten[region.id], 1)
	assert_eq(loaded.recruits_waiting, 1)
	assert_true(_boss_on_board(loaded) != null, "the boss mission is still on the board")

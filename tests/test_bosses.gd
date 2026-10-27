## Region bosses: missions completed in a region open its boss mission, the
## first win lets a new hero join and opens the next region, and the boss
## returns a tier harder.
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


## The fixture region and a second one behind it.
func _two_regions() -> CampaignDef:
	var def := _def()
	var second := Fixtures.region(&"second", ["wave_1", "wave_2"], ["brute_and_bones"], ["wave_3"])
	second.boss = load("res://content/encounters/the_glutton.tres")
	def.regions.append(second)
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


func _ordinary(campaign: Campaign, length := CampaignRules.Length.SHORT) -> Mission:
	return campaign._make_mission(CampaignRules.Tier.APPRENTICE, length, campaign.def.regions[0])


func _boss_on_board(campaign: Campaign) -> Mission:
	for mission in campaign.board:
		if mission.boss:
			return mission
	return null


func test_completed_missions_fill_the_regions_boss_progress() -> void:
	var campaign := Campaign.create(_def(), 1)
	var region := campaign.def.regions[0]
	_finish(campaign, _ordinary(campaign), false)
	assert_eq(campaign.boss_progress(region), 0.0, "retreats don't count")
	for i in 3:
		assert_eq(_finish(campaign, _ordinary(campaign)).progress, region)
		assert_eq(_boss_on_board(campaign), null)
	assert_almost_eq(campaign.boss_progress(region), 0.75)
	_finish(campaign, _ordinary(campaign))
	var boss := _boss_on_board(campaign)
	assert_true(boss != null, "the boss mission appears")
	assert_eq(boss.length, CampaignRules.Length.LONG)
	assert_eq(boss.tier, CampaignRules.Tier.APPRENTICE)
	assert_eq(boss.heirloom_amount(), 2 * CampaignRules.heirloom_amount(boss.heirloom, boss.tier, boss.length))
	campaign._advance_week([])
	assert_true(_boss_on_board(campaign) != null, "it stays until beaten")


func test_longer_missions_fill_more_of_the_progress() -> void:
	var campaign := Campaign.create(_def(), 9)
	var region := campaign.def.regions[0]
	var shares := [0.25, 0.35, 0.5]
	for length in shares.size():
		assert_almost_eq(campaign.progress_for(_ordinary(campaign, length)), shares[length])
	_finish(campaign, _ordinary(campaign, CampaignRules.Length.MEDIUM))
	_finish(campaign, _ordinary(campaign, CampaignRules.Length.LONG))
	assert_eq(_boss_on_board(campaign), null, "85% isn't enough")
	_finish(campaign, _ordinary(campaign))
	var boss := _boss_on_board(campaign)
	assert_true(boss != null)
	assert_almost_eq(campaign.boss_progress(region), 1.0, "it stops at full")
	assert_eq(campaign.progress_for(boss), 0.0, "the boss mission itself doesn't count")


func test_saves_from_before_the_progress_bar_convert_mission_counts() -> void:
	var campaign := Campaign.create(_def(), 10)
	var region := campaign.def.regions[0]
	var data: Dictionary = JSON.parse_string(JSON.stringify(campaign.to_dict()))
	data.version = 3
	data.region_progress = {String(region.id): 2}
	assert_eq(Campaign.from_dict(data, campaign.def).region_progress[region.id], 67, "2 of the old 3 missions")


func test_a_boss_mission_ends_at_the_boss() -> void:
	var campaign := Campaign.create(_def(), 2)
	var region := campaign.def.regions[0]
	campaign.region_progress[region.id] = CampaignRules.BOSS_PROGRESS_FULL
	campaign._refresh_board()
	var run := campaign.embark(_boss_on_board(campaign), campaign.roster().slice(0, 4))
	assert_eq(run.map.columns, CampaignRules.MAP_COLUMNS[CampaignRules.Length.LONG])
	assert_eq(run.map.final_room().encounter, region.boss)


func test_the_first_boss_win_lets_a_hero_join_at_level_1() -> void:
	var campaign := Campaign.create(_def(), 3)
	var region := campaign.def.regions[0]
	campaign.region_progress[region.id] = CampaignRules.BOSS_PROGRESS_FULL
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
	campaign.region_progress[region.id] = CampaignRules.BOSS_PROGRESS_FULL
	campaign._refresh_board()
	var boss := _boss_on_board(campaign)
	assert_eq(boss.tier, CampaignRules.Tier.VETERAN)
	var summary := _finish(campaign, boss)
	assert_false(summary.recruit)
	assert_eq(campaign.recruits_waiting, 0)
	campaign.bosses_beaten[region.id] = CampaignRules.TIER_NAMES.size()
	campaign.region_progress[region.id] = CampaignRules.BOSS_PROGRESS_FULL
	campaign._refresh_board()
	assert_eq(_boss_on_board(campaign), null, "no boss after the Champion one")


func test_only_the_first_region_is_open_until_its_boss_falls() -> void:
	var campaign := Campaign.create(_two_regions(), 7)
	var first := campaign.def.regions[0]
	var second := campaign.def.regions[1]
	assert_true(campaign.region_open(first))
	assert_false(campaign.region_open(second))
	assert_true(campaign.board.all(func(m: Mission) -> bool: return m.region == first))
	assert_eq(campaign.board.size(), CampaignRules.MIN_BOARD_MISSIONS, "the first region alone offers more")
	campaign.region_progress[first.id] = CampaignRules.BOSS_PROGRESS_FULL
	campaign._refresh_board()
	var summary := _finish(campaign, _boss_on_board(campaign))
	assert_eq(summary.opened, second.display_name)
	assert_true(campaign.region_open(second))
	for region in campaign.def.regions:
		assert_eq(campaign.board.filter(func(m: Mission) -> bool: return m.region == region).size(),
				CampaignRules.MISSIONS_PER_REGION, region.id)
	campaign.region_progress[first.id] = CampaignRules.BOSS_PROGRESS_FULL
	campaign._refresh_board()
	assert_eq(_finish(campaign, _boss_on_board(campaign)).opened, "", "only the first win opens a region")


func test_saves_offering_missions_in_closed_regions_get_a_new_board() -> void:
	var campaign := Campaign.create(load("res://content/campaign.tres"), 8)
	var regions := campaign.def.regions
	campaign.board.append(campaign._make_mission(CampaignRules.Tier.APPRENTICE, CampaignRules.Length.SHORT, regions[2]))
	var loaded := Campaign.from_dict(JSON.parse_string(JSON.stringify(campaign.to_dict())), campaign.def)
	assert_false(loaded.board.is_empty())
	assert_true(loaded.board.all(func(m: Mission) -> bool: return m.region == regions[0]))


func test_no_recruit_when_everyone_has_joined() -> void:
	var def := _def()
	def.recruits.clear()
	var campaign := Campaign.create(def, 5)
	campaign.region_progress[def.regions[0].id] = CampaignRules.BOSS_PROGRESS_FULL
	campaign._refresh_board()
	assert_false(_finish(campaign, _boss_on_board(campaign)).recruit)


func test_boss_progress_survives_saving() -> void:
	var campaign := Campaign.create(_def(), 6)
	var region := campaign.def.regions[0]
	campaign.region_progress[region.id] = 2
	campaign.bosses_beaten[region.id] = 1
	campaign.recruits_waiting = 1
	campaign.region_progress[region.id] = CampaignRules.BOSS_PROGRESS_FULL
	campaign._refresh_board()
	var loaded := Campaign.from_dict(JSON.parse_string(JSON.stringify(campaign.to_dict())), campaign.def)
	assert_eq(loaded.region_progress[region.id], CampaignRules.BOSS_PROGRESS_FULL)
	assert_eq(loaded.bosses_beaten[region.id], 1)
	assert_eq(loaded.recruits_waiting, 1)
	assert_true(_boss_on_board(loaded) != null, "the boss mission is still on the board")

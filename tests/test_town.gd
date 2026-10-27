## The town's buildings: upgrade lines, the Abbey and the Tavern with its side
## effects and the Bar's bonds, the Heirloom Exchange, and buildings opening
## over the first weeks.
extends TestCase

const HEROES := ["vanguard", "cutthroat", "marksman", "mender"]


func _campaign(seed_value: int = 1) -> Campaign:
	var def := CampaignDef.new()
	for id: String in HEROES:
		def.starting_heroes.append(load("res://content/heroes/%s.tres" % id))
	def.regions.assign([Fixtures.region(&"first", ["wave_1", "wave_2"], ["brute_and_bones"], ["wave_3"])])
	return Campaign.create(def, seed_value)


## A campaign in `week`, with every hero at `stress`.
func _town(week: int, stress: int = 6, seed_value: int = 1) -> Campaign:
	var campaign := _campaign(seed_value)
	campaign.week = week
	campaign.gold = 50000
	for hero in campaign.roster():
		hero.stress = stress
	return campaign


func test_every_upgrade_line_belongs_to_one_building() -> void:
	var seen := {}
	for id: StringName in CampaignRules.BUILDINGS:
		for line: StringName in CampaignRules.BUILDINGS[id].lines:
			assert_false(seen.has(line), "%s in two buildings" % line)
			seen[line] = true
			assert_true(CampaignRules.UPGRADE_NAMES.has(line), "%s has a name" % line)
	assert_eq(seen.size(), CampaignRules.UPGRADES.size(), "every line is in a building")
	for activity: StringName in CampaignRules.ACTIVITIES:
		assert_eq(Campaign.building_of(activity), CampaignRules.ACTIVITIES[activity].building)


func test_upgrading_a_line_spends_its_heirlooms_level_by_level() -> void:
	var campaign := _campaign()
	campaign.heirlooms[&"deed"] = 8
	campaign.heirlooms[&"crest"] = 8
	assert_eq(campaign.upgrade(&"weaponsmith"), "")
	assert_eq(campaign.upgrades[&"weaponsmith"], 1)
	assert_eq(campaign.upgrades[&"armorsmith"], 0, "lines are separate")
	assert_eq(campaign.heirlooms[&"deed"], 0)
	assert_eq(campaign.upgrade(&"weaponsmith"), "Not enough Deeds.")
	campaign.upgrades[&"weaponsmith"] = CampaignRules.UPGRADES[&"weaponsmith"].size()
	assert_eq(campaign.upgrade(&"weaponsmith"), "Fully upgraded.")
	assert_false(campaign.upgrade_ready(&"blacksmith"), "nothing affordable")
	campaign.heirlooms[&"deed"] = 4
	campaign.heirlooms[&"crest"] = 4
	assert_true(campaign.upgrade_ready(&"blacksmith"), "the Furnace's first level")


func test_discount_lines_cut_gear_and_skill_gold() -> void:
	var campaign := _campaign()
	var hero := campaign.roster()[0]
	campaign.upgrades[&"furnace"] = 2
	assert_eq(campaign.gear_cost(1), roundi(CampaignRules.GEAR_COST[0] * 0.8))
	campaign.upgrades[&"regimen"] = 3
	assert_eq(campaign.skill_cost(hero, hero.def.skills[0]), roundi(CampaignRules.SKILL_COST[0] * 0.7))


func test_the_tavern_and_exchange_open_after_the_first_weeks() -> void:
	var campaign := _town(1)
	var hero := campaign.roster()[0]
	assert_eq(campaign.can_send(hero, &"bar"), "The Tavern isn't open yet.")
	assert_eq(campaign.can_upgrade(&"bar"), "The Tavern isn't open yet.")
	assert_eq(campaign.can_send(hero, &"meditation"), "", "the Abbey is open from the start")
	campaign.week = CampaignRules.BUILDINGS[&"tavern"].opens
	assert_eq(campaign.can_send(hero, &"bar"), "")
	campaign.heirlooms[&"crest"] = 6
	assert_eq(campaign.can_exchange(2), "The Heirloom Exchange isn't open yet.")
	campaign.week = CampaignRules.BUILDINGS[&"exchange"].opens
	assert_eq(campaign.can_exchange(2), "")


func test_heroes_at_the_bar_together_bond() -> void:
	var campaign := _town(3)
	var heroes := campaign.roster()
	assert_eq(campaign.activity_slots(&"bar"), 2, "room for two from the start")
	assert_eq(campaign.send(heroes[0], &"bar"), "")
	assert_eq(campaign.send(heroes[1], &"bar"), "")
	assert_eq(campaign.send(heroes[2], &"bar"), "No free slot.")
	assert_eq(campaign.eligibility(heroes[0], campaign.board[0]), Campaign.Eligibility.BUSY)
	campaign._advance_week([])
	assert_eq(campaign.bonds.points_of(heroes[0], heroes[1]), CampaignRules.BAR_BOND_POINTS)
	assert_eq(campaign.bonds.points_of(heroes[0], heroes[2]), 0)
	assert_true(campaign.week_report.any(func(line: String) -> bool: return "drank together" in line))


func test_tavern_side_effects_follow_their_odds() -> void:
	var counts := {won = 0, lost = 0, away = 0}
	var runs := 600
	for seed_value in runs:
		var campaign := _town(3, 6, seed_value)
		var hero := campaign.roster()[0]
		campaign.send(hero, &"gambling")
		var gold := campaign.gold
		campaign._advance_week([])
		counts.won += int(campaign.gold > gold)
		counts.lost += int(campaign.gold < gold)
		counts.away += int(hero.away_weeks > 0)
		assert_eq(hero.stress, 6 - CampaignRules.ACTIVITIES[&"gambling"].relief[0])
	assert_between(counts.won / float(runs), 0.02, 0.08, "wins 2,000 gold")
	assert_between(counts.lost / float(runs), 0.05, 0.11, "loses 1,000 gold")
	assert_between(counts.away / float(runs), 0.07, 0.13, "stays out a week")


func test_the_abbey_has_no_side_effects() -> void:
	for seed_value in 100:
		var campaign := _town(1, 6, seed_value)
		var hero := campaign.roster()[0]
		campaign.send(hero, &"flagellation")
		var gold := campaign.gold
		campaign._advance_week([])
		assert_eq(campaign.gold, gold)
		assert_eq(hero.away_weeks, 0)
		assert_true(hero.next_mission.is_empty())
		assert_eq(hero.stress, 0)


func test_a_hero_away_misses_a_week_then_comes_back() -> void:
	var campaign := _town(3)
	var hero := campaign.roster()[0]
	campaign._side_effect(hero, &"away", 1)
	assert_true(hero.is_busy())
	assert_eq(campaign.can_send(hero, &"bar"), "%s can't go this week." % hero.display_name)
	assert_eq(campaign.eligibility(hero, campaign.board[0]), Campaign.Eligibility.BUSY)
	campaign._advance_week([])
	assert_false(hero.is_busy())
	assert_true(campaign.week_report.any(func(line: String) -> bool: return "is back" in line))


func test_tavern_perks_last_the_next_mission_only() -> void:
	var campaign := _town(3, 0)
	var hero := campaign.roster()[0]
	campaign._side_effect(hero, &"max_hp", 0.2)
	campaign._side_effect(hero, &"speed", 1)
	var plain := Growth.hero_combatant(HeroRecord.new(hero.def))
	var mission := campaign._make_mission(CampaignRules.Tier.APPRENTICE, CampaignRules.Length.SHORT)
	campaign.board.append(mission)
	var run := campaign.embark(mission, campaign.roster())
	assert_eq(run.combatants[0].max_hp, plain.max_hp + roundi(hero.def.max_hp * 0.2))
	assert_eq(run.combatants[0].speed(), plain.speed() + 1)
	run.retreat()
	campaign.finish_mission()
	assert_true(hero.next_mission.is_empty(), "used up")


func test_gold_lost_at_the_tavern_stops_at_zero() -> void:
	var campaign := _town(3)
	campaign.gold = 300
	assert_eq(campaign._side_effect(campaign.roster()[0], &"gold", -1000), "Lost 300 gold")
	assert_eq(campaign.gold, 0)


func test_the_exchange_trades_at_its_rates() -> void:
	var campaign := _town(CampaignRules.BUILDINGS[&"exchange"].opens)
	campaign.heirlooms[&"crest"] = 7
	assert_eq(campaign.exchange(2), "", "6 Crests for a Portrait")
	assert_eq(campaign.heirlooms[&"crest"], 1)
	assert_eq(campaign.heirlooms[&"portrait"], 1)
	assert_eq(campaign.exchange(2), "Not enough Crests.")
	assert_eq(campaign.exchange(5), "", "a Portrait for 3 Crests")
	assert_eq(campaign.heirlooms[&"crest"], 4)


func test_a_missions_results_carry_the_weeks_town_news() -> void:
	var campaign := _town(1, 4)
	var heroes := campaign.roster()
	campaign.send(heroes[3], &"meditation")
	var mission := campaign._make_mission(CampaignRules.Tier.APPRENTICE, CampaignRules.Length.SHORT)
	campaign.board.append(mission)
	var run := campaign.embark(mission, heroes.slice(0, 3))
	run.retreat()
	var summary := campaign.finish_mission()
	assert_true(summary.town.any(func(line: String) -> bool: return line.begins_with(heroes[3].display_name)))
	assert_true(campaign.week_report.is_empty(), "shown with the results instead")


func test_town_state_survives_saving() -> void:
	var campaign := _town(3)
	var heroes := campaign.roster()
	campaign.upgrades[&"bar"] = 2
	campaign.send(heroes[0], &"bar")
	heroes[1].away_weeks = 1
	heroes[2].next_mission[&"speed"] = 1
	var loaded := Campaign.from_dict(JSON.parse_string(JSON.stringify(campaign.to_dict())), campaign.def)
	assert_eq(loaded.upgrades[&"bar"], 2)
	assert_eq(loaded.heroes[0].activity, &"bar")
	assert_eq(loaded.heroes[1].away_weeks, 1)
	assert_eq(loaded.heroes[2].next_mission[&"speed"], 1.0)


func test_saves_from_before_upgrade_lines_split_the_abbey() -> void:
	var campaign := _town(2)
	var data: Dictionary = JSON.parse_string(JSON.stringify(campaign.to_dict()))
	data.erase("upgrades")
	data.buildings = {abbey = 3, guild = 1, weaponsmith = 2}
	var hero: Dictionary = data.heroes[0]
	for key: String in ["activity", "away_weeks", "next_mission"]:
		hero.erase(key)
	hero.abbey_activity = 1
	var loaded := Campaign.from_dict(data, campaign.def)
	for line: StringName in [&"meditation", &"prayer", &"flagellation"]:
		assert_eq(loaded.upgrades[line], 3, String(line))
	assert_eq(loaded.upgrades[&"guild"], 1)
	assert_eq(loaded.upgrades[&"weaponsmith"], 2)
	assert_eq(loaded.upgrades[&"bar"], 0)
	assert_eq(loaded.heroes[0].activity, &"prayer")

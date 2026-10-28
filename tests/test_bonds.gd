## Bonds between heroes: points from missions together and from helping each
## other, the levels they reach, the bonuses partners get, and level-up boosts.
extends TestCase

const HEROES := ["vanguard", "cutthroat", "plaguebearer", "mender"]


func _campaign(seed_value: int = 1) -> Campaign:
	var def := CampaignDef.new()
	for id: String in HEROES:
		def.starting_heroes.append(load("res://content/heroes/%s.tres" % id))
	def.regions.assign([Fixtures.region(&"first", ["wave_1", "wave_2"], ["brute_and_bones"], ["wave_3"])])
	def.events.assign([Fixtures.spring_event()])
	return Campaign.create(def, seed_value)


func _embark(campaign: Campaign) -> MissionRun:
	var mission := campaign._make_mission(CampaignRules.Tier.APPRENTICE, CampaignRules.Length.SHORT)
	campaign.board.append(mission)
	return campaign.embark(mission, campaign.roster().slice(0, 4))


## Enters the first fight and ends it as a win, with `helps` as the [helper, helped] pairs.
func _win_with_helps(run: MissionRun, helps: Array) -> void:
	run.enter(run.next_rooms()[0].id)
	var battle := run.start_fight()
	for help: Array in helps:
		battle.helps.append(help)
	battle.state = Battle.State.VICTORY
	run.finish_fight()


func test_levels_follow_the_points() -> void:
	assert_eq(Bonds.level_for(0), Bonds.Level.STRANGERS)
	assert_eq(Bonds.level_for(4), Bonds.Level.STRANGERS)
	assert_eq(Bonds.level_for(5), Bonds.Level.FRIENDLY)
	assert_eq(Bonds.level_for(12), Bonds.Level.RESPECTED)
	assert_eq(Bonds.level_for(20), Bonds.Level.PARTNERS)


func test_points_only_go_up_to_the_last_level_and_are_shared_by_the_pair() -> void:
	var heroes := _campaign().roster()
	var bonds := Bonds.new()
	assert_false(bonds.add(heroes[0], heroes[1], 4))
	assert_true(bonds.add(heroes[1], heroes[0], 1), "reaching Friendly")
	assert_eq(bonds.points_of(heroes[0], heroes[1]), 5)
	bonds.add(heroes[0], heroes[1], 100)
	assert_eq(bonds.points_of(heroes[1], heroes[0]), CampaignRules.BOND_POINTS.back())
	assert_eq(bonds.points_of(heroes[0], heroes[2]), 0, "other pairs are untouched")


func test_every_pair_on_a_mission_bonds_more_for_completing_it() -> void:
	var campaign := _campaign()
	var run := _embark(campaign)
	run.outcome = MissionRun.Outcome.COMPLETED
	campaign.finish_mission()
	var party := run.party
	for i in party.size():
		for j in range(i + 1, party.size()):
			assert_eq(campaign.bonds.points_of(party[i], party[j]), CampaignRules.BOND_COMPLETED_POINTS)
	run = _embark(campaign)
	run.retreat()
	campaign.finish_mission()
	assert_eq(campaign.bonds.points_of(party[0], party[3]),
			CampaignRules.BOND_COMPLETED_POINTS + CampaignRules.BOND_MISSION_POINTS)


func test_skills_used_on_allies_are_recorded_as_help() -> void:
	var helps := 0
	for seed_value in 10:
		var run := _embark(_campaign(seed_value))
		run.enter(run.next_rooms()[0].id)
		var battle := run.start_fight()
		for i in 3000:
			if battle.state == Battle.State.VICTORY or battle.state == Battle.State.DEFEAT:
				break
			battle.advance()
			if battle.state == Battle.State.AWAITING_INPUT:
				var choice := AutoPlayer.best(battle)
				battle.submit(choice[0], choice[1])
		for help in battle.helps:
			assert_true(help[0].is_hero and help[1].is_hero, "heroes helping heroes")
			assert_ne(help[0], help[1], "not themselves")
		helps += battle.helps.size()
	assert_true(helps > 0, "the Vestal heals someone in ten fights")


func test_helping_earns_at_most_one_point_per_pair_per_fight() -> void:
	var earned := 0
	for seed_value in 40:
		var campaign := _campaign(seed_value)
		var run := _embark(campaign)
		var c := run.combatants
		_win_with_helps(run, [[c[3], c[0]], [c[0], c[3]], [c[3], c[0]], [c[1], c[2]]])
		var points := campaign.bonds.points_of(run.party[3], run.party[0])
		assert_true(points <= 1, "once per pair per fight")
		earned += points
		assert_eq(campaign.bonds.points_of(run.party[0], run.party[1]), 0, "only pairs that helped")
	assert_between(earned / 40.0, 0.3, 0.7, "about half the time")


func test_partners_standing_together_get_their_levels_bonuses() -> void:
	var campaign := _campaign()
	var heroes := campaign.roster()
	campaign.bonds.add(heroes[0], heroes[1], CampaignRules.BOND_POINTS[Bonds.Level.PARTNERS])
	campaign.bonds.add(heroes[0], heroes[2], CampaignRules.BOND_POINTS[Bonds.Level.FRIENDLY])
	var run := _embark(campaign)
	var lead := run.combatants[0]
	assert_almost_eq(lead.stat(&"resist_stress"), 2 * CampaignRules.BOND_STRESS_RESIST)
	assert_almost_eq(lead.stat(&"crit"), CampaignRules.BOND_CRIT)
	assert_almost_eq(lead.stat(&"resolute"), CampaignRules.BOND_RESOLUTE)
	assert_almost_eq(run.combatants[3].stat(&"resist_stress"), 0.0, "no bonds, no bonus")
	run.formation.erase(run.combatants[1])
	run.apply_bonds()
	assert_almost_eq(lead.stat(&"resist_stress"), CampaignRules.BOND_STRESS_RESIST, "only partners still standing")
	assert_almost_eq(lead.stat(&"resolute"), 0.0)


func test_bond_bonuses_reach_the_fight() -> void:
	var campaign := _campaign()
	var heroes := campaign.roster()
	campaign.bonds.add(heroes[0], heroes[1], CampaignRules.BOND_POINTS[Bonds.Level.RESPECTED])
	var run := _embark(campaign)
	run.enter(run.next_rooms()[0].id)
	var battle := run.start_fight()
	assert_almost_eq(battle.heroes[0].stat(&"crit"), CampaignRules.BOND_CRIT)
	battle.state = Battle.State.VICTORY
	battle._finish(true)
	assert_almost_eq(battle.heroes[0].stat(&"crit"), CampaignRules.BOND_CRIT, "kept after the fight")


func test_partners_turn_resolute_more_often() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var meltdowns := 0
	for i in 1000:
		var hero := Combatant.new(Fixtures.unit("Hero", 40), true)
		hero.stress = Rules.STRESS_MAX
		hero.add_buff(&"resolute", CampaignRules.BOND_RESOLUTE, Combatant.BuffExpiry.BOND)
		meltdowns += int(hero.overstress(rng) == &"meltdown")
	assert_between(meltdowns / 1000.0, Rules.MELTDOWN_CHANCE - CampaignRules.BOND_RESOLUTE - 0.04,
			Rules.MELTDOWN_CHANCE - CampaignRules.BOND_RESOLUTE + 0.04)


func test_a_new_level_mid_mission_boosts_both_heroes_at_once() -> void:
	var boosted := 0
	for seed_value in 20:
		var campaign := _campaign(seed_value)
		var heroes := campaign.roster()
		campaign.bonds.add(heroes[0], heroes[3], CampaignRules.BOND_POINTS[Bonds.Level.FRIENDLY] - 1)
		var run := _embark(campaign)
		var c := run.combatants
		for unit in c:
			unit.stress = 5
		_win_with_helps(run, [[c[3], c[0]]])
		if campaign.bonds.level(heroes[0], heroes[3]) != Bonds.Level.FRIENDLY:
			continue
		boosted += 1
		for unit in [c[0], c[3]]:
			assert_eq(unit.stress, 5 - CampaignRules.BOND_BOOST_STRESS)
			assert_almost_eq(unit.stat(&"damage"), CampaignRules.BOND_BOOST_DAMAGE)
		assert_eq(c[1].stress, 5, "only the pair")
		assert_eq(run.new_bonds, [Bonds.level_up_line(heroes[3], heroes[0], Bonds.Level.FRIENDLY)] as Array[String])
		assert_almost_eq(c[0].stat(&"resist_stress"), CampaignRules.BOND_STRESS_RESIST, "the new level's bonus")
	assert_true(boosted > 0, "some seed should level the pair up")


func test_a_new_level_as_a_mission_ends_boosts_the_pairs_next_mission_together() -> void:
	var campaign := _campaign()
	var heroes := campaign.roster()
	campaign.bonds.add(heroes[0], heroes[1], CampaignRules.BOND_POINTS[Bonds.Level.FRIENDLY] - 1)
	var run := _embark(campaign)
	run.outcome = MissionRun.Outcome.COMPLETED
	var summary := campaign.finish_mission()
	assert_true(Bonds.level_up_line(heroes[0], heroes[1], Bonds.Level.FRIENDLY) in summary.bonds)
	assert_eq(campaign.bonds.boosts_waiting, [Bonds.key(heroes[0], heroes[1])] as Array[String])
	heroes[0].stress = 4
	run = _embark(campaign)
	assert_eq(run.combatants[0].stress, 4 - CampaignRules.BOND_BOOST_STRESS)
	assert_almost_eq(run.combatants[1].stat(&"damage"), CampaignRules.BOND_BOOST_DAMAGE)
	assert_eq(run.setting_out.size(), 1)
	assert_true(campaign.bonds.boosts_waiting.is_empty(), "used up")


func test_bonds_survive_saving() -> void:
	var campaign := _campaign()
	var heroes := campaign.roster()
	campaign.bonds.add(heroes[0], heroes[2], 13)
	campaign.bonds.boosts_waiting.append(Bonds.key(heroes[0], heroes[2]))
	var loaded := Campaign.from_dict(JSON.parse_string(JSON.stringify(campaign.to_dict())), campaign.def)
	assert_eq(loaded.bonds.level(loaded.heroes[0], loaded.heroes[2]), Bonds.Level.RESPECTED)
	assert_eq(loaded.bonds.boosts_waiting, campaign.bonds.boosts_waiting)

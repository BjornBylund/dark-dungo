## Skill loadouts, as in DD1: heroes learn skills at the Guild and take
## CampaignRules.SKILL_SLOTS of them into fights.
extends TestCase


func _campaign() -> Campaign:
	var def := CampaignDef.new()
	for id: String in ["vanguard", "cutthroat", "marksman", "mender"]:
		def.starting_heroes.append(load("res://content/heroes/%s.tres" % id))
	def.regions.assign([Fixtures.region(&"first", ["wave_1"], ["brute_and_bones"], ["wave_3"])])
	var campaign := Campaign.create(def, 1)
	campaign.gold = 10000
	return campaign


## A hero record whose class has more skills than slots.
func _hero(campaign: Campaign) -> HeroRecord:
	var hero := campaign.roster()[0]
	assert_true(hero.def.skills.size() > CampaignRules.SKILL_SLOTS, "a class with skills to learn")
	return hero


func test_heroes_start_with_their_first_skills_learned_and_equipped() -> void:
	var hero := _hero(_campaign())
	var first := hero.def.skills.slice(0, CampaignRules.SKILL_SLOTS)
	assert_eq(hero.equipped_skills(), first)
	for skill in hero.def.skills:
		assert_eq(hero.knows(skill), skill in first, skill.display_name)
	assert_eq(Growth.hero_combatant(hero).skills, first, "only equipped skills reach the fight")


func test_learning_a_skill_costs_gold_and_needs_a_free_slot_to_equip() -> void:
	var campaign := _campaign()
	var hero := _hero(campaign)
	var extra := hero.def.skills[CampaignRules.SKILL_SLOTS]
	assert_eq(campaign.upgrade_skill(hero, extra), "Learn it first.")
	assert_eq(campaign.learn(hero, extra), "")
	assert_eq(campaign.gold, 10000 - CampaignRules.SKILL_LEARN_PRICE)
	assert_true(hero.knows(extra))
	assert_false(hero.is_equipped(extra), "every slot was taken")
	assert_eq(campaign.learn(hero, extra), "Already learned.")
	assert_ne(campaign.equip(hero, extra), "", "four is the most")
	assert_eq(campaign.unequip(hero, hero.def.skills[0]), "")
	assert_eq(campaign.equip(hero, extra), "")
	assert_true(Growth.hero_combatant(hero).skills.has(extra))
	assert_false(Growth.hero_combatant(hero).skills.has(hero.def.skills[0]))


func test_a_hero_keeps_at_least_one_skill() -> void:
	var campaign := _campaign()
	var hero := _hero(campaign)
	for skill in hero.def.skills.slice(1, CampaignRules.SKILL_SLOTS):
		assert_eq(campaign.unequip(hero, skill), "")
	assert_ne(campaign.unequip(hero, hero.def.skills[0]), "")
	assert_eq(hero.equipped.size(), 1)


func test_learning_is_dearer_for_higher_levels() -> void:
	var campaign := _campaign()
	var hero := _hero(campaign)
	hero.xp = CampaignRules.LEVEL_XP[4]
	assert_eq(campaign.learn_price(hero), roundi(CampaignRules.SKILL_LEARN_PRICE * 1.8))


func test_changing_skills_mid_mission_changes_the_next_fight() -> void:
	var campaign := _campaign()
	var hero := _hero(campaign)
	var extra := hero.def.skills[CampaignRules.SKILL_SLOTS]
	campaign.learn(hero, extra)
	var mission := campaign._make_mission(CampaignRules.Tier.APPRENTICE, CampaignRules.Length.SHORT)
	campaign.board.append(mission)
	var run := campaign.embark(mission, campaign.roster())
	campaign.unequip(hero, hero.def.skills[1])
	campaign.equip(hero, extra)
	assert_true(run.combatants[0].skills.has(extra))
	assert_false(run.combatants[0].skills.has(hero.def.skills[1]))


func test_loadouts_survive_saving_and_old_saves_keep_what_they_trained() -> void:
	var campaign := _campaign()
	var hero := _hero(campaign)
	var extra := hero.def.skills[CampaignRules.SKILL_SLOTS]
	campaign.learn(hero, extra)
	campaign.unequip(hero, hero.def.skills[2])
	campaign.equip(hero, extra)
	var data: Dictionary = JSON.parse_string(JSON.stringify(campaign.to_dict()))
	var loaded := Campaign.from_dict(data, campaign.def)
	assert_eq(loaded.heroes[0].known, hero.known)
	assert_eq(loaded.heroes[0].equipped, hero.equipped)
	var old: Dictionary = data.heroes[0]
	old.erase("known")
	old.erase("equipped")
	old.skill_ranks = {String(extra.id): 3}
	var legacy := HeroRecord.from_dict(old)
	assert_true(legacy.knows(extra), "a skill they had trained")
	assert_eq(legacy.equipped.size(), CampaignRules.SKILL_SLOTS)

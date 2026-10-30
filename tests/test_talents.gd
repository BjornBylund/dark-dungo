## Talents: a point at levels 2, 4, 6, 8 and 10 buys one of the row's three;
## they work in fights like trinkets that can't come off, keep through saving,
## and the Guild clears them for gold.
extends TestCase

const CAMPAIGN: CampaignDef = preload("res://content/campaign.tres")


func _campaign() -> Campaign:
	var campaign := Campaign.create(CAMPAIGN, 1)
	campaign.scenes.clear()
	return campaign


func _crusader(campaign: Campaign) -> HeroRecord:
	for hero in campaign.roster():
		if hero.def.resource_path.ends_with("vanguard.tres"):
			return hero
	return null


func _at_level(hero: HeroRecord, level: int) -> void:
	hero.xp = 0 if level == 0 else CampaignRules.LEVEL_XP[level - 1]


# --- The talents ---

func test_every_hero_has_five_rows_of_three_talents_that_do_something() -> void:
	var cast: Array[UnitDef] = []
	cast.append_array(CAMPAIGN.starting_heroes)
	cast.append_array(CAMPAIGN.recruits)
	for unit in cast:
		assert_eq(unit.talents.size(), CampaignRules.TALENT_LEVELS.size() * CampaignRules.TALENTS_PER_ROW,
				"%s's talents" % unit.display_name)
		var ids := {}
		var skill_ids := unit.skills.map(func(skill: SkillDef) -> StringName: return skill.id)
		if unit.riposte_skill:
			skill_ids.append(unit.riposte_skill.id)
		for talent in unit.talents:
			var label := "%s: %s" % [unit.display_name, talent.display_name]
			assert_false(ids.has(talent.id), label + " has its own id")
			ids[talent.id] = true
			assert_ne(talent.display_name, "", label + " has a name")
			assert_false(UiStyle.perk_effects(talent, unit).is_empty(), label + " does something")
			for bonus in talent.bonuses:
				for id in bonus.if_skills:
					assert_true(id in skill_ids, "%s names the class's skill %s" % [label, id])
			for trigger in talent.triggers:
				for id in trigger.if_skills:
					assert_true(id in skill_ids, "%s names the class's skill %s" % [label, id])


# --- Choosing ---

func test_a_row_opens_at_each_talent_level() -> void:
	var hero := _crusader(_campaign())
	for pair: Array in [[0, 0], [1, 0], [2, 1], [3, 1], [4, 2], [9, 4], [10, 5]]:
		_at_level(hero, pair[0])
		assert_eq(hero.talent_rows_open(), pair[1], "level %d" % pair[0])
		assert_eq(hero.talent_points(), pair[1], "nothing spent at level %d" % pair[0])


func test_a_point_buys_one_talent_of_an_open_row() -> void:
	var campaign := _campaign()
	var hero := _crusader(campaign)
	var first := hero.talent_row(0)
	var second := hero.talent_row(1)
	assert_eq(campaign.choose_talent(hero, first[1]), "Opens at level 2.")
	_at_level(hero, 4)
	assert_eq(campaign.choose_talent(hero, second[2]), "", "rows can be chosen in any order")
	assert_eq(campaign.choose_talent(hero, first[1]), "")
	assert_eq(hero.talent_on(0), first[1])
	assert_eq(hero.talent_on(1), second[2])
	assert_eq(hero.talent_points(), 0)
	assert_ne(campaign.choose_talent(hero, first[0]), "", "one per row")
	assert_eq(hero.talent_on(0), first[1])
	var other: HeroRecord = campaign.roster().filter(func(h: HeroRecord) -> bool: return h != hero)[0]
	assert_ne(campaign.choose_talent(other, first[0]), "", "only the class's own")


func test_the_guild_clears_talents_for_gold() -> void:
	var campaign := _campaign()
	var hero := _crusader(campaign)
	_at_level(hero, 2)
	assert_eq(campaign.can_reset_talents(hero), "No talents chosen yet.")
	campaign.choose_talent(hero, hero.talent_row(0)[0])
	var gold := campaign.gold
	assert_eq(campaign.reset_talents(hero), "")
	assert_eq(campaign.gold, gold - campaign.talent_reset_price(hero))
	assert_eq(hero.chosen_talents().size(), 0)
	assert_eq(hero.talent_points(), 1, "the point is back")
	campaign.choose_talent(hero, hero.talent_row(0)[2])
	campaign.gold = 0
	assert_eq(campaign.reset_talents(hero), "Not enough gold.")


# --- In fights and saves ---

func test_chosen_talents_work_like_trinkets() -> void:
	var campaign := _campaign()
	var hero := _crusader(campaign)
	_at_level(hero, 10)
	var plain := Growth.hero_combatant(hero)
	var zealot: TalentDef = hero.def.talents.filter(func(t: TalentDef) -> bool: return t.id == &"zealot")[0]
	var crusade: TalentDef = hero.def.talents.filter(func(t: TalentDef) -> bool: return t.id == &"crusade")[0]
	campaign.choose_talent(hero, zealot)
	campaign.choose_talent(hero, crusade)
	var unit := Growth.hero_combatant(hero)
	assert_between(unit.stat(&"damage") - plain.stat(&"damage"), 0.099, 0.101)
	assert_true(crusade.triggers[0] in unit.triggers, "its trigger fires in fights")
	var steadfast: TalentDef = hero.def.talents.filter(func(t: TalentDef) -> bool: return t.id == &"steadfast")[0]
	campaign.reset_talents(hero)
	campaign.choose_talent(hero, steadfast)
	assert_eq(Growth.hero_combatant(hero).max_hp, plain.max_hp + roundi(hero.def.max_hp * 0.12))


func test_talents_survive_saving() -> void:
	var campaign := _campaign()
	var hero := _crusader(campaign)
	_at_level(hero, 6)
	campaign.choose_talent(hero, hero.talent_row(0)[1])
	campaign.choose_talent(hero, hero.talent_row(2)[0])
	var data: Dictionary = JSON.parse_string(JSON.stringify(campaign.to_dict()))
	var loaded := _crusader(Campaign.from_dict(data, CAMPAIGN))
	assert_eq(loaded.talent_on(0), hero.talent_on(0))
	assert_eq(loaded.talent_on(1), null)
	assert_eq(loaded.talent_on(2), hero.talent_on(2))
	assert_eq(loaded.talent_points(), 1)


func test_saves_from_before_talents_and_unknown_ones_load_with_points_to_spend() -> void:
	var campaign := _campaign()
	var hero := _crusader(campaign)
	_at_level(hero, 4)
	var data := hero.to_dict()
	data.erase("talents")
	assert_eq(HeroRecord.from_dict(data).talent_points(), 2)
	data["talents"] = ["no_such_talent", String(hero.talent_row(1)[0].id)]
	var loaded := HeroRecord.from_dict(data)
	assert_eq(loaded.talent_on(0), null, "a talent the class no longer has is dropped")
	assert_eq(loaded.talent_on(1), hero.talent_row(1)[0])

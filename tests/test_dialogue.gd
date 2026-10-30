## Dialogue scenes: the scripts in content/dialogue/ are well formed, and the
## campaign queues the opening, a recruit's join and a scene per level gained.
extends TestCase

const CAMPAIGN: CampaignDef = preload("res://content/campaign.tres")


func _cast() -> Array[UnitDef]:
	var cast: Array[UnitDef] = []
	cast.append_array(CAMPAIGN.starting_heroes)
	cast.append_array(CAMPAIGN.recruits)
	return cast


func _names(units: Array[UnitDef]) -> Array:
	return units.map(func(unit: UnitDef) -> String: return unit.display_name)


func _facts(party: Array[HeroRecord] = []) -> Dictionary:
	return {region = null, boss = false, long = false, opened = "", party = party, fallen = [] as Array[HeroRecord],
			bonds = Bonds.new(), week = 1}


func _said(variant: Dictionary) -> String:
	return variant.lines[0][1] if not variant.is_empty() else ""


# --- The scripts ---

## Every script holds what it needs (a story part for each level, lines that
## always play), and uses only known speakers, conditions and placeholders.
func test_every_script_passes_its_checks() -> void:
	for hero: UnitDef in [null] + _cast():
		var path: String = hero.dialogue if hero else CAMPAIGN.dialogue
		assert_true(FileAccess.file_exists(path), "%s has a script" % (hero.display_name if hero else "the Ancestor"))
		var found := Dialogue.problems(FileAccess.get_file_as_string(path), Dialogue.context_for(CAMPAIGN, hero, _cast()))
		for problem in found:
			assert_true(false, "%s line %d: %s" % [path.get_file(), problem.line + 1, problem.text])


func test_the_checks_name_each_mistake_and_its_line() -> void:
	var crusader: UnitDef = load("res://content/heroes/vanguard.tres")
	var context := Dialogue.context_for(CAMPAIGN, crusader, _cast())
	var text := "\n".join([
		"Ancestor: a line before any section",
		"== level 1",
		"Crusader: fine",
		"Vestal: not here without a with",
		"Crusader {partner} without its condition",
		"? boss, sunset",
		"Crusader: the {nowhere} and a { brace",
	])
	var found := Dialogue.problems(text, context)
	var lines := found.map(func(problem: Dictionary) -> int: return problem.line)
	assert_true(0 in lines, "outside any section")
	assert_true(3 in lines, "a speaker who can't be there")
	assert_true(4 in lines, "no speaker")
	assert_true(5 in lines, "an unknown condition")
	assert_true(6 in lines, "an unknown placeholder or a stray brace")
	assert_true(-1 in lines, "missing sections, like level 2")
	assert_eq(Dialogue.problems("== opening\nAncestor: {region} waits.\n== homecoming\nAncestor: Home.",
			Dialogue.context_for(CAMPAIGN, null, _cast())), [] as Array[Dictionary])


# --- Picking lines ---

func test_the_variant_with_the_most_conditions_that_hold_plays() -> void:
	var variants: Array = Dialogue.parse("""
		# A comment.
		== reflect
		Ancestor: plain
		? boss
		Ancestor: boss
		? boss, long
		Ancestor: boss and long
		? stressed
		Ancestor: stressed
		""")["reflect"]
	var facts := _facts()
	assert_eq(_said(Dialogue.pick(variants, null, facts, 0)), "plain")
	facts.boss = true
	assert_eq(_said(Dialogue.pick(variants, null, facts, 0)), "boss")
	facts.long = true
	assert_eq(_said(Dialogue.pick(variants, null, facts, 0)), "boss and long")
	var hero := HeroRecord.new(CAMPAIGN.starting_heroes[0])
	hero.stress = Dialogue.STRESSED
	facts.boss = false
	assert_eq(_said(Dialogue.pick(variants, hero, facts, 0)), "stressed")
	assert_eq(_said(Dialogue.pick(variants, null, facts, 0)), "plain", "the Ancestor is never stressed")


func test_ties_go_by_the_moment_and_with_needs_someone_else() -> void:
	var variants: Array = Dialogue.parse("""
		== reflect
		? with Vestal
		Ancestor: with the Vestal
		? with Crusader
		Ancestor: with the Crusader
		""")["reflect"]
	var crusader := HeroRecord.new(load("res://content/heroes/vanguard.tres"))
	var vestal := HeroRecord.new(load("res://content/heroes/mender.tres"))
	assert_eq(_said(Dialogue.pick(variants, crusader, _facts([crusader, vestal]), 0)), "with the Vestal",
			"the Crusader isn't with themself")
	var both := [_said(Dialogue.pick(variants, null, _facts([crusader, vestal]), 0)),
			_said(Dialogue.pick(variants, null, _facts([crusader, vestal]), 1))]
	both.sort()
	assert_eq(both, ["with the Crusader", "with the Vestal"])
	assert_eq(Dialogue.pick(variants, null, _facts(), 0), {}, "nothing holds")


# --- The campaign ---

func test_a_new_campaign_opens_with_the_starting_heroes_arriving() -> void:
	var campaign := Campaign.create(CAMPAIGN, 1)
	assert_eq(campaign.scenes.size(), 1)
	var scene := campaign.scenes[0]
	assert_eq(scene.cast.size(), CAMPAIGN.starting_heroes.size())
	assert_eq(scene.speakers[0], null, "the Ancestor speaks first")
	assert_true(scene.texts.any(func(text: String) -> bool: return CAMPAIGN.regions[0].display_name in text),
			"names the first region, capitalised to start a sentence")
	assert_false(scene.texts.any(func(text: String) -> bool: return "{" in text), "placeholders are filled in")
	assert_eq(Dialogue.mid_sentence("The Burrows"), "the Burrows")


func test_a_recruit_joins_with_their_own_scene() -> void:
	var campaign := Campaign.create(CAMPAIGN, 1)
	campaign.scenes.clear()
	campaign.recruits_waiting = 1
	var hero := campaign.recruit_choices()[0]
	assert_eq(campaign.recruit(hero), "")
	assert_eq(campaign.scenes.size(), 1)
	assert_eq(campaign.scenes[0].cast.size(), 1)
	assert_eq(campaign.scenes[0].cast[0], hero.def)
	assert_true(hero.display_name in campaign.scenes[0].title)


func test_heroes_who_level_up_get_a_scene_per_level_after_the_ancestor_greets_them_home() -> void:
	var campaign := Campaign.create(CAMPAIGN, 1)
	campaign.scenes.clear()
	var party := campaign.roster().slice(0, 4)
	party[0].xp = CampaignRules.LEVEL_XP[1] - 1
	var mission := campaign._make_mission(CampaignRules.Tier.APPRENTICE, CampaignRules.Length.LONG,
			campaign.def.regions[0])
	mission.boss = true
	campaign.board.append(mission)
	var run := campaign.embark(mission, party)
	run.outcome = MissionRun.Outcome.COMPLETED
	var before := party.map(func(hero: HeroRecord) -> int: return hero.level())
	var summary := campaign.finish_mission()
	var gained := 0
	for i in party.size():
		gained += party[i].level() - before[i]
	assert_true(party[0] in summary.level_ups)
	assert_eq(campaign.scenes.size(), gained, "one scene per level gained")
	var first := campaign.scenes[0]
	assert_eq(first.title, "%s reaches level %d" % [party[0].display_name, before[0] + 1])
	assert_eq(first.speakers[0], null, "the Ancestor greets the party home")
	assert_true(party[0].def in first.cast)
	assert_true(first.texts.size() > 3, "a look back on the mission, then the level's part of the story")
	for scene in campaign.scenes.slice(1):
		assert_ne(scene.texts[0], first.texts[0], "the Ancestor greets them only once")
	for scene in campaign.scenes:
		assert_false(scene.texts.any(func(text: String) -> bool: return "{" in text), "placeholders are filled in")


func test_waiting_scenes_survive_saving() -> void:
	var campaign := Campaign.create(CAMPAIGN, 1)
	var loaded := Campaign.from_dict(JSON.parse_string(JSON.stringify(campaign.to_dict())), CAMPAIGN)
	assert_eq(loaded.scenes.size(), 1)
	assert_eq(loaded.scenes[0].to_dict(), campaign.scenes[0].to_dict())
	assert_eq(loaded.scenes[0].cast, campaign.scenes[0].cast)

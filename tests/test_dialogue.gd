## Dialogue scenes: the scripts in content/dialogue/ are well formed, and the
## campaign queues the opening, a recruit's join and a scene per level gained.
extends TestCase

const CAMPAIGN: CampaignDef = preload("res://content/campaign.tres")
const PLACEHOLDER := "\\{(\\w*)\\}"


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

func test_every_hero_has_a_story_part_for_each_level_and_a_fallback_to_reflect() -> void:
	for unit in _cast():
		var script := Dialogue.script_at(unit.dialogue)
		assert_false(script.is_empty(), "%s has a script" % unit.display_name)
		var recruit := unit in CAMPAIGN.recruits
		var sections := ["reflect"]
		if recruit:
			sections.append("join")
		# Recruits join at level 1; the starting heroes start at 0.
		for level in range(2 if recruit else 1, CampaignRules.MAX_LEVEL + 1):
			sections.append("level %d" % level)
		for section: String in sections:
			var variants: Array = script.get(section, [])
			assert_true(variants.any(func(variant: Dictionary) -> bool: return variant.conditions.is_empty()),
					"%s's %s has lines that always play" % [unit.display_name, section])
	var ancestor := Dialogue.script_at(CAMPAIGN.dialogue)
	for section: String in ["opening", "homecoming"]:
		assert_true(ancestor.get(section, []).any(func(variant: Dictionary) -> bool: return variant.conditions.is_empty()),
				"the Ancestor's %s" % section)


func test_scripts_use_only_known_speakers_conditions_and_placeholders() -> void:
	_check_script(CAMPAIGN.dialogue, "")
	for unit in _cast():
		_check_script(unit.dialogue, unit.display_name)


## A hero's lines are theirs and the Ancestor's, plus whoever a "with" condition
## brings; the opening is the starting heroes'. Placeholders need the condition
## that gives them a value.
func _check_script(path: String, own_name: String) -> void:
	var names := _names(_cast())
	var starting := _names(CAMPAIGN.starting_heroes)
	var regions := CAMPAIGN.regions.map(func(region: RegionDef) -> String: return String(region.id))
	var placeholder := RegEx.create_from_string(PLACEHOLDER)
	var script := Dialogue.script_at(path)
	for section: String in script:
		for variant: Dictionary in script[section]:
			var where := "%s, %s ? %s" % [path.get_file(), section, ", ".join(variant.conditions)]
			var present := []
			for condition: String in variant.conditions:
				var word := condition.get_slice(" ", 0)
				var argument := condition.substr(word.length()).strip_edges()
				assert_true(word in Dialogue.CONDITIONS, "%s: unknown condition" % where)
				if word == "with":
					assert_true(argument in names and argument != own_name, "%s: nobody to be with" % where)
					present.append(argument)
				if word == "region":
					assert_true(argument in regions, "%s: no such region" % where)
			assert_false(variant.lines.is_empty(), "%s: has lines" % where)
			for line: Array in variant.lines:
				var speaker: String = line[0]
				assert_true(speaker == Dialogue.NARRATOR or speaker == own_name or speaker in present
						or (section == "opening" and speaker in starting), "%s: %s can't speak here" % [where, speaker])
				var found := placeholder.search_all(line[1])
				assert_eq(found.size(), String(line[1]).count("{"), "%s: a stray brace" % where)
				for match_result in found:
					var key := match_result.get_string(1)
					assert_true(Dialogue.PLACEHOLDERS.has(key), "%s: unknown {%s}" % [where, key])
					var needs: String = Dialogue.PLACEHOLDERS.get(key, "")
					assert_true(needs == "" or needs in variant.conditions, "%s: {%s} needs ? %s" % [where, key, needs])


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
	assert_eq(Dialogue._mid_sentence("The Burrows"), "the Burrows")


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

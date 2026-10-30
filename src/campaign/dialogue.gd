## Dialogue scenes from the scripts in content/dialogue/: the campaign's
## opening, a recruit joining, and heroes levelling up. Pure logic: the
## campaign queues the scenes and the town plays them (DialogueView).
##
## A script is plain text. "== name" starts a section, and every other line is
## "Speaker: text", the speaker being "Ancestor" or a hero's class name. Lines
## starting with # are comments. A section can hold variants: "? a, b" starts
## one that plays only when all its conditions hold, and of those that hold
## the one with the most conditions wins (ties go by the moment, so the same
## moment always says the same). Lines before any "?" are a variant with no
## conditions: the fallback.
##
## The Ancestor's script (CampaignDef.dialogue) has "opening", played as a
## campaign starts, and "homecoming", which greets a party home before its
## heroes' level-up scenes. A hero's script (UnitDef.dialogue) has "join" (for
## a recruit), "level 1" to "level 10" (their story, a part per level) and
## "reflect", where they look back on the mission before the level's part.
##
## Conditions, about the mission just finished:
##   boss            its boss fell
##   long            it was a long mission
##   opened          the boss win opened a new region ({opened})
##   fallen          a hero in the party fell and is wounded ({fallen})
##   region <id>     it was in that region, e.g. "region graveyard"
##   with <class>    that hero was in the party, e.g. "with Vestal"; they may speak
##   partner         the hero fought beside someone they are Respected or
##                   Partners with ({partner})
##   stressed, calm  the hero's stress is 6 or more, or 1 or less
## Placeholders: {region} and {boss} (the mission's region and its boss, or the
## newest open region outside a mission), {week}, and those above. Hero names
## are class names, so lines say "the {fallen}".
class_name Dialogue
extends RefCounted

const NARRATOR := "Ancestor"
const CONDITIONS: Array[String] = ["boss", "long", "opened", "fallen", "region", "with", "partner", "stressed", "calm"]
## Placeholder -> the condition its variant needs, or "" when it always has a value.
const PLACEHOLDERS := {"region": "", "boss": "", "week": "", "opened": "opened", "fallen": "fallen", "partner": "partner"}
const STRESSED := 6
const CALM := 1

## Path -> parsed script.
static var _scripts := {}
## "the" starting a line or a sentence, as a placeholder leaves it.
static var _sentence_case := RegEx.create_from_string("(^|[.!?] )the ")


## The parsed script at `path` (empty for no path): section name -> variants,
## each {conditions: Array[String], lines: [[speaker, text], ...]}.
static func script_at(path: String) -> Dictionary:
	if path == "":
		return {}
	if not _scripts.has(path):
		_scripts[path] = parse(FileAccess.get_file_as_string(path))
	return _scripts[path]


static func parse(text: String) -> Dictionary:
	var sections := {}
	var variants := []
	for raw: String in text.split("\n"):
		var line := raw.strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("=="):
			variants = []
			sections[line.trim_prefix("==").strip_edges()] = variants
		elif line.begins_with("?"):
			var conditions: Array[String] = []
			for condition: String in line.trim_prefix("?").split(",", false):
				if condition.strip_edges() != "":
					conditions.append(condition.strip_edges())
			variants.append({conditions = conditions, lines = []})
		else:
			if variants.is_empty():
				variants.append({conditions = [] as Array[String], lines = []})
			var colon := line.find(":")
			variants.back().lines.append([line.left(colon).strip_edges(), line.substr(colon + 1).strip_edges()])
	return sections


## The scene that opens a campaign, as the starting heroes arrive. Null without one.
static func opening(campaign: Campaign) -> DialogueScene:
	var scene := DialogueScene.new("Arrival")
	_add(scene, script_at(campaign.def.dialogue).get("opening", []), null, _town_facts(campaign), campaign, 0)
	return null if scene.is_empty() else scene


## The scene for `hero` joining the roster. Null without one.
static func join(campaign: Campaign, hero: HeroRecord) -> DialogueScene:
	var scene := DialogueScene.new("The %s joins" % hero.display_name)
	_add(scene, script_at(hero.def.dialogue).get("join", []), hero, _town_facts(campaign), campaign, 0)
	return null if scene.is_empty() else scene


## The scenes for heroes who levelled up finishing `mission`, one per level
## gained: the first opens with the Ancestor greeting the party home, and each
## hero's first looks back on the mission. `levels_before` maps each of those
## heroes to the level they had before it.
static func level_ups(campaign: Campaign, mission: Mission, party: Array[HeroRecord], fallen: Array[HeroRecord],
		opened: String, levels_before: Dictionary) -> Array[DialogueScene]:
	var facts := {
		region = mission.region, boss = mission.boss, long = mission.length == CampaignRules.Length.LONG,
		opened = opened, party = party, fallen = fallen, bonds = campaign.bonds, week = campaign.week,
	}
	var scenes: Array[DialogueScene] = []
	for hero: HeroRecord in levels_before:
		var script := script_at(hero.def.dialogue)
		if script.is_empty():
			continue
		for level in range(levels_before[hero] + 1, hero.level() + 1):
			var scene := DialogueScene.new("%s reaches level %d" % [hero.display_name, level])
			if scenes.is_empty():
				_add(scene, script_at(campaign.def.dialogue).get("homecoming", []), null, facts, campaign, campaign.week)
			if level == levels_before[hero] + 1:
				_add(scene, script.get("reflect", []), hero, facts, campaign, campaign.week + level)
			_add(scene, script.get("level %d" % level, []), hero, facts, campaign, campaign.week + level)
			if not scene.is_empty():
				scenes.append(scene)
	return scenes


## The variant of `variants` that fits best for `hero` (null for the Ancestor):
## of those whose conditions all hold, the one with the most conditions, ties
## going by `moment`. Empty if none holds.
static func pick(variants: Array, hero: HeroRecord, facts: Dictionary, moment: int) -> Dictionary:
	var best := []
	var most := -1
	for variant: Dictionary in variants:
		if not variant.conditions.all(func(condition: String) -> bool: return _holds(condition, hero, facts)):
			continue
		if variant.conditions.size() > most:
			most = variant.conditions.size()
			best = [variant]
		elif variant.conditions.size() == most:
			best.append(variant)
	return {} if best.is_empty() else best[posmod(moment, best.size())]


## Facts outside a mission: the newest open region, nobody in a party.
static func _town_facts(campaign: Campaign) -> Dictionary:
	var regions := campaign.open_regions()
	return {
		region = regions.back() if not regions.is_empty() else null, boss = false, long = false, opened = "",
		party = [] as Array[HeroRecord], fallen = [] as Array[HeroRecord], bonds = campaign.bonds, week = campaign.week,
	}


## Adds the lines of the variant that fits best, placeholders filled in. A line
## by a hero who isn't in the roster is left out.
static func _add(scene: DialogueScene, variants: Array, hero: HeroRecord, facts: Dictionary, campaign: Campaign,
		moment: int) -> void:
	var variant := pick(variants, hero, facts, moment)
	if variant.is_empty():
		return
	var values := _values(hero, facts)
	for line: Array in variant.lines:
		var speaker: UnitDef = null
		if line[0] != NARRATOR:
			var record := _in_roster(campaign, line[0])
			if record == null:
				continue
			speaker = record.def
		scene.add_line(speaker, _sentence_case.sub(String(line[1]).format(values), "$1The ", true))


static func _holds(condition: String, hero: HeroRecord, facts: Dictionary) -> bool:
	var word := condition.get_slice(" ", 0)
	var argument := condition.substr(word.length()).strip_edges()
	match word:
		"boss":
			return facts.boss
		"long":
			return facts.long
		"opened":
			return facts.opened != ""
		"fallen":
			return not facts.fallen.is_empty()
		"region":
			return facts.region != null and facts.region.id == StringName(argument)
		"with":
			return facts.party.any(func(other: HeroRecord) -> bool: return other != hero and other.display_name == argument)
		"partner":
			return _partner(hero, facts) != null
		"stressed":
			return hero != null and hero.stress >= STRESSED
		"calm":
			return hero != null and hero.stress <= CALM
	return false


## Someone in the party `hero` is Respected or Partners with, or null.
static func _partner(hero: HeroRecord, facts: Dictionary) -> HeroRecord:
	if hero == null:
		return null
	for other: HeroRecord in facts.party:
		if other != hero and facts.bonds.level(hero, other) >= Bonds.Level.RESPECTED:
			return other
	return null


## Names like "The Burrows" go in as "the Burrows"; _add capitalises them again
## at the start of a sentence.
static func _values(hero: HeroRecord, facts: Dictionary) -> Dictionary:
	var region: RegionDef = facts.region
	var partner := _partner(hero, facts)
	return {
		"region": _mid_sentence(region.display_name) if region else "",
		"boss": _mid_sentence(region.boss.display_name) if region and region.boss else "",
		"week": str(facts.week),
		"opened": _mid_sentence(facts.opened),
		"fallen": facts.fallen[0].display_name if not facts.fallen.is_empty() else "",
		"partner": partner.display_name if partner else "",
	}


static func _mid_sentence(name: String) -> String:
	return "the " + name.trim_prefix("The ") if name.begins_with("The ") else name


static func _in_roster(campaign: Campaign, display_name: String) -> HeroRecord:
	for hero in campaign.roster():
		if hero.display_name == display_name:
			return hero
	return null

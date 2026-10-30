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
static var _placeholder := RegEx.create_from_string("\\{(\\w*)\\}")


## The parsed script at `path` (empty for no path): section name -> variants,
## each {conditions: Array[String], at: its first line, lines: [[speaker, text,
## line], ...]}, line numbers counting from 0.
static func script_at(path: String) -> Dictionary:
	if path == "":
		return {}
	if not _scripts.has(path):
		_scripts[path] = parse(FileAccess.get_file_as_string(path))
	return _scripts[path]


## Drops the parsed script at `path`, so the next script_at() reads the file again.
static func forget(path: String) -> void:
	_scripts.erase(path)


static func parse(text: String) -> Dictionary:
	var sections := {}
	var variants := []
	var raw_lines := text.split("\n")
	for i in raw_lines.size():
		var line := raw_lines[i].strip_edges()
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
			variants.append({conditions = conditions, at = i, lines = []})
		else:
			if variants.is_empty():
				variants.append({conditions = [] as Array[String], at = i, lines = []})
			var colon := line.find(":")
			variants.back().lines.append([line.left(colon).strip_edges(), line.substr(colon + 1).strip_edges(), i])
	return sections


## What's wrong with a script, as {line (from 0, or -1 for the whole script),
## text}, in line order. `context`: {own: the hero's class name ("" for the
## Ancestor's script), cast: every hero's class name, starting: the starting
## heroes', regions: region ids, sections: the sections it must have, each with
## lines that always play}. A hero's lines are theirs and the Ancestor's, plus
## whoever a "with" condition brings; the opening is the starting heroes'.
## Placeholders need the condition that gives them a value.
static func problems(text: String, context: Dictionary) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var raw_lines := text.split("\n")
	var in_section := false
	for i in raw_lines.size():
		var line := raw_lines[i].strip_edges()
		if line == "" or line.begins_with("#"):
			continue
		if line.begins_with("=="):
			in_section = true
		elif not in_section:
			found.append({line = i, text = "Outside any section: add a \"== name\" line above it."})
		elif not line.begins_with("?") and line.find(":") < 0:
			found.append({line = i, text = "No speaker: write \"Speaker: text\"."})
	var script := parse(text)
	for section: String in context.get("sections", []):
		if not script.get(section, []).any(func(variant: Dictionary) -> bool: return variant.conditions.is_empty()):
			found.append({line = -1, text = "Needs \"== %s\" with lines that always play (before any \"?\")." % section})
	for section: String in script:
		for variant: Dictionary in script[section]:
			var present: Array[String] = []
			for condition: String in variant.conditions:
				var word := condition.get_slice(" ", 0)
				var argument := condition.substr(word.length()).strip_edges()
				if word not in CONDITIONS:
					found.append({line = variant.at, text = "Unknown condition \"%s\"." % condition})
				elif word == "with":
					if argument not in context.get("cast", []) or argument == context.get("own", ""):
						found.append({line = variant.at, text = "\"with %s\": no other hero by that name." % argument})
					else:
						present.append(argument)
				elif word == "region" and argument not in context.get("regions", []):
					found.append({line = variant.at, text = "\"region %s\": no region with that id." % argument})
			if variant.lines.is_empty():
				found.append({line = variant.at, text = "A variant with no lines."})
			for line: Array in variant.lines:
				var speaker: String = line[0]
				if not (speaker == NARRATOR or speaker == context.get("own", "") or speaker in present
						or (section == "opening" and speaker in context.get("starting", []))):
					found.append({line = line[2], text = _who_may_speak(speaker, context)})
				var marks := _placeholder.search_all(line[1])
				if marks.size() != String(line[1]).count("{") or marks.size() != String(line[1]).count("}"):
					found.append({line = line[2], text = "A brace without its pair: placeholders look like {region}."})
				for mark in marks:
					var key := mark.get_string(1)
					if not PLACEHOLDERS.has(key):
						found.append({line = line[2], text = "Unknown placeholder {%s}." % key})
					elif PLACEHOLDERS[key] != "" and PLACEHOLDERS[key] not in variant.conditions.map(
							func(condition: String) -> String: return condition.get_slice(" ", 0)):
						found.append({line = line[2], text = "{%s} needs \"? %s\" on its variant." % [key, PLACEHOLDERS[key]]})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line < b.line)
	return found


## What problems() checks `hero`'s script against (null for the Ancestor's),
## from `campaign` and the heroes in `cast`: a starting hero's script needs
## "reflect" and "level 1" to the top level, a recruit's "join" and from
## "level 2", the Ancestor's "opening" and "homecoming".
static func context_for(campaign: CampaignDef, hero: UnitDef, cast: Array) -> Dictionary:
	var sections: Array[String] = ["opening", "homecoming"]
	if hero:
		var recruit := hero in campaign.recruits
		sections.assign(["reflect", "join"] if recruit else ["reflect"])
		for level in range(2 if recruit else 1, CampaignRules.MAX_LEVEL + 1):
			sections.append("level %d" % level)
	var name_of := func(unit: UnitDef) -> String: return unit.display_name
	return {
		own = hero.display_name if hero else "", cast = cast.map(name_of),
		starting = campaign.starting_heroes.map(name_of),
		regions = campaign.regions.map(func(region: RegionDef) -> String: return String(region.id)),
		sections = sections,
	}


## Why `speaker` can't say a line here.
static func _who_may_speak(speaker: String, context: Dictionary) -> String:
	var who := "%s can't speak here" % (speaker if speaker != "" else "Nobody")
	if context.get("own", "") != "":
		return who + ": only the %s, the %s, and heroes a \"? with\" brings." % [NARRATOR, context.own]
	return who + ": only the %s, and the starting heroes in \"== opening\"." % NARRATOR


## `text` with its placeholders filled from `values`, a "the" that begins a
## sentence capitalised.
static func fill(text: String, values: Dictionary) -> String:
	return _sentence_case.sub(text.format(values), "$1The ", true)


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
		scene.add_line(speaker, fill(line[1], values))


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
		"region": mid_sentence(region.display_name) if region else "",
		"boss": mid_sentence(region.boss.display_name) if region and region.boss else "",
		"week": str(facts.week),
		"opened": mid_sentence(facts.opened),
		"fallen": facts.fallen[0].display_name if not facts.fallen.is_empty() else "",
		"partner": partner.display_name if partner else "",
	}


## "The Burrows" as it reads mid-sentence: "the Burrows".
static func mid_sentence(name: String) -> String:
	return "the " + name.trim_prefix("The ") if name.begins_with("The ") else name


static func _in_roster(campaign: Campaign, display_name: String) -> HeroRecord:
	for hero in campaign.roster():
		if hero.display_name == display_name:
			return hero
	return null

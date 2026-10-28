## The balance tool's Arena: one hand-picked fight played over and over with
## different dice by AutoPlayer.best. Up to four heroes stand in rank order,
## each with their loadout and trinkets, against an encounter at a preset,
## starting at a share of their HP and some stress. step() plays a few fights
## at a time so the tool stays responsive; restart() starts over, as the tool
## does whenever anything changes. The combat screen can play it too (Watch),
## through battle(), `title` and `bot_plays`. The setup is kept in
## user://balance_arena.json between sessions.
class_name BalanceArena
extends RefCounted

## Fights per run, and per run of More.
const FIGHTS := 200
const MORE := 1000
const SAVE_PATH := "user://balance_arena.json"

## Up to four, rank 1 first: {hero: UnitDef, skills: Array[SkillDef], trinkets: Array[TrinketDef]}.
var slots: Array[Dictionary] = []
var encounter: EncounterDef
var preset: BalancePreset
## The party's starting HP, as a share of max HP, and stress.
var hp := 1.0
var stress := 0
## Whether the bot plays the fight in the combat screen (Watch) or the player does.
var bot_plays := true
## What the current run found so far: {n, wins, stalled, lost, stress, deaths, rounds}.
var totals := {}
## Hero def -> {n, lost, died}.
var heroes := {}
## Skill -> times used, and hero def -> turns taken.
var uses := {}
var turns := {}
## {win, lost} of the last run that finished before the latest restart, to compare with.
var previous := {}
var _goal := 0

var title: String:
	get:
		return encounter.display_name if encounter else "Arena"


## The setup saved at `path`, or the first four starting heroes against the first region's boss.
static func loaded(library: BalanceLibrary, path: String = SAVE_PATH) -> BalanceArena:
	var arena := BalanceArena.new()
	arena.preset = library.targets.preset_named("Base")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if data is Dictionary:
		arena._read(library, data)
	if arena.slots.is_empty():
		var cast := library.campaign.starting_heroes if not library.campaign.starting_heroes.is_empty() else library.heroes
		for hero in cast.slice(0, 4):
			arena.slots.append({hero = hero, skills = hero.skills.slice(0, Rules.SKILL_SLOTS), trinkets = []})
	if arena.encounter == null and not library.encounters.is_empty():
		var regions := library.campaign.regions
		arena.encounter = regions[0].boss if not regions.is_empty() and regions[0].boss else library.encounters[0]
	return arena


func _read(library: BalanceLibrary, data: Dictionary) -> void:
	preset = library.targets.preset_named(str(data.get("preset", "Base")))
	hp = clampf(float(data.get("hp", 1.0)), 0.05, 1.0)
	stress = clampi(int(data.get("stress", 0)), 0, Rules.STRESS_MAX - 1)
	for encounter_def in library.encounters:
		if encounter_def.resource_path == data.get("encounter", ""):
			encounter = encounter_def
	for entry: Dictionary in data.get("slots", []):
		var found := library.heroes.filter(func(h: UnitDef) -> bool: return String(h.id) == entry.get("hero", ""))
		if found.is_empty():
			continue
		var hero: UnitDef = found[0]
		var skills: Array[SkillDef] = []
		skills.assign(hero.skills.filter(func(s: SkillDef) -> bool: return String(s.id) in entry.get("skills", [])))
		var trinkets: Array[TrinketDef] = []
		trinkets.assign(library.trinkets.filter(func(t: TrinketDef) -> bool: return String(t.id) in entry.get("trinkets", [])))
		slots.append({hero = hero, skills = skills, trinkets = trinkets})


func save_setup(path: String = SAVE_PATH) -> void:
	var data := {
		preset = preset.name, hp = hp, stress = stress, encounter = encounter.resource_path if encounter else "",
		slots = slots.filter(func(slot: Dictionary) -> bool: return slot.hero != null).map(func(slot: Dictionary) -> Dictionary:
			return {
				hero = String(slot.hero.id),
				skills = slot.skills.map(func(s: SkillDef) -> String: return String(s.id)),
				trinkets = slot.trinkets.map(func(t: TrinketDef) -> String: return String(t.id)),
			}),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


# --- Running ---

## Forgets what was found and aims for `fights` more. A finished run becomes `previous`.
func restart(fights: int = FIGHTS) -> void:
	if _goal > 0 and played() >= _goal:
		previous = {win = rate("wins"), lost = rate("lost")}
	totals = {}
	heroes = {}
	uses = {}
	turns = {}
	_goal = fights


func played() -> int:
	return totals.get("n", 0)


func goal() -> int:
	return _goal


func is_ready() -> bool:
	return encounter != null and not encounter.enemies.is_empty() \
			and slots.any(func(slot: Dictionary) -> bool: return slot.hero != null)


func is_done() -> bool:
	return played() >= _goal or not is_ready()


## Plays fights until `msec` milliseconds have passed, at least one.
func step(msec: int) -> void:
	var until := Time.get_ticks_msec() + msec
	while not is_done():
		var fight := battle(hash(["arena", played()]))
		_count(BalanceSweep.play(fight, fight.heroes.duplicate()))
		if Time.get_ticks_msec() >= until:
			return


## The fight with fresh combatants, rolling dice from `seed_value`.
func battle(seed_value: int) -> Battle:
	var party: Array[Combatant] = []
	for slot in slots:
		var hero: UnitDef = slot.hero
		if hero == null:
			continue
		var loadout: Array[SkillDef] = []
		loadout.assign(slot.skills.filter(func(s: SkillDef) -> bool: return s in hero.skills))
		if loadout.is_empty():
			loadout.assign(hero.skills.slice(0, Rules.SKILL_SLOTS))
		var worn: Array[TrinketDef] = []
		worn.assign(slot.trinkets)
		var unit := Growth.hero_combatant(BalanceSweep.record(hero, loadout, worn, preset))
		unit.hp = maxi(1, roundi(unit.max_hp * hp))
		unit.stress = stress
		party.append(unit)
	var enemies: Array[Combatant] = []
	for enemy in encounter.enemies:
		enemies.append(Growth.enemy_combatant(enemy, preset.tier))
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	return Battle.new(party, enemies, dice)


func _count(outcome: Dictionary) -> void:
	BalanceSweep.tally(totals, {n = 1, wins = int(outcome.win), stalled = int(outcome.stalled), lost = outcome.lost,
			stress = outcome.stress, deaths = outcome.deaths, rounds = outcome.rounds})
	for hero: UnitDef in outcome.hero_lost:
		BalanceSweep.tally(heroes.get_or_add(hero, {}), {n = 1, lost = outcome.hero_lost[hero],
				died = int(outcome.hero_died[hero])})
	BalanceSweep.tally(uses, outcome.uses)
	BalanceSweep.tally(turns, outcome.turns)


# --- Results ---

## A total per fight: rate("wins") is the win rate, rate("lost") the HP lost.
func rate(key: String) -> float:
	return BalanceSweep.Results.rate(totals, key)


func hero_rate(hero: UnitDef, key: String) -> float:
	return BalanceSweep.Results.rate(heroes.get(hero, {}), key)


## The share of `hero`'s turns spent on `skill`.
func usage(hero: UnitDef, skill: SkillDef) -> float:
	return float(uses.get(skill, 0)) / maxi(1, turns.get(hero, 0))

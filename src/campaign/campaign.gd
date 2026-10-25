## The campaign: the estate's gold and heirlooms, the cast, building levels, the
## week and its mission board, and the mission in progress. Pure logic like the
## combat core: every random choice comes from `rng`, and the whole state saves
## to a dictionary. Town actions return "" when allowed, or the reason they aren't.
class_name Campaign
extends RefCounted

enum Eligibility { OK, UNDERLEVELED, WILL_NOT_GO, WOUNDED, BUSY, NOT_RECRUITED }

## 2 added regions to missions and 3 mission maps; older saves still load.
const SAVE_VERSION := 3

var def: CampaignDef
var week := 1
var gold := CampaignRules.STARTING_GOLD
var heirlooms: Dictionary[StringName, int] = {}
var buildings: Dictionary[StringName, int] = {}
## The whole cast: starting heroes, then arrivals in order.
var heroes: Array[HeroRecord] = []
var board: Array[Mission] = []
## The mission in progress, or null when the party is in town.
var run: MissionRun
var rng := RandomNumberGenerator.new()


static func create(campaign_def: CampaignDef, seed_value: int) -> Campaign:
	var campaign := Campaign.new()
	campaign.def = campaign_def
	campaign.rng.seed = seed_value
	for unit in campaign_def.starting_heroes:
		var record := HeroRecord.new(unit)
		record.arrived = true
		record.recruited = true
		campaign.heroes.append(record)
	for unit in campaign_def.arrivals:
		campaign.heroes.append(HeroRecord.new(unit))
	campaign._refresh_board()
	return campaign


func _init() -> void:
	for heirloom in CampaignRules.HEIRLOOMS:
		heirlooms[heirloom] = 0
	for id: StringName in CampaignRules.BUILDINGS:
		buildings[id] = 0


# --- Roster ---

func roster() -> Array[HeroRecord]:
	return _heroes_where(func(h: HeroRecord) -> bool: return h.recruited)


## Heroes waiting at the Stagecoach to be hired.
func stagecoach() -> Array[HeroRecord]:
	return _heroes_where(func(h: HeroRecord) -> bool: return h.arrived and not h.recruited)


func hire(hero: HeroRecord) -> String:
	if not hero.arrived or hero.recruited:
		return "%s is not at the Stagecoach." % hero.display_name
	hero.recruited = true
	return ""


func eligibility(hero: HeroRecord, mission: Mission) -> Eligibility:
	if not hero.recruited:
		return Eligibility.NOT_RECRUITED
	if hero.wounded:
		return Eligibility.WOUNDED
	if hero.abbey_activity >= 0:
		return Eligibility.BUSY
	if hero.level() >= mission.level() + CampaignRules.WILL_NOT_GO_GAP:
		return Eligibility.WILL_NOT_GO
	if levels_short(hero, mission) > 0:
		return Eligibility.UNDERLEVELED
	return Eligibility.OK


## How far a hero is below the level a mission expects: one under its level
## (0 for Apprentice, 2 for Veteran, 4 for Champion).
func levels_short(hero: HeroRecord, mission: Mission) -> int:
	return maxi(0, mission.level() - 1 - hero.level())


# --- Buildings ---

## Heirlooms for the building's next level, or {} when it is at its highest.
func building_upgrade_cost(id: StringName) -> Dictionary:
	var ladder: Array = CampaignRules.BUILDINGS[id]
	return ladder[buildings[id]] if buildings[id] < ladder.size() else {}


func upgrade_building(id: StringName) -> String:
	var cost := building_upgrade_cost(id)
	if cost.is_empty():
		return "Fully upgraded."
	for heirloom: StringName in cost:
		if heirlooms[heirloom] < cost[heirloom]:
			return "Not enough %s." % CampaignRules.HEIRLOOM_NAMES[heirloom]
	for heirloom: StringName in cost:
		heirlooms[heirloom] -= cost[heirloom]
	buildings[id] += 1
	return ""


# --- Blacksmith and Guild ---

## Gold for the hero's next weapon or armour rank, or 0 at rank 5.
func gear_cost(rank: int) -> int:
	return CampaignRules.GEAR_COST[rank - 1] if rank < CampaignRules.MAX_RANK else 0


func can_upgrade_weapon(hero: HeroRecord) -> String:
	return _can_raise_rank(hero, hero.weapon_rank, &"weaponsmith", gear_cost(hero.weapon_rank))


func upgrade_weapon(hero: HeroRecord) -> String:
	var reason := can_upgrade_weapon(hero)
	if reason == "":
		gold -= gear_cost(hero.weapon_rank)
		hero.weapon_rank += 1
	return reason


func can_upgrade_armor(hero: HeroRecord) -> String:
	return _can_raise_rank(hero, hero.armor_rank, &"armorsmith", gear_cost(hero.armor_rank))


func upgrade_armor(hero: HeroRecord) -> String:
	var reason := can_upgrade_armor(hero)
	if reason == "":
		gold -= gear_cost(hero.armor_rank)
		hero.armor_rank += 1
	return reason


func skill_cost(hero: HeroRecord, skill: SkillDef) -> int:
	var rank := hero.skill_rank(skill)
	return CampaignRules.SKILL_COST[rank - 1] if rank < CampaignRules.MAX_RANK else 0


func can_upgrade_skill(hero: HeroRecord, skill: SkillDef) -> String:
	return _can_raise_rank(hero, hero.skill_rank(skill), &"guild", skill_cost(hero, skill))


func upgrade_skill(hero: HeroRecord, skill: SkillDef) -> String:
	var reason := can_upgrade_skill(hero, skill)
	if reason == "":
		gold -= skill_cost(hero, skill)
		hero.skill_ranks[skill.id] = hero.skill_rank(skill) + 1
	return reason


## Rank r + 1 needs the building at level r, the hero at the rank's level, and the gold.
func _can_raise_rank(hero: HeroRecord, rank: int, building: StringName, cost: int) -> String:
	if not hero.recruited:
		return "Not in the roster."
	if rank >= CampaignRules.MAX_RANK:
		return "Already at the highest rank."
	if buildings[building] < rank:
		return "Upgrade the %s first." % CampaignRules.BUILDING_NAMES[building]
	var needed: int = CampaignRules.RANK_HERO_LEVEL[rank - 1]
	if hero.level() < needed:
		return "Needs hero level %d." % needed
	if gold < cost:
		return "Not enough gold."
	return ""


# --- Abbey and wounds ---

func abbey_slots() -> int:
	var level := buildings[&"abbey"]
	return 1 + int(level >= 3) + int(level >= 6)


func abbey_relief(activity: int) -> int:
	var level := buildings[&"abbey"]
	return CampaignRules.ABBEY_RELIEF[int(level >= 1) + int(level >= 4)][activity]


func abbey_price(hero: HeroRecord, activity: int) -> int:
	var level := buildings[&"abbey"]
	var discount := CampaignRules.ABBEY_DISCOUNT * (int(level >= 2) + int(level >= 5))
	return roundi(CampaignRules.ABBEY_PRICES[activity] * CampaignRules.service_multiplier(hero.level())
			* (1.0 - discount))


func abbey_occupants(activity: int) -> Array[HeroRecord]:
	return _heroes_where(func(h: HeroRecord) -> bool: return h.abbey_activity == activity)


func can_send_to_abbey(hero: HeroRecord, activity: int) -> String:
	if not hero.recruited or hero.wounded or hero.abbey_activity >= 0:
		return "%s can't go this week." % hero.display_name
	if hero.stress <= 0:
		return "%s has no stress." % hero.display_name
	if abbey_occupants(activity).size() >= abbey_slots():
		return "No free slot."
	if gold < abbey_price(hero, activity):
		return "Not enough gold."
	return ""


## Pays now; the stress comes off when the week ends, and the hero misses this week's mission.
func send_to_abbey(hero: HeroRecord, activity: int) -> String:
	var reason := can_send_to_abbey(hero, activity)
	if reason == "":
		gold -= abbey_price(hero, activity)
		hero.abbey_activity = activity
	return reason


func cancel_abbey(hero: HeroRecord) -> void:
	if hero.abbey_activity >= 0:
		gold += abbey_price(hero, hero.abbey_activity)
		hero.abbey_activity = -1


func treatment_price(hero: HeroRecord) -> int:
	return roundi(CampaignRules.WOUND_TREATMENT_PRICE * CampaignRules.service_multiplier(hero.level()))


func treat(hero: HeroRecord) -> String:
	if not hero.wounded:
		return "%s is not wounded." % hero.display_name
	if gold < treatment_price(hero):
		return "Not enough gold."
	gold -= treatment_price(hero)
	hero.wounded = false
	return ""


# --- Missions ---

func available_tiers() -> Array[int]:
	var best := 0
	for hero in roster():
		best = maxi(best, hero.level())
	var tiers: Array[int] = []
	for tier in CampaignRules.TIER_UNLOCK_LEVEL.size():
		if best >= CampaignRules.TIER_UNLOCK_LEVEL[tier]:
			tiers.append(tier)
	return tiers


func can_embark(mission: Mission, party: Array[HeroRecord]) -> String:
	if run:
		return "A mission is already under way."
	if mission not in board:
		return "That mission is no longer on the board."
	if party.is_empty() or party.size() > 4:
		return "Choose 1 to 4 heroes."
	for hero in party:
		if party.count(hero) > 1:
			return "A hero can only go once."
		match eligibility(hero, mission):
			Eligibility.WILL_NOT_GO:
				return "%s will not go on a level %d mission." % [hero.display_name, mission.level()]
			Eligibility.WOUNDED, Eligibility.BUSY, Eligibility.NOT_RECRUITED:
				return "%s can't go this week." % hero.display_name
	return ""


## With nobody fit to go (everyone wounded or at the Abbey, nobody waiting at
## the Stagecoach) the week can pass without a mission, so a wipe never strands
## a campaign that can't afford treatment.
func can_wait() -> String:
	if run:
		return "A mission is already under way."
	for hero in heroes:
		if hero.arrived and not hero.wounded and hero.abbey_activity < 0:
			return "Someone can still go on a mission."
	return ""


func wait_week() -> String:
	var reason := can_wait()
	if reason == "":
		_advance_week([])
	return reason


## Draws the mission's map. Heroes below the mission level start it stressed.
func embark(mission: Mission, party: Array[HeroRecord]) -> MissionRun:
	if can_embark(mission, party) != "":
		return null
	for hero in party:
		var short := levels_short(hero, mission)
		if short > 0:
			hero.stress = mini(hero.stress + short * CampaignRules.UNDERLEVEL_STRESS, Rules.STRESS_MAX)
	run = MissionRun.new(mission, _draw_map(mission), party, rng)
	return run


func _draw_map(mission: Mission) -> MissionMap:
	if mission.region == null:
		mission.region = def.regions[0]
	var events: Array[EventDef] = []
	events.append_array(def.events)
	events.append_array(mission.region.events)
	return MissionMap.generate(mission.region, mission.length, events, rng)


## Settles a finished mission and ends the week. Returns a summary for the
## results screen: {outcome, gold, heirlooms: {type: amount}, xp, level_ups, wounded}.
## Completing pays everything; retreating keeps what was earned on the way.
func finish_mission() -> Dictionary:
	var mission := run.mission
	var summary := {
		outcome = run.outcome, gold = 0, heirlooms = {}, xp = 0, level_ups = [], wounded = [],
	}
	for i in run.party.size():
		run.party[i].stress = clampi(run.combatants[i].stress, 0, Rules.STRESS_MAX)
	if run.outcome != MissionRun.Outcome.FAILED:
		summary.gold = run.gold_earned
		summary.heirlooms = run.heirlooms_earned.duplicate()
	match run.outcome:
		MissionRun.Outcome.COMPLETED:
			summary.gold += mission.completion_gold()
			summary.heirlooms[mission.heirloom] = summary.heirlooms.get(mission.heirloom, 0) + mission.heirloom_amount()
			summary.xp = mission.xp()
			for hero in run.party:
				if hero in run.defeated:
					continue
				var before := hero.level()
				hero.xp += summary.xp
				if hero.level() > before:
					summary.level_ups.append(hero)
		MissionRun.Outcome.RETREATED:
			for hero in run.party:
				hero.stress = mini(hero.stress + CampaignRules.RETREAT_STRESS, Rules.STRESS_MAX)
	gold += summary.gold
	for type: StringName in summary.heirlooms:
		heirlooms[type] += summary.heirlooms[type]
	var party := run.party
	var defeated := run.defeated
	run = null
	_advance_week(party)
	for hero in defeated:
		hero.wounded = true
		summary.wounded.append(hero)
	return summary


## Abbey visits and wounds resolve, idle heroes rest, a new hero may arrive, and the board refreshes.
func _advance_week(party: Array[HeroRecord]) -> void:
	week += 1
	for hero in roster():
		if hero.abbey_activity >= 0:
			hero.stress = maxi(0, hero.stress - abbey_relief(hero.abbey_activity))
			hero.abbey_activity = -1
			continue
		hero.wounded = false
		if hero not in party:
			hero.stress = maxi(0, hero.stress - CampaignRules.IDLE_STRESS_RELIEF)
	for hero in heroes:
		if not hero.arrived:
			hero.arrived = true
			var level := buildings[&"stagecoach"]
			hero.xp = CampaignRules.LEVEL_XP[level - 1] if level > 0 else 0
			break
	_refresh_board()


## Two missions per region at random unlocked tiers and lengths, but always at
## least one at the highest unlocked tier and one at Apprentice.
func _refresh_board() -> void:
	board.clear()
	var tiers := available_tiers()
	var count := def.regions.size() * CampaignRules.MISSIONS_PER_REGION
	var forced := {}
	var highest := rng.randi_range(0, count - 1)
	forced[highest] = tiers.back()
	if tiers.back() != CampaignRules.Tier.APPRENTICE:
		forced[(highest + rng.randi_range(1, count - 1)) % count] = CampaignRules.Tier.APPRENTICE
	for region in def.regions:
		for i in CampaignRules.MISSIONS_PER_REGION:
			var random_tier: int = tiers[rng.randi_range(0, tiers.size() - 1)]
			var length := rng.randi_range(0, CampaignRules.LENGTH_NAMES.size() - 1)
			board.append(_make_mission(forced.get(board.size(), random_tier), length, region))


## A mission in `region` (the first region if none is given).
func _make_mission(tier: int, length: int, region: RegionDef = null) -> Mission:
	if region == null:
		region = def.regions[0]
	var mission := Mission.new()
	mission.region = region
	mission.tier = tier as CampaignRules.Tier
	mission.length = length as CampaignRules.Length
	mission.heirloom = CampaignRules.HEIRLOOMS[rng.randi_range(0, CampaignRules.HEIRLOOMS.size() - 1)]
	return mission


func _heroes_where(predicate: Callable) -> Array[HeroRecord]:
	var result: Array[HeroRecord] = []
	result.assign(heroes.filter(predicate))
	return result


# --- Saving ---

func to_dict() -> Dictionary:
	var data := {
		version = SAVE_VERSION, week = week, gold = gold, heirlooms = heirlooms, buildings = buildings,
		# 64-bit RNG values don't survive JSON numbers, so they are stored as text.
		seed = str(rng.seed), rng_state = str(rng.state),
		heroes = heroes.map(func(h: HeroRecord) -> Dictionary: return h.to_dict()),
		board = board.map(func(m: Mission) -> Dictionary: return m.to_dict()),
		run = null,
	}
	if run:
		var run_data := run.to_dict()
		run_data.party = run.party.map(func(h: HeroRecord) -> int: return heroes.find(h))
		data.run = run_data
	return data


static func from_dict(data: Dictionary, campaign_def: CampaignDef) -> Campaign:
	var campaign := Campaign.new()
	campaign.def = campaign_def
	campaign.week = int(data.week)
	campaign.gold = int(data.gold)
	for id: String in data.heirlooms:
		campaign.heirlooms[StringName(id)] = int(data.heirlooms[id])
	for id: String in data.buildings:
		campaign.buildings[StringName(id)] = int(data.buildings[id])
	campaign.rng.seed = String(data.seed).to_int()
	campaign.rng.state = String(data.rng_state).to_int()
	for hero_data: Dictionary in data.heroes:
		campaign.heroes.append(HeroRecord.from_dict(hero_data))
	if int(data.version) < 2:
		# Saves from before regions: deal a fresh board with them.
		campaign._refresh_board()
	else:
		for mission_data: Dictionary in data.board:
			campaign.board.append(Mission.from_dict(mission_data))
	if data.run != null:
		var party: Array[HeroRecord] = []
		for index in data.run.party:
			party.append(campaign.heroes[int(index)])
		var run_data: Dictionary = data.run
		if int(data.version) < 3:
			run_data = campaign._run_before_maps(run_data)
		campaign.run = MissionRun.from_dict(run_data, party, campaign.rng)
	return campaign


## A mission saved mid-way before missions had maps carries on at the start of
## a freshly drawn map, keeping the party's state and the gold earned.
func _run_before_maps(data: Dictionary) -> Dictionary:
	var mission := Mission.from_dict(data.mission)
	var map := _draw_map(mission)
	var upgraded := data.duplicate()
	upgraded.mission = mission.to_dict()
	upgraded.map = map.to_dict()
	upgraded.merge({room_id = -1, room_done = true, heirlooms_earned = {}, pending = "", pending_kind = 0})
	return upgraded


func save(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(to_dict(), "\t"))
	return OK


## Null when there is no save or it can't be read.
static func load_from(path: String, campaign_def: CampaignDef) -> Campaign:
	if not FileAccess.file_exists(path):
		return null
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or int(data.get("version", 0)) not in range(1, SAVE_VERSION + 1):
		return null
	return from_dict(data, campaign_def)

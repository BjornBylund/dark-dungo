## The campaign: the estate's gold and heirlooms, the cast, building levels, the
## week and its mission board, and the mission in progress. Pure logic like the
## combat core: every random choice comes from `rng`, and the whole state saves
## to a dictionary. Town actions return "" when allowed, or the reason they aren't.
class_name Campaign
extends RefCounted

enum Eligibility { OK, UNDERLEVELED, WILL_NOT_GO, WOUNDED, BUSY, NOT_RECRUITED }

## 2 added regions to missions, 3 mission maps, and 4 boss progress as a share
## instead of a mission count; older saves still load.
const SAVE_VERSION := 4
## Before version 4, this many completed missions brought a region's boss.
const _OLD_BOSS_MISSIONS := 3

var def: CampaignDef
var week := 1
var gold := CampaignRules.STARTING_GOLD
var heirlooms: Dictionary[StringName, int] = {}
## Upgrade line (CampaignRules.UPGRADES) -> levels bought.
var upgrades: Dictionary[StringName, int] = {}
## The whole cast: starting heroes, then those who can join later.
var heroes: Array[HeroRecord] = []
var board: Array[Mission] = []
var bonds := Bonds.new()
## Region id -> progress towards its next boss, 0 to BOSS_PROGRESS_FULL.
var region_progress: Dictionary[StringName, int] = {}
## Region id -> boss tiers beaten (Apprentice, then Veteran, then Champion).
var bosses_beaten: Dictionary[StringName, int] = {}
## Heroes the player may still pick to join, earned by first boss wins.
var recruits_waiting := 0
## The estate's trinkets that nobody is wearing.
var trinkets: Array[TrinketDef] = []
## What the Nomad Wagon sells this week.
var wagon: Array[TrinketDef] = []
## The mission in progress, or null when the party is in town.
var run: MissionRun
var rng := RandomNumberGenerator.new()
## What happened in town as the last week ended (Abbey and Tavern visits, the
## Bar's bonds), for the screen to show once. A mission's results take it over
## (see finish_mission). Not saved.
var week_report: Array[String] = []
## Dialogue scenes waiting for the town to play them, in order: the opening,
## a recruit joining, heroes levelling up.
var scenes: Array[DialogueScene] = []


static func create(campaign_def: CampaignDef, seed_value: int) -> Campaign:
	var campaign := Campaign.new()
	campaign.def = campaign_def
	campaign.rng.seed = seed_value
	for unit in campaign_def.starting_heroes:
		var record := HeroRecord.new(unit)
		record.recruited = true
		campaign.heroes.append(record)
	for unit in campaign_def.recruits:
		campaign.heroes.append(HeroRecord.new(unit))
	campaign._refresh_board()
	campaign._restock_wagon()
	var opening := Dialogue.opening(campaign)
	if opening:
		campaign.scenes.append(opening)
	return campaign


func _init() -> void:
	for heirloom in CampaignRules.HEIRLOOMS:
		heirlooms[heirloom] = 0
	for line: StringName in CampaignRules.UPGRADES:
		upgrades[line] = 0


# --- Roster ---

func roster() -> Array[HeroRecord]:
	return _heroes_where(func(h: HeroRecord) -> bool: return h.recruited)


## Heroes who haven't joined yet; one may join for each region boss beaten
## for the first time.
func recruit_choices() -> Array[HeroRecord]:
	return _heroes_where(func(h: HeroRecord) -> bool: return not h.recruited)


## A recruit earned by a boss joins, at level 1, with their joining scene.
func recruit(hero: HeroRecord) -> String:
	if recruits_waiting <= 0:
		return "Defeat a region's boss to recruit a hero."
	if hero.recruited:
		return "%s is already in the roster." % hero.display_name
	hero.recruited = true
	hero.xp = CampaignRules.LEVEL_XP[0]
	recruits_waiting -= 1
	var scene := Dialogue.join(self, hero)
	if scene:
		scenes.append(scene)
	return ""


func eligibility(hero: HeroRecord, mission: Mission) -> Eligibility:
	if not hero.recruited:
		return Eligibility.NOT_RECRUITED
	if hero.wounded:
		return Eligibility.WOUNDED
	if hero.is_busy():
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


# --- Buildings and their upgrades ---

## Some buildings open after the first weeks, as in DD1.
func building_open(id: StringName) -> bool:
	return week >= CampaignRules.BUILDINGS[id].opens


## The building an upgrade line belongs to.
static func building_of(line: StringName) -> StringName:
	for id: StringName in CampaignRules.BUILDINGS:
		if line in CampaignRules.BUILDINGS[id].lines:
			return id
	return &""


## Heirlooms for the line's next level, or {} when it is at its highest.
func upgrade_cost(line: StringName) -> Dictionary:
	var ladder: Array = CampaignRules.UPGRADES[line]
	return ladder[upgrades[line]] if upgrades[line] < ladder.size() else {}


func can_upgrade(line: StringName) -> String:
	var building := building_of(line)
	if not building_open(building):
		return "The %s isn't open yet." % CampaignRules.BUILDINGS[building].name
	var cost := upgrade_cost(line)
	if cost.is_empty():
		return "Fully upgraded."
	for heirloom: StringName in cost:
		if heirlooms[heirloom] < cost[heirloom]:
			return "Not enough %s." % CampaignRules.HEIRLOOM_NAMES[heirloom]
	return ""


func upgrade(line: StringName) -> String:
	var reason := can_upgrade(line)
	if reason == "":
		var cost := upgrade_cost(line)
		for heirloom: StringName in cost:
			heirlooms[heirloom] -= cost[heirloom]
		upgrades[line] += 1
	return reason


## Whether any of the building's upgrades can be bought now, for the hamlet's marker.
func upgrade_ready(building: StringName) -> bool:
	return CampaignRules.BUILDINGS[building].lines.any(func(line: StringName) -> bool: return can_upgrade(line) == "")


# --- Blacksmith and Guild ---

## Gold for the hero's next weapon or armour rank (less the Furnace's
## discount), or 0 at rank 5.
func gear_cost(rank: int) -> int:
	if rank >= CampaignRules.MAX_RANK:
		return 0
	return roundi(CampaignRules.GEAR_COST[rank - 1] * (1.0 - CampaignRules.UPGRADE_DISCOUNT * upgrades[&"furnace"]))


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


## Gold for the skill's next rank (less the Training regimen's discount), or 0 at rank 5.
func skill_cost(hero: HeroRecord, skill: SkillDef) -> int:
	var rank := hero.skill_rank(skill)
	if rank >= CampaignRules.MAX_RANK:
		return 0
	return roundi(CampaignRules.SKILL_COST[rank - 1] * (1.0 - CampaignRules.UPGRADE_DISCOUNT * upgrades[&"regimen"]))


func can_upgrade_skill(hero: HeroRecord, skill: SkillDef) -> String:
	if not hero.knows(skill):
		return "Learn it first."
	return _can_raise_rank(hero, hero.skill_rank(skill), &"guild", skill_cost(hero, skill))


func upgrade_skill(hero: HeroRecord, skill: SkillDef) -> String:
	var reason := can_upgrade_skill(hero, skill)
	if reason == "":
		gold -= skill_cost(hero, skill)
		hero.skill_ranks[skill.id] = hero.skill_rank(skill) + 1
	return reason


## Gold to learn a new skill, by the hero's level as with other services.
func learn_price(hero: HeroRecord) -> int:
	return roundi(CampaignRules.SKILL_LEARN_PRICE * CampaignRules.service_multiplier(hero.level()))


func can_learn(hero: HeroRecord, skill: SkillDef) -> String:
	if not hero.recruited:
		return "Not in the roster."
	if hero.knows(skill):
		return "Already learned."
	if gold < learn_price(hero):
		return "Not enough gold."
	return ""


## Learns the skill at the Guild; it is equipped too while a slot is free.
func learn(hero: HeroRecord, skill: SkillDef) -> String:
	var reason := can_learn(hero, skill)
	if reason == "":
		gold -= learn_price(hero)
		hero.known.append(skill.id)
		if hero.equipped.size() < CampaignRules.SKILL_SLOTS:
			equip(hero, skill)
	return reason


## Takes a learned skill into fights, if a slot is free. Mid-mission, between
## fights, the hero's combatant changes too.
func equip(hero: HeroRecord, skill: SkillDef) -> String:
	if not hero.knows(skill):
		return "Learn it first."
	if hero.is_equipped(skill):
		return "Already equipped."
	if hero.equipped.size() >= CampaignRules.SKILL_SLOTS:
		return "Only %d skills fit. Unequip one first." % CampaignRules.SKILL_SLOTS
	hero.equipped.append(skill.id)
	_refit(hero)
	return ""


func unequip(hero: HeroRecord, skill: SkillDef) -> String:
	if not hero.is_equipped(skill):
		return "Not equipped."
	if hero.equipped.size() <= 1:
		return "A hero needs at least one skill."
	hero.equipped.erase(skill.id)
	_refit(hero)
	return ""


func _refit(hero: HeroRecord) -> void:
	if run and hero in run.party:
		run.combatants[run.party.find(hero)].skills = hero.equipped_skills()


## Rank r + 1 needs the upgrade line at level r, the hero at the rank's level, and the gold.
func _can_raise_rank(hero: HeroRecord, rank: int, line: StringName, cost: int) -> String:
	if not hero.recruited:
		return "Not in the roster."
	if rank >= CampaignRules.MAX_RANK:
		return "Already at the highest rank."
	if upgrades[line] < rank:
		return "Upgrade %s first." % CampaignRules.UPGRADE_NAMES[line]
	var needed: int = CampaignRules.RANK_HERO_LEVEL[rank - 1]
	if hero.level() < needed:
		return "Needs hero level %d." % needed
	if gold < cost:
		return "Not enough gold."
	return ""


# --- Stress relief (Abbey and Tavern) and wounds ---

## Each activity's own upgrade line adds a slot at levels 3 and 6.
func activity_slots(activity: StringName) -> int:
	var level := upgrades[activity]
	return CampaignRules.ACTIVITIES[activity].slots + int(level >= 3) + int(level >= 6)


## Stress taken off, raised at levels 1 and 4.
func activity_relief(activity: StringName) -> int:
	var level := upgrades[activity]
	return CampaignRules.ACTIVITIES[activity].relief[int(level >= 1) + int(level >= 4)]


## By the hero's level (DD1's service tiers), after the line's discounts.
func activity_price(hero: HeroRecord, activity: StringName) -> int:
	return roundi(activity_base_price(activity) * CampaignRules.service_multiplier(hero.level()))


## The price for heroes up to level 2, cut at line levels 2 and 5.
func activity_base_price(activity: StringName) -> float:
	var level := upgrades[activity]
	var discount := CampaignRules.ACTIVITY_DISCOUNT * (int(level >= 2) + int(level >= 5))
	return CampaignRules.ACTIVITIES[activity].price * (1.0 - discount)


func activity_occupants(activity: StringName) -> Array[HeroRecord]:
	return _heroes_where(func(h: HeroRecord) -> bool: return h.activity == activity)


func can_send(hero: HeroRecord, activity: StringName) -> String:
	var building: StringName = CampaignRules.ACTIVITIES[activity].building
	if not building_open(building):
		return "The %s isn't open yet." % CampaignRules.BUILDINGS[building].name
	if not hero.recruited or hero.wounded or hero.is_busy():
		return "%s can't go this week." % hero.display_name
	if hero.stress <= 0:
		return "%s has no stress." % hero.display_name
	if activity_occupants(activity).size() >= activity_slots(activity):
		return "No free slot."
	if gold < activity_price(hero, activity):
		return "Not enough gold."
	return ""


## Pays now; the stress comes off when the week ends (with the Tavern's side
## effects), and the hero misses this week's mission.
func send(hero: HeroRecord, activity: StringName) -> String:
	var reason := can_send(hero, activity)
	if reason == "":
		gold -= activity_price(hero, activity)
		hero.activity = activity
	return reason


func cancel_activity(hero: HeroRecord) -> void:
	if hero.activity != &"":
		gold += activity_price(hero, hero.activity)
		hero.activity = &""


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


# --- Heirloom Exchange ---

## Trade `index` in CampaignRules.EXCHANGE_TRADES, if the Exchange is open and
## the heirlooms are there.
func can_exchange(index: int) -> String:
	if not building_open(&"exchange"):
		return "The Heirloom Exchange isn't open yet."
	var give: Dictionary = CampaignRules.EXCHANGE_TRADES[index][0]
	for heirloom: StringName in give:
		if heirlooms[heirloom] < give[heirloom]:
			return "Not enough %s." % CampaignRules.HEIRLOOM_NAMES[heirloom]
	return ""


func exchange(index: int) -> String:
	var reason := can_exchange(index)
	if reason == "":
		var trade: Array = CampaignRules.EXCHANGE_TRADES[index]
		for heirloom: StringName in trade[0]:
			heirlooms[heirloom] -= trade[0][heirloom]
		for heirloom: StringName in trade[1]:
			heirlooms[heirloom] += trade[1][heirloom]
	return reason


# --- Trinkets and the Nomad Wagon ---

## Every trinket the estate owns: unworn, then worn by the cast.
func owned_trinkets() -> Array[TrinketDef]:
	var result: Array[TrinketDef] = trinkets.duplicate()
	for hero in heroes:
		result.append_array(hero.trinkets)
	return result


## Whether the hero can put on this unworn trinket: in the roster, of the
## trinket's class, with a slot free, and not already wearing the same one.
func can_wear(hero: HeroRecord, trinket: TrinketDef) -> String:
	if not hero.recruited:
		return "Not in the roster."
	if trinket not in trinkets:
		return "Not in the estate's trinkets."
	if trinket.hero and trinket.hero != hero.def:
		return "Only the %s can wear this." % trinket.hero.display_name
	if trinket in hero.trinkets:
		return "Already wearing one."
	if hero.trinkets.size() >= CampaignRules.TRINKET_SLOTS:
		return "Both trinket slots are full. Take one off first."
	return ""


func wear(hero: HeroRecord, trinket: TrinketDef) -> String:
	var reason := can_wear(hero, trinket)
	if reason == "":
		trinkets.erase(trinket)
		hero.trinkets.append(trinket)
	return reason


func take_off(hero: HeroRecord, trinket: TrinketDef) -> String:
	if trinket not in hero.trinkets:
		return "Not wearing that."
	hero.trinkets.erase(trinket)
	trinkets.append(trinket)
	return ""


func sell_price(trinket: TrinketDef) -> int:
	return roundi(trinket.price * CampaignRules.TRINKET_SELL_SHARE)


func can_sell(trinket: TrinketDef) -> String:
	if trinket not in trinkets:
		return "Take it off first."
	if sell_price(trinket) <= 0:
		return "Boss and Ancestral trinkets can't be sold."
	return ""


func sell(trinket: TrinketDef) -> String:
	var reason := can_sell(trinket)
	if reason == "":
		trinkets.erase(trinket)
		gold += sell_price(trinket)
	return reason


## Gold for a trinket at the Nomad Wagon: its price, less the Haggling line's discount.
func wagon_price(trinket: TrinketDef) -> int:
	var discount := CampaignRules.UPGRADE_DISCOUNT * upgrades[&"haggling"]
	return roundi(trinket.price * (1.0 - discount))


func can_buy(trinket: TrinketDef) -> String:
	if not building_open(&"wagon"):
		return "The Nomad Wagon isn't here yet."
	if trinket not in wagon:
		return "Already sold."
	if gold < wagon_price(trinket):
		return "Not enough gold."
	return ""


func buy(trinket: TrinketDef) -> String:
	var reason := can_buy(trinket)
	if reason == "":
		gold -= wagon_price(trinket)
		wagon.erase(trinket)
		trinkets.append(trinket)
	return reason


## A new week's wares, at the best tier the roster can take on, none of them
## already owned.
func _restock_wagon() -> void:
	wagon.clear()
	var tier: int = available_tiers().back()
	for i in CampaignRules.WAGON_STOCK + upgrades[&"wagon_stock"]:
		var trinket := Trinkets.roll(def.trinkets, tier, rng, owned_trinkets() + wagon)
		if trinket:
			wagon.append(trinket)


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


## With nobody fit to go (everyone wounded or busy in town, no recruit waiting
## to join) the week can pass without a mission, so a wipe never strands a
## campaign that can't afford treatment.
func can_wait() -> String:
	if run:
		return "A mission is already under way."
	for hero in heroes:
		if hero.recruited and not hero.wounded and not hero.is_busy():
			return "Someone can still go on a mission."
	if recruits_waiting > 0 and not recruit_choices().is_empty():
		return "A new hero is waiting to join."
	return ""


func wait_week() -> String:
	var reason := can_wait()
	if reason == "":
		_advance_week([])
	return reason


## Draws the mission's first map. Heroes below the mission level start it stressed.
func embark(mission: Mission, party: Array[HeroRecord]) -> MissionRun:
	if can_embark(mission, party) != "":
		return null
	for hero in party:
		var short := levels_short(hero, mission)
		if short > 0:
			hero.stress = mini(hero.stress + short * CampaignRules.UNDERLEVEL_STRESS, Rules.STRESS_MAX)
	run = MissionRun.new(mission, _draw_map(mission), party, rng)
	run.bonds = bonds
	run.trinket_pool = def.trinkets
	run.trinkets_owned = owned_trinkets()
	run.set_out()
	return run


func _draw_map(mission: Mission) -> MissionMap:
	if mission.region == null:
		mission.region = def.regions[0]
	return MissionMap.generate(mission.region, mission.length, _events_for(mission), rng,
			mission.region.boss if mission.boss else null)


## The shared events and the mission's region's own.
func _events_for(mission: Mission) -> Array[EventDef]:
	var events: Array[EventDef] = []
	events.append_array(def.events)
	if mission.region:
		events.append_array(mission.region.events)
	return events


## Settles a finished mission and ends the week. Returns a summary for the
## results screen: {outcome, gold, heirlooms: {type: amount}, xp, level_ups,
## bonds (level-up lines), wounded, town (the week's report), recruit (a new
## hero may join), opened (the name of a region the boss win opened, or ""),
## progress (the region whose boss progress grew, or null), trinkets (the ones
## brought home)}.
## Completing pays everything, including a trinket (an Ancestral one for a
## boss), and counts towards the region's boss; retreating keeps what was
## earned on the way. Every pair in the party bonds a little, more for
## completing. Tavern perks for this mission end. Heroes who level up get
## their scenes.
func finish_mission() -> Dictionary:
	var mission := run.mission
	var summary := {
		outcome = run.outcome, gold = 0, heirlooms = {}, xp = 0, level_ups = [], wounded = [],
		bonds = run.new_bonds.duplicate(), recruit = false, opened = "", progress = null, trinkets = [],
	}
	var bond_points := CampaignRules.BOND_COMPLETED_POINTS if run.outcome == MissionRun.Outcome.COMPLETED \
			else CampaignRules.BOND_MISSION_POINTS
	for i in run.party.size():
		for j in range(i + 1, run.party.size()):
			var a := run.party[i]
			var b := run.party[j]
			if bonds.add(a, b, bond_points):
				summary.bonds.append(Bonds.level_up_line(a, b, bonds.level(a, b)))
				bonds.hold_boost(a, b)
	for i in run.party.size():
		run.party[i].stress = clampi(run.combatants[i].stress, 0, Rules.STRESS_MAX)
		run.party[i].next_mission.clear()
	if run.outcome != MissionRun.Outcome.FAILED:
		summary.gold = run.gold_earned
		summary.heirlooms = run.heirlooms_earned.duplicate()
		summary.trinkets.append_array(run.trinkets_found)
	var levels_before := {}
	match run.outcome:
		MissionRun.Outcome.COMPLETED:
			var owned := owned_trinkets() + run.trinkets_found
			var reward := Trinkets.boss_reward(def.trinkets, owned, rng) if mission.boss \
					else Trinkets.roll(def.trinkets, mission.tier, rng, owned)
			if reward:
				summary.trinkets.append(reward)
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
					levels_before[hero] = before
			var open_before := open_regions().size()
			if progress_for(mission) > 0.0:
				summary.progress = mission.region
			summary.recruit = _region_progresses(mission)
			if open_regions().size() > open_before:
				summary.opened = open_regions().back().display_name
		MissionRun.Outcome.RETREATED:
			for hero in run.party:
				hero.stress = mini(hero.stress + CampaignRules.RETREAT_STRESS, Rules.STRESS_MAX)
	gold += summary.gold
	for type: StringName in summary.heirlooms:
		heirlooms[type] += summary.heirlooms[type]
	for trinket: TrinketDef in summary.trinkets:
		trinkets.append(trinket)
	var party := run.party
	var defeated := run.defeated
	run = null
	_advance_week(party)
	for hero in defeated:
		hero.wounded = true
		summary.wounded.append(hero)
	summary.town = week_report.duplicate()
	week_report.clear()
	scenes.append_array(Dialogue.level_ups(self, mission, party, defeated, summary.opened, levels_before))
	return summary


## Abbey and Tavern visits resolve (with the Tavern's side effects and the
## Bar's bonds), heroes away come back, wounds heal, idle heroes rest, and the
## board refreshes. Town news goes in week_report.
func _advance_week(party: Array[HeroRecord]) -> void:
	week += 1
	week_report.clear()
	var at_bar: Array[HeroRecord] = []
	for hero in roster():
		if hero.away_weeks > 0:
			hero.away_weeks -= 1
			if hero.away_weeks == 0:
				week_report.append("%s is back from the Tavern." % hero.display_name)
			continue
		if hero.activity != &"":
			if hero.activity == &"bar":
				at_bar.append(hero)
			_finish_activity(hero)
			continue
		hero.wounded = false
		if hero not in party:
			hero.stress = maxi(0, hero.stress - CampaignRules.IDLE_STRESS_RELIEF)
	_drink_together(at_bar)
	_refresh_board()
	_restock_wagon()


## Takes the activity's stress off and, at the Tavern, rolls its side effect.
func _finish_activity(hero: HeroRecord) -> void:
	var activity := hero.activity
	hero.activity = &""
	var relief := activity_relief(activity)
	hero.stress = maxi(0, hero.stress - relief)
	var line := "%s, %s: -%d stress" % [hero.display_name, CampaignRules.ACTIVITIES[activity].name, relief]
	var effects: Array = CampaignRules.SIDE_EFFECTS.get(activity, [])
	if not effects.is_empty():
		var roll := rng.randf()
		for effect: Array in effects:
			roll -= effect[0]
			if roll < 0.0:
				line += ". " + _side_effect(hero, effect[1], effect[2])
				break
	week_report.append(line + ".")


## Applies a Tavern side effect and describes it.
func _side_effect(hero: HeroRecord, effect: StringName, amount: float) -> String:
	match effect:
		&"max_hp":
			hero.next_mission[&"max_hp"] = amount
			return "Feels hale: +%d%% max HP next mission" % roundi(amount * 100)
		&"speed":
			hero.next_mission[&"speed"] = amount
			return "Light on their feet: +%d speed next mission" % roundi(amount)
		&"relief":
			hero.stress = maxi(0, hero.stress - roundi(amount))
			return "Truly unwinds: -%d more stress" % roundi(amount)
		&"away":
			hero.away_weeks = roundi(amount)
			return "Lost track of time: away next week too"
	var before := gold
	gold = maxi(0, gold + roundi(amount))
	return "Won %d gold" % (gold - before) if amount > 0 else "Lost %d gold" % (before - gold)


## Every pair of heroes at the Bar this week gains bond points.
func _drink_together(at_bar: Array[HeroRecord]) -> void:
	if at_bar.size() < 2:
		return
	week_report.append("%s drank together: +%d bond points for each pair." % [
			" and ".join(at_bar.map(func(h: HeroRecord) -> String: return h.display_name)),
			CampaignRules.BAR_BOND_POINTS])
	for i in at_bar.size():
		for j in range(i + 1, at_bar.size()):
			if bonds.add(at_bar[i], at_bar[j], CampaignRules.BAR_BOND_POINTS):
				week_report.append(Bonds.level_up_line(at_bar[i], at_bar[j], bonds.level(at_bar[i], at_bar[j])))
				bonds.hold_boost(at_bar[i], at_bar[j])


## Missions in each open region (two, or more while few are open) at random
## unlocked tiers and lengths, but always at least one at the highest unlocked
## tier and one at Apprentice.
func _refresh_board() -> void:
	board.clear()
	var tiers := available_tiers()
	var regions := open_regions()
	var per_region := maxi(CampaignRules.MISSIONS_PER_REGION,
			ceili(float(CampaignRules.MIN_BOARD_MISSIONS) / regions.size()))
	var count := regions.size() * per_region
	var forced := {}
	var highest := rng.randi_range(0, count - 1)
	forced[highest] = tiers.back()
	if tiers.back() != CampaignRules.Tier.APPRENTICE:
		forced[(highest + rng.randi_range(1, count - 1)) % count] = CampaignRules.Tier.APPRENTICE
	for region in regions:
		for i in per_region:
			var random_tier: int = tiers[rng.randi_range(0, tiers.size() - 1)]
			var length := rng.randi_range(0, CampaignRules.LENGTH_NAMES.size() - 1)
			board.append(_make_mission(forced.get(board.size(), random_tier), length, region))
	for region in regions:
		if boss_ready(region):
			var mission := _make_mission(boss_tier(region), CampaignRules.Length.LONG, region)
			mission.boss = true
			board.append(mission)


# --- Regions and their bosses ---

## Regions open one at a time, in the campaign's order: the first from the
## start, each next one once the boss before it has fallen.
func region_open(region: RegionDef) -> bool:
	var index := def.regions.find(region)
	return index == 0 or (index > 0 and boss_tier(def.regions[index - 1]) > 0)


func open_regions() -> Array[RegionDef]:
	var result: Array[RegionDef] = []
	result.assign(def.regions.filter(region_open))
	return result


## The tier the region's boss comes at next, or 3 once all three are beaten.
func boss_tier(region: RegionDef) -> int:
	return bosses_beaten.get(region.id, 0)


## Whether the region's boss mission is on the board: once missions completed
## there since the last boss win have filled its progress. It stays until beaten.
func boss_ready(region: RegionDef) -> bool:
	return region.boss != null and not boss_conquered(region) \
			and region_progress.get(region.id, 0) >= CampaignRules.BOSS_PROGRESS_FULL


## Whether the region's last (Champion) boss has fallen, or it has none.
func boss_conquered(region: RegionDef) -> bool:
	return region.boss == null or boss_tier(region) >= CampaignRules.TIER_NAMES.size()


## How full the region's boss progress is, 0 to 1.
func boss_progress(region: RegionDef) -> float:
	return float(region_progress.get(region.id, 0)) / CampaignRules.BOSS_PROGRESS_FULL


## How much completing `mission` adds to its region's boss progress, 0 to 1,
## or 0 when it doesn't count (a boss mission, or a conquered region).
func progress_for(mission: Mission) -> float:
	if mission.boss or mission.region == null or boss_conquered(mission.region):
		return 0.0
	return float(CampaignRules.BOSS_PROGRESS[mission.length]) / CampaignRules.BOSS_PROGRESS_FULL


## Adds a completed mission's share to the region's boss progress, or records a
## boss win: the region starts again towards the next tier's boss, and the first
## win lets a new hero join. Returns true when that first win earned a recruit.
func _region_progresses(mission: Mission) -> bool:
	var region := mission.region
	if region == null or boss_tier(region) >= CampaignRules.TIER_NAMES.size():
		return false
	if not mission.boss:
		region_progress[region.id] = mini(region_progress.get(region.id, 0) + CampaignRules.BOSS_PROGRESS[mission.length],
				CampaignRules.BOSS_PROGRESS_FULL)
		return false
	bosses_beaten[region.id] = boss_tier(region) + 1
	region_progress[region.id] = 0
	if bosses_beaten[region.id] == 1 and recruit_choices().size() > recruits_waiting:
		recruits_waiting += 1
		return true
	return false


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
		version = SAVE_VERSION, week = week, gold = gold, heirlooms = heirlooms, upgrades = upgrades,
		# 64-bit RNG values don't survive JSON numbers, so they are stored as text.
		seed = str(rng.seed), rng_state = str(rng.state),
		heroes = heroes.map(func(h: HeroRecord) -> Dictionary: return h.to_dict()),
		board = board.map(func(m: Mission) -> Dictionary: return m.to_dict()),
		bonds = bonds.to_dict(),
		region_progress = region_progress, bosses_beaten = bosses_beaten, recruits_waiting = recruits_waiting,
		trinkets = Trinkets.to_paths(trinkets), wagon = Trinkets.to_paths(wagon),
		scenes = scenes.map(func(scene: DialogueScene) -> Dictionary: return scene.to_dict()),
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
	if data.has("upgrades"):
		for line: String in data.upgrades:
			if CampaignRules.UPGRADES.has(StringName(line)):
				campaign.upgrades[StringName(line)] = int(data.upgrades[line])
	else:
		# Saves from before upgrade lines kept one level per building, and one
		# Abbey level for all three activities.
		for id: String in data.buildings:
			for line: StringName in ([&"meditation", &"prayer", &"flagellation"] if id == "abbey" else [StringName(id)]):
				if CampaignRules.UPGRADES.has(line):
					campaign.upgrades[line] = int(data.buildings[id])
	for region: String in data.get("region_progress", {}):
		var progress := int(data.region_progress[region])
		if int(data.version) < 4:
			progress = mini(roundi(progress * float(CampaignRules.BOSS_PROGRESS_FULL) / _OLD_BOSS_MISSIONS),
					CampaignRules.BOSS_PROGRESS_FULL)
		campaign.region_progress[StringName(region)] = progress
	for region: String in data.get("bosses_beaten", {}):
		campaign.bosses_beaten[StringName(region)] = int(data.bosses_beaten[region])
	campaign.recruits_waiting = int(data.get("recruits_waiting", 0))
	campaign.rng.seed = String(data.seed).to_int()
	campaign.rng.state = String(data.rng_state).to_int()
	# Heroes whose class has left the cast (the Arbalest) are dropped, and their
	# trinkets go back to the estate. Saved hero indices map to the kept ones.
	var kept := {}
	for i in data.heroes.size():
		var hero_data: Dictionary = data.heroes[i]
		if not ResourceLoader.exists(hero_data.def):
			campaign.trinkets.append_array(Trinkets.from_paths(hero_data.get("trinkets", [])))
			continue
		kept[i] = campaign.heroes.size()
		campaign.heroes.append(HeroRecord.from_dict(hero_data))
	if int(data.version) < 2:
		# Saves from before regions: deal a fresh board with them.
		campaign._refresh_board()
	else:
		for mission_data: Dictionary in data.board:
			campaign.board.append(Mission.from_dict(mission_data))
		# Saves from before regions opened one by one may offer missions in closed ones.
		if campaign.board.any(func(m: Mission) -> bool: return m.region and not campaign.region_open(m.region)):
			campaign._refresh_board()
	campaign.bonds = Bonds.from_dict(data.get("bonds", {}))
	campaign.trinkets.append_array(Trinkets.from_paths(data.get("trinkets", [])))
	if data.has("wagon"):
		campaign.wagon = Trinkets.from_paths(data.wagon)
	else:
		# Saves from before trinkets: stock the Wagon now.
		campaign._restock_wagon()
	for scene_data: Dictionary in data.get("scenes", []):
		var scene := DialogueScene.from_dict(scene_data)
		if scene:
			campaign.scenes.append(scene)
	# A mission under way with a dropped hero in the party can't carry on; it is
	# abandoned without a week passing.
	if data.run != null and data.run.party.all(func(index: Variant) -> bool: return kept.has(int(index))):
		var party: Array[HeroRecord] = []
		for index in data.run.party:
			party.append(campaign.heroes[kept[int(index)]])
		var run_data: Dictionary = data.run
		if int(data.version) < 3:
			run_data = campaign._run_before_maps(run_data)
		campaign.run = MissionRun.from_dict(run_data, party, campaign.rng)
		campaign.run.bonds = campaign.bonds
		campaign.run.trinket_pool = campaign_def.trinkets
		campaign.run.trinkets_owned = campaign.owned_trinkets()
		campaign.run.apply_bonds()
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

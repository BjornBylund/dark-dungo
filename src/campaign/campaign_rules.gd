## The town loop's numbers: DD1's, with stress divided by 10 for our 0-10 scale.
## Sources: docs/research/darkest-dungeon-town.md; decisions: docs/design.md, Campaign.
class_name CampaignRules
extends RefCounted

enum Tier { APPRENTICE, VETERAN, CHAMPION }
enum Length { SHORT, MEDIUM, LONG }

const TIER_NAMES := ["Apprentice", "Veteran", "Champion"]
const LENGTH_NAMES := ["Short", "Medium", "Long"]

const STARTING_GOLD := 5000
const MISSIONS_PER_REGION := 2

# Missions, indexed [tier] or [length].
const TIER_LEVELS := [1, 3, 5]
## Half a mission's gold divided by this is the fight share, paid for every fight won.
## About the shares a full clear earns from fights, elites, caches and events
## (scripts/balance.ps1 measures it).
const FIGHT_SHARES := [6, 9, 12]
const GOLD := [3000, 4500, 7500]
const TIER_GOLD_MULTIPLIER := [1.0, 1.5, 2.0]
const XP := [2, 3, 4]
const TIER_XP_MULTIPLIER := [1, 2, 4]
## A hero must reach this level before Veteran / Champion missions show up.
const TIER_UNLOCK_LEVEL := [0, 2, 4]

# Mission maps, indexed [length] or [tier].
## Columns of rooms, counting the final room. Medium is about a Slay the Spire
## act (15 floors and the boss).
const MAP_COLUMNS := [10, 15, 20]
const MAP_ROWS := 5
## Random walks from the first column that make up the routes.
const MAP_WALKS := 4
## The all-cache column (0-based), a little past the middle like Slay the
## Spire's treasure floor. The column before the finale is all rests.
const CACHE_COLUMN := [5, 8, 11]
## No elite or rest in this many first columns.
const EARLY_COLUMNS := [4, 5, 7]
## Odds for rooms the placement rules leave open, by MapRoom.Type: fight, event, rest, elite, cache.
const ROOM_WEIGHTS := [50, 22, 12, 8, 8]
const ELITE_HEIRLOOMS := [2, 3, 4]
const CACHE_HEIRLOOMS := [2, 3, 4]
const EVENT_HEIRLOOM_MULTIPLIER := [1.0, 1.5, 2.0]
const REST_HEAL := 0.3
const REST_STRESS := 2

const HEIRLOOMS: Array[StringName] = [&"bust", &"portrait", &"deed", &"crest"]
const HEIRLOOM_NAMES := {&"bust": "Busts", &"portrait": "Portraits", &"deed": "Deeds", &"crest": "Crests"}
## Heirlooms paid on completion, [tier][length]. Busts and portraits are the rarer kind.
const RARE_HEIRLOOM_AMOUNT := [[2, 2, 4], [2, 3, 6], [3, 5, 9]]
const COMMON_HEIRLOOM_AMOUNT := [[3, 5, 9], [4, 6, 12], [6, 9, 18]]

# Heroes.
## Total XP needed for levels 1-6.
const LEVEL_XP := [2, 8, 14, 24, 36, 48]
const MAX_LEVEL := 6
## Heroes this many levels or more above a mission's level refuse it.
const WILL_NOT_GO_GAP := 2
const UNDERLEVEL_STRESS := 2
const RETREAT_STRESS := 2
const IDLE_STRESS_RELIEF := 1
const LEVEL_RESIST_BONUS := 0.1

# Bonds between heroes, after DD2's relationships, indexed by Bonds.Level.
const BOND_NAMES := ["Strangers", "Friendly", "Respected", "Partners"]
const BOND_POINTS := [0, 5, 12, 20]
## Points for every pair in the party when a mission ends: completed, or any other ending.
const BOND_COMPLETED_POINTS := 2
const BOND_MISSION_POINTS := 1
## Chance that a skill used on an ally earns the pair a point, at most once per pair per fight.
const BOND_HELP_CHANCE := 0.5
## While both partners are in the party: Friendly and up, Respected and up, Partners.
const BOND_STRESS_RESIST := 0.1
const BOND_CRIT := 0.05
## Added to the chance of Resolute instead of Meltdown at max stress.
const BOND_RESOLUTE := 0.15
## On reaching a new level: stress off both heroes, and a damage bonus for the rest of the mission.
const BOND_BOOST_STRESS := 2
const BOND_BOOST_DAMAGE := 0.1

# Weapon, armour and skill ranks 2-5, indexed [rank - 2].
const MAX_RANK := 5
const GEAR_COST := [750, 1750, 3000, 6000]
const SKILL_COST := [250, 750, 1250, 2500]
const RANK_HERO_LEVEL := [1, 2, 3, 5]
const WEAPON_DAMAGE_PER_RANK := 0.1
const WEAPON_CRIT_PER_RANK := 0.01
const WEAPON_SPEED_RANKS := [3, 5]
const ARMOR_HP_PER_RANK := 0.2

# Enemy difficulty, indexed [tier].
const ENEMY_HP_BONUS := [0.0, 0.25, 0.5]
const ENEMY_DAMAGE_BONUS := [0.0, 0.25, 0.5]
const ENEMY_CRIT_BONUS := [0.0, 0.0, 0.05]

# Abbey.
const ABBEY_ACTIVITIES := ["Meditation", "Prayer", "Flagellation"]
const ABBEY_PRICES := [1000, 1250, 1500]
## Stress removed per activity, by relief tier (raised by Abbey upgrades 1 and 4).
const ABBEY_RELIEF := [[4, 5, 6], [6, 7, 8], [7, 9, 10]]
const ABBEY_DISCOUNT := 0.15
const WOUND_TREATMENT_PRICE := 750

## Building upgrade ladders: one heirloom cost per level.
const BUILDINGS := {
	&"stagecoach": [{&"bust": 9, &"crest": 12}, {&"bust": 12, &"crest": 16}, {&"bust": 15, &"crest": 20}],
	&"guild": [{&"portrait": 6, &"crest": 14}, {&"portrait": 15, &"crest": 38},
			{&"portrait": 24, &"crest": 60}, {&"portrait": 33, &"crest": 84}],
	&"weaponsmith": [{&"deed": 8, &"crest": 8}, {&"deed": 20, &"crest": 21},
			{&"deed": 32, &"crest": 35}, {&"deed": 44, &"crest": 49}],
	&"armorsmith": [{&"deed": 8, &"crest": 8}, {&"deed": 20, &"crest": 21},
			{&"deed": 32, &"crest": 35}, {&"deed": 44, &"crest": 49}],
	&"abbey": [{&"bust": 4, &"crest": 5}, {&"bust": 8, &"crest": 10}, {&"bust": 11, &"crest": 14},
			{&"bust": 15, &"crest": 19}, {&"bust": 19, &"crest": 24}, {&"bust": 23, &"crest": 29}],
}

const BUILDING_NAMES := {
	&"stagecoach": "Stagecoach", &"guild": "Guild", &"weaponsmith": "Weaponsmith",
	&"armorsmith": "Armorsmith", &"abbey": "Abbey",
}


static func level_for_xp(xp: int) -> int:
	var level := 0
	for needed: int in LEVEL_XP:
		if xp >= needed:
			level += 1
	return level


## Price multiplier for services by hero level: x1.4 at levels 3-4, x1.8 at 5-6.
static func service_multiplier(level: int) -> float:
	if level >= 5:
		return 1.8
	if level >= 3:
		return 1.4
	return 1.0


static func heirloom_amount(heirloom: StringName, tier: Tier, length: Length) -> int:
	var table: Array = RARE_HEIRLOOM_AMOUNT if heirloom in [&"bust", &"portrait"] else COMMON_HEIRLOOM_AMOUNT
	return table[tier][length]

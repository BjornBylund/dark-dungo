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
## Regular missions on the board at least, so the first region alone still
## offers a choice: it gets 4 while it's the only one open.
const MIN_BOARD_MISSIONS := 4
## Boss progress, like DD1's region progress bar: each mission completed in a
## region fills it by its length's share (short, medium, long: 4, 3 or 2
## missions), and the boss mission appears when it's full (again, a tier
## harder, after each win).
const BOSS_PROGRESS := [25, 35, 50]
const BOSS_PROGRESS_FULL := 100
const BOSS_HEIRLOOM_MULTIPLIER := 2

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

# Skills, as in DD1: a hero takes this many into a fight, from the ones learned.
const SKILL_SLOTS := Rules.SKILL_SLOTS
## Gold to learn another skill at the Guild, times the service multiplier by level.
const SKILL_LEARN_PRICE := 500

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

# Stress relief in town: DD1's Abbey (safe) and Tavern (with side effects).
# Each activity is also the id of its upgrade line: levels 1 and 4 raise the
# relief (base / L1 / L4 below), 2 and 5 cut the price by ACTIVITY_DISCOUNT,
# and 3 and 6 add a slot. The Bar starts with two slots so heroes can drink together.
const ACTIVITIES := {
	&"meditation": {building = &"abbey", name = "Meditation", relief = [4, 6, 7], price = 1000, slots = 1},
	&"prayer": {building = &"abbey", name = "Prayer", relief = [5, 7, 9], price = 1250, slots = 1},
	&"flagellation": {building = &"abbey", name = "Flagellation", relief = [6, 8, 10], price = 1500, slots = 1},
	&"bar": {building = &"tavern", name = "Bar", relief = [4, 6, 7], price = 1000, slots = 2},
	&"gambling": {building = &"tavern", name = "Gambling Hall", relief = [5, 7, 9], price = 1250, slots = 1},
	&"bathhouse": {building = &"tavern", name = "Bathhouse", relief = [6, 8, 10], price = 1500, slots = 1},
}
const ACTIVITY_DISCOUNT := 0.15
## Tavern side effects, one roll per visit: [chance, effect, amount], DD1's
## without quirks, trinkets or diseases. "max_hp" (a fraction) and "speed" last
## the hero's next mission, "relief" takes more stress off, "away" keeps the
## hero busy next week too, and "gold" is won or lost.
const SIDE_EFFECTS := {
	&"bar": [[0.10, &"max_hp", 0.2], [0.10, &"away", 1], [0.05, &"gold", -500]],
	&"gambling": [[0.05, &"gold", 2000], [0.10, &"away", 1], [0.08, &"gold", -1000]],
	&"bathhouse": [[0.08, &"speed", 1], [0.04, &"relief", 2], [0.08, &"away", 1], [0.04, &"gold", -750]],
}
## Bond points for every pair of heroes at the Bar in the same week.
const BAR_BOND_POINTS := 2
const WOUND_TREATMENT_PRICE := 750

# Buildings and their upgrade lines, DD1's: one heirloom cost per level.
const ABBEY_LADDER := [{&"bust": 4, &"crest": 5}, {&"bust": 8, &"crest": 10}, {&"bust": 11, &"crest": 14},
		{&"bust": 15, &"crest": 19}, {&"bust": 19, &"crest": 24}, {&"bust": 23, &"crest": 29}]
const TAVERN_LADDER := [{&"portrait": 2, &"crest": 5}, {&"portrait": 4, &"crest": 10}, {&"portrait": 6, &"crest": 14},
		{&"portrait": 8, &"crest": 19}, {&"portrait": 10, &"crest": 24}, {&"portrait": 11, &"crest": 29}]
const SMITHING_LADDER := [{&"deed": 8, &"crest": 8}, {&"deed": 20, &"crest": 21},
		{&"deed": 32, &"crest": 35}, {&"deed": 44, &"crest": 49}]
const UPGRADES := {
	&"weaponsmith": SMITHING_LADDER,
	&"armorsmith": SMITHING_LADDER,
	&"furnace": [{&"deed": 4, &"crest": 4}, {&"deed": 9, &"crest": 10}, {&"deed": 14, &"crest": 15},
			{&"deed": 18, &"crest": 20}, {&"deed": 24, &"crest": 26}],
	&"guild": [{&"portrait": 6, &"crest": 14}, {&"portrait": 15, &"crest": 38},
			{&"portrait": 24, &"crest": 60}, {&"portrait": 33, &"crest": 84}],
	&"regimen": [{&"portrait": 2, &"crest": 6}, {&"portrait": 5, &"crest": 14}, {&"portrait": 8, &"crest": 21},
			{&"portrait": 11, &"crest": 29}, {&"portrait": 14, &"crest": 36}],
	&"meditation": ABBEY_LADDER,
	&"prayer": ABBEY_LADDER,
	&"flagellation": ABBEY_LADDER,
	&"bar": TAVERN_LADDER,
	&"gambling": TAVERN_LADDER,
	&"bathhouse": TAVERN_LADDER,
	&"wagon_stock": [{&"portrait": 3, &"crest": 6}, {&"portrait": 6, &"crest": 12}, {&"portrait": 10, &"crest": 20}],
	&"haggling": [{&"portrait": 2, &"crest": 4}, {&"portrait": 4, &"crest": 9}, {&"portrait": 7, &"crest": 14},
			{&"portrait": 9, &"crest": 18}, {&"portrait": 12, &"crest": 24}],
}
const UPGRADE_NAMES := {
	&"weaponsmith": "Weaponsmithing", &"armorsmith": "Armorsmithing",
	&"furnace": "Furnace", &"guild": "Instructors", &"regimen": "Training regimen", &"meditation": "Cloister",
	&"prayer": "Transept", &"flagellation": "Penance hall", &"bar": "Bar", &"gambling": "Gambling hall",
	&"bathhouse": "Bathhouse", &"wagon_stock": "Stock", &"haggling": "Haggling",
}
## Off gear gold per Furnace level, off skill gold per Training regimen level,
## and off Nomad Wagon prices per Haggling level.
const UPGRADE_DISCOUNT := 0.1
## The hamlet's buildings: their upgrade lines, and the week they open (DD1
## opens buildings over the first weeks).
const BUILDINGS := {
	&"blacksmith": {name = "Blacksmith", lines = [&"weaponsmith", &"armorsmith", &"furnace"], opens = 1},
	&"guild": {name = "Guild", lines = [&"guild", &"regimen"], opens = 1},
	&"abbey": {name = "Abbey", lines = [&"meditation", &"prayer", &"flagellation"], opens = 1},
	&"tavern": {name = "Tavern", lines = [&"bar", &"gambling", &"bathhouse"], opens = 3},
	&"exchange": {name = "Heirloom Exchange", lines = [], opens = 5},
	&"wagon": {name = "Nomad Wagon", lines = [&"wagon_stock", &"haggling"], opens = 2},
}
# Trinkets, DD2's (docs/research/darkest-dungeon-2-trinkets.md).
const TRINKET_SLOTS := 2
const RARITY_NAMES := ["Vague", "Distant", "Indelible", "Ancestral"]
## Drop weights by rarity, [mission tier][Vague, Distant, Indelible]: DD2's
## road-battle ladder (10 : 6 : 2) at Apprentice. As in DD2, Vague trinkets fade
## out of harder dungeons, where Indelible ones grow common. Boss and Ancestral
## trinkets come only from region bosses.
const TRINKET_WEIGHTS := [[10, 6, 2], [3, 6, 3], [0, 6, 4]]
## Chance of a trinket in a cache room and from a won elite fight. Completing
## a mission always gives one, and a boss one of its own.
const CACHE_TRINKET_CHANCE := 0.5
const ELITE_TRINKET_CHANCE := 0.5
## The Nomad Wagon buys trinkets back for this share of their price.
const TRINKET_SELL_SHARE := 0.25
## The Nomad Wagon sells this many trinkets a week (more with its Stock line).
const WAGON_STOCK := 4

## DD1's Heirloom Exchange: [give, get]. A Crest is worth about 1, a Bust or
## Deed about 2 and a Portrait about 4, and every trade loses a little.
const EXCHANGE_TRADES := [
	[{&"crest": 3}, {&"bust": 1}], [{&"crest": 3}, {&"deed": 1}], [{&"crest": 6}, {&"portrait": 1}],
	[{&"bust": 2}, {&"crest": 3}], [{&"deed": 2}, {&"crest": 3}], [{&"portrait": 1}, {&"crest": 3}],
	[{&"bust": 3}, {&"deed": 2}], [{&"deed": 3}, {&"bust": 2}],
	[{&"bust": 3}, {&"portrait": 1}], [{&"deed": 3}, {&"portrait": 1}],
	[{&"portrait": 2}, {&"bust": 3}], [{&"portrait": 2}, {&"deed": 3}],
]


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

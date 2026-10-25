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
const FIGHTS := [2, 3, 4]
const GOLD := [3000, 4500, 7500]
const TIER_GOLD_MULTIPLIER := [1.0, 1.5, 2.0]
const XP := [2, 3, 4]
const TIER_XP_MULTIPLIER := [1, 2, 4]
## A hero must reach this level before Veteran / Champion missions show up.
const TIER_UNLOCK_LEVEL := [0, 2, 4]

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

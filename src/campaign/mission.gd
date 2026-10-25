## A mission on the board: a chain of fights in one region at one difficulty
## tier, with its rewards.
class_name Mission
extends RefCounted

## Null only for missions from saves made before regions.
var region: RegionDef
var tier: CampaignRules.Tier
var length: CampaignRules.Length
## Heirloom type paid on completion.
var heirloom: StringName
var encounters: Array[EncounterDef] = []


func level() -> int:
	return CampaignRules.TIER_LEVELS[tier]


func fights() -> int:
	return encounters.size()


func title() -> String:
	return "%s %s" % [CampaignRules.LENGTH_NAMES[length], CampaignRules.TIER_NAMES[tier]]


func gold() -> int:
	return roundi(CampaignRules.GOLD[length] * CampaignRules.TIER_GOLD_MULTIPLIER[tier])


## Half the gold is split across the fights and paid as each is won.
func fight_gold() -> int:
	return gold() / 2 / fights()


## The rest is paid on completion.
func completion_gold() -> int:
	return gold() - fight_gold() * fights()


func xp() -> int:
	return CampaignRules.XP[length] * CampaignRules.TIER_XP_MULTIPLIER[tier]


func heirloom_amount() -> int:
	return CampaignRules.heirloom_amount(heirloom, tier, length)


func to_dict() -> Dictionary:
	return {
		region = region.resource_path if region else "", tier = tier, length = length, heirloom = heirloom,
		encounters = encounters.map(func(e: EncounterDef) -> String: return e.resource_path),
	}


static func from_dict(data: Dictionary) -> Mission:
	var mission := Mission.new()
	if data.get("region", "") != "":
		mission.region = load(data.region)
	mission.tier = int(data.tier) as CampaignRules.Tier
	mission.length = int(data.length) as CampaignRules.Length
	mission.heirloom = StringName(data.heirloom)
	for path: String in data.encounters:
		mission.encounters.append(load(path))
	return mission

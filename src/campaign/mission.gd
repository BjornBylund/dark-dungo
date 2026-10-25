## A mission on the board: a region, a difficulty tier and a length, with its
## rewards. Its map is drawn when the party embarks.
class_name Mission
extends RefCounted

## Null only for missions from saves made before regions.
var region: RegionDef
var tier: CampaignRules.Tier
var length: CampaignRules.Length
## Heirloom type paid on completion.
var heirloom: StringName


func level() -> int:
	return CampaignRules.TIER_LEVELS[tier]


func title() -> String:
	return "%s %s" % [CampaignRules.LENGTH_NAMES[length], CampaignRules.TIER_NAMES[tier]]


func gold() -> int:
	return roundi(CampaignRules.GOLD[length] * CampaignRules.TIER_GOLD_MULTIPLIER[tier])


## Paid for every fight won: half the gold, split as if the route held 2 / 3 / 4 fights.
func fight_gold() -> int:
	return gold() / 2 / CampaignRules.FIGHT_SHARES[length]


## The rest is paid on completion.
func completion_gold() -> int:
	return gold() - fight_gold() * CampaignRules.FIGHT_SHARES[length]


func xp() -> int:
	return CampaignRules.XP[length] * CampaignRules.TIER_XP_MULTIPLIER[tier]


func heirloom_amount() -> int:
	return CampaignRules.heirloom_amount(heirloom, tier, length)


func to_dict() -> Dictionary:
	return {region = region.resource_path if region else "", tier = tier, length = length, heirloom = heirloom}


static func from_dict(data: Dictionary) -> Mission:
	var mission := Mission.new()
	if data.get("region", "") != "":
		mission.region = load(data.region)
	mission.tier = int(data.tier) as CampaignRules.Tier
	mission.length = int(data.length) as CampaignRules.Length
	mission.heirloom = StringName(data.heirloom)
	return mission

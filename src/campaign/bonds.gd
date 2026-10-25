## How well each pair of heroes gets on, after DD2's relationships: points that
## only go up, from missions together and from helping each other in fights,
## and the level they reach (Strangers, Friendly, Respected, Partners).
## Partners in the same party get bonuses; reaching a new level adds a boost for
## the rest of the mission, or for the pair's next mission together.
class_name Bonds
extends RefCounted

enum Level { STRANGERS, FRIENDLY, RESPECTED, PARTNERS }

## Pair key -> points.
var points: Dictionary[String, int] = {}
## Pair keys whose level-up boost waits for their next mission together.
var boosts_waiting: Array[String] = []


## The same key whichever way round the pair is given.
static func key(a: HeroRecord, b: HeroRecord) -> String:
	var ids := [a.def.resource_path, b.def.resource_path]
	ids.sort()
	return "%s|%s" % ids


static func level_for(amount: int) -> Level:
	var level := Level.STRANGERS
	for i in CampaignRules.BOND_POINTS.size():
		if amount >= CampaignRules.BOND_POINTS[i]:
			level = i as Level
	return level


static func level_name(level: Level) -> String:
	return CampaignRules.BOND_NAMES[level]


func points_of(a: HeroRecord, b: HeroRecord) -> int:
	return points.get(key(a, b), 0)


func level(a: HeroRecord, b: HeroRecord) -> Level:
	return level_for(points_of(a, b))


## Adds points, up to the last level's. Returns true when the pair reached a new level.
func add(a: HeroRecord, b: HeroRecord, amount: int) -> bool:
	var before := level(a, b)
	points[key(a, b)] = mini(points_of(a, b) + amount, CampaignRules.BOND_POINTS.back())
	return level(a, b) > before


## "Vanguard and Mender are now Friendly!"
static func level_up_line(a: HeroRecord, b: HeroRecord, level: Level) -> String:
	return "%s and %s are now %s!" % [a.display_name, b.display_name, level_name(level)]


func to_dict() -> Dictionary:
	return {points = points, boosts_waiting = boosts_waiting}


static func from_dict(data: Dictionary) -> Bonds:
	var bonds := Bonds.new()
	for pair: String in data.get("points", {}):
		bonds.points[pair] = int(data.points[pair])
	for pair: String in data.get("boosts_waiting", []):
		bonds.boosts_waiting.append(pair)
	return bonds

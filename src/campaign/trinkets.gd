## Picking trinkets to drop or sell: a rarity by the dungeon's tier, then any
## trinket of it nobody owns yet (DD2 allows one of each).
class_name Trinkets
extends RefCounted


## A random trinket for a mission of `tier`, not in `owned`. Rarer ones are
## less likely; boss and Ancestral trinkets never come this way. A rarity with
## nothing left falls back to the others, rarer first. Null when none are left.
static func roll(pool: Array[TrinketDef], tier: int, rng: RandomNumberGenerator,
		owned: Array[TrinketDef] = []) -> TrinketDef:
	var weights: Array = CampaignRules.TRINKET_WEIGHTS[tier]
	var total := 0
	for weight: int in weights:
		total += weight
	var pick := rng.randi_range(0, total - 1)
	var rarity := 0
	while pick >= weights[rarity]:
		pick -= weights[rarity]
		rarity += 1
	var order: Array[int] = [rarity]
	for other in range(weights.size() - 1, -1, -1):
		if other != rarity:
			order.append(other)
	for each in order:
		var choices := droppable(pool, owned).filter(func(t: TrinketDef) -> bool: return t.rarity == each)
		if not choices.is_empty():
			return choices[rng.randi_range(0, choices.size() - 1)]
	return null


## A boss's reward: a boss or Ancestral trinket the estate doesn't have yet,
## or an Indelible one once it has them all.
static func boss_reward(pool: Array[TrinketDef], owned: Array[TrinketDef], rng: RandomNumberGenerator) -> TrinketDef:
	var choices := pool.filter(func(t: TrinketDef) -> bool:
		return (t.boss_only or t.rarity == TrinketDef.Rarity.ANCESTRAL) and t not in owned)
	if choices.is_empty():
		choices = droppable(pool, owned).filter(func(t: TrinketDef) -> bool: return t.rarity == TrinketDef.Rarity.INDELIBLE)
	return choices[rng.randi_range(0, choices.size() - 1)] if not choices.is_empty() else null


## Trinkets that drop in dungeons and sell at the Wagon, minus those in `owned`.
static func droppable(pool: Array[TrinketDef], owned: Array[TrinketDef]) -> Array[TrinketDef]:
	var result: Array[TrinketDef] = []
	result.assign(pool.filter(func(t: TrinketDef) -> bool:
		return not t.boss_only and t.rarity != TrinketDef.Rarity.ANCESTRAL and t not in owned))
	return result


## Trinkets are saved by their resource paths.
static func to_paths(trinkets: Array[TrinketDef]) -> Array:
	return trinkets.map(func(t: TrinketDef) -> String: return t.resource_path)


## The trinkets at `paths`, skipping any that no longer exist.
static func from_paths(paths: Array) -> Array[TrinketDef]:
	var result: Array[TrinketDef] = []
	for path: String in paths:
		if ResourceLoader.exists(path):
			result.append(load(path))
	return result

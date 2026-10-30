## What the balance tool flags in a sweep's results, against content/balance_targets.tres:
## encounters outside their targets, heroes far from the cast's average win
## rate, and skills and trinkets whose worth stands out from their group's.
class_name BalanceFlags
extends RefCounted


## How an encounter misses its targets at the results' preset, like
## "win 82% (want 40–46%)". Empty when it meets them or has none.
static func encounter_misses(results: BalanceSweep.Results, encounter: EncounterDef, roles: Array[StringName],
		targets: BalanceTargets) -> Array[String]:
	var misses: Array[String] = []
	var entry: Dictionary = results.encounters.get(encounter, {})
	if entry.is_empty():
		return misses
	for role in roles:
		for target in targets.for_role(role, results.preset):
			var value := BalanceSweep.Results.rate(entry, "wins" if target.metric == BalanceTarget.Metric.WIN else "lost")
			if value < target.low or value > target.high:
				misses.append("%s %s (want %d–%d%%)" % [BalanceTarget.METRIC_NAMES[target.metric],
						UiStyle.percent(value), roundi(target.low * 100), roundi(target.high * 100)])
	return misses


## The encounter's targets at the results' preset, like "win 40–46%".
static func encounter_targets(results: BalanceSweep.Results, roles: Array[StringName],
		targets: BalanceTargets) -> Array[String]:
	var lines: Array[String] = []
	for role in roles:
		for target in targets.for_role(role, results.preset):
			lines.append(target.range_text())
	return lines


## A hero's win rate less the cast's average.
static func hero_lead(results: BalanceSweep.Results, hero: UnitDef) -> float:
	return BalanceSweep.Results.rate(results.heroes.get(hero, {}), "wins") - results.hero_average


static func hero_flagged(results: BalanceSweep.Results, hero: UnitDef, targets: BalanceTargets) -> bool:
	return results.heroes.has(hero) and absf(hero_lead(results, hero)) > targets.hero_spread


## {win, lost}: the middle differences of `subjects` (skills, trinkets or talents) that were measured.
static func middle_worth(results: BalanceSweep.Results, subjects: Array) -> Dictionary:
	var middle := {win = 0.0, lost = 0.0}
	for key: String in ["win", "lost"]:
		var values: Array[float] = []
		for subject: Resource in subjects:
			if results.pairs.has(subject):
				values.append(results.pairs[subject][key])
		if values.is_empty():
			continue
		values.sort()
		var half := values.size() / 2
		middle[key] = values[half] if values.size() % 2 == 1 else (values[half - 1] + values[half]) / 2.0
	return middle


## Whether a skill, trinket or talent's win or HP-lost difference is further than its
## standout from the group's `middle`, and further than its margin of error.
static func stands_out(results: BalanceSweep.Results, subject: Resource, middle: Dictionary,
		targets: BalanceTargets) -> bool:
	if not results.pairs.has(subject):
		return false
	var pair: Dictionary = results.pairs[subject]
	var win_gap: float = absf(pair.win - middle.win)
	var lost_gap: float = absf(pair.lost - middle.lost)
	return (win_gap > targets.standout_win and win_gap > pair.win_margin) \
			or (lost_gap > targets.standout_hp and lost_gap > pair.lost_margin)

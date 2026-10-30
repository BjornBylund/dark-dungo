## The balance tool's result columns: what the last sweep found, beside the
## numbers on paper. A cell is flagged when an encounter misses its target or
## a hero, skill, trinket or talent stands out, greyed when edits have made the
## results out of date, and the last column compares with the pinned run.
class_name BalanceResultColumns
extends RefCounted

const PIN_TIP := "Change since the pinned run"

var library: BalanceLibrary
var results: BalanceSweep.Results
var pinned: BalanceSweep.Results
## Edits since the run: its numbers no longer match what's on screen.
var stale := false
var _middle_skills := {}
var _middle_trinkets := {}
var _middle_talents := {}


func _init(content: BalanceLibrary, now: BalanceSweep.Results, pin: BalanceSweep.Results) -> void:
	library = content
	results = now
	pinned = pin
	stale = now != null and now.state != content.state()
	if now:
		var skills: Array = []
		for hero in content.heroes:
			skills.append_array(hero.skills)
		_middle_skills = BalanceFlags.middle_worth(now, skills)
		_middle_trinkets = BalanceFlags.middle_worth(now, content.trinkets)
		_middle_talents = BalanceFlags.middle_worth(now, content.talents)


# --- Heroes ---

static func hero_columns() -> Array[Dictionary]:
	return [
		{title = "Win", width = 58, tip = "Hero: how often parties with them won"},
		{title = "±Win", width = 62,
				tip = "Hero: win rate against the cast's average.\nSkill: wins with it against without (swapped for another)."},
		{title = "HP lost", width = 66,
				tip = "Hero: share of their HP they lost per fight.\nSkill: party HP lost with it against without; below 0 is better."},
		{title = "Died", width = 52, tip = "Hero: how often they died"},
		{title = "Used", width = 54, tip = "Skill: share of the hero's turns it was picked on, when taken along"},
		{title = "vs pin", width = 60, tip = PIN_TIP + ": the hero's win rate, a skill's HP-lost difference"},
	]


func hero_cells(hero: UnitDef) -> Array:
	var entry: Dictionary = results.heroes.get(hero, {}) if results else {}
	if entry.is_empty():
		return [null, null, null, null, null, null]
	var win := BalanceSweep.Results.rate(entry, "wins")
	var lead := BalanceFlags.hero_lead(results, hero)
	var flagged := BalanceFlags.hero_flagged(results, hero, library.targets)
	return [
		_cell(win, UiStyle.percent(win), "%d fights, ±%s" % [entry.n, _points(BalanceSweep.Results.margin(win, entry.n))]),
		_cell(lead, signed(lead), "Cast average %s; flagged beyond ±%s" % [UiStyle.percent(results.hero_average),
				_points(library.targets.hero_spread)], flagged),
		_cell(BalanceSweep.Results.rate(entry, "lost"), UiStyle.percent(BalanceSweep.Results.rate(entry, "lost"))),
		_cell(BalanceSweep.Results.rate(entry, "died"), UiStyle.percent(BalanceSweep.Results.rate(entry, "died"))),
		null,
		_pin(win, func(old: BalanceSweep.Results) -> Variant:
			return BalanceSweep.Results.rate(old.heroes[hero], "wins") if old.heroes.has(hero) else null),
	]


func hero_skill_cells(skill: SkillDef) -> Array:
	if results == null:
		return [null, null, null, null, null, null]
	var pair: Dictionary = results.pairs.get(skill, {})
	var cells: Array = [null, null, null, null, _usage(skill), null]
	if not pair.is_empty():
		var flagged := BalanceFlags.stands_out(results, skill, _middle_skills, library.targets)
		cells[1] = _cell(pair.win, signed(pair.win), "±%s over %d pairs" % [_points(pair.win_margin), pair.n], flagged)
		cells[2] = _cell(pair.lost, signed(pair.lost, 1), "±%s; skills' middle %s" % [_points(pair.lost_margin, 1),
				signed(_middle_skills.lost, 1)], flagged)
		cells[5] = _pin(pair.lost, func(old: BalanceSweep.Results) -> Variant:
			return old.pairs[skill].lost if old.pairs.has(skill) else null, 1)
	return cells


# --- Enemies ---

static func enemy_columns() -> Array[Dictionary]:
	return [
		{title = "Win vs", width = 62, tip = "How often parties won fights with it"},
		{title = "HP lost", width = 66, tip = "Party HP lost in fights with it"},
		{title = "Used", width = 54, tip = "Skill: share of the enemy's turns it was used on"},
		{title = "vs pin", width = 60, tip = PIN_TIP + ": win rate against it"},
	]


func enemy_cells(enemy: UnitDef) -> Array:
	var entry: Dictionary = results.enemies.get(enemy, {}) if results else {}
	if entry.is_empty():
		return [null, null, null, null]
	var win := BalanceSweep.Results.rate(entry, "wins")
	return [
		_cell(win, UiStyle.percent(win), "%d fights, ±%s" % [entry.n, _points(BalanceSweep.Results.margin(win, entry.n))]),
		_cell(BalanceSweep.Results.rate(entry, "lost"), UiStyle.percent(BalanceSweep.Results.rate(entry, "lost"))),
		null,
		_pin(win, func(old: BalanceSweep.Results) -> Variant:
			return BalanceSweep.Results.rate(old.enemies[enemy], "wins") if old.enemies.has(enemy) else null),
	]


func enemy_skill_cells(skill: SkillDef) -> Array:
	return [null, null, _usage(skill) if results else null, null]


# --- Encounters ---

static func encounter_columns() -> Array[Dictionary]:
	return [
		{title = "Win", width = 58, tip = "How often parties won"},
		{title = "HP lost", width = 66, tip = "Party HP lost per fight"},
		{title = "Stress", width = 56, tip = "Stress per hero at the end"},
		{title = "Died", width = 52, tip = "Heroes dead per fight"},
		{title = "Rounds", width = 60},
		{title = "Target", width = 230, tip = "Its targets at this preset, from content/balance_targets.tres"},
		{title = "vs pin", width = 60, tip = PIN_TIP + ": win rate"},
	]


func encounter_cells(encounter: EncounterDef) -> Array:
	var entry: Dictionary = results.encounters.get(encounter, {}) if results else {}
	if entry.is_empty():
		return [null, null, null, null, null, null, null]
	var win := BalanceSweep.Results.rate(entry, "wins")
	var lost := BalanceSweep.Results.rate(entry, "lost")
	var roles := library.role_keys(encounter)
	var misses := BalanceFlags.encounter_misses(results, encounter, roles, library.targets)
	var aims := BalanceFlags.encounter_targets(results, roles, library.targets)
	var target: Variant = null
	var where := "Targets at %s, from content/balance_targets.tres" % results.preset.name
	if not misses.is_empty():
		target = _cell(misses[0], "✗ " + "; ".join(misses), where, true)
	elif not aims.is_empty():
		target = _cell("ok", "✓ " + "; ".join(aims), where)
	var stalled := " %d hit the %d-round cap." % [entry.stalled, BalanceSweep.MAX_ROUNDS] if entry.stalled > 0 else ""
	var win_flagged := misses.any(func(miss: String) -> bool: return miss.begins_with("win"))
	var lost_flagged := misses.any(func(miss: String) -> bool: return miss.begins_with("HP"))
	return [
		_cell(win, UiStyle.percent(win), "%d fights, ±%s.%s" % [entry.n, _points(BalanceSweep.Results.margin(win, entry.n)),
				stalled], win_flagged),
		_cell(lost, UiStyle.percent(lost), "", lost_flagged),
		_cell(BalanceSweep.Results.rate(entry, "stress"), String.num(BalanceSweep.Results.rate(entry, "stress"), 1)),
		_cell(BalanceSweep.Results.rate(entry, "deaths"), String.num(BalanceSweep.Results.rate(entry, "deaths"), 1)),
		_cell(BalanceSweep.Results.rate(entry, "rounds"), String.num(BalanceSweep.Results.rate(entry, "rounds"), 1)),
		target,
		_pin(win, func(old: BalanceSweep.Results) -> Variant:
			return BalanceSweep.Results.rate(old.encounters[encounter], "wins") if old.encounters.has(encounter) else null),
	]


# --- Trinkets ---

static func trinket_columns() -> Array[Dictionary]:
	return [
		{title = "±Win", width = 62, tip = "Wins with it against without, on a hero who may wear it"},
		{title = "HP lost", width = 66, tip = "Party HP lost with it against without; below 0 is better"},
		{title = "vs pin", width = 60, tip = PIN_TIP + ": HP-lost difference"},
	]


func trinket_cells(trinket: TrinketDef) -> Array:
	var pair: Dictionary = results.pairs.get(trinket, {}) if results else {}
	if pair.is_empty():
		return [null, null, null]
	var flagged := BalanceFlags.stands_out(results, trinket, _middle_trinkets, library.targets)
	return [
		_cell(pair.win, signed(pair.win), "±%s over %d pairs" % [_points(pair.win_margin), pair.n], flagged),
		_cell(pair.lost, signed(pair.lost, 1), "±%s; trinkets' middle %s" % [_points(pair.lost_margin, 1),
				signed(_middle_trinkets.lost, 1)], flagged),
		_pin(pair.lost, func(old: BalanceSweep.Results) -> Variant:
			return old.pairs[trinket].lost if old.pairs.has(trinket) else null, 1),
	]


# --- Talents ---

static func talent_columns() -> Array[Dictionary]:
	return [
		{title = "±Win", width = 62, tip = "Wins with it against another talent of its row, on its hero"},
		{title = "HP lost", width = 66, tip = "Party HP lost with it against another of its row; below 0 is better"},
		{title = "vs pin", width = 60, tip = PIN_TIP + ": HP-lost difference"},
	]


func talent_cells(talent: TalentDef) -> Array:
	var pair: Dictionary = results.pairs.get(talent, {}) if results else {}
	if pair.is_empty():
		return [null, null, null]
	var flagged := BalanceFlags.stands_out(results, talent, _middle_talents, library.targets)
	return [
		_cell(pair.win, signed(pair.win), "±%s over %d pairs" % [_points(pair.win_margin), pair.n], flagged),
		_cell(pair.lost, signed(pair.lost, 1), "±%s; talents' middle %s" % [_points(pair.lost_margin, 1),
				signed(_middle_talents.lost, 1)], flagged),
		_pin(pair.lost, func(old: BalanceSweep.Results) -> Variant:
			return old.pairs[talent].lost if old.pairs.has(talent) else null, 1),
	]


# --- Cells ---

func _usage(skill: SkillDef) -> Variant:
	var entry: Dictionary = results.usage.get(skill, {})
	if entry.is_empty() or entry.turns <= 0:
		return null
	var share: float = float(entry.uses) / entry.turns
	return _cell(share, UiStyle.percent(share), "%d of %d turns" % [entry.uses, entry.turns])


func _cell(value: Variant, text: String, tip: String = "", flag: bool = false) -> Dictionary:
	return {value = value, text = text, tip = tip, flag = flag, stale = stale}


## The change in a number since the pinned run, which `then` reads from it.
func _pin(now: float, then: Callable, decimals: int = 0) -> Variant:
	if pinned == null:
		return null
	var old: Variant = then.call(pinned)
	if old == null:
		return null
	var change: float = now - old
	return _cell(change, signed(change, decimals), "Pinned: %s at %s" % [signed(old, decimals) if decimals > 0
			else UiStyle.percent(old), pinned.preset.name])


## A share as signed points: "+3%", or with decimals "-1.5%".
static func signed(share: float, decimals: int = 0) -> String:
	var points := share * 100.0
	if absf(points) < pow(10.0, -decimals) / 2.0:
		return "0%"
	return ("%+." + str(decimals) + "f%%") % points


static func _points(share: float, decimals: int = 0) -> String:
	return ("%." + str(decimals) + "f%%") % (share * 100.0)

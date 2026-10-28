## The balance tool's simulations: fights of the content as it stands, saved
## or not (from a copy taken at the start), played by AutoPlayer.best at one
## preset.
##  - The sweep: random parties of four, each hero with five random skills
##    (and at presets with trinkets, two random trinkets they may wear), against
##    every encounter. Parties stand in order of where their skills reach from.
##  - Paired fights for every hero skill and trinket, on random elites, finales
##    and bosses: the same party, seed and encounter twice, once with it and once
##    without (the skill swapped for another of the hero's, the trinket taken
##    off). The difference between the two is what it is worth.
## Each fight's seed comes from what it measures and its number, so runs of
## the same content share their dice, and differences come from the changes.
##
## GDScript slows down rather than speeding up on several threads, so start()
## runs the fights in headless Godot processes (tools/balance_worker.gd): it
## saves the copy and a manifest to a run folder, each worker rebuilds the same
## plan from it, plays its share and writes what happened, and results()
## reads it all back.
class_name BalanceSweep
extends RefCounted

enum Size { QUICK, THOROUGH }

const MAX_ROUNDS := 60
## At Quick: fights per encounter, and pairs per skill and per trinket.
## Thorough runs THOROUGH_SCALE times as many.
const COUNTS := {encounter = 100, skill = 20, trinket = 16}
const THOROUGH_SCALE := 4
const SIZE_NAMES := ["Quick", "Thorough"]
const RUNS_FOLDER := "user://balance_runs"
const WORKER := "res://tools/balance_worker.gd"
## Workers write how many fights they have played this often.
const PROGRESS_EVERY := 20

var preset: BalancePreset
var size: Size
## The library's version when the copy was taken.
var version := 0
var _copy: Copy
var _counts := {}
var _plan: Array[Dictionary] = []
var _outcomes: Array = []
var _folder := ""
var _workers: Array[int] = []
var _started := 0
var _seconds := 0.0
var _collected := false


## The content copied for the fights, with the way back to the library's own.
class Copy:
	var heroes: Array[UnitDef] = []
	var enemies: Array[UnitDef] = []
	var encounters: Array[EncounterDef] = []
	var trinkets: Array[TrinketDef] = []
	## Encounters for paired fights: the regions' elites, finales and bosses.
	var hard: Array[EncounterDef] = []
	## Copy (unit, skill, encounter or trinket) -> the library's original.
	var original := {}
	## Skill -> [side (0 heroes, 1 enemies), unit index, skill index], to write a fight down.
	var places := {}

	static func of(library: BalanceLibrary) -> Copy:
		var copy := Copy.new()
		var units := {}
		for pair: Array in [[library.heroes, copy.heroes], [library.enemies, copy.enemies]]:
			for unit: UnitDef in pair[0]:
				var twin: UnitDef = unit.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
				units[unit] = twin
				copy.original[twin] = unit
				for i in unit.skills.size():
					copy.original[twin.skills[i]] = unit.skills[i]
				pair[1].append(twin)
		for trinket in library.trinkets:
			var twin: TrinketDef = trinket.duplicate_deep(Resource.DEEP_DUPLICATE_INTERNAL)
			twin.hero = units.get(trinket.hero, trinket.hero)
			copy.original[twin] = trinket
			copy.trinkets.append(twin)
		for encounter in library.encounters:
			var twin := EncounterDef.new()
			twin.display_name = encounter.display_name
			for enemy in encounter.enemies:
				twin.enemies.append(units.get(enemy, enemy))
			copy.original[twin] = encounter
			copy.encounters.append(twin)
			if library.role_keys(encounter).any(func(role: StringName) -> bool: return role != &"fights"):
				copy.hard.append(twin)
		copy._finish()
		return copy

	## The copy a run folder holds, as saved by save().
	static func loaded(folder: String, manifest: Dictionary) -> Copy:
		var copy := Copy.new()
		for pair: Array in [["heroes", copy.heroes], ["enemies", copy.enemies], ["encounters", copy.encounters],
				["trinkets", copy.trinkets]]:
			for file: String in manifest[pair[0]]:
				pair[1].append(load(folder.path_join(file)))
		for index: float in manifest["hard"]:
			copy.hard.append(copy.encounters[int(index)])
		copy._finish()
		return copy

	func _finish() -> void:
		if hard.is_empty():
			hard = encounters.duplicate()
		for side in 2:
			var units := heroes if side == 0 else enemies
			for u in units.size():
				for s in units[u].skills.size():
					places[units[u].skills[s]] = [side, u, s]

	## Saves every copied file into `folder` and returns the manifest listing
	## them. Each gets its path there first, so encounters and trinkets refer to
	## the copied units instead of holding copies of their own.
	func save(folder: String) -> Dictionary:
		var manifest := {"heroes": [], "enemies": [], "encounters": [], "trinkets": [], "hard": []}
		var lists := [["heroes", heroes], ["enemies", enemies], ["trinkets", trinkets], ["encounters", encounters]]
		for pair: Array in lists:
			for i in pair[1].size():
				var resource: Resource = pair[1][i]
				# Art isn't needed to fight, and leaving it out keeps the workers quick to start.
				if resource is UnitDef:
					resource.sprite = null
					for skill: SkillDef in resource.skills:
						skill.icon = null
				elif resource is TrinketDef:
					resource.icon = null
				var file := "%s_%d.tres" % [pair[0], i]
				resource.take_over_path(folder.path_join(file))
				manifest[pair[0]].append(file)
		for pair: Array in lists:
			for resource: Resource in pair[1]:
				ResourceSaver.save(resource)
		for encounter in hard:
			manifest["hard"].append(encounters.find(encounter))
		return manifest


## A sweep of `library`'s content as it stands. `counts` overrides COUNTS (for tests).
static func of(library: BalanceLibrary, at: BalancePreset, run_size: Size, counts: Dictionary = {}) -> BalanceSweep:
	var sweep := BalanceSweep.new(Copy.of(library), at, run_size, counts)
	sweep.version = library.version
	return sweep


## The sweep a run folder describes, for a worker.
static func from_folder(folder: String) -> BalanceSweep:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("manifest.json")))
	var at: BalancePreset = load(folder.path_join("preset.tres"))
	return BalanceSweep.new(Copy.loaded(folder, manifest), at, int(manifest["run_size"]) as Size, manifest["counts"])


func _init(copy: Copy, at: BalancePreset, run_size: Size, counts: Dictionary) -> void:
	_copy = copy
	preset = at
	size = run_size
	_counts = counts
	var how_many := COUNTS.merged(counts, true)
	var scale := THOROUGH_SCALE if run_size == Size.THOROUGH else 1
	for encounter in _copy.encounters:
		for i in int(how_many.encounter) * scale:
			_plan.append({group = &"sweep", encounter = encounter, seed = hash(["sweep", encounter.display_name, i])})
	for hero in _copy.heroes:
		for skill in hero.skills:
			for i in int(how_many.skill) * scale:
				var seed_value := hash(["skill", hero.id, skill.id, i])
				for with in [true, false]:
					_plan.append({group = &"skill", subject = skill, hero = hero, with = with, seed = seed_value})
	for trinket in _copy.trinkets:
		var wearers := _copy.heroes.filter(func(h: UnitDef) -> bool: return trinket.hero == null or trinket.hero == h)
		if wearers.is_empty():
			continue
		for i in int(how_many.trinket) * scale:
			var seed_value := hash(["trinket", trinket.id, i])
			var draw := RandomNumberGenerator.new()
			draw.seed = seed_value
			var hero: UnitDef = wearers[draw.randi_range(0, wearers.size() - 1)]
			for with in [true, false]:
				_plan.append({group = &"trinket", subject = trinket, hero = hero, with = with, seed = seed_value})
	_outcomes.resize(_plan.size())


func fight_count() -> int:
	return _plan.size()


## Workers to run: every processor but two, for the editor and the screen.
static func default_workers() -> int:
	return clampi(OS.get_processor_count() - 2, 1, 14)


# --- Running ---

## Starts the fights in `workers` headless processes, or with 0, plays them
## all here before returning.
func start(workers: int = default_workers()) -> void:
	_started = Time.get_ticks_msec()
	if workers <= 0:
		for i in _plan.size():
			_outcomes[i] = fight(_plan[i])
		_collected = true
		_seconds = (Time.get_ticks_msec() - _started) / 1000.0
		return
	_clear_old_runs()
	_folder = RUNS_FOLDER.path_join("run_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_folder)
	var manifest := _copy.save(_folder)
	manifest["run_size"] = size
	manifest["counts"] = _counts
	ResourceSaver.save(preset.duplicate(), _folder.path_join("preset.tres"))
	_write(_folder.path_join("manifest.json"), JSON.stringify(manifest))
	# Workers run the same project, so user:// is the same folder for them, and
	# the saved files' references to each other load as the same resources.
	var project := ProjectSettings.globalize_path("res://")
	for share in workers:
		_workers.append(OS.create_process(OS.get_executable_path(), ["--headless", "--path", project, "--script", WORKER,
				"--", "--run=" + _folder, "--share=%d/%d" % [share, workers]]))


## Stops the workers; results() then holds what they finished.
func cancel() -> void:
	for pid in _workers:
		if OS.is_process_running(pid):
			OS.kill(pid)
	_workers.clear()


func is_finished() -> bool:
	return _workers.all(func(pid: int) -> bool: return not OS.is_process_running(pid))


## Blocks until every worker is done.
func wait() -> void:
	while not is_finished():
		OS.delay_msec(50)


## Fights played so far, from the workers' progress files.
func done_count() -> int:
	if _collected:
		return _plan.size()
	var count := 0
	for share in _workers.size():
		var path := _folder.path_join("progress_%d.txt" % share)
		if FileAccess.file_exists(path):
			count += int(FileAccess.get_file_as_string(path))
	return count


## Plays share `share` of `shares` (every shares-th fight from `share`) and
## writes the outcomes into the run folder. For tools/balance_worker.gd.
func run_share(folder: String, share: int, shares: int) -> void:
	var played: Array = []
	for i in range(share, _plan.size(), shares):
		played.append([i, _encode(fight(_plan[i]))])
		if played.size() % PROGRESS_EVERY == 0:
			_write(folder.path_join("progress_%d.txt" % share), str(played.size()))
	_write(folder.path_join("out_%d.json" % share), JSON.stringify(played, "", false, true))
	_write(folder.path_join("progress_%d.txt" % share), str(played.size()))


static func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(text)
		file.close()


## Reads back what the workers wrote, once.
func _collect() -> void:
	if _collected:
		return
	_collected = true
	_seconds = (Time.get_ticks_msec() - _started) / 1000.0
	for share in _workers.size():
		var path := _folder.path_join("out_%d.json" % share)
		if not FileAccess.file_exists(path):
			continue
		var played: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if played is Array:
			for entry: Array in played:
				_outcomes[int(entry[0])] = _decode(entry[1])


static func _clear_old_runs() -> void:
	if not DirAccess.dir_exists_absolute(RUNS_FOLDER):
		return
	for run in DirAccess.get_directories_at(RUNS_FOLDER):
		var folder := RUNS_FOLDER.path_join(run)
		for file in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(file))
		DirAccess.remove_absolute(folder)


## A fight's outcome with its resources written as places in the copy, for JSON.
func _encode(outcome: Dictionary) -> Dictionary:
	var party: Array[UnitDef] = outcome.party
	var uses: Array = []
	for skill: SkillDef in outcome.uses:
		if _copy.places.has(skill):
			uses.append(_copy.places[skill] + [outcome.uses[skill]])
	return {
		win = outcome.win, stalled = outcome.stalled, lost = outcome.lost, stress = outcome.stress,
		deaths = outcome.deaths, rounds = outcome.rounds, uses = uses,
		encounter = _copy.encounters.find(outcome.encounter),
		party = party.map(func(hero: UnitDef) -> int: return _copy.heroes.find(hero)),
		loadouts = range(party.size()).map(func(p: int) -> Array:
			return outcome.loadouts[p].map(func(skill: SkillDef) -> int: return party[p].skills.find(skill))),
		hero_lost = party.map(func(hero: UnitDef) -> float: return outcome.hero_lost[hero]),
		hero_died = party.map(func(hero: UnitDef) -> bool: return outcome.hero_died[hero]),
		turns = party.map(func(hero: UnitDef) -> int: return outcome.turns.get(hero, 0)),
	}


## The other way: an outcome as fight() returns it, from what _encode() wrote.
func _decode(data: Dictionary) -> Dictionary:
	var party: Array[UnitDef] = []
	var loadouts: Array = []
	var lost := {}
	var died := {}
	var turns := {}
	for p in data.party.size():
		var hero := _copy.heroes[int(data.party[p])]
		party.append(hero)
		loadouts.append(data.loadouts[p].map(func(s: float) -> SkillDef: return hero.skills[int(s)]))
		lost[hero] = data.hero_lost[p]
		died[hero] = data.hero_died[p]
		turns[hero] = int(data.turns[p])
	var uses := {}
	for place: Array in data.uses:
		var units := _copy.heroes if int(place[0]) == 0 else _copy.enemies
		uses[units[int(place[1])].skills[int(place[2])]] = int(place[3])
	return {
		win = data.win, stalled = data.stalled, lost = data.lost, stress = data.stress, deaths = int(data.deaths),
		rounds = int(data.rounds), hero_lost = lost, hero_died = died, uses = uses, turns = turns, party = party,
		loadouts = loadouts, encounter = _copy.encounters[int(data.encounter)],
	}


# --- One fight ---

## One planned fight: sets up the party and enemies from its seed and plays it out.
func fight(job: Dictionary) -> Dictionary:
	var setup := _setup(job)
	var heroes: Array[Combatant] = []
	for i in setup.party.size():
		heroes.append(Growth.hero_combatant(record(setup.party[i], setup.loadouts[i], setup.trinkets[i], preset)))
	var enemies: Array[Combatant] = []
	for enemy: UnitDef in setup.encounter.enemies:
		enemies.append(Growth.enemy_combatant(enemy, preset.tier))
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([job.seed, "battle"])
	var outcome := play(Battle.new(heroes, enemies, dice), heroes)
	outcome.party = setup.party
	outcome.loadouts = setup.loadouts
	outcome.encounter = setup.encounter
	return outcome


## Plays a battle out with AutoPlayer.best, up to MAX_ROUNDS. `party` is the
## heroes it started with (the dead may leave the battle's own list). Returns
## {win, stalled, lost (the party's average share of HP lost), stress
## (average), deaths, rounds, hero_lost and hero_died (by hero def), uses
## (skill -> times used, enemies' too), turns (hero def -> turns taken)}.
static func play(battle: Battle, party: Array[Combatant]) -> Dictionary:
	var uses := {}
	var turns := {}
	while battle.state != Battle.State.VICTORY and battle.state != Battle.State.DEFEAT and battle.round_number <= MAX_ROUNDS:
		for event in battle.advance():
			if event.type == &"skill" and not event.get("riposte", false):
				uses[event.skill] = uses.get(event.skill, 0) + 1
		if battle.state == Battle.State.AWAITING_INPUT:
			var choice := AutoPlayer.best(battle)
			uses[choice[0]] = uses.get(choice[0], 0) + 1
			turns[battle.current.def] = turns.get(battle.current.def, 0) + 1
			battle.submit(choice[0], choice[1])
	var lost := {}
	var died := {}
	var stress := 0.0
	for hero in party:
		lost[hero.def] = 1.0 if hero.dead else 1.0 - hero.hp_fraction()
		died[hero.def] = hero.dead
		stress += hero.stress
	var party_lost := 0.0
	for share: float in lost.values():
		party_lost += share
	var count := maxi(1, lost.size())
	return {
		win = battle.state == Battle.State.VICTORY, stalled = battle.state == Battle.State.RUNNING \
				or battle.state == Battle.State.AWAITING_INPUT,
		lost = party_lost / count, stress = stress / count,
		deaths = died.values().count(true), rounds = battle.round_number,
		hero_lost = lost, hero_died = died, uses = uses, turns = turns,
	}


## {party, loadouts, trinkets, encounter} for a job, drawn from its seed. Both
## fights of a pair draw the same, and differ only in the measured skill or trinket.
func _setup(job: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = job.seed
	var encounter: EncounterDef = job.get("encounter")
	if encounter == null:
		encounter = _copy.hard[rng.randi_range(0, _copy.hard.size() - 1)]
	var party: Array[UnitDef] = []
	if job.has("hero"):
		party.append(job.hero)
	var cast := _copy.heroes
	while party.size() < mini(4, cast.size()):
		var pick: UnitDef = cast[rng.randi_range(0, cast.size() - 1)]
		if pick not in party:
			party.append(pick)
	var loadouts: Array = []
	var trinkets: Array = []
	var stand_in: SkillDef = null
	for hero in party:
		var pool := hero.skills.duplicate()
		_shuffle(pool, rng)
		var loadout: Array[SkillDef] = []
		loadout.assign(pool.slice(0, Rules.SKILL_SLOTS))
		var spare: Array = pool.slice(Rules.SKILL_SLOTS)
		if job.group == &"skill" and hero == job.hero:
			if job.subject not in loadout:
				spare.append(loadout.back())
				loadout[-1] = job.subject
			spare.erase(job.subject)
			stand_in = spare[rng.randi_range(0, spare.size() - 1)] if not spare.is_empty() else null
		loadouts.append(loadout)
		# Every hero draws two trinkets either way, so both fights of a pair draw alike.
		var drawn: Array[TrinketDef] = []
		if job.group == &"trinket":
			drawn.append(job.subject)
		for slot in CampaignRules.TRINKET_SLOTS:
			var extra := _draw_trinket(hero, drawn, rng)
			if extra:
				drawn.append(extra)
		if job.group == &"trinket":
			drawn.pop_front()
		var worn: Array[TrinketDef] = []
		if preset.trinkets:
			worn = drawn.duplicate()
		if job.group == &"trinket" and hero == job.hero:
			worn = worn.slice(0, CampaignRules.TRINKET_SLOTS - 1)
			if job.with:
				worn.push_front(job.subject)
		trinkets.append(worn)
	# The line-up comes from the loadouts with the measured skill, so both fights stand alike.
	_order(party, loadouts, trinkets)
	if job.group == &"skill" and not job.with and stand_in:
		var loadout: Array[SkillDef] = loadouts[party.find(job.hero)]
		loadout[loadout.find(job.subject)] = stand_in
	return {party = party, loadouts = loadouts, trinkets = trinkets, encounter = encounter}


## A trinket `hero` may wear, not in `taken`, of a rarity drawn with the preset tier's drop odds.
func _draw_trinket(hero: UnitDef, taken: Array, rng: RandomNumberGenerator) -> TrinketDef:
	var weights: Array = CampaignRules.TRINKET_WEIGHTS[preset.tier]
	var total := 0
	for weight: int in weights:
		total += weight
	var pick := rng.randi_range(0, total - 1)
	var rarity := 0
	while pick >= weights[rarity]:
		pick -= weights[rarity]
		rarity += 1
	var choices := _copy.trinkets.filter(func(t: TrinketDef) -> bool:
		return t.rarity == rarity and not t.boss_only and (t.hero == null or t.hero == hero) and t not in taken)
	return choices[rng.randi_range(0, choices.size() - 1)] if not choices.is_empty() else null


## Lines the party up by the average rank their skills are used from, front first.
func _order(party: Array[UnitDef], loadouts: Array, trinkets: Array) -> void:
	var slots := range(party.size())
	var reach := func(i: int) -> float:
		var total := 0.0
		for skill: SkillDef in loadouts[i]:
			var sum := 0.0
			for rank in skill.launch_ranks:
				sum += rank
			total += sum / maxi(1, skill.launch_ranks.size())
		return total / maxi(1, loadouts[i].size())
	slots.sort_custom(func(a: int, b: int) -> bool:
		var x: float = reach.call(a)
		var y: float = reach.call(b)
		return x < y if x != y else a < b)
	var sorted := [party.duplicate(), loadouts.duplicate(), trinkets.duplicate()]
	for i in slots.size():
		party[i] = sorted[0][slots[i]]
		loadouts[i] = sorted[1][slots[i]]
		trinkets[i] = sorted[2][slots[i]]


## A hero at `at`'s level, gear and skill ranks, taking `loadout` and wearing `worn`.
static func record(hero: UnitDef, loadout: Array[SkillDef], worn: Array[TrinketDef], at: BalancePreset) -> HeroRecord:
	var result := HeroRecord.new(hero)
	result.xp = CampaignRules.LEVEL_XP[at.level - 1] if at.level > 0 else 0
	result.weapon_rank = at.gear_rank
	result.armor_rank = at.gear_rank
	if at.skill_rank > 1:
		for skill in hero.skills:
			result.skill_ranks[skill.id] = at.skill_rank
	result.known.assign(loadout.map(func(skill: SkillDef) -> StringName: return skill.id))
	result.equipped = result.known.duplicate()
	result.trinkets = worn
	return result


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var item: Variant = items[i]
		items[i] = items[j]
		items[j] = item


# --- Results ---

## What the fights found, keyed by the library's own resources. Each entry
## holds counts and sums; rate() and margin() turn them into numbers.
class Results:
	var preset: BalancePreset
	var size: Size
	var version := 0
	## Fights planned, and played (fewer if a worker failed or the run was stopped).
	var fights := 0
	var played := 0
	var seconds := 0.0
	## Encounter -> {n, wins, stalled, lost, stress, deaths, rounds}.
	var encounters := {}
	## Hero -> {n, wins, lost, died}, from the sweep.
	var heroes := {}
	## Enemy -> {n, wins, lost}: the party's results in fights with it.
	var enemies := {}
	## Skill -> {uses, turns}: how often it was picked when it could be, from the sweep.
	var usage := {}
	## Skill or trinket -> {n, win, win_margin, lost, lost_margin}: with minus without.
	var pairs := {}
	## The sweep's overall win rate and the average hero's.
	var win := 0.0
	var hero_average := 0.0

	static func rate(entry: Dictionary, key: String) -> float:
		return float(entry.get(key, 0.0)) / maxi(1, entry.get("n", 0))

	## The 95% margin of error of a rate from `n` fights.
	static func margin(share: float, n: int) -> float:
		return 1.96 * sqrt(maxf(share * (1.0 - share), 0.0) / maxi(1, n))


## Adds up every fight played. Call once the run is finished.
func results() -> Results:
	_collect()
	var result := Results.new()
	result.preset = preset
	result.size = size
	result.version = version
	result.fights = _plan.size()
	result.seconds = _seconds
	var original := _copy.original
	var wins := 0
	var sweeps := 0
	var diffs := {}
	for i in _plan.size():
		var job := _plan[i]
		var outcome: Dictionary = _outcomes[i] if _outcomes[i] != null else {}
		if outcome.is_empty():
			continue
		result.played += 1
		match job.group:
			&"sweep":
				sweeps += 1
				wins += int(outcome.win)
				_add(result.encounters, original[job.encounter], {n = 1, wins = int(outcome.win),
						stalled = int(outcome.stalled), lost = outcome.lost, stress = outcome.stress,
						deaths = outcome.deaths, rounds = outcome.rounds})
				for hero: UnitDef in outcome.party:
					_add(result.heroes, original[hero], {n = 1, wins = int(outcome.win),
							lost = outcome.hero_lost[hero], died = int(outcome.hero_died[hero])})
				var seen := {}
				for enemy: UnitDef in outcome.encounter.enemies:
					if not original.has(enemy) or seen.has(enemy):
						continue
					seen[enemy] = true
					_add(result.enemies, original[enemy], {n = 1, wins = int(outcome.win), lost = outcome.lost})
					for skill in enemy.skills:
						_add(result.usage, original[skill], {uses = outcome.uses.get(skill, 0),
								turns = _enemy_turns(enemy, outcome.uses)})
				for p in outcome.party.size():
					var hero: UnitDef = outcome.party[p]
					for skill: SkillDef in outcome.loadouts[p]:
						_add(result.usage, original[skill], {uses = outcome.uses.get(skill, 0),
								turns = outcome.turns.get(hero, 0)})
			&"skill", &"trinket":
				if not job.with or _outcomes[i + 1] == null or _outcomes[i + 1].is_empty():
					continue
				var other: Dictionary = _outcomes[i + 1]
				var list: Array = diffs.get_or_add(original[job.subject], [])
				list.append([int(outcome.win) - int(other.win), outcome.lost - other.lost])
	for subject: Resource in diffs:
		result.pairs[subject] = _paired(diffs[subject])
	result.win = float(wins) / maxi(1, sweeps)
	var total := 0.0
	for hero: Resource in result.heroes:
		total += Results.rate(result.heroes[hero], "wins")
	result.hero_average = total / maxi(1, result.heroes.size())
	return result


## How many turns an enemy took in a fight: the uses of all its skills.
static func _enemy_turns(enemy: UnitDef, uses: Dictionary) -> int:
	var count := 0
	for skill in enemy.skills:
		count += uses.get(skill, 0)
	return count


static func _add(totals: Dictionary, key: Resource, values: Dictionary) -> void:
	var entry: Dictionary = totals.get_or_add(key, {})
	for name: String in values:
		entry[name] = entry.get(name, 0) + values[name]


## {n, win, win_margin, lost, lost_margin}: the mean differences of [win, lost]
## pairs and their 95% margins of error.
static func _paired(list: Array) -> Dictionary:
	var result := {n = list.size()}
	for column: int in [0, 1]:
		var mean := 0.0
		for pair: Array in list:
			mean += pair[column]
		mean /= maxi(1, list.size())
		var spread := 0.0
		for pair: Array in list:
			spread += pow(pair[column] - mean, 2)
		var sd := sqrt(spread / maxi(1, list.size() - 1))
		var name := "win" if column == 0 else "lost"
		result[name] = mean
		result[name + "_margin"] = 1.96 * sd / sqrt(maxi(1, list.size()))
	return result

## The balance tool's sweep from the terminal: random parties against every
## encounter, and every hero skill and trinket measured with and without, at
## one preset. Prints encounters (flagging missed targets), heroes, and the
## skills and trinkets that stand out.
## Run: godot --headless --path . --script res://tools/balance_probe.gd -- [--preset=Base] [--thorough] [--all]
## --all lists every skill and trinket, not just the ones that stand out.
extends SceneTree


func _initialize() -> void:
	var library := BalanceLibrary.new()
	var preset_name := "Base"
	var size := BalanceSweep.Size.QUICK
	var everything := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preset="):
			preset_name = arg.trim_prefix("--preset=")
		elif arg == "--thorough":
			size = BalanceSweep.Size.THOROUGH
		elif arg == "--all":
			everything = true
	var preset := library.targets.preset_named(preset_name)
	var sweep := BalanceSweep.of(library, preset, size)
	print("%s sweep at %s: %d fights in %d workers..." % [BalanceSweep.SIZE_NAMES[size], preset.name,
			sweep.fight_count(), BalanceSweep.default_workers()])
	sweep.start()
	sweep.wait()
	var results := sweep.results()
	print("Done in %.1f s (%d fights played). Overall win %s.\n" % [results.seconds, results.played,
			UiStyle.percent(results.win)])
	_print_encounters(library, results)
	_print_heroes(library, results)
	_print_worth(library, results, "Skills", _hero_skills(library), everything)
	_print_worth(library, results, "Trinkets", library.trinkets, everything)
	quit()


func _print_encounters(library: BalanceLibrary, results: BalanceSweep.Results) -> void:
	print("%-26s %-8s %10s %8s %7s %7s %7s  %s" % ["Encounter", "role", "win", "HP lost", "stress", "deaths",
			"rounds", "target"])
	for encounter in library.encounters:
		var entry: Dictionary = results.encounters.get(encounter, {})
		if entry.is_empty():
			continue
		var roles := library.role_keys(encounter)
		var win := BalanceSweep.Results.rate(entry, "wins")
		var misses := BalanceFlags.encounter_misses(results, encounter, roles, library.targets)
		var targets := BalanceFlags.encounter_targets(results, roles, library.targets)
		var verdict := ("MISSES " + "; ".join(misses)) if not misses.is_empty() else ("ok" if not targets.is_empty() else "")
		print("%-26s %-8s %4s ±%2d%% %8s %7.1f %7.1f %7.1f  %s%s" % [encounter.display_name.left(26),
				",".join(roles), UiStyle.percent(win), roundi(100 * BalanceSweep.Results.margin(win, entry.n)),
				UiStyle.percent(BalanceSweep.Results.rate(entry, "lost")), BalanceSweep.Results.rate(entry, "stress"),
				BalanceSweep.Results.rate(entry, "deaths"), BalanceSweep.Results.rate(entry, "rounds"), verdict,
				"  (%d stalled)" % entry.stalled if entry.stalled > 0 else ""])
	print("")


func _print_heroes(library: BalanceLibrary, results: BalanceSweep.Results) -> void:
	print("%-16s %6s %8s %8s %6s" % ["Hero", "win", "vs avg", "HP lost", "died"])
	for hero in library.heroes:
		var entry: Dictionary = results.heroes.get(hero, {})
		if entry.is_empty():
			continue
		var lead := BalanceFlags.hero_lead(results, hero)
		print("%-16s %6s %+7.0f%% %8s %6s%s" % [hero.display_name, UiStyle.percent(BalanceSweep.Results.rate(entry, "wins")),
				lead * 100, UiStyle.percent(BalanceSweep.Results.rate(entry, "lost")),
				UiStyle.percent(BalanceSweep.Results.rate(entry, "died")),
				"  FLAG" if BalanceFlags.hero_flagged(results, hero, library.targets) else ""])
	print("")


func _hero_skills(library: BalanceLibrary) -> Array:
	var skills: Array = []
	for hero in library.heroes:
		skills.append_array(hero.skills)
	return skills


## Each skill or trinket's win and HP-lost difference with against without, best first.
func _print_worth(library: BalanceLibrary, results: BalanceSweep.Results, title: String, subjects: Array,
		everything: bool) -> void:
	var middle := BalanceFlags.middle_worth(results, subjects)
	var measured := subjects.filter(func(s: Resource) -> bool: return results.pairs.has(s))
	measured.sort_custom(func(a: Resource, b: Resource) -> bool: return results.pairs[a].lost < results.pairs[b].lost)
	print("%s, with against without (middle: win %+.0f%%, HP lost %+.1f%%):" % [title, middle.win * 100,
			middle.lost * 100])
	for subject: Resource in measured:
		var flagged := BalanceFlags.stands_out(results, subject, middle, library.targets)
		if not everything and not flagged:
			continue
		var pair: Dictionary = results.pairs[subject]
		var owner := ""
		if subject is SkillDef:
			for hero in library.heroes:
				if subject in hero.skills:
					owner = hero.display_name + ": "
		print("  %-36s win %+4.0f%% ±%2.0f   HP lost %+5.1f%% ±%3.1f%s" % [(owner + subject.display_name).left(36),
				pair.win * 100, pair.win_margin * 100, pair.lost * 100, pair.lost_margin * 100,
				"  FLAG" if flagged else ""])
	print("")

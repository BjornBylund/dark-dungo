## Plays whole sandbox runs with scripted players. Guards against stalemates
## and crashes, and prints win rates as a rough balance signal.
extends TestCase

const RUNS := 50
const MAX_ROUNDS := 60


func test_random_player_runs_always_finish() -> void:
	var stats := _simulate(AutoPlayer.random)
	print("        random player:   %s" % _summary(stats))
	assert_eq(stats.stalled, 0, "battles that hit %d rounds" % MAX_ROUNDS)


func test_sensible_player_runs_always_finish() -> void:
	var stats := _simulate(AutoPlayer.sensible)
	print("        sensible player: %s" % _summary(stats))
	assert_eq(stats.stalled, 0, "battles that hit %d rounds" % MAX_ROUNDS)


func _simulate(policy: Callable) -> Dictionary:
	var sandbox: SandboxDef = load("res://content/sandbox.tres")
	var stats := {wins = 0, stalled = 0, waves_cleared = [0, 0, 0, 0], deaths = 0, rounds = 0, battles = 0}
	for seed_value in RUNS:
		var run := SandboxRun.new(sandbox, seed_value)
		var cleared := 0
		while run.has_next_wave():
			var battle := run.start_next_wave()
			while battle.state != Battle.State.VICTORY and battle.state != Battle.State.DEFEAT:
				if battle.round_number > MAX_ROUNDS:
					stats.stalled += 1
					print("        stalled (seed %d, wave %d): %s" % [seed_value, run.wave_index + 1, _lineup(battle)])
					break
				battle.advance()
				if battle.state == Battle.State.AWAITING_INPUT:
					var choice: Array = policy.call(battle)
					battle.submit(choice[0], choice[1])
			stats.rounds += battle.round_number
			stats.battles += 1
			if battle.state != Battle.State.VICTORY:
				break
			cleared += 1
		stats.waves_cleared[cleared] += 1
		stats.deaths += sandbox.party.size() - run.party.filter(func(h: Combatant) -> bool: return h.is_active()).size()
		if cleared == sandbox.waves.size():
			stats.wins += 1
	return stats


func _summary(stats: Dictionary) -> String:
	return "win %d%%, waves cleared 0/1/2/3 = %s, avg deaths %.1f, avg rounds/battle %.1f" % [
		roundi(100.0 * stats.wins / RUNS), stats.waves_cleared, float(stats.deaths) / RUNS,
		float(stats.rounds) / maxi(stats.battles, 1)]


func _lineup(battle: Battle) -> String:
	var describe := func(unit: Combatant) -> String:
		return "%s@%d%s" % [unit.display_name, battle.rank_of(unit), " (corpse)" if unit.is_corpse else ""]
	return "%s vs %s" % [battle.heroes.map(describe), battle.enemies.map(describe)]

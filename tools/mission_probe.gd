## Balance probe: random parties of the whole cast play whole missions with the
## map auto-player, and the probe prints how often they finish and how far they
## get. scripts/balance.ps1 runs many of these in parallel and adds them up.
## Run: godot --headless --path . --script res://tools/mission_probe.gd --
##     [--length=0|1|2] [--tier=0|1|2] [--level=N] [--runs=N] [--first-seed=N]
## Prints one line per length: RESULT length=.. runs=.. completed=.. maps=.. fights=.. clear_shares=..
## and one per hero class: CLASS<tab>length<tab>name<tab>completed<tab>runs
## fights counts the fight shares of gold won (fights, elites, caches, events);
## clear_shares counts them in completed runs only.
extends SceneTree

const MAX_ROUNDS := 60
## A script error stops a headless script without quitting; this makes sure it ends.
const TIME_LIMIT := 300.0


func _initialize() -> void:
	create_timer(TIME_LIMIT).timeout.connect(func() -> void:
		printerr("mission_probe: gave up after %d s" % TIME_LIMIT)
		quit(1))
	var lengths: Array = [0, 1, 2]
	var tier := CampaignRules.Tier.APPRENTICE
	var level := 0
	var runs := 60
	var first_seed := 0
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=", 1)
		match arg.get_slice("=", 0):
			"--length":
				lengths = [int(value)]
			"--tier":
				tier = int(value) as CampaignRules.Tier
			"--level":
				level = int(value)
			"--runs":
				runs = int(value)
			"--first-seed":
				first_seed = int(value)
	if level >= CampaignRules.TIER_LEVELS[tier] + CampaignRules.WILL_NOT_GO_GAP:
		printerr("mission_probe: level %d heroes refuse %s missions" % [level, CampaignRules.TIER_NAMES[tier]])
		quit(1)
		return
	for length: int in lengths:
		_probe(length, tier, level, runs, first_seed)
	quit()


func _probe(length: int, tier: CampaignRules.Tier, level: int, runs: int, first_seed: int) -> void:
	var def: CampaignDef = load("res://content/campaign.tres")
	var completed := 0
	var maps := 0
	var fights := 0
	var clear_shares := 0
	var by_class := {}
	for seed_value in range(first_seed, first_seed + runs):
		var campaign := Campaign.create(def, seed_value)
		for hero in campaign.heroes:
			hero.arrived = true
			hero.recruited = true
			hero.xp = CampaignRules.LEVEL_XP[level - 1] if level > 0 else 0
		var pool := campaign.roster()
		var party: Array[HeroRecord] = []
		while party.size() < 4:
			var pick := pool[campaign.rng.randi_range(0, pool.size() - 1)]
			if pick not in party:
				party.append(pick)
		var mission := campaign._make_mission(tier, length, def.regions[seed_value % def.regions.size()])
		campaign.board.append(mission)
		var run := campaign.embark(mission, party)
		if not MapAutoPlayer.play(run, MAX_ROUNDS):
			printerr("mission_probe: seed %d stalled" % seed_value)
		var won := run.outcome == MissionRun.Outcome.COMPLETED
		var shares := roundi(float(run.gold_earned) / mission.fight_gold())
		fights += shares
		clear_shares += shares if won else 0
		maps += run.layer + int(won)
		completed += int(won)
		for hero in party:
			var entry: Array = by_class.get(hero.display_name, [0, 0])
			by_class[hero.display_name] = [entry[0] + int(won), entry[1] + 1]
	print("RESULT length=%d runs=%d completed=%d maps=%d fights=%d clear_shares=%d" % [length, runs, completed,
			maps, fights, clear_shares])
	for name: String in by_class:
		print("CLASS\t%d\t%s\t%d\t%d" % [length, name, by_class[name][0], by_class[name][1]])

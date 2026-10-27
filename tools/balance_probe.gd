## Balance probe: fresh random Apprentice parties against
## every enemy group, printing win rate, HP lost and stress gained.
## Run: godot --headless --path . --script res://tools/balance_probe.gd
extends SceneTree

const RUNS := 150


func _initialize() -> void:
	var def: CampaignDef = load("res://content/campaign.tres")
	var cast: Array[UnitDef] = []
	cast.append_array(def.starting_heroes)
	cast.append_array(def.recruits)
	for region in def.regions:
		for kind: String in ["encounters", "elites", "finales"]:
			for group: EncounterDef in region.get(kind):
				print("%-14s %-9s %s" % [region.id, kind, _probe(group, cast)])
		if region.boss:
			print("%-14s %-9s %s" % [region.id, "boss", _probe(region.boss, cast)])
	quit()


func _probe(group: EncounterDef, cast: Array[UnitDef]) -> String:
	var wins := 0
	var hp_lost := 0.0
	var stress := 0.0
	var rounds := 0
	for seed_value in RUNS:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var heroes: Array[Combatant] = []
		var picked: Array[UnitDef] = []
		while picked.size() < 4:
			var pick := cast[rng.randi_range(0, cast.size() - 1)]
			if pick not in picked:
				picked.append(pick)
				heroes.append(Growth.hero_combatant(HeroRecord.new(pick)))
		var party := heroes.duplicate()
		var enemies: Array[Combatant] = []
		for enemy in group.enemies:
			enemies.append(Growth.enemy_combatant(enemy, CampaignRules.Tier.APPRENTICE))
		var battle := Battle.new(heroes, enemies, rng)
		while battle.state != Battle.State.VICTORY and battle.state != Battle.State.DEFEAT and battle.round_number < 60:
			battle.advance()
			if battle.state == Battle.State.AWAITING_INPUT:
				var choice := AutoPlayer.sensible(battle)
				battle.submit(choice[0], choice[1])
		wins += int(battle.state == Battle.State.VICTORY)
		rounds += battle.round_number
		for unit: Combatant in party:
			hp_lost += 1.0 - float(unit.hp) / unit.max_hp
			stress += unit.stress
	return "%-26s win %3d%%  hp lost %3d%%  stress %.1f  rounds %.1f" % [group.display_name, 100 * wins / RUNS,
			roundi(100 * hp_lost / (RUNS * 4)), stress / (RUNS * 4), float(rounds) / RUNS]

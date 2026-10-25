## A run through the sandbox: the party fights each wave in order. Heroes keep
## HP, stress and long-lasting buffs between waves, and the dead stay dead.
class_name SandboxRun
extends RefCounted

var sandbox: SandboxDef
var seed_value: int
var rng := RandomNumberGenerator.new()
## Surviving heroes in their current order; index 0 stands in rank 1.
var party: Array[Combatant] = []
var wave_index := -1
var battle: Battle


func _init(definition: SandboxDef, run_seed: int) -> void:
	sandbox = definition
	seed_value = run_seed
	rng.seed = run_seed
	for unit_def in definition.party:
		party.append(Combatant.new(unit_def, true))


func wave_count() -> int:
	return sandbox.waves.size()


func has_next_wave() -> bool:
	_collect_survivors()
	return wave_index + 1 < wave_count() and not party.is_empty()


func start_next_wave() -> Battle:
	_collect_survivors()
	wave_index += 1
	var enemies: Array[Combatant] = []
	for unit_def in sandbox.waves[wave_index].enemies:
		enemies.append(Combatant.new(unit_def, false))
	battle = Battle.new(party, enemies, rng)
	return battle


func _collect_survivors() -> void:
	if battle == null or battle.state not in [Battle.State.VICTORY, Battle.State.DEFEAT]:
		return
	party.assign(battle.heroes.filter(func(hero: Combatant) -> bool: return hero.is_active()))

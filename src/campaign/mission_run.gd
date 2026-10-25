## A mission in progress: the party's combatants carried from fight to fight,
## the gold earned so far and who has been defeated.
class_name MissionRun
extends RefCounted

enum Outcome { IN_PROGRESS, COMPLETED, RETREATED, FAILED }

var mission: Mission
var party: Array[HeroRecord] = []
## Combatant per party member, in the same order; kept after defeat for their final stress.
var combatants: Array[Combatant] = []
## Standing heroes in formation order (index 0 in rank 1).
var formation: Array[Combatant] = []
var fight_index := 0
var gold_earned := 0
var defeated: Array[HeroRecord] = []
var outcome := Outcome.IN_PROGRESS
var battle: Battle
var rng: RandomNumberGenerator


func _init(run_mission: Mission, members: Array[HeroRecord], random: RandomNumberGenerator) -> void:
	mission = run_mission
	party.assign(members)
	rng = random
	for record in party:
		combatants.append(Growth.hero_combatant(record))
	formation.assign(combatants)


func has_next_fight() -> bool:
	return outcome == Outcome.IN_PROGRESS and fight_index < mission.fights()


func start_next_fight() -> Battle:
	var enemies: Array[Combatant] = []
	for def in mission.encounters[fight_index].enemies:
		enemies.append(Growth.enemy_combatant(def, mission.tier))
	battle = Battle.new(formation, enemies, rng)
	return battle


## Call once the current battle has ended.
func finish_fight() -> void:
	for i in party.size():
		if combatants[i].dead and party[i] not in defeated:
			defeated.append(party[i])
	formation.assign(battle.heroes)
	if battle.state == Battle.State.VICTORY:
		gold_earned += mission.fight_gold()
		fight_index += 1
		if fight_index >= mission.fights():
			outcome = Outcome.COMPLETED
	else:
		outcome = Outcome.FAILED
	battle = null


func retreat() -> void:
	outcome = Outcome.RETREATED


func record_of(unit: Combatant) -> HeroRecord:
	var index := combatants.find(unit)
	return party[index] if index >= 0 else null


## Between fights only: survivors' HP, stress and lasting buffs are kept.
func to_dict() -> Dictionary:
	var states := []
	for unit in combatants:
		var buffs := unit.buffs.filter(func(buff: Dictionary) -> bool:
			return buff.expiry == Combatant.BuffExpiry.RUN or buff.expiry == Combatant.BuffExpiry.ROUNDS)
		states.append({hp = unit.hp, stress = unit.stress, dead = unit.dead, buffs = buffs})
	return {
		mission = mission.to_dict(), fight_index = fight_index, gold_earned = gold_earned,
		states = states, formation = formation.map(func(u: Combatant) -> int: return combatants.find(u)),
		defeated = defeated.map(func(r: HeroRecord) -> int: return party.find(r)),
	}


static func from_dict(data: Dictionary, members: Array[HeroRecord], random: RandomNumberGenerator) -> MissionRun:
	var run := MissionRun.new(Mission.from_dict(data.mission), members, random)
	run.fight_index = int(data.fight_index)
	run.gold_earned = int(data.gold_earned)
	for i in run.combatants.size():
		var state: Dictionary = data.states[i]
		var unit := run.combatants[i]
		unit.hp = int(state.hp)
		unit.stress = int(state.stress)
		unit.dead = state.dead
		for buff: Dictionary in state.buffs:
			unit.add_buff(StringName(buff.stat), buff.amount, int(buff.expiry) as Combatant.BuffExpiry, int(buff.rounds))
	run.formation.clear()
	for index in data.formation:
		run.formation.append(run.combatants[int(index)])
	for index in data.defeated:
		run.defeated.append(run.party[int(index)])
	return run

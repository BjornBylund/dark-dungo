## Sensible choices on a mission map, for autoplay and the balance tests: rest
## when hurt or stressed, take elites only when healthy, skip fights when badly
## hurt, otherwise prefer loot.
class_name MapAutoPlayer
extends RefCounted


static func choose_room(run: MissionRun) -> int:
	var hp := _average(run, func(unit: Combatant) -> float: return unit.hp_fraction())
	var stress := _average(run, func(unit: Combatant) -> float: return unit.stress)
	var best: MapRoom = null
	var best_score := -1.0
	for room in run.next_rooms():
		var score := 1.0
		match room.type:
			MapRoom.Type.REST:
				score = 3.0 if hp < 0.6 or stress >= 5.0 else 0.5
			MapRoom.Type.CACHE:
				score = 2.0
			MapRoom.Type.FIGHT:
				score = 1.5 if hp >= 0.5 else 0.8
			MapRoom.Type.EVENT:
				score = 1.2
			MapRoom.Type.ELITE:
				score = 1.8 if hp > 0.8 and stress < 4.0 else 0.2
		if score > best_score:
			best = room
			best_score = score
	return best.id


## True to heal, false to relieve stress.
static func choose_rest(run: MissionRun) -> bool:
	var hp := _average(run, func(unit: Combatant) -> float: return unit.hp_fraction())
	var stress := _average(run, func(unit: Combatant) -> float: return unit.stress)
	return hp < 0.75 or stress < 2.0


static func choose_event(run: MissionRun) -> int:
	var choices := run.event().choices
	for i in choices.size():
		if run.choice_blocked(choices[i]) == "":
			return i
	return 0


## Plays a whole mission: routes, rests and events with the choices above, and
## fights with AutoPlayer.sensible. Returns false if a fight stalled past
## `max_rounds` (the mission is left in progress).
static func play(run: MissionRun, max_rounds: int = 60) -> bool:
	while run.outcome == MissionRun.Outcome.IN_PROGRESS:
		if run.has_pending_fight():
			var battle := run.start_fight()
			while battle.state != Battle.State.VICTORY and battle.state != Battle.State.DEFEAT:
				if battle.round_number > max_rounds:
					return false
				battle.advance()
				if battle.state == Battle.State.AWAITING_INPUT:
					var choice := AutoPlayer.sensible(battle)
					battle.submit(choice[0], choice[1])
			run.finish_fight()
		elif not run.room_done:
			if run.event():
				run.choose(choose_event(run))
			else:
				run.rest(choose_rest(run))
		else:
			run.enter(choose_room(run))
	return true


static func _average(run: MissionRun, value: Callable) -> float:
	if run.formation.is_empty():
		return 0.0
	var total := 0.0
	for unit in run.formation:
		total += value.call(unit)
	return total / run.formation.size()

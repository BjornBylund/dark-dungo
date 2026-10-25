## A mission in progress: the party walking its maps room by room, their
## combatants carried from fight to fight, what they have earned on the way and
## who has been defeated.
##
## Pick a room from next_rooms() and enter() it. Fight rooms (and fights started
## by events) leave a pending fight: start_fight(), play the Battle, then
## finish_fight(). Rest rooms wait for rest(), event rooms for choose(); caches
## pay as soon as they are entered. Once a room is done the party moves on, or
## retreats. Winning a map's finale leads to the next map, healed, like a new
## Slay the Spire act; winning the last map's finale completes the mission.
class_name MissionRun
extends RefCounted

enum Outcome { IN_PROGRESS, COMPLETED, RETREATED, FAILED }
## How a won fight pays.
enum FightKind { NORMAL, ELITE, FINALE }

var mission: Mission
## The map the party is on: map number `layer` of `layers`.
var map: MissionMap
var layer := 0
var layers := 1
## Set on reaching a new map, until the first room of it is entered.
var new_map := false
## Events for drawing the next maps; not saved, the campaign sets them.
var events: Array[EventDef] = []
var party: Array[HeroRecord] = []
## Combatant per party member, in the same order; kept after defeat for their final stress.
var combatants: Array[Combatant] = []
## Standing heroes in formation order (index 0 in rank 1).
var formation: Array[Combatant] = []
## The room the party is in, or -1 before the first.
var room_id := -1
## Every room entered, in order: the route so far.
var visited: Array[int] = []
## Whether the current room is dealt with, so the party can move on or retreat.
var room_done := true
var gold_earned := 0
var heirlooms_earned: Dictionary[StringName, int] = {}
var defeated: Array[HeroRecord] = []
var outcome := Outcome.IN_PROGRESS
## The fight waiting to start, from a fight room or an event, and how it pays.
var pending: EncounterDef
var pending_kind := FightKind.NORMAL
var battle: Battle
var rng: RandomNumberGenerator


func _init(run_mission: Mission, run_map: MissionMap, members: Array[HeroRecord], random: RandomNumberGenerator) -> void:
	mission = run_mission
	map = run_map
	layers = CampaignRules.MAP_LAYERS[mission.length]
	party.assign(members)
	rng = random
	for record in party:
		combatants.append(Growth.hero_combatant(record))
	formation.assign(combatants)


func current_room() -> MapRoom:
	return map.room(room_id) if room_id >= 0 else null


## The rooms the party can go to now: the first column at the start, then the
## current room's exits once it is done.
func next_rooms() -> Array[MapRoom]:
	if outcome != Outcome.IN_PROGRESS or not room_done:
		return []
	if room_id < 0:
		return map.in_column(0)
	return map.exits_of(current_room())


func enter(id: int) -> String:
	if map.room(id) not in next_rooms():
		return "The party can't go there now."
	room_id = id
	room_done = false
	new_map = false
	visited.append(id)
	var room := current_room()
	match room.type:
		MapRoom.Type.FIGHT:
			_queue_fight(room.encounter, FightKind.NORMAL)
		MapRoom.Type.ELITE:
			_queue_fight(room.encounter, FightKind.ELITE)
		MapRoom.Type.FINALE:
			_queue_fight(room.encounter, FightKind.FINALE)
		MapRoom.Type.CACHE:
			_open_cache(room)
	return ""


func can_retreat() -> bool:
	return outcome == Outcome.IN_PROGRESS and room_done


func retreat() -> void:
	if can_retreat():
		outcome = Outcome.RETREATED


func record_of(unit: Combatant) -> HeroRecord:
	var index := combatants.find(unit)
	return party[index] if index >= 0 else null


# --- Fights ---

func has_pending_fight() -> bool:
	return pending != null


func start_fight() -> Battle:
	var enemies: Array[Combatant] = []
	for def in pending.enemies:
		enemies.append(Growth.enemy_combatant(def, mission.tier))
	battle = Battle.new(formation, enemies, rng)
	return battle


## Call once the current battle has ended. A win pays the fight share (twice
## that and heirlooms for an elite) and finishes the room; winning a finale
## leads on to the next map, or completes the mission after the last one.
## Losing any fight fails it.
func finish_fight() -> void:
	for i in party.size():
		if combatants[i].dead and party[i] not in defeated:
			defeated.append(party[i])
	formation.assign(battle.heroes)
	var won_finale := false
	if battle.state == Battle.State.VICTORY:
		match pending_kind:
			FightKind.ELITE:
				gold_earned += 2 * mission.fight_gold()
				_add_heirlooms(mission.heirloom, CampaignRules.ELITE_HEIRLOOMS[mission.tier])
			_:
				gold_earned += mission.fight_gold()
		room_done = true
		won_finale = pending_kind == FightKind.FINALE
	else:
		outcome = Outcome.FAILED
	pending = null
	battle = null
	if won_finale:
		if layer + 1 < layers:
			_next_map()
		else:
			outcome = Outcome.COMPLETED


## The party moves on to a freshly drawn map, back at full HP as between Slay
## the Spire's acts. Stress stays.
func _next_map() -> void:
	layer += 1
	map = MissionMap.generate(mission.region, events, rng)
	room_id = -1
	visited.clear()
	room_done = true
	new_map = true
	for unit in formation:
		unit.hp = unit.max_hp
		unit.deaths_door = false


func _queue_fight(encounter: EncounterDef, kind: FightKind) -> void:
	pending = encounter
	pending_kind = kind


# --- Rests and caches ---

## The whole party heals REST_HEAL of max HP (leaving Death's Door), or loses REST_STRESS stress.
func rest(heal: bool) -> String:
	var room := current_room()
	if room == null or room.type != MapRoom.Type.REST or room_done:
		return "There is no rest here."
	for unit in formation:
		if heal:
			unit.hp = mini(unit.max_hp, unit.hp + ceili(unit.max_hp * CampaignRules.REST_HEAL))
			unit.deaths_door = false
		else:
			unit.stress = maxi(0, unit.stress - CampaignRules.REST_STRESS)
	room_done = true
	return ""


func cache_gold() -> int:
	return mission.fight_gold()


func cache_heirlooms() -> int:
	return CampaignRules.CACHE_HEIRLOOMS[mission.tier]


func _open_cache(room: MapRoom) -> void:
	if room.cache_heirloom == &"":
		gold_earned += cache_gold()
	else:
		_add_heirlooms(room.cache_heirloom, cache_heirlooms())
	room_done = true


func _add_heirlooms(type: StringName, amount: int) -> void:
	heirlooms_earned[type] = maxi(0, heirlooms_earned.get(type, 0) + amount)


# --- Events ---

## The current room's event while it waits for a choice, otherwise null.
func event() -> EventDef:
	var room := current_room()
	return room.event if room and room.type == MapRoom.Type.EVENT and not room_done else null


## Why the party can't take a choice, or "".
func choice_blocked(choice: EventChoiceDef) -> String:
	if choice.requires and _hero_of_class(choice.requires) == null:
		return "Needs the %s." % choice.requires.display_name
	return ""


## Takes the event choice at `index`: rolls its chance and applies the outcomes.
## Returns {success, text, lines} for the screen, or {} if it can't be taken. A
## fight outcome leaves a pending fight; otherwise the room is done.
func choose(index: int) -> Dictionary:
	var scene := event()
	if scene == null or index < 0 or index >= scene.choices.size():
		return {}
	var choice := scene.choices[index]
	if choice_blocked(choice) != "":
		return {}
	var success := choice.chance >= 1.0 or rng.randf() < choice.chance
	var chosen := _hero_of_class(choice.requires) if choice.requires else null
	var lines: Array[String] = []
	for effect in (choice.success if success else choice.failure):
		lines.append_array(_apply(effect, chosen))
	if pending == null:
		room_done = true
	return {success = success, text = choice.success_text if success else choice.failure_text, lines = lines}


## What a choice does, for its button: "the party heals 20% HP" or
## "60%: +900 gold; otherwise: a fight".
func describe_choice(choice: EventChoiceDef) -> String:
	var success := describe_outcomes(choice.success, choice.requires)
	if choice.chance >= 1.0:
		return success
	var failure := describe_outcomes(choice.failure, choice.requires)
	return "%d%%: %s; otherwise: %s" % [roundi(choice.chance * 100), success, failure if failure != "" else "nothing"]


func describe_outcomes(effects: Array[EventOutcomeDef], requires: UnitDef = null) -> String:
	var parts: Array[String] = []
	for effect in effects:
		var who := "the party"
		match effect.target:
			EventOutcomeDef.Target.RANDOM_HERO:
				who = "one hero"
			EventOutcomeDef.Target.CHOSEN_HERO:
				who = "the %s" % requires.display_name if requires else "one hero"
		match effect.kind:
			EventOutcomeDef.Kind.HP:
				parts.append("%s %s %d%% HP" % [who, "heals" if effect.amount > 0 else "loses", roundi(absf(effect.amount) * 100)])
			EventOutcomeDef.Kind.STRESS:
				parts.append("%s %+d stress" % [who, int(effect.amount)])
			EventOutcomeDef.Kind.GOLD:
				parts.append("%+d gold" % _event_gold(effect))
			EventOutcomeDef.Kind.HEIRLOOMS:
				parts.append("%+d %s" % [_event_heirlooms(effect), CampaignRules.HEIRLOOM_NAMES[_heirloom_type(effect)]])
			EventOutcomeDef.Kind.TOKEN:
				parts.append("%s gains %s%s" % [who, Tokens.display_name(effect.token),
						" x%d" % effect.stacks if effect.stacks > 1 else ""])
			EventOutcomeDef.Kind.FIGHT:
				parts.append("a fight")
			EventOutcomeDef.Kind.ELITE:
				parts.append("an elite fight")
	return ", ".join(parts)


func _apply(effect: EventOutcomeDef, chosen: Combatant) -> Array[String]:
	var lines: Array[String] = []
	match effect.kind:
		EventOutcomeDef.Kind.HP:
			for unit in _targets(effect, chosen):
				var change := roundi(unit.max_hp * effect.amount)
				var before := unit.hp
				unit.hp = clampi(unit.hp + change, 1, unit.max_hp)
				if change > 0:
					unit.deaths_door = false
				lines.append("%s %s %d HP" % [unit.display_name, "heals" if change > 0 else "loses",
						absi(unit.hp - before)])
		EventOutcomeDef.Kind.STRESS:
			for unit in _targets(effect, chosen):
				var before := unit.stress
				unit.stress = clampi(unit.stress + int(effect.amount), 0, Rules.STRESS_MAX)
				lines.append("%s %+d stress" % [unit.display_name, unit.stress - before])
		EventOutcomeDef.Kind.GOLD:
			var before := gold_earned
			gold_earned = maxi(0, gold_earned + _event_gold(effect))
			lines.append("%+d gold" % (gold_earned - before))
		EventOutcomeDef.Kind.HEIRLOOMS:
			var type := _heirloom_type(effect)
			var before: int = heirlooms_earned.get(type, 0)
			_add_heirlooms(type, _event_heirlooms(effect))
			lines.append("%+d %s" % [heirlooms_earned[type] - before, CampaignRules.HEIRLOOM_NAMES[type]])
		EventOutcomeDef.Kind.TOKEN:
			for unit in _targets(effect, chosen):
				unit.add_token(effect.token, effect.stacks)
				lines.append("%s gains %s" % [unit.display_name, Tokens.display_name(effect.token)])
		EventOutcomeDef.Kind.FIGHT:
			_queue_fight(MissionMap._pick(mission.region.encounters, rng), FightKind.NORMAL)
			lines.append("A fight!")
		EventOutcomeDef.Kind.ELITE:
			var region := mission.region
			_queue_fight(MissionMap._pick(region.elites if not region.elites.is_empty() else region.finales, rng),
					FightKind.ELITE)
			lines.append("An elite fight!")
	return lines


func _targets(effect: EventOutcomeDef, chosen: Combatant) -> Array[Combatant]:
	var result: Array[Combatant] = []
	match effect.target:
		EventOutcomeDef.Target.PARTY:
			result.assign(formation)
		EventOutcomeDef.Target.CHOSEN_HERO when chosen != null:
			result.append(chosen)
		_:
			if not formation.is_empty():
				result.append(formation[rng.randi_range(0, formation.size() - 1)])
	return result


func _hero_of_class(unit: UnitDef) -> Combatant:
	for hero in formation:
		if hero.def == unit:
			return hero
	return null


func _event_gold(effect: EventOutcomeDef) -> int:
	return roundi(effect.amount * mission.fight_gold())


func _event_heirlooms(effect: EventOutcomeDef) -> int:
	return roundi(effect.amount * CampaignRules.EVENT_HEIRLOOM_MULTIPLIER[mission.tier])


func _heirloom_type(effect: EventOutcomeDef) -> StringName:
	return effect.heirloom if effect.heirloom != &"" else mission.heirloom


# --- Saving ---

## Between fights only: survivors' HP, stress, tokens and lasting buffs are kept.
func to_dict() -> Dictionary:
	var states := []
	for unit in combatants:
		var buffs := unit.buffs.filter(func(buff: Dictionary) -> bool:
			return buff.expiry == Combatant.BuffExpiry.RUN or buff.expiry == Combatant.BuffExpiry.ROUNDS)
		states.append({hp = unit.hp, stress = unit.stress, dead = unit.dead, buffs = buffs, tokens = unit.tokens,
				token_turns = unit.token_turns})
	return {
		mission = mission.to_dict(), map = map.to_dict(), layer = layer, new_map = new_map,
		room_id = room_id, visited = visited, room_done = room_done,
		gold_earned = gold_earned, heirlooms_earned = heirlooms_earned,
		pending = pending.resource_path if pending else "", pending_kind = pending_kind,
		states = states, formation = formation.map(func(u: Combatant) -> int: return combatants.find(u)),
		defeated = defeated.map(func(r: HeroRecord) -> int: return party.find(r)),
	}


static func from_dict(data: Dictionary, members: Array[HeroRecord], random: RandomNumberGenerator) -> MissionRun:
	var run := MissionRun.new(Mission.from_dict(data.mission), MissionMap.from_dict(data.map), members, random)
	run.layer = int(data.get("layer", 0))
	run.new_map = data.get("new_map", false)
	run.room_id = int(data.room_id)
	for id in data.get("visited", []):
		run.visited.append(int(id))
	run.room_done = data.room_done
	run.gold_earned = int(data.gold_earned)
	for type: String in data.heirlooms_earned:
		run.heirlooms_earned[StringName(type)] = int(data.heirlooms_earned[type])
	if data.pending != "":
		run.pending = load(data.pending)
	run.pending_kind = int(data.pending_kind) as FightKind
	for i in run.combatants.size():
		var state: Dictionary = data.states[i]
		var unit := run.combatants[i]
		unit.hp = int(state.hp)
		unit.stress = int(state.stress)
		unit.dead = state.dead
		for buff: Dictionary in state.buffs:
			unit.add_buff(StringName(buff.stat), buff.amount, int(buff.expiry) as Combatant.BuffExpiry, int(buff.rounds))
		for token: String in state.get("tokens", {}):
			unit.tokens[StringName(token)] = int(state.tokens[token])
			unit.token_turns[StringName(token)] = int(state.token_turns.get(token, Rules.TOKEN_DURATION))
	run.formation.clear()
	for index in data.formation:
		run.formation.append(run.combatants[int(index)])
	for index in data.defeated:
		run.defeated.append(run.party[int(index)])
	return run

## Mission maps: how they are built, and walking one room by room.
extends TestCase

const MENDER := "res://content/heroes/mender.tres"


func _region() -> RegionDef:
	return Fixtures.region(&"test", ["wave_1", "wave_2"], ["the_glutton"], ["wave_3"])


func _map(seed_value: int, events: Array[EventDef] = [Fixtures.spring_event()]) -> MissionMap:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return MissionMap.generate(_region(), events, rng)


## A run on `map` (or a generated one); short missions cross just that one map.
func _run(map: MissionMap = null, heroes: Array = ["vanguard", "cutthroat", "marksman", "mender"],
		tier: int = CampaignRules.Tier.APPRENTICE, length: int = CampaignRules.Length.SHORT) -> MissionRun:
	var mission := Mission.new()
	mission.region = _region()
	mission.tier = tier as CampaignRules.Tier
	mission.length = length as CampaignRules.Length
	mission.heirloom = &"crest"
	var party: Array[HeroRecord] = []
	for id: String in heroes:
		party.append(HeroRecord.new(load("res://content/heroes/%s.tres" % id)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	return MissionRun.new(mission, map if map else _map(3), party, rng)


## A one-column map: start rooms of the given types, all leading to the finale.
func _map_of(types: Array) -> MissionMap:
	var map := MissionMap.new()
	map.columns = 2
	for i in types.size():
		var room := MapRoom.new()
		room.id = i
		room.column = 0
		room.row = i
		room.type = types[i]
		room.exits.append(types.size())
		if room.is_fight():
			room.encounter = load("res://content/encounters/wave_1.tres")
		if room.type == MapRoom.Type.EVENT:
			room.event = Fixtures.spring_event()
		map.rooms.append(room)
	var final := MapRoom.new()
	final.id = types.size()
	final.column = 1
	final.row = -1
	final.type = MapRoom.Type.FINALE
	final.encounter = load("res://content/encounters/wave_3.tres")
	map.rooms.append(final)
	return map


func _win(run: MissionRun) -> void:
	var battle := run.start_fight()
	for enemy in battle.enemies:
		enemy.hp = 1
	for i in 3000:
		if battle.state == Battle.State.VICTORY or battle.state == Battle.State.DEFEAT:
			break
		battle.advance()
		if battle.state == Battle.State.AWAITING_INPUT:
			var choice := AutoPlayer.sensible(battle)
			battle.submit(choice[0], choice[1])
	run.finish_fight()


# --- Building maps ---

func test_maps_have_nine_floors_and_end_in_one_finale() -> void:
	for seed_value in 20:
		var map := _map(seed_value)
		assert_eq(map.columns, CampaignRules.MAP_COLUMNS)
		var final := map.final_room()
		assert_eq(final.type, MapRoom.Type.FINALE)
		assert_eq(final.column, map.columns - 1)
		assert_eq(final.encounter, load("res://content/encounters/wave_3.tres"))
		assert_eq(map.rooms.filter(func(r: MapRoom) -> bool: return r.type == MapRoom.Type.FINALE).size(), 1)


func test_every_room_is_on_a_route_from_the_start_to_the_finale() -> void:
	for seed_value in 20:
		var map := _map(seed_value)
		var reached := {}
		for room in map.in_column(0):
			reached[room.id] = true
		for room in map.rooms:
			if reached.has(room.id):
				for exit in room.exits:
					reached[exit] = true
		assert_eq(reached.size(), map.rooms.size(), "every room reachable")
		for room in map.rooms:
			if room.type != MapRoom.Type.FINALE:
				assert_true(not room.exits.is_empty(), "room %d leads on" % room.id)
				for exit in room.exits:
					assert_eq(map.room(exit).column, room.column + 1)
		assert_true(map.in_column(0).size() >= 2, "a choice of starting rooms")


func test_maps_never_narrow_to_one_room_before_the_end() -> void:
	for seed_value in 300:
		var map := _map(seed_value)
		assert_eq(map.layout_problems(), [] as Array[String], "seed %d" % seed_value)
		for column in map.columns - 1:
			assert_true(map.in_column(column).size() >= 2, "column %d has a choice" % column)


func test_every_map_has_an_elite_with_a_way_around_it() -> void:
	for seed_value in 300:
		var map := _map(seed_value)
		var elites := map.rooms.filter(func(r: MapRoom) -> bool: return r.type == MapRoom.Type.ELITE)
		assert_true(not elites.is_empty(), "seed %d has an elite" % seed_value)
		assert_eq(map.type_problems(), [] as Array[String], "seed %d" % seed_value)
		for elite: MapRoom in elites:
			assert_true(elite.encounter in _region().elites)


func test_type_problems_spot_an_unavoidable_elite() -> void:
	var map := MissionMap.new()
	map.columns = 3
	for spec: Array in [[0, 0, [2], MapRoom.Type.FIGHT], [0, 1, [3], MapRoom.Type.FIGHT],
			[1, 0, [4], MapRoom.Type.ELITE], [1, 1, [4], MapRoom.Type.ELITE], [2, -1, [], MapRoom.Type.FINALE]]:
		var room := MapRoom.new()
		room.id = map.rooms.size()
		room.column = spec[0]
		room.row = spec[1]
		room.exits.assign(spec[2])
		room.type = spec[3]
		map.rooms.append(room)
	assert_eq(map.type_problems(), ["every route goes through an elite"] as Array[String])
	map.rooms[3].type = MapRoom.Type.EVENT
	assert_eq(map.type_problems(), [] as Array[String])


func test_layout_problems_spot_a_choke_point() -> void:
	var map := MissionMap.new()
	map.columns = 3
	for spec: Array in [[0, 0, [2]], [0, 1, [2]], [1, 1, [3]], [2, -1, []]]:
		var room := MapRoom.new()
		room.id = map.rooms.size()
		room.column = spec[0]
		room.row = spec[1]
		room.exits.assign(spec[2])
		if spec[1] < 0:
			room.type = MapRoom.Type.FINALE
		map.rooms.append(room)
	assert_eq(map.layout_problems(), ["column 2 narrows to one room"] as Array[String])


func test_routes_step_one_row_at_most_and_never_cross() -> void:
	for seed_value in 40:
		var map := _map(seed_value)
		for column in map.columns - 2:
			var links: Array[Vector2i] = []
			for room in map.in_column(column):
				for exit in room.exits:
					links.append(Vector2i(room.row, map.room(exit).row))
			for link in links:
				assert_true(absi(link.x - link.y) <= 1, "one row at most")
				for other in links:
					assert_true((link.x - other.x) * (link.y - other.y) >= 0, "no crossing in column %d" % column)


func test_room_types_follow_the_placement_rules() -> void:
	var fixed_columns := [0, CampaignRules.CACHE_COLUMN, CampaignRules.REST_COLUMN]
	for seed_value in 60:
		var map := _map(seed_value)
		for room in map.rooms:
			var spaced := room.type == MapRoom.Type.ELITE or room.type == MapRoom.Type.REST
			if room.column == 0:
				assert_eq(room.type, MapRoom.Type.FIGHT, "first column")
			if room.column == CampaignRules.CACHE_COLUMN:
				assert_eq(room.type, MapRoom.Type.CACHE, "cache column")
			if room.column == CampaignRules.REST_COLUMN:
				assert_eq(room.type, MapRoom.Type.REST, "rest before the finale")
			if spaced:
				assert_true(room.column >= CampaignRules.EARLY_COLUMNS, "no elite or rest early")
			if room.column == CampaignRules.REST_COLUMN - 1:
				assert_ne(room.type, MapRoom.Type.REST, "no rest just before the rest column")
			for exit in room.exits:
				if spaced:
					assert_ne(map.room(exit).type, room.type, "no %s after %s" % [room.type_name(), room.type_name()])
			if room.column + 1 not in fixed_columns:
				var exit_types := room.exits.map(func(id: int) -> int: return map.room(id).type)
				for type: int in exit_types:
					assert_eq(exit_types.count(type), 1, "exits lead to different types")


func test_rooms_get_their_regions_content() -> void:
	var region := _region()
	for seed_value in 20:
		var map := _map(seed_value)
		for room in map.rooms:
			match room.type:
				MapRoom.Type.FIGHT:
					assert_true(room.encounter in region.encounters)
				MapRoom.Type.ELITE:
					assert_true(room.encounter in region.elites)
				MapRoom.Type.EVENT:
					assert_true(room.event != null)


func test_events_do_not_repeat_until_all_have_been_used() -> void:
	var events: Array[EventDef] = []
	for i in 40:
		var event := Fixtures.spring_event()
		event.id = StringName("event_%d" % i)
		events.append(event)
	for seed_value in 20:
		var map := _map(seed_value, events)
		var seen := {}
		for room in map.rooms:
			if room.event:
				assert_false(seen.has(room.event.id), "event repeated")
				seen[room.event.id] = true


func test_without_events_event_rooms_become_fights() -> void:
	var none: Array[EventDef] = []
	for seed_value in 10:
		for room in _map(seed_value, none).rooms:
			assert_ne(room.type, MapRoom.Type.EVENT)


func test_room_types_roughly_follow_the_weights() -> void:
	var counts := [0, 0, 0, 0, 0, 0]
	for seed_value in 200:
		for room in _map(seed_value).rooms:
			counts[room.type] += 1
	var total := 0
	for count: int in counts:
		total += count
	print("        room mix over 200 long maps: fight %d%%, event %d%%, rest %d%%, elite %d%%, cache %d%%" % [
			100 * counts[0] / total, 100 * counts[1] / total, 100 * counts[2] / total, 100 * counts[3] / total,
			100 * counts[4] / total])
	assert_true(counts[MapRoom.Type.ELITE] > 0 and counts[MapRoom.Type.CACHE] > 0 and counts[MapRoom.Type.EVENT] > 0)


# --- Walking a map ---

func test_the_party_starts_in_the_first_column_and_moves_along_exits() -> void:
	var run := _run()
	assert_eq(run.next_rooms(), run.map.in_column(0))
	var first := run.next_rooms()[0]
	assert_eq(run.enter(first.id), "")
	assert_true(run.has_pending_fight(), "the first column is fights")
	assert_eq(run.next_rooms().size(), 0, "can't move on mid-room")
	assert_false(run.can_retreat())
	_win(run)
	assert_true(run.room_done)
	assert_eq(run.next_rooms(), run.map.exits_of(first))
	assert_ne(run.enter(run.map.final_room().id), "", "can't skip ahead")


func test_fights_pay_the_fight_share_and_elites_double_plus_heirlooms() -> void:
	var run := _run(_map_of([MapRoom.Type.FIGHT, MapRoom.Type.ELITE]), ["vanguard", "cutthroat", "marksman", "mender"],
			CampaignRules.Tier.VETERAN)
	run.enter(0)
	_win(run)
	assert_eq(run.gold_earned, run.mission.fight_gold())
	run.room_id = -1
	run.enter(1)
	_win(run)
	assert_eq(run.gold_earned, 3 * run.mission.fight_gold())
	assert_eq(run.heirlooms_earned[&"crest"], CampaignRules.ELITE_HEIRLOOMS[CampaignRules.Tier.VETERAN])


func test_winning_the_finale_completes_the_mission() -> void:
	var run := _run(_map_of([MapRoom.Type.FIGHT]))
	run.enter(0)
	_win(run)
	run.enter(1)
	assert_eq(run.pending_kind, MissionRun.FightKind.FINALE)
	_win(run)
	assert_eq(run.outcome, MissionRun.Outcome.COMPLETED)
	assert_eq(run.gold_earned, 2 * run.mission.fight_gold())


func test_short_medium_and_long_missions_cross_one_two_and_three_maps() -> void:
	for length in 3:
		var run := _run(null, ["vanguard"], CampaignRules.Tier.APPRENTICE, length)
		assert_eq(run.layers, CampaignRules.MAP_LAYERS[length])
		assert_eq(run.layer, 0)


func test_winning_a_maps_finale_leads_to_the_next_map_at_full_hp() -> void:
	var run := _run(_map_of([MapRoom.Type.FIGHT]), ["vanguard", "cutthroat", "marksman", "mender"],
			CampaignRules.Tier.APPRENTICE, CampaignRules.Length.MEDIUM)
	run.events.assign([Fixtures.spring_event()])
	run.enter(0)
	_win(run)
	run.enter(1)
	for unit in run.formation:
		unit.hp = 3
		unit.stress = 4
	_win(run)
	assert_eq(run.outcome, MissionRun.Outcome.IN_PROGRESS, "one map to go")
	assert_eq(run.layer, 1)
	assert_true(run.new_map)
	assert_eq(run.room_id, -1)
	assert_eq(run.visited, [] as Array[int])
	assert_eq(run.map.columns, CampaignRules.MAP_COLUMNS)
	assert_eq(run.next_rooms(), run.map.in_column(0))
	for unit in run.formation:
		assert_eq(unit.hp, unit.max_hp, "healed between maps")
		assert_eq(unit.stress, 4, "stress stays")
	var copy := MissionRun.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())), run.party, run.rng)
	assert_eq(copy.layer, 1)
	assert_true(copy.new_map)
	run.map = _map_of([MapRoom.Type.FIGHT])
	run.enter(0)
	assert_false(run.new_map)
	_win(run)
	run.enter(1)
	_win(run)
	assert_eq(run.outcome, MissionRun.Outcome.COMPLETED, "the last map's finale completes the mission")


func test_caches_pay_on_entry() -> void:
	var map := _map_of([MapRoom.Type.CACHE, MapRoom.Type.CACHE])
	map.room(1).cache_heirloom = &"bust"
	var run := _run(map)
	run.enter(0)
	assert_true(run.room_done)
	assert_eq(run.gold_earned, run.mission.fight_gold())
	run.room_id = -1
	run.enter(1)
	assert_eq(run.heirlooms_earned[&"bust"], CampaignRules.CACHE_HEIRLOOMS[CampaignRules.Tier.APPRENTICE])


func test_rests_heal_or_relieve_stress_for_the_whole_party() -> void:
	var run := _run(_map_of([MapRoom.Type.REST, MapRoom.Type.REST]))
	for unit in run.formation:
		unit.hp = 1
		unit.stress = 5
	run.enter(0)
	assert_false(run.room_done, "waits for a choice")
	assert_eq(run.rest(true), "")
	for unit in run.formation:
		assert_eq(unit.hp, 1 + ceili(unit.max_hp * CampaignRules.REST_HEAL))
	assert_ne(run.rest(true), "", "only once")
	run.room_id = -1
	run.enter(1)
	run.rest(false)
	for unit in run.formation:
		assert_eq(unit.stress, 5 - CampaignRules.REST_STRESS)


func test_retreat_only_between_rooms() -> void:
	var run := _run(_map_of([MapRoom.Type.REST]))
	assert_true(run.can_retreat(), "before the first room")
	run.enter(0)
	run.retreat()
	assert_eq(run.outcome, MissionRun.Outcome.IN_PROGRESS)
	run.rest(true)
	run.retreat()
	assert_eq(run.outcome, MissionRun.Outcome.RETREATED)


# --- Events ---

func test_certain_choices_apply_their_outcomes() -> void:
	var run := _run(_map_of([MapRoom.Type.EVENT]))
	for unit in run.formation:
		unit.hp = 5
	run.enter(0)
	assert_true(run.event() != null)
	var result := run.choose(0)
	assert_true(result.success)
	assert_true(run.room_done)
	assert_eq(run.event(), null)
	for unit in run.formation:
		assert_eq(unit.hp, mini(unit.max_hp, 5 + roundi(unit.max_hp * 0.2)))
	assert_eq(result.lines.size(), run.formation.size())


func test_a_choice_can_need_a_class_in_the_party() -> void:
	var without := _run(_map_of([MapRoom.Type.EVENT]), ["vanguard", "cutthroat", "marksman"])
	without.enter(0)
	var bless := without.event().choices[2]
	assert_eq(without.choice_blocked(bless), "Needs the Mender.")
	assert_eq(without.choose(2), {})
	var with := _run(_map_of([MapRoom.Type.EVENT]))
	with.enter(0)
	var mender := with.formation[3]
	mender.stress = 4
	with.formation[0].stress = 4
	with.choose(2)
	assert_eq(mender.stress, 2, "the chosen hero is the Mender")
	assert_eq(with.formation[0].stress, 4)


func test_chance_choices_succeed_about_as_often_as_stated_and_can_start_fights() -> void:
	var fights := 0
	var wins := 0
	for seed_value in 200:
		var run := _run(_map_of([MapRoom.Type.EVENT]))
		run.rng.seed = seed_value
		run.enter(0)
		var result := run.choose(1)
		if result.success:
			wins += 1
			assert_eq(run.gold_earned, run.mission.fight_gold())
			assert_true(run.room_done)
		else:
			fights += 1
			assert_true(run.has_pending_fight())
			assert_eq(run.pending_kind, MissionRun.FightKind.NORMAL)
			assert_false(run.room_done, "done once the fight is won")
	assert_between(wins, 75, 125)
	assert_eq(wins + fights, 200)


func test_event_hp_loss_never_kills_and_gold_loss_stops_at_zero() -> void:
	var map := _map_of([MapRoom.Type.EVENT])
	map.room(0).event.choices.assign([Fixtures.choice("Bleed", [
		Fixtures.outcome(EventOutcomeDef.Kind.HP, -2.0),
		Fixtures.outcome(EventOutcomeDef.Kind.GOLD, -3.0),
	])])
	var run := _run(map)
	run.gold_earned = 100
	run.enter(0)
	run.choose(0)
	for unit in run.formation:
		assert_eq(unit.hp, 1)
	assert_eq(run.gold_earned, 0)


func test_tokens_from_events_carry_into_the_next_fight() -> void:
	var map := _map_of([MapRoom.Type.EVENT])
	var bless := Fixtures.outcome(EventOutcomeDef.Kind.TOKEN)
	bless.token = Tokens.STRENGTH
	map.room(0).event.choices.assign([Fixtures.choice("Pray", [bless])])
	var run := _run(map)
	run.enter(0)
	run.choose(0)
	run.enter(1)
	var battle := run.start_fight()
	for hero in battle.heroes:
		assert_eq(hero.token_count(Tokens.STRENGTH), 1)


func test_choices_describe_what_they_do() -> void:
	var run := _run(_map_of([MapRoom.Type.EVENT]))
	var event := Fixtures.spring_event()
	assert_eq(run.describe_choice(event.choices[0]), "the party heals 20% HP")
	assert_eq(run.describe_choice(event.choices[1]), "50%%: +%d gold; otherwise: a fight" % run.mission.fight_gold())
	assert_eq(run.describe_choice(event.choices[2]), "the Mender -2 stress")


# --- Playing whole maps ---

func test_the_map_auto_player_finishes_maps() -> void:
	var completed := 0
	for seed_value in 20:
		var run := _run(_map(seed_value))
		for record in run.party:
			record.weapon_rank = 5
			record.armor_rank = 5
		run.combatants.clear()
		for record in run.party:
			run.combatants.append(Growth.hero_combatant(record))
		run.formation.assign(run.combatants)
		assert_true(MapAutoPlayer.play(run), "no stalled fights")
		assert_ne(run.outcome, MissionRun.Outcome.IN_PROGRESS)
		completed += int(run.outcome == MissionRun.Outcome.COMPLETED)
	assert_true(completed > 10, "strong parties finish most short missions (%d/20)" % completed)

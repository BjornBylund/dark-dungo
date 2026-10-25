## A mission's map: rooms in columns, played left to right like a Slay the
## Spire act. Random walks through a grid of MAP_ROWS rows make the routes, and
## every route ends at the region's finale. Room types follow Slay the Spire's
## placement rules (docs/design.md, Mission maps).
class_name MissionMap
extends RefCounted

## Maps drawn before giving up on one that passes layout_problems() and type_problems().
const ATTEMPTS := 100

## Rooms in column order, top row first; the final room is last.
var rooms: Array[MapRoom] = []
## Columns, counting the final room's.
var columns := 0


## Draws maps until one passes layout_problems() and type_problems(), then fills the rooms.
static func generate(region: RegionDef, length: int, events: Array[EventDef], rng: RandomNumberGenerator) -> MissionMap:
	var map := MissionMap.new()
	map.columns = CampaignRules.MAP_COLUMNS[length]
	for attempt in ATTEMPTS:
		map.rooms.clear()
		map._lay_out(rng)
		if not map.layout_problems().is_empty():
			continue
		map._assign_types(rng)
		if map.needs_elite():
			map._add_elite(rng)
		if map.type_problems().is_empty():
			break
	map._fill(region, events, rng)
	return map


## Medium and long maps always hold at least one elite.
func needs_elite() -> bool:
	return columns >= CampaignRules.MAP_COLUMNS[CampaignRules.Length.MEDIUM]


## Rules the room types must keep beyond the placement rules, as readable
## problems: medium and long maps have an elite, and some route reaches the
## finale without one.
func type_problems() -> Array[String]:
	var problems: Array[String] = []
	if needs_elite() and not rooms.any(func(r: MapRoom) -> bool: return r.type == MapRoom.Type.ELITE):
		problems.append("no elite")
	if not _route_avoiding(MapRoom.Type.ELITE):
		problems.append("every route goes through an elite")
	return problems


## Rules a layout must keep, as readable problems (empty when it keeps them all):
## every column before the final room offers at least two rooms, so routes never
## narrow to a single room before the end; every room leads on; and every room
## can be reached from the first column.
func layout_problems() -> Array[String]:
	var problems: Array[String] = []
	for c in columns - 1:
		if in_column(c).size() < 2:
			problems.append("column %d narrows to one room" % (c + 1))
	var reached := {}
	for start in in_column(0):
		reached[start.id] = true
	for spot in rooms:
		if spot.type != MapRoom.Type.FINALE and spot.exits.is_empty():
			problems.append("room %d leads nowhere" % spot.id)
		if reached.has(spot.id):
			for exit in spot.exits:
				reached[exit] = true
	if reached.size() != rooms.size():
		problems.append("%d rooms can't be reached" % (rooms.size() - reached.size()))
	return problems


func room(id: int) -> MapRoom:
	return rooms[id]


func final_room() -> MapRoom:
	return rooms.back()


func in_column(column: int) -> Array[MapRoom]:
	var result: Array[MapRoom] = []
	result.assign(rooms.filter(func(r: MapRoom) -> bool: return r.column == column))
	return result


func parents(child: MapRoom) -> Array[MapRoom]:
	var result: Array[MapRoom] = []
	result.assign(rooms.filter(func(r: MapRoom) -> bool: return child.id in r.exits))
	return result


func exits_of(from: MapRoom) -> Array[MapRoom]:
	var result: Array[MapRoom] = []
	for id in from.exits:
		result.append(rooms[id])
	return result


# --- Generation ---

## Walks from different rows of the first column to the last grid column, each
## step to the same row or the next one up or down, never crossing an earlier
## route. Grid spots no walk reached have no room. The last grid column all
## leads to the final room.
func _lay_out(rng: RandomNumberGenerator) -> void:
	var grid_columns := columns - 1
	var rows := CampaignRules.MAP_ROWS
	var reached := {}
	# Per gap between grid columns: Vector2i(from_row, to_row) for each path.
	var links: Array = []
	for c in grid_columns - 1:
		links.append([])
	var starts: Array[int] = []
	for walk in CampaignRules.MAP_WALKS:
		var row := rng.randi_range(0, rows - 1)
		while row in starts and starts.size() < rows:
			row = rng.randi_range(0, rows - 1)
		starts.append(row)
		reached[Vector2i(0, row)] = true
		for c in grid_columns - 1:
			var options: Array[int] = []
			for next in [row - 1, row, row + 1]:
				if next >= 0 and next < rows and not _crosses(links[c], row, next):
					options.append(next)
			var next: int = options[rng.randi_range(0, options.size() - 1)]
			if Vector2i(row, next) not in links[c]:
				links[c].append(Vector2i(row, next))
			row = next
			reached[Vector2i(c + 1, row)] = true
	var ids := {}
	for c in grid_columns:
		for r in rows:
			if reached.has(Vector2i(c, r)):
				var spot := MapRoom.new()
				spot.id = rooms.size()
				spot.column = c
				spot.row = r
				ids[Vector2i(c, r)] = spot.id
				rooms.append(spot)
	var final := MapRoom.new()
	final.id = rooms.size()
	final.column = grid_columns
	final.row = -1
	final.type = MapRoom.Type.FINALE
	rooms.append(final)
	for c in grid_columns - 1:
		for link: Vector2i in links[c]:
			rooms[ids[Vector2i(c, link.x)]].exits.append(ids[Vector2i(c + 1, link.y)])
	for last in in_column(grid_columns - 1):
		last.exits.append(final.id)
	for spot in rooms:
		spot.exits.sort()


## A step from row `a` to row `b` crosses an earlier one if they swap order.
static func _crosses(links: Array, a: int, b: int) -> bool:
	for link: Vector2i in links:
		if (a - link.x) * (b - link.y) < 0:
			return true
	return false


## The first column is all fights and the middle column of medium and long maps
## all rests; every other room is rolled from ROOM_WEIGHTS and re-rolled while it
## breaks a placement rule.
func _assign_types(rng: RandomNumberGenerator) -> void:
	var middle := _middle_column()
	var typed := {}
	for spot in rooms:
		if spot.type == MapRoom.Type.FINALE:
			typed[spot.id] = true
		elif spot.column == 0:
			spot.type = MapRoom.Type.FIGHT
			typed[spot.id] = true
		elif spot.column == middle:
			spot.type = MapRoom.Type.REST
			typed[spot.id] = true
	for spot in rooms:
		if typed.has(spot.id):
			continue
		spot.type = _roll_type(spot, typed, rng)
		typed[spot.id] = true


## The all-rest column of medium and long maps, or -1.
func _middle_column() -> int:
	return floori((columns - 1) / 2.0) if needs_elite() else -1


## Turns one open room into an elite where the placement rules allow it and a
## route around it remains, trying fight rooms first so the map keeps its
## events, rests and caches.
func _add_elite(rng: RandomNumberGenerator) -> void:
	var typed := {}
	for spot in rooms:
		typed[spot.id] = true
	var open := rooms.filter(func(r: MapRoom) -> bool:
		return r.column != 0 and r.column != _middle_column() and r.type != MapRoom.Type.FINALE)
	var fights := open.filter(func(r: MapRoom) -> bool: return r.type == MapRoom.Type.FIGHT)
	var others := open.filter(func(r: MapRoom) -> bool: return r.type != MapRoom.Type.FIGHT)
	for pool: Array in [fights, others]:
		while not pool.is_empty():
			var spot: MapRoom = pool.pop_at(rng.randi_range(0, pool.size() - 1))
			var before := spot.type
			if not _allowed(spot, MapRoom.Type.ELITE, typed):
				continue
			spot.type = MapRoom.Type.ELITE
			if _route_avoiding(MapRoom.Type.ELITE):
				return
			spot.type = before


## Whether some route from the first column reaches the final room without
## passing through a room of `type`.
func _route_avoiding(type: MapRoom.Type) -> bool:
	var reached := {}
	for start in in_column(0):
		if start.type != type:
			reached[start.id] = true
	for spot in rooms:
		if reached.has(spot.id):
			for exit in spot.exits:
				if rooms[exit].type != type:
					reached[exit] = true
	return reached.has(final_room().id)


func _roll_type(spot: MapRoom, typed: Dictionary, rng: RandomNumberGenerator) -> MapRoom.Type:
	var total := 0
	for weight: int in CampaignRules.ROOM_WEIGHTS:
		total += weight
	for attempt in 30:
		var roll := rng.randi_range(1, total)
		var type := 0
		while roll > CampaignRules.ROOM_WEIGHTS[type]:
			roll -= CampaignRules.ROOM_WEIGHTS[type]
			type += 1
		if _allowed(spot, type as MapRoom.Type, typed):
			return type as MapRoom.Type
	for type: MapRoom.Type in [MapRoom.Type.FIGHT, MapRoom.Type.EVENT, MapRoom.Type.CACHE]:
		if _allowed(spot, type, typed):
			return type
	return MapRoom.Type.FIGHT


func _allowed(spot: MapRoom, type: MapRoom.Type, typed: Dictionary) -> bool:
	var grid_columns := columns - 1
	var spaced := type == MapRoom.Type.ELITE or type == MapRoom.Type.REST
	if spaced and spot.column < ceili(grid_columns / 3.0):
		return false
	if type == MapRoom.Type.REST and spot.column == grid_columns - 1:
		return false
	for parent in parents(spot):
		if spaced and typed.has(parent.id) and parent.type == type:
			return false
		for sibling in parent.exits:
			if sibling != spot.id and typed.has(sibling) and rooms[sibling].type == type:
				return false
	for child in spot.exits:
		if spaced and typed.has(child) and rooms[child].type == type:
			return false
	return true


## Gives fights their enemy groups, events their scene (no repeats until every
## event has been used) and caches their loot.
func _fill(region: RegionDef, events: Array[EventDef], rng: RandomNumberGenerator) -> void:
	var unused: Array[EventDef] = []
	for spot in rooms:
		if spot.type == MapRoom.Type.EVENT and events.is_empty():
			spot.type = MapRoom.Type.FIGHT
		match spot.type:
			MapRoom.Type.FIGHT:
				spot.encounter = _pick(region.encounters, rng)
			MapRoom.Type.ELITE:
				spot.encounter = _pick(region.elites if not region.elites.is_empty() else region.finales, rng)
			MapRoom.Type.FINALE:
				spot.encounter = _pick(region.finales if not region.finales.is_empty() else region.encounters, rng)
			MapRoom.Type.EVENT:
				if unused.is_empty():
					unused.assign(events)
				spot.event = unused.pop_at(rng.randi_range(0, unused.size() - 1))
			MapRoom.Type.CACHE:
				if rng.randf() < 0.5:
					spot.cache_heirloom = CampaignRules.HEIRLOOMS[rng.randi_range(0, CampaignRules.HEIRLOOMS.size() - 1)]


static func _pick(pool: Array[EncounterDef], rng: RandomNumberGenerator) -> EncounterDef:
	return pool[rng.randi_range(0, pool.size() - 1)]


# --- Saving ---

func to_dict() -> Dictionary:
	return {columns = columns, rooms = rooms.map(func(r: MapRoom) -> Dictionary: return r.to_dict())}


static func from_dict(data: Dictionary) -> MissionMap:
	var map := MissionMap.new()
	map.columns = int(data.columns)
	for i in data.rooms.size():
		map.rooms.append(MapRoom.from_dict(i, data.rooms[i]))
	return map

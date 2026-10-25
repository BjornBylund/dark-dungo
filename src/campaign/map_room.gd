## One room on a mission map: what it holds and which rooms it leads to.
class_name MapRoom
extends RefCounted

enum Type { FIGHT, EVENT, REST, ELITE, CACHE, FINALE }

const TYPE_NAMES := ["Fight", "Event", "Rest", "Elite", "Cache", "Finale"]

var id: int
var column: int
## 0 to MAP_ROWS - 1; the final room has -1 and is drawn centred.
var row: int
var type := Type.FIGHT
## Ids of the rooms this one leads to, in the next column.
var exits: Array[int] = []
## The enemy group of a fight, elite or finale room.
var encounter: EncounterDef
var event: EventDef
## A cache's heirloom type, or empty when it holds gold.
var cache_heirloom: StringName


func is_fight() -> bool:
	return type == Type.FIGHT or type == Type.ELITE or type == Type.FINALE


func type_name() -> String:
	return TYPE_NAMES[type]


func to_dict() -> Dictionary:
	return {
		column = column, row = row, type = type, exits = exits, cache_heirloom = cache_heirloom,
		encounter = encounter.resource_path if encounter else "",
		event = event.resource_path if event else "",
	}


static func from_dict(index: int, data: Dictionary) -> MapRoom:
	var room := MapRoom.new()
	room.id = index
	room.column = int(data.column)
	room.row = int(data.row)
	room.type = int(data.type) as Type
	for exit in data.exits:
		room.exits.append(int(exit))
	room.cache_heirloom = StringName(data.cache_heirloom)
	if data.encounter != "":
		room.encounter = load(data.encounter)
	if data.event != "":
		room.event = load(data.event)
	return room

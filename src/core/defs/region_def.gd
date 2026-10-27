## A place on the expedition map with its own enemies and events, like DD1's
## Ruins or Weald.
class_name RegionDef
extends Resource

@export var id: StringName
@export var display_name: String
## Enemy groups for fight rooms and fights started by events.
@export var encounters: Array[EncounterDef] = []
## The miniboss groups for elite rooms.
@export var elites: Array[EncounterDef] = []
## Tougher groups for the final room of every mission map.
@export var finales: Array[EncounterDef] = []
## The region's boss and escorts, at the end of a boss mission: it opens after
## enough missions here, and the first win lets a new hero join.
@export var boss: EncounterDef
## Events only this region has; they join the campaign's shared events.
@export var events: Array[EventDef] = []
## Where the region's quest markers sit on the expedition map, in 1920x1080 stage pixels.
@export var map_position: Vector2

## A place on the expedition map with its own enemies, like DD1's Ruins or Weald.
class_name RegionDef
extends Resource

@export var id: StringName
@export var display_name: String
## Enemy groups for every fight but a medium or long mission's last.
@export var encounters: Array[EncounterDef] = []
## Tougher groups that end medium and long missions.
@export var finales: Array[EncounterDef] = []
## Where the region's quest markers sit on the expedition map, in 1920x1080 stage pixels.
@export var map_position: Vector2

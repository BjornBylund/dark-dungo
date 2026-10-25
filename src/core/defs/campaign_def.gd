## The campaign's content: the cast and the enemy groups missions draw from.
class_name CampaignDef
extends Resource

## Heroes in the roster at the start of a campaign.
@export var starting_heroes: Array[UnitDef] = []
## Heroes arriving at the Stagecoach, one per week from week 2, in this order.
@export var arrivals: Array[UnitDef] = []
## Enemy groups for every fight but a medium or long mission's last.
@export var encounters: Array[EncounterDef] = []
## Tougher groups that end medium and long missions.
@export var finales: Array[EncounterDef] = []
## Scene behind the fights.
@export var battle_background: Texture2D
## The hamlet panorama for the town screen.
@export var town_background: Texture2D

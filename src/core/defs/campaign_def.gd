## The campaign's content: the cast and the regions missions go to.
class_name CampaignDef
extends Resource

## Heroes in the roster at the start of a campaign.
@export var starting_heroes: Array[UnitDef] = []
## Heroes arriving at the Stagecoach, one per week from week 2, in this order.
@export var arrivals: Array[UnitDef] = []
## Places on the expedition map, each with its own enemy groups.
@export var regions: Array[RegionDef] = []
## Scene behind the fights.
@export var battle_background: Texture2D
## The hamlet panorama for the town screen.
@export var town_background: Texture2D
## The map of the surroundings for choosing a mission.
@export var expedition_background: Texture2D

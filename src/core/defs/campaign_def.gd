## The campaign's content: the cast and the regions missions go to.
class_name CampaignDef
extends Resource

## Heroes in the roster at the start of a campaign.
@export var starting_heroes: Array[UnitDef] = []
## Heroes who can join later: one, chosen by the player, for each region boss
## beaten for the first time.
@export var recruits: Array[UnitDef] = []
## Places on the expedition map, each with its own enemy groups.
@export var regions: Array[RegionDef] = []
## Events that can happen in any region.
@export var events: Array[EventDef] = []
## Every trinket that can drop in a dungeon or be sold at the Nomad Wagon.
@export var trinkets: Array[TrinketDef] = []
## Scene behind the fights.
@export var battle_background: Texture2D
## The hamlet panorama for the town screen.
@export var town_background: Texture2D
## The map of the surroundings for choosing a mission.
@export var expedition_background: Texture2D
## Behind every mission map.
@export var map_background: Texture2D

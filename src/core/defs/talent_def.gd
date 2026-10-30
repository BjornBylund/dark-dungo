## A talent: one of three on a row of a class's talent rows (UnitDef.talents).
## A hero gets a point at each of CampaignRules.TALENT_LEVELS and spends it on
## one talent of that row; it then works like a trinket that can't be taken
## off (see Perk), until the Guild clears the hero's talents.
class_name TalentDef
extends Perk

@export var id: StringName
@export var display_name: String
## A line of flavour shown under the name; the effects are spelled out from the parts.
@export_multiline var flavour: String

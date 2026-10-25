## A hero's lasting state in the campaign, between missions: progress, gear,
## skills, stress, and whether they can go on this week's mission.
class_name HeroRecord
extends RefCounted

var def: UnitDef
## Arrived at the Stagecoach; may not be hired yet.
var arrived := false
var recruited := false
var xp := 0
var stress := 0
var weapon_rank := 1
var armor_rank := 1
## Skill id -> rank 2-5. Skills not listed are rank 1.
var skill_ranks: Dictionary[StringName, int] = {}
## Sits out this week's mission after being defeated.
var wounded := false
## Abbey activity index while busy this week, or -1.
var abbey_activity := -1

var display_name: String:
	get:
		return def.display_name


func _init(unit_def: UnitDef) -> void:
	def = unit_def


func level() -> int:
	return CampaignRules.level_for_xp(xp)


func skill_rank(skill: SkillDef) -> int:
	return skill_ranks.get(skill.id, 1)


## Recruited, not wounded and not at the Abbey.
func is_available() -> bool:
	return recruited and not wounded and abbey_activity < 0


func to_dict() -> Dictionary:
	return {
		def = def.resource_path, arrived = arrived, recruited = recruited, xp = xp, stress = stress,
		weapon_rank = weapon_rank, armor_rank = armor_rank, skill_ranks = skill_ranks,
		wounded = wounded, abbey_activity = abbey_activity,
	}


static func from_dict(data: Dictionary) -> HeroRecord:
	var record := HeroRecord.new(load(data.def))
	record.arrived = data.arrived
	record.recruited = data.recruited
	record.xp = int(data.xp)
	record.stress = int(data.stress)
	record.weapon_rank = int(data.weapon_rank)
	record.armor_rank = int(data.armor_rank)
	for id: String in data.skill_ranks:
		record.skill_ranks[StringName(id)] = int(data.skill_ranks[id])
	record.wounded = data.wounded
	record.abbey_activity = int(data.abbey_activity)
	return record

## A hero's lasting state in the campaign, between missions: progress, gear,
## skills, stress, and whether they can go on this week's mission.
class_name HeroRecord
extends RefCounted

var def: UnitDef
## In the roster; heroes who aren't yet can join after a region boss falls.
var recruited := false
var xp := 0
var stress := 0
var weapon_rank := 1
var armor_rank := 1
## Skill id -> rank 2-5. Skills not listed are rank 1.
var skill_ranks: Dictionary[StringName, int] = {}
## Sits out this week's mission after being defeated.
var wounded := false
## The Abbey or Tavern activity (CampaignRules.ACTIVITIES) the hero spends this
## week on, or empty.
var activity := &""
## Weeks still away after a Tavern visit ran long; busy until it is 0.
var away_weeks := 0
## Tavern perks for the hero's next mission: "max_hp" (a fraction) and "speed".
var next_mission: Dictionary[StringName, float] = {}

var display_name: String:
	get:
		return def.display_name


func _init(unit_def: UnitDef) -> void:
	def = unit_def


func level() -> int:
	return CampaignRules.level_for_xp(xp)


func skill_rank(skill: SkillDef) -> int:
	return skill_ranks.get(skill.id, 1)


## Recruited, not wounded, and not busy in town.
func is_available() -> bool:
	return recruited and not wounded and not is_busy()


## Spending the week at the Abbey or Tavern, or still away from a Tavern visit.
func is_busy() -> bool:
	return activity != &"" or away_weeks > 0


func to_dict() -> Dictionary:
	return {
		def = def.resource_path, recruited = recruited, xp = xp, stress = stress,
		weapon_rank = weapon_rank, armor_rank = armor_rank, skill_ranks = skill_ranks,
		wounded = wounded, activity = activity, away_weeks = away_weeks, next_mission = next_mission,
	}


static func from_dict(data: Dictionary) -> HeroRecord:
	var record := HeroRecord.new(load(data.def))
	record.recruited = data.recruited
	record.xp = int(data.xp)
	record.stress = int(data.stress)
	record.weapon_rank = int(data.weapon_rank)
	record.armor_rank = int(data.armor_rank)
	for id: String in data.skill_ranks:
		record.skill_ranks[StringName(id)] = int(data.skill_ranks[id])
	record.wounded = data.wounded
	if data.has("abbey_activity"):
		# Saves from before the Tavern kept an Abbey activity index.
		var index := int(data.abbey_activity)
		record.activity = [&"meditation", &"prayer", &"flagellation"][index] if index >= 0 else &""
	else:
		record.activity = StringName(data.activity)
		record.away_weeks = int(data.away_weeks)
		for perk: String in data.next_mission:
			record.next_mission[StringName(perk)] = float(data.next_mission[perk])
	return record

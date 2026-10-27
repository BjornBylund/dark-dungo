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
## Skill ids the hero has learned, as in DD1: their class's first
## CampaignRules.SKILL_SLOTS to start with, the rest at the Guild.
var known: Array[StringName] = []
## The learned skills taken into fights, at most SKILL_SLOTS, in the order chosen.
var equipped: Array[StringName] = []
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
	_start_with_first_skills()


func level() -> int:
	return CampaignRules.level_for_xp(xp)


func skill_rank(skill: SkillDef) -> int:
	return skill_ranks.get(skill.id, 1)


func knows(skill: SkillDef) -> bool:
	return skill.id in known


func is_equipped(skill: SkillDef) -> bool:
	return skill.id in equipped


## The equipped skills, in the order chosen.
func equipped_skills() -> Array[SkillDef]:
	var result: Array[SkillDef] = []
	for id in equipped:
		for skill in def.skills:
			if skill.id == id:
				result.append(skill)
	return result


func _start_with_first_skills() -> void:
	known.clear()
	for skill in def.skills.slice(0, CampaignRules.SKILL_SLOTS):
		known.append(skill.id)
	equipped = known.duplicate()


## Recruited, not wounded, and not busy in town.
func is_available() -> bool:
	return recruited and not wounded and not is_busy()


## Spending the week at the Abbey or Tavern, or still away from a Tavern visit.
func is_busy() -> bool:
	return activity != &"" or away_weeks > 0


func to_dict() -> Dictionary:
	return {
		def = def.resource_path, recruited = recruited, xp = xp, stress = stress,
		weapon_rank = weapon_rank, armor_rank = armor_rank, skill_ranks = skill_ranks, known = known,
		equipped = equipped, wounded = wounded, activity = activity, away_weeks = away_weeks,
		next_mission = next_mission,
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
	# Only skills the class still has; saves from before loadouts keep the
	# starting four, plus any skill they had already trained.
	var skill_ids := record.def.skills.map(func(skill: SkillDef) -> StringName: return skill.id)
	for id: String in data.get("known", []):
		if StringName(id) in skill_ids and StringName(id) not in record.known:
			record.known.append(StringName(id))
	for id: StringName in record.skill_ranks:
		if id in skill_ids and id not in record.known:
			record.known.append(id)
	if data.has("equipped"):
		record.equipped.clear()
		for id: String in data.equipped:
			if StringName(id) in record.known:
				record.equipped.append(StringName(id))
	if record.equipped.is_empty():
		record.equipped = record.known.slice(0, CampaignRules.SKILL_SLOTS)
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

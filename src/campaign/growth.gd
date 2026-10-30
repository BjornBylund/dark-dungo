## Turns campaign state into battle-ready combatants: a hero's level, gear,
## trinkets, talents, skill ranks and Tavern perks, or an enemy's difficulty tier.
class_name Growth
extends RefCounted


static func hero_combatant(record: HeroRecord) -> Combatant:
	var unit := Combatant.new(record.def, true)
	var max_hp_share: float = record.next_mission.get(&"max_hp", 0.0)
	for trinket in record.trinkets:
		max_hp_share += _apply(unit, trinket, Combatant.BuffExpiry.TRINKET)
	for talent in record.chosen_talents():
		max_hp_share += _apply(unit, talent, Combatant.BuffExpiry.TALENT)
	unit.set_bonus_max_hp(armor_hp_bonus(record.def, record.armor_rank) + roundi(record.def.max_hp * max_hp_share))
	var weapon_steps := record.weapon_rank - 1
	unit.damage_bonus = CampaignRules.WEAPON_DAMAGE_PER_RANK * weapon_steps
	unit.crit_bonus = CampaignRules.WEAPON_CRIT_PER_RANK * weapon_steps
	unit.speed_bonus = weapon_speed_bonus(record.weapon_rank) + roundi(record.next_mission.get(&"speed", 0.0))
	unit.resist_bonus = CampaignRules.LEVEL_RESIST_BONUS * record.level()
	unit.skill_ranks = record.skill_ranks.duplicate()
	unit.skills = record.equipped_skills()
	unit.stress = record.stress
	return unit


static func enemy_combatant(def: UnitDef, tier: CampaignRules.Tier) -> Combatant:
	var unit := Combatant.new(def, false)
	unit.set_bonus_max_hp(roundi(def.max_hp * CampaignRules.ENEMY_HP_BONUS[tier]))
	unit.damage_bonus = CampaignRules.ENEMY_DAMAGE_BONUS[tier]
	unit.crit_bonus = CampaignRules.ENEMY_CRIT_BONUS[tier]
	return unit


## Puts a trinket's or talent's stats, bonuses and triggers on `unit`. Returns
## its max HP share, which the caller adds up.
static func _apply(unit: Combatant, perk: Perk, expiry: Combatant.BuffExpiry) -> float:
	var max_hp_share := 0.0
	for stat: StringName in perk.stats:
		if stat == &"max_hp":
			max_hp_share += perk.stats[stat]
		else:
			unit.add_buff(stat, perk.stats[stat], expiry)
	for bonus in perk.bonuses:
		unit.add_buff(bonus.stat, bonus.amount, expiry, 0, bonus.condition())
	unit.triggers.append_array(perk.triggers)
	unit.perks.append(perk)
	return max_hp_share


static func armor_hp_bonus(def: UnitDef, rank: int) -> int:
	return roundi(def.max_hp * CampaignRules.ARMOR_HP_PER_RANK * (rank - 1))


static func weapon_speed_bonus(rank: int) -> int:
	return CampaignRules.WEAPON_SPEED_RANKS.filter(func(at: int) -> bool: return rank >= at).size()

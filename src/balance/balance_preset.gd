## A power level the balance tool simulates at: the heroes' level, gear,
## skill ranks and trinkets, and the enemies' difficulty tier.
class_name BalancePreset
extends Resource

@export var name: String
@export_range(0, 6) var level: int = 0
## Weapon and armour rank.
@export_range(1, 5) var gear_rank: int = 1
## The rank of every skill.
@export_range(1, 5) var skill_rank: int = 1
## Each hero wears two random trinkets they may wear, drawn with the tier's drop odds.
@export var trinkets: bool = false
@export var tier: CampaignRules.Tier = CampaignRules.Tier.APPRENTICE

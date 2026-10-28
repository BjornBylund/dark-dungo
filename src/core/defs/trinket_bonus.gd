## A trinket stat that only counts while its condition holds, like DD2's
## "If Stealth: +20% DMG" or "If Target has Bleed: +25% DMG".
class_name TrinketBonus
extends Resource

@export var stat: StringName
@export var amount: float = 0.0
## While the wearer holds this token (or DoT: bleed, blight, burn), or with
## `lacks`, doesn't.
@export var if_token: StringName
@export var lacks: bool = false
## Against a target holding this token or DoT (damage and crit only).
@export var if_target: StringName
## While the wearer is below this share of max HP (0 for any).
@export var if_hp_below: float = 0.0
## Only with these skills (empty for any).
@export var if_skills: Array[StringName] = []


## The buff entry Combatant.buffs keeps for it.
func condition() -> Dictionary:
	return {token = if_token, lacks = lacks, target = if_target, hp_below = if_hp_below, skills = if_skills}

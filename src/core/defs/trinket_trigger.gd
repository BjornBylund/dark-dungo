## A trinket line that fires on a combat event, like DD2's "Apply on Hit: Weak
## (15%)", "Gain When Hit: Block+ (33%)" or "Turn Start: If First in Turn
## Order: Blind". The effects keep their own chances.
class_name TrinketTrigger
extends Resource

enum When {
	COMBAT_START,
	ROUND_START,
	ROUND_END,
	TURN_START,
	TURN_END,
	ON_HIT,              ## The wearer's attack hits.
	ON_MISS,             ## The wearer's attack misses.
	ON_CRIT,             ## The wearer's attack or heal crits.
	WHEN_HIT,            ## An enemy's attack hits the wearer.
	WHEN_MISSED,         ## An enemy's attack misses the wearer.
	DEATHS_DOOR_ENTER,
	DEATHS_DOOR_LEAVE,
	WHEN_MOVED,          ## The wearer changes rank, by any means.
	WHEN_MOVED_BY_ENEMY,
	ON_RESIST,           ## The wearer resists `if_resist`.
	ON_SKILL,            ## The wearer uses one of `if_skills` (any with none listed).
}
## Who gets the effects.
enum To {
	SELF,
	OTHER,          ## The other unit of the event: who was hit or missed, the attacker, the skill's target.
	EACH_ALLY,      ## Every hero on the wearer's side, the wearer too.
	ALLIES_BEHIND,  ## Every ally in a rank behind the wearer.
	ALLY_BEHIND,    ## The ally just behind the wearer.
	RANDOM_ALLY,    ## One other ally at random.
}

@export var when: When = When.TURN_START
@export var to: To = To.SELF
@export var effects: Array[EffectDef] = []
## "X or Y": stops after the first effect that lands.
@export var pick_one: bool = false
## A drawback line, shown in red.
@export var malus: bool = false

@export_group("Conditions")
## Only in this rank (0 for any).
@export var if_rank: int = 0
## Only while the wearer holds this token (or DoT), or with `lacks`, doesn't.
@export var if_token: StringName
@export var lacks: bool = false
## Only while the wearer acts first in the round's turn order.
@export var if_first: bool = false
## Only at or below / at or above this speed (0 for any).
@export var if_speed_at_most: int = 0
@export var if_speed_at_least: int = 0
## ON_SKILL and the hit triggers: only with these skills (empty for any).
@export var if_skills: Array[StringName] = []
## ON_SKILL: only when the skill's target is another hero.
@export var if_ally_target: bool = false
## ON_RESIST: which resistance (stun, bleed, blight, burn, move, debuff).
@export var if_resist: StringName

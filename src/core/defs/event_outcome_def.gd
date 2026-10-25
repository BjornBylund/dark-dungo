## One effect of an event choice.
class_name EventOutcomeDef
extends Resource

enum Kind {
	HP,         ## `amount` is a fraction of max HP: 0.2 heals 20%, -0.1 costs 10%. Never kills.
	STRESS,     ## `amount` stress, negative relieves.
	GOLD,       ## `amount` fight shares of the mission's gold; losses come out of what was earned on the way.
	HEIRLOOMS,  ## `amount` at Apprentice, x1.5 Veteran, x2 Champion; `heirloom` empty means the mission's.
	TOKEN,      ## `stacks` of `token`, carried into the next fight.
	FIGHT,      ## One of the region's enemy groups, paid like a fight room.
	ELITE,      ## The region's elite group, paid like an elite room.
}
## Who HP, stress and token outcomes affect.
enum Target { PARTY, RANDOM_HERO, CHOSEN_HERO }

@export var kind := Kind.HP
@export var target := Target.PARTY
@export var amount: float = 0.0
@export var heirloom: StringName
@export var token: StringName
@export var stacks: int = 1

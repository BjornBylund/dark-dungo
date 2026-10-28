## One thing a skill does to a unit besides damage, healing and stress.
class_name EffectDef
extends Resource

enum Kind {
	TOKEN,             ## Give `stacks` of `token` (or one random token from `token_pool`).
	DOT,               ## Bleed, blight or burn: `amount` damage per turn for `duration` turns.
	MOVE,              ## Push the target: positive `amount` moves it forward, negative back.
	CLEANSE_DOTS,      ## Remove all bleed, blight and burn.
	CLEANSE_NEGATIVE,  ## Remove all negative tokens.
	GUARD,             ## The user guards the target for `stacks` attacks.
	REMOVE_TOKENS,     ## Remove every stack of the tokens in `token_pool`.
	BUFF,              ## Change `stat` by `amount` for `duration` rounds (see Combatant.buffs).
	REGEN,             ## Heal `amount` at the start of each of the target's turns, for `duration` turns.
	SHUFFLE,           ## Move the target to a random other rank.
	EXTRA_TURN,        ## The target acts again straight after this turn.
	STEAL_DOTS,        ## The user takes over the target's bleed, blight and burn.
	CLEANSE_POSITIVE,  ## Remove all positive tokens.
	STRESS,            ## Change the target's stress by `amount`, if it is at least `min_stress`.
	CONSECRATE,        ## Bless the target's rank for `duration` rounds: whoever stands there gains one of `token_pool` each turn.
	HEAL,              ## Heal `amount` HP plus `stat_amount` of max HP.
	DAMAGE,            ## Deal `amount` damage, ignoring tokens.
	CONVERT,           ## Turn every `token` stack into `token_to`.
	REMOVE_ONE,        ## Remove one stack of a random token from `token_pool` that the target holds.
	STEAL_ONE,         ## Move one stack of a random token from `token_pool` from the target to the user.
}

@export var kind: Kind = Kind.TOKEN
@export var token: StringName
## For CONVERT: what `token` becomes.
@export var token_to: StringName
## When not empty, one token from this pool is picked at random instead of `token`.
## REMOVE_TOKENS removes all of them; CONSECRATE gives one of them each turn.
@export var token_pool: Array[StringName] = []
@export var stacks: int = 1
## &"bleed", &"blight" or &"burn" for DOT effects.
@export var dot: StringName
@export var amount: int = 0
@export var duration: int = Rules.DOT_DURATION
## DOT duration on a crit instead of `duration`, or 0 for the same.
@export var crit_duration: int = 0
## For BUFF: the stat changed, and by how much (fractions for resistances, damage and healing).
@export var stat: StringName
@export var stat_amount: float = 0.0
## For STRESS: only if the target already has at least this much stress.
@export var min_stress: int = 0
## Chance the effect is attempted at all; the target's resistance is rolled separately.
@export_range(0.0, 1.0) var chance: float = 1.0
@export var ignore_resist: bool = false

@export_group("Conditions")
## Only if the skill crit.
@export var on_crit_only: bool = false
## Only if the target held this token when the skill reached it (before the skill ends it).
@export var requires_target_token: StringName
## Only if the user holds this token, or with `user_lacks`, doesn't.
@export var requires_user_token: StringName
@export var user_lacks: bool = false
## Only at or above this count of the skill's tier tokens (the Vestal's Conviction).
@export var min_tier: int = 0


static func make_token(token_id: StringName, stack_count: int = 1) -> EffectDef:
	var effect := EffectDef.new()
	effect.kind = Kind.TOKEN
	effect.token = token_id
	effect.stacks = stack_count
	return effect


static func make_dot(dot_type: StringName, per_turn: int, turns: int = Rules.DOT_DURATION) -> EffectDef:
	var effect := EffectDef.new()
	effect.kind = Kind.DOT
	effect.dot = dot_type
	effect.amount = per_turn
	effect.duration = turns
	return effect


static func make_move(distance: int) -> EffectDef:
	var effect := EffectDef.new()
	effect.kind = Kind.MOVE
	effect.amount = distance
	return effect


static func make_buff(stat_name: StringName, change: float, rounds: int = Rules.DOT_DURATION) -> EffectDef:
	var effect := EffectDef.new()
	effect.kind = Kind.BUFF
	effect.stat = stat_name
	effect.stat_amount = change
	effect.duration = rounds
	return effect


static func make_removal(tokens: Array[StringName]) -> EffectDef:
	var effect := EffectDef.new()
	effect.kind = Kind.REMOVE_TOKENS
	effect.token_pool = tokens
	return effect


static func make(effect_kind: Kind) -> EffectDef:
	var effect := EffectDef.new()
	effect.kind = effect_kind
	return effect

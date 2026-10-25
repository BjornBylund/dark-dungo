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
}

@export var kind: Kind = Kind.TOKEN
@export var token: StringName
## When not empty, one token from this pool is picked at random instead of `token`.
@export var token_pool: Array[StringName] = []
@export var stacks: int = 1
## &"bleed", &"blight" or &"burn" for DOT effects.
@export var dot: StringName
@export var amount: int = 0
@export var duration: int = Rules.DOT_DURATION
## Chance the effect is attempted at all; the target's resistance is rolled separately.
@export_range(0.0, 1.0) var chance: float = 1.0
@export var ignore_resist: bool = false


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


static func make(effect_kind: Kind) -> EffectDef:
	var effect := EffectDef.new()
	effect.kind = effect_kind
	return effect

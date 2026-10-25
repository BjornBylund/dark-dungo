## Token ids and their DD2 rules: stack limit, how they expire, which tokens
## cancel each other, and which resistance applies when an enemy inflicts them.
class_name Tokens
extends RefCounted

enum Expiry {
	TURNS,          ## One shared timer per token type, counted down at the holder's turn end.
	SINGLE_REMOVE,  ## One stack falls off at each of the holder's turn ends.
	CONSUMED,       ## Stays until something uses it up.
	ROUND_END,      ## Removed at the end of the round.
}

const CRIT := &"crit"
const DODGE := &"dodge"
const DODGE_PLUS := &"dodge_plus"
const BLOCK := &"block"
const BLOCK_PLUS := &"block_plus"
const STRENGTH := &"strength"
const RIPOSTE := &"riposte"
const GUARD := &"guard"
const SPEED := &"speed"
const STEALTH := &"stealth"
const STUN := &"stun"
const DAZE := &"daze"
const BLIND := &"blind"
const WEAK := &"weak"
const VULNERABLE := &"vulnerable"
const TAUNT := &"taunt"
const IMMOBILIZE := &"immobilize"
const COMBO := &"combo"

const RULES := {
	CRIT: {"limit": 2, "expiry": Expiry.TURNS, "negative": false},
	DODGE: {"limit": 3, "expiry": Expiry.TURNS, "negative": false},
	DODGE_PLUS: {"limit": 3, "expiry": Expiry.TURNS, "negative": false},
	BLOCK: {"limit": 3, "expiry": Expiry.TURNS, "negative": false, "negates": [VULNERABLE]},
	BLOCK_PLUS: {"limit": 3, "expiry": Expiry.TURNS, "negative": false, "negates": [VULNERABLE]},
	STRENGTH: {"limit": 2, "expiry": Expiry.TURNS, "negative": false, "negates": [WEAK]},
	RIPOSTE: {"limit": 3, "expiry": Expiry.TURNS, "negative": false},
	GUARD: {"limit": 3, "expiry": Expiry.TURNS, "negative": false},
	SPEED: {"limit": 1, "expiry": Expiry.ROUND_END, "negative": false, "negates": [DAZE]},
	STEALTH: {"limit": 2, "expiry": Expiry.SINGLE_REMOVE, "negative": false},
	STUN: {"limit": 1, "expiry": Expiry.CONSUMED, "negative": true, "resist": &"stun"},
	DAZE: {"limit": 1, "expiry": Expiry.CONSUMED, "negative": true, "resist": &"stun", "negates": [SPEED]},
	BLIND: {"limit": 2, "expiry": Expiry.TURNS, "negative": true, "resist": &"debuff"},
	WEAK: {"limit": 2, "expiry": Expiry.TURNS, "negative": true, "resist": &"debuff", "negates": [STRENGTH]},
	VULNERABLE: {"limit": 2, "expiry": Expiry.TURNS, "negative": true, "resist": &"debuff", "negates": [BLOCK_PLUS, BLOCK]},
	TAUNT: {"limit": 3, "expiry": Expiry.TURNS, "negative": true, "resist": &"debuff"},
	IMMOBILIZE: {"limit": 3, "expiry": Expiry.SINGLE_REMOVE, "negative": true, "resist": &"debuff"},
	COMBO: {"limit": 1, "expiry": Expiry.TURNS, "negative": false},
}


static func limit(token: StringName) -> int:
	return RULES[token]["limit"]


static func expiry(token: StringName) -> Expiry:
	return RULES[token]["expiry"]


static func is_negative(token: StringName) -> bool:
	return RULES[token]["negative"]


## Resistance that an enemy-inflicted stack rolls against, or &"" when it cannot be resisted.
static func resist_of(token: StringName) -> StringName:
	return RULES[token].get("resist", &"")


## Tokens that cancel against this one, in the order they are removed.
static func negates(token: StringName) -> Array:
	return RULES[token].get("negates", [])

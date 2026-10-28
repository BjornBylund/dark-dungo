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
# Class tokens. They last the whole fight unless something spends them.
## The Vestal's: +1 each turn; her skills grow stronger with it and spend it.
const CONVICTION := &"conviction"
## The Flagellant's, from Toxic at max stress: attackers who hit him are Blighted.
const TOXIC := &"toxic"
## The Flagellant's, from More! MORE!: each heals him at his turn end, then all go.
const PAIN := &"pain"

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
	CONVICTION: {"limit": 3, "expiry": Expiry.CONSUMED, "negative": false},
	TOXIC: {"limit": 3, "expiry": Expiry.CONSUMED, "negative": false},
	PAIN: {"limit": 3, "expiry": Expiry.CONSUMED, "negative": false},
}


## DD2's "Add 1 Positive Token" and "Add 1 Negative Token" draw from these.
const RANDOM_POSITIVE: Array[StringName] = [CRIT, DODGE, STRENGTH, BLOCK, SPEED]
const RANDOM_NEGATIVE: Array[StringName] = [BLIND, WEAK, TAUNT, VULNERABLE, IMMOBILIZE]
## What "a positive token" and "a negative token" mean to effects that remove
## or steal one (class tokens and Combo aside).
const POSITIVE: Array[StringName] = [CRIT, DODGE, DODGE_PLUS, BLOCK, BLOCK_PLUS, STRENGTH, RIPOSTE, SPEED, STEALTH]
const NEGATIVE: Array[StringName] = [STUN, DAZE, BLIND, WEAK, VULNERABLE, TAUNT, IMMOBILIZE]


static func limit(token: StringName) -> int:
	return RULES[token]["limit"]


static func expiry(token: StringName) -> Expiry:
	return RULES[token]["expiry"]


const NAMES := {
	CRIT: "Crit", DODGE: "Dodge", DODGE_PLUS: "Dodge+", BLOCK: "Block", BLOCK_PLUS: "Block+",
	STRENGTH: "Strength", RIPOSTE: "Riposte", GUARD: "Guard", SPEED: "Speed", STEALTH: "Stealth", STUN: "Stun",
	DAZE: "Daze", BLIND: "Blind", WEAK: "Weak", VULNERABLE: "Vulnerable", TAUNT: "Taunt",
	IMMOBILIZE: "Immobilize", COMBO: "Combo", CONVICTION: "Conviction", TOXIC: "Toxic", PAIN: "Pain",
}


static func display_name(token: StringName) -> String:
	return NAMES.get(token, String(token).capitalize())


static func is_negative(token: StringName) -> bool:
	return RULES[token]["negative"]


## Resistance that an enemy-inflicted stack rolls against, or &"" when it cannot be resisted.
static func resist_of(token: StringName) -> StringName:
	return RULES[token].get("resist", &"")


## Tokens that cancel against this one, in the order they are removed.
static func negates(token: StringName) -> Array:
	return RULES[token].get("negates", [])

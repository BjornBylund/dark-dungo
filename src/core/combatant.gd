## Runtime state of one unit in combat. Heroes keep their Combatant across
## waves, so HP, stress and long-lasting buffs carry over; enemies get a fresh one.
class_name Combatant
extends RefCounted

enum BuffExpiry {
	TURN_START,    ## Removed at the holder's next turn start (stun recovery).
	ROUNDS,        ## Lasts `rounds` round ends, then removed.
	COMBAT,        ## Removed when the battle ends.
	RUN,           ## Kept until the run restarts ("until next Inn" in DD2).
	DEATHS_DOOR,   ## Removed when the unit leaves Death's Door.
	BOND,          ## From the hero's bonds with the party; the campaign sets them between fights.
	TRINKET,       ## From the hero's trinkets, for as long as they're worn.
	TALENT,        ## From the hero's talents.
}

static var _next_uid := 1

var uid: int
var def: UnitDef
var is_hero: bool
## The skills this unit fights with: its def's, or for a hero the ones equipped.
var skills: Array[SkillDef] = []
var hp: int
var stress := 0
## Token id -> stacks.
var tokens: Dictionary[StringName, int] = {}
## Token id -> holder turns left. One shared timer per token type, started by
## the first stack and not refreshed by later ones.
var token_turns: Dictionary[StringName, int] = {}
## Bleed, blight and burn instances: {type: StringName, amount: int, turns: int}.
var dots: Array[Dictionary] = []
## Regen, healing over time: {amount: int, turns: int}, ticking with the DoTs.
var regens: Array[Dictionary] = []
## Stat modifiers: {stat: StringName, amount: float, expiry: BuffExpiry, rounds: int}.
## Stats are "speed", "resist_<kind>", "crit" and "damage" (added to the
## attacker's chance and modifier), "resolute" (added to the chance of
## Resolute instead of Meltdown), "heal_received" (more or less from healing
## skills) and "heal_power" (the unit's healing skills heal more or less).
var buffs: Array[Dictionary] = []
## Trinket and talent lines that fire on combat events; the battle runs them.
var triggers: Array[TrinketTrigger] = []
## The trinkets and talents a hero brought, for showing; their stats and
## triggers are already in buffs and triggers.
var perks: Array[Perk] = []
## Skill id -> turns until usable again.
var cooldowns: Dictionary[StringName, int] = {}
## Skill id -> uses this battle.
var uses: Dictionary[StringName, int] = {}
var deaths_door := false
var dead := false
var is_corpse := false
var corpse_rounds := 0
var death_armor := 0
## The unit that takes attacks aimed at this one while it has Guard tokens.
var guarded_by: Combatant
var speed_bonus_next_round := false

# Lasting modifiers from outside the battle: hero gear, levels and skill ranks,
# or an enemy's difficulty tier. They are set when the combatant is created.
var bonus_max_hp := 0
## Attacker-side damage bonus, added to the other attack modifiers (0.1 = +10%).
var damage_bonus := 0.0
var crit_bonus := 0.0
var speed_bonus := 0
## Added to the stun, bleed, blight, burn, move and debuff resistances.
var resist_bonus := 0.0
## Skill id -> rank 1-5; a missing skill is rank 1.
var skill_ranks: Dictionary[StringName, int] = {}

var display_name: String:
	get:
		return def.display_name

var max_hp: int:
	get:
		return def.max_hp + bonus_max_hp

var size: int:
	get:
		return def.size


func _init(unit_def: UnitDef, hero: bool) -> void:
	uid = _next_uid
	_next_uid += 1
	def = unit_def
	is_hero = hero
	skills.assign(unit_def.skills.slice(0, Rules.SKILL_SLOTS) if hero else unit_def.skills)
	hp = unit_def.max_hp
	death_armor = unit_def.death_armor


## Alive and standing: not dead and not a corpse.
func is_active() -> bool:
	return not dead


func hp_fraction() -> float:
	return float(hp) / float(max_hp)


## The stat's total. A buff with a condition ("if", see TrinketBonus) counts
## only while it holds: target and skill conditions need the target or skill.
func stat(name: StringName, target: Combatant = null, skill: SkillDef = null) -> float:
	var total := 0.0
	for buff in buffs:
		if buff.stat == name and (not buff.has("if") or _holds(buff.if, target, skill)):
			total += buff.amount
	return total


func _holds(condition: Dictionary, target: Combatant, skill: SkillDef) -> bool:
	if condition.token != &"" and has_status(condition.token) == condition.lacks:
		return false
	if condition.target != &"" and (target == null or not target.has_status(condition.target)):
		return false
	if condition.hp_below > 0.0 and hp_fraction() >= condition.hp_below:
		return false
	return condition.skills.is_empty() or (skill != null and skill.id in condition.skills)


## Holds the token, or the DoT when `name` is bleed, blight or burn.
func has_status(name: StringName) -> bool:
	return dot_total(name) > 0 if name in [&"bleed", &"blight", &"burn"] else has_token(name)


## Raises max HP and fills HP to match. Meant for setting up a new combatant.
func set_bonus_max_hp(bonus: int) -> void:
	bonus_max_hp = bonus
	hp = max_hp


func speed() -> int:
	return def.speed + roundi(stat(&"speed")) + speed_bonus


func resist(kind: StringName) -> float:
	var bonus := resist_bonus if kind in Rules.LEVELED_RESISTS else 0.0
	return def.base_resist(kind) + stat(StringName("resist_%s" % kind)) + bonus


func skill_rank(skill: SkillDef) -> int:
	return skill_ranks.get(skill.id, 1)


func add_buff(name: StringName, amount: float, expiry: BuffExpiry, rounds: int = 0, condition: Dictionary = {}) -> void:
	var buff := {stat = name, amount = amount, expiry = expiry, rounds = rounds}
	if not condition.is_empty():
		buff["if"] = condition
	buffs.append(buff)


func remove_buffs(expiry: BuffExpiry) -> void:
	buffs.assign(buffs.filter(func(buff: Dictionary) -> bool: return buff.expiry != expiry))


## Counts down round-based buffs at round end.
func tick_round_buffs() -> void:
	for buff in buffs:
		if buff.expiry == BuffExpiry.ROUNDS:
			buff.rounds -= 1
	buffs.assign(buffs.filter(func(buff: Dictionary) -> bool:
		return buff.expiry != BuffExpiry.ROUNDS or buff.rounds > 0))


# --- Healing and stress ---

## Raises HP, at most to max HP. Any healing lifts the unit off Death's Door and
## its penalties. Returns whether it did.
func heal(amount: int) -> bool:
	var left_deaths_door := deaths_door and amount > 0
	if left_deaths_door:
		deaths_door = false
		remove_buffs(BuffExpiry.DEATHS_DOOR)
	hp = mini(max_hp, hp + amount)
	return left_deaths_door


## At max stress, one of DD2's one-off events: a Meltdown (MELTDOWN_CHANCE, less
## the "resolute" stat) cuts HP and leaves the hero easier to kill; a Resolute
## heals and steadies them. Both reset stress. A unit whose class has its own
## overstress (the Flagellant's Toxic) always gets that. Returns &"meltdown",
## &"resolute" or &"toxic".
func overstress(rng: RandomNumberGenerator) -> StringName:
	if def.overstress == &"toxic":
		stress = Rules.TOXIC_STRESS
		var target_hp := roundi(max_hp * Rules.TOXIC_HP_FRACTION)
		if hp < target_hp:
			heal(target_hp - hp)
		elif hp > 0:
			hp = target_hp
		cooldowns.clear()
		add_token(Tokens.TOXIC)
		add_buff(&"resist_deathblow", Rules.TOXIC_DEATHBLOW, BuffExpiry.RUN)
		return &"toxic"
	if rng.randf() < Rules.MELTDOWN_CHANCE - stat(&"resolute"):
		stress = Rules.MELTDOWN_STRESS
		if hp > 0:
			hp = mini(hp, maxi(1, roundi(max_hp * Rules.MELTDOWN_HP_FRACTION)))
		add_buff(&"resist_deathblow", Rules.MELTDOWN_DEATHBLOW, BuffExpiry.RUN)
		add_buff(&"resist_stress", Rules.OVERSTRESS_STRESS_RESIST, BuffExpiry.ROUNDS, Rules.OVERSTRESS_BUFF_ROUNDS)
		return &"meltdown"
	stress = 0
	add_buff(&"resist_deathblow", Rules.RESOLUTE_DEATHBLOW, BuffExpiry.RUN)
	add_buff(&"resist_debuff", Rules.RESOLUTE_DEBUFF_RESIST, BuffExpiry.ROUNDS, Rules.OVERSTRESS_BUFF_ROUNDS)
	add_buff(&"resist_stress", Rules.OVERSTRESS_STRESS_RESIST, BuffExpiry.ROUNDS, Rules.OVERSTRESS_BUFF_ROUNDS)
	heal(roundi(max_hp * Rules.RESOLUTE_HEAL_FRACTION))
	return &"resolute"


# --- Tokens ---

func has_token(token: StringName) -> bool:
	return tokens.get(token, 0) > 0


func token_count(token: StringName) -> int:
	return tokens.get(token, 0)


## Adds up to `stacks` tokens. Each stack first cancels one opposing token
## (Block vs Vulnerable, Strength vs Weak, Speed vs Daze) instead of being added,
## and stacks beyond the limit are dropped.
## Returns {added: int, negated: Array[StringName]}.
func add_token(token: StringName, stacks: int = 1) -> Dictionary:
	var added := 0
	var negated: Array[StringName] = []
	if stat(StringName("blocks_%s" % token)) > 0.0:
		return {added = added, negated = negated}
	for i in stacks:
		var opposite := _present_opposite(token)
		if opposite != &"":
			remove_token(opposite)
			negated.append(opposite)
			continue
		if token_count(token) >= Tokens.limit(token):
			break
		if not has_token(token):
			token_turns[token] = Rules.TOKEN_DURATION
		tokens[token] = token_count(token) + 1
		added += 1
	return {added = added, negated = negated}


func remove_token(token: StringName, stacks: int = 1) -> void:
	var left := token_count(token) - stacks
	if left > 0:
		tokens[token] = left
		return
	tokens.erase(token)
	token_turns.erase(token)
	if token == Tokens.GUARD:
		guarded_by = null


## Removes one stack if present. Returns whether there was one.
func consume_token(token: StringName) -> bool:
	if not has_token(token):
		return false
	remove_token(token)
	return true


func clear_tokens() -> void:
	tokens.clear()
	token_turns.clear()
	guarded_by = null


## Turn-end token upkeep. Returns the token ids that ran out completely.
func tick_tokens_turn_end() -> Array[StringName]:
	var expired: Array[StringName] = []
	for token in tokens.keys():
		match Tokens.expiry(token):
			Tokens.Expiry.TURNS:
				token_turns[token] -= 1
				if token_turns[token] <= 0:
					remove_token(token, token_count(token))
					expired.append(token)
			Tokens.Expiry.SINGLE_REMOVE:
				remove_token(token)
				if not has_token(token):
					expired.append(token)
	return expired


func _present_opposite(token: StringName) -> StringName:
	for opposite: StringName in Tokens.negates(token):
		if has_token(opposite):
			return opposite
	return &""


# --- Damage over time ---

func dot_total(type: StringName = &"") -> int:
	var total := 0
	for dot in dots:
		if type == &"" or dot.type == type:
			total += dot.amount
	return total


## Counts every instance down by one turn and drops the finished ones.
func tick_dots() -> void:
	for dot in dots:
		dot.turns -= 1
	dots.assign(dots.filter(func(dot: Dictionary) -> bool: return dot.turns > 0))


# --- Skills ---

func cooldown_left(skill: SkillDef) -> int:
	return cooldowns.get(skill.id, 0)


func uses_left(skill: SkillDef) -> int:
	if skill.uses_per_battle <= 0:
		return 1 << 30
	return skill.uses_per_battle - uses.get(skill.id, 0)


## Turn-end cooldown upkeep. The skill used this turn keeps its full cooldown.
func tick_cooldowns(used_this_turn: StringName) -> void:
	for id in cooldowns.keys():
		if id == used_this_turn:
			continue
		cooldowns[id] -= 1
		if cooldowns[id] <= 0:
			cooldowns.erase(id)


## Clears everything that only lasts one battle. Long-lasting buffs, HP and stress stay.
func clear_battle_state() -> void:
	clear_tokens()
	dots.clear()
	regens.clear()
	cooldowns.clear()
	uses.clear()
	speed_bonus_next_round = false
	buffs.assign(buffs.filter(func(buff: Dictionary) -> bool:
		return buff.expiry in [BuffExpiry.RUN, BuffExpiry.DEATHS_DOOR, BuffExpiry.BOND, BuffExpiry.TRINKET,
				BuffExpiry.TALENT]))

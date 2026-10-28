## Darkest Dungeon 2 combat constants, copied from the game where known.
## Sources and confidence for every number: docs/research/darkest-dungeon-combat.md.
## Choices made where DD2 is unknown are listed in docs/design.md.
class_name Rules
extends RefCounted

const RANKS := 4

# Initiative: round speed = SPD + randi(0..6), re-rolled every round.
const ROUND_SPEED_ROLL_MAX := 6
const EXTRA_TURN_SPEED_PENALTY := 2
const SPEED_TOKEN_BONUS := 100

# Hit and damage.
const BLIND_MISS_CHANCE := 0.5
const DODGE_CHANCE := 0.5
const DODGE_PLUS_CHANCE := 0.75
const STRENGTH_BONUS := 0.5
const WEAK_MULTIPLIER := 0.5
const BLOCK_REDUCTION := 0.5
const BLOCK_PLUS_REDUCTION := 0.75
const VULNERABLE_BONUS := 0.5
const CRIT_DAMAGE_MULTIPLIER := 1.5
const CRIT_RESIST_PIERCE := 0.2
const HEAL_CRIT_CHANCE := 0.05
const HEAL_CRIT_MULTIPLIER := 1.5

# Statuses.
const DOT_DURATION := 3
const TOKEN_DURATION := 3
const STUN_RECOVERY_RESIST := 0.5

# Death's Door.
const DEATHBLOW_MIN := 0.33
const DEATHBLOW_MAX := 0.9
const DEATHBLOW_SURVIVE_PENALTY := -0.1
const DEATHS_DOOR_SPEED := -3
const DEATHS_DOOR_WEAK := 1
const CORPSE_ROUNDS := 3

# Stress (0..10) and what happens at 10.
const STRESS_MAX := 10
const MELTDOWN_CHANCE := 0.8
const MELTDOWN_HP_FRACTION := 0.1
const MELTDOWN_STRESS := 1
const MELTDOWN_DEATHBLOW := -0.15
const RESOLUTE_HEAL_FRACTION := 0.67
const RESOLUTE_DEATHBLOW := 0.15
const RESOLUTE_DEBUFF_RESIST := 0.5
const OVERSTRESS_STRESS_RESIST := 0.4
const OVERSTRESS_BUFF_ROUNDS := 3
# The Flagellant's Toxic instead: stress drops to 1, HP is set to 30%, his
# cooldowns reset and he gains a Toxic token. Each Toxic token Blights anyone
# who hits him by 2 more per turn.
const TOXIC_STRESS := 1
const TOXIC_HP_FRACTION := 0.3
const TOXIC_DEATHBLOW := -0.1
const TOXIC_BLIGHT_PER_TOKEN := 2
## The Flagellant heals this share of max HP per Pain token at his turn end.
const PAIN_HEAL := 0.1

# Stress triggers: amount and chance.
const STRESS_CRIT_RECEIVED := 1
const STRESS_CRIT_RECEIVED_CHANCE := 0.8
const STRESS_ALLY_CRIT_RECEIVED_CHANCE := 0.15
const STRESS_CRIT_LANDED := -1
const STRESS_CRIT_LANDED_CHANCE := 0.5
const STRESS_ALLY_CRIT_LANDED_CHANCE := 0.05
const STRESS_DEATHS_DOOR := 1
const STRESS_DEATHS_DOOR_CHANCE := 0.5
const STRESS_ALLY_DEATHS_DOOR_CHANCE := 0.25
const STRESS_ALLY_DIED := 1

# Basic actions.
const PASS_STRESS := 2
const RECOVER_HP_THRESHOLD := 0.25
const RECOVER_HEAL_FRACTION := 0.2
const RECOVER_STRESS := 2
const RECOVER_COOLDOWN := 3

# After a won battle heroes are healed up to at least this fraction of max HP.
const BATTLE_END_MIN_HP := 0.2

## Skills a hero takes into a fight, as in DD2. Without a chosen loadout, the first ones.
const SKILL_SLOTS := 5

# Skill ranks 2-5 (Guild upgrades): each rank above 1 adds these.
const SKILL_RANK_POWER := 0.1   # damage or healing
const SKILL_RANK_CRIT := 0.01
const SKILL_RANK_PIERCE := 0.1  # resistance pierce on the skill's effects

## Resistances raised by hero levels (DD1: not deathblow or stress).
const LEVELED_RESISTS: Array[StringName] = [&"stun", &"bleed", &"blight", &"burn", &"move", &"debuff"]

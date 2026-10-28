## A combat skill. Heroes and enemies share this schema, as in DD2.
class_name SkillDef
extends Resource

enum Kind { ACTION, SWAP, PASS }
enum TargetSide { ENEMY, ALLY, SELF }
enum Condition {
	NONE,
	SELF_HP_BELOW,      ## User's HP fraction is below `condition_value`.
	SELF_LACKS_TOKEN,   ## User has no `condition_token`.
	ANY_ALLY_HP_BELOW,  ## Some ally (not the user) is below `condition_value` HP.
	TARGET_HP_BELOW,    ## Only targets below `condition_value` HP are valid.
	TARGET_HAS_TOKEN,   ## Only targets with `condition_token` are valid.
	SELF_HAS_ANY,       ## User holds one of `condition_tokens`.
	## Only targets holding one of `condition_tokens` (which may name the DoTs
	## bleed, blight and burn), or below `condition_value` HP when it is above 0.
	TARGET_HAS_ANY,
	TARGET_STRESS_AT_LEAST,  ## Only targets with at least `condition_value` stress.
	TARGET_ON_CONSECRATION,  ## Only allies standing on a consecrated rank.
}
enum TargetPreference { RANDOM, LOWEST_HP, HIGHEST_STRESS, HAS_COMBO }

@export var id: StringName
@export var display_name: String
## Square icon for the skill bar. Empty shows the skill's name instead.
@export var icon: Texture2D
@export var kind: Kind = Kind.ACTION

@export_group("Ranks")
@export var launch_ranks: Array[int] = [1, 2, 3, 4]
@export var side: TargetSide = TargetSide.ENEMY
@export var target_ranks: Array[int] = [1, 2, 3, 4]
## Hits every unit in `target_ranks` instead of one chosen target.
@export var multi_target: bool = false
## For ally skills: whether the user may pick themself.
@export var can_target_self: bool = true

@export_group("Damage")
@export var damage_min: int = 0
@export var damage_max: int = 0
@export_range(0.0, 1.0) var crit_chance: float = 0.0
## Bypasses up to this many enemy Death Armor tokens.
@export var execution: int = 0
@export var can_be_riposted: bool = true
## Extra attacker-side damage against a target with Combo. Using it consumes the Combo.
@export var combo_damage_bonus: float = 0.0
## Extra attacker-side damage while the user is below half HP.
@export var low_hp_bonus: float = 0.0
## HP the user loses after using the skill. It never drops them below 1 HP.
@export var self_damage: int = 0
## Like self_damage, as a share of the user's max HP.
@export var self_damage_fraction: float = 0.0
## Tokens on the target the skill ignores: Block, Block+, Dodge, Dodge+, Guard
## and Stealth (which lets it pick a stealthed target). One stack of each is
## still spent, as in DD2.
@export var ignore_tokens: Array[StringName] = []
## Ignored as well, but only while the user holds Stealth.
@export var ignore_tokens_if_stealthed: Array[StringName] = []
## Removes the target's Combo after the hit (combo_damage_bonus does this too).
@export var ends_combo: bool = false
## Extra crit chance when the primary target has Combo.
@export var combo_crit_bonus: float = 0.0
## Lowers the target's resistance to the skill's effects while it has Combo.
@export var combo_pierce: float = 0.0
## Deals this share of the target's remaining DoT damage instead of rolling,
## ignoring every damage modifier and token (Cause of Death).
@export var damage_from_dots: float = 0.0

@export_group("Healing and stress")
@export var heal_min: int = 0
@export var heal_max: int = 0
## Heal as a fraction of the target's max HP, added to the rolled heal.
@export var heal_fraction: float = 0.0
## The heal lands only on a target below this share of max HP (1 for any).
@export var heal_below: float = 1.0
## Extra heal per positive token on the target, as a share of its max HP.
@export var heal_per_buff_token: float = 0.0
## The user heals this fraction of their own max HP after using the skill...
@export var self_heal_fraction: float = 0.0
## ...if below this share of max HP (1 for always).
@export var self_heal_below: float = 1.0
## The user heals this share of max HP for each target the skill hits.
@export var self_heal_per_hit: float = 0.0
## The user heals this share of max HP if a target had Combo.
@export var combo_self_heal: float = 0.0
## The user's stress changes by this much if the skill kills.
@export var kill_stress: int = 0
## Stress given to each target; negative values relieve stress.
@export var stress: int = 0
@export var self_stress: int = 0

@export_group("Effects")
@export var effects: Array[EffectDef] = []
@export var self_effects: Array[EffectDef] = []
## User moves after acting: positive is forward (towards rank 1), negative is back.
@export var self_move: int = 0

@export_group("Usage")
## Turns before the skill can be used again.
@export var cooldown: int = 0
## 0 means unlimited.
@export var uses_per_battle: int = 0
@export var condition: Condition = Condition.NONE
@export var condition_value: float = 0.0
@export var condition_token: StringName
@export var condition_tokens: Array[StringName] = []

@export_group("Tiers")
## Tokens the user builds up that strengthen the skill, counted together: the
## Vestal's Conviction, or the Man-at-Arms's Block and Block+.
@export var tier_tokens: Array[StringName] = []
## Extra damage by that count (index 0, 1, 2, 3...), like +100% at 2 or more.
@export var tier_damage: Array[float] = []
## Heal share of max HP by that count, replacing heal_fraction.
@export var tier_heal: Array[float] = []
## At or above this count the skill also ignores `tier_ignore_tokens` (0 for never).
@export var tier_ignore_from: int = 0
@export var tier_ignore_tokens: Array[StringName] = []
## At or above this count the skill spends all of the tokens (0 for never).
@export var tier_spend_from: int = 0

@export_group("Corpses")
## Targets an enemy corpse, and clears it.
@export var targets_corpse: bool = false
## Effects on the units just in front of and behind the cleared corpse.
@export var neighbor_effects: Array[EffectDef] = []
## Clears every corpse on the enemy side, hit or miss.
@export var clears_corpses: bool = false

@export_group("Enemy AI")
## Relative pick weight among usable skills. DD2 picks uniformly, so the default is 1.
@export var ai_weight: float = 1.0
## The AI must use this skill whenever it is usable.
@export var ai_forced: bool = false
@export var ai_target: TargetPreference = TargetPreference.RANDOM


func is_attack() -> bool:
	return kind == Kind.ACTION and side == TargetSide.ENEMY


func deals_damage() -> bool:
	return damage_max > 0 or damage_from_dots > 0.0


func heals() -> bool:
	return heal_max > 0 or heal_fraction > 0.0 or not tier_heal.is_empty() or heal_per_buff_token > 0.0

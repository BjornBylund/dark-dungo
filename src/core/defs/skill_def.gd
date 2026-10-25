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

@export_group("Healing and stress")
@export var heal_min: int = 0
@export var heal_max: int = 0
## Heal as a fraction of the target's max HP, added to the rolled heal.
@export var heal_fraction: float = 0.0
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

@export_group("Enemy AI")
## Relative pick weight among usable skills. DD2 picks uniformly, so the default is 1.
@export var ai_weight: float = 1.0
## The AI must use this skill whenever it is usable.
@export var ai_forced: bool = false
@export var ai_target: TargetPreference = TargetPreference.RANDOM


func is_attack() -> bool:
	return kind == Kind.ACTION and side == TargetSide.ENEMY


func deals_damage() -> bool:
	return damage_max > 0


func heals() -> bool:
	return heal_max > 0 or heal_fraction > 0.0

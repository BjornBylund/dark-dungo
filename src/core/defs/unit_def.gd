## A hero class or enemy type.
class_name UnitDef
extends Resource

@export var id: StringName
@export var display_name: String
## One line shown in the UI, e.g. "Front-line tank".
@export var role: String
## Placeholder body colour until there is art.
@export var color: Color = Color.GRAY
## Ranks occupied; large enemies are 2.
@export_range(1, 4) var size: int = 1
@export var max_hp: int = 20
@export var speed: int = 3
@export var turns_per_round: int = 1
## HP of the corpse left behind; 0 means no corpse.
@export var corpse_hp: int = 0
## Enemy Death Armor tokens: lethal hits it can absorb while on Death's Door.
@export var death_armor: int = 0

@export_group("Resistances")
@export var resist_stun: float = 0.0
@export var resist_bleed: float = 0.0
@export var resist_blight: float = 0.0
@export var resist_burn: float = 0.0
@export var resist_move: float = 0.0
@export var resist_debuff: float = 0.0
@export var resist_deathblow: float = 0.6
@export var resist_stress: float = 0.0

@export_group("Skills")
@export var skills: Array[SkillDef] = []
## Counter-attack used when this unit has a Riposte token. Required to gain Riposte.
@export var riposte_skill: SkillDef
## Relative positions a hero may Swap with: negative is towards rank 1.
@export var swap_offsets: Array[int] = [-1, 1]


func base_resist(kind: StringName) -> float:
	return get("resist_%s" % kind)

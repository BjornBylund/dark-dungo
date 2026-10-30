## A hero class or enemy type.
class_name UnitDef
extends Resource

@export var id: StringName
@export var display_name: String
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

@export_group("Class rules")
## Tokens gained at the start of each of the unit's turns (the Vestal's Conviction).
@export var turn_start_tokens: Dictionary[StringName, int] = {}
## What max stress brings: empty for DD2's Meltdown or Resolute, or &"toxic"
## for the Flagellant's Toxic.
@export var overstress: StringName
## Whether Death's Door makes the unit Weak, as it does every DD2 hero but the Flagellant.
@export var deaths_door_weak: bool = true

@export_group("Art")
## Drawn facing right with the feet at the bottom edge; enemies are mirrored.
## Fitted into the unit's slot keeping its aspect ratio. Empty draws the coloured placeholder.
@export var sprite: Texture2D
## Extra scale on top of the automatic fit, for art that should stand taller or shorter.
@export_range(0.25, 2.0, 0.05) var sprite_scale: float = 1.0

@export_group("Talents")
## A hero's talents, row by row: three for each of CampaignRules.TALENT_LEVELS,
## the first three for the first. Empty for enemies.
@export var talents: Array[TalentDef] = []

@export_group("Story")
## A hero's dialogue script, content/dialogue/<class>.txt: their joining and
## level-up scenes (see src/campaign/dialogue.gd).
@export_file("*.txt") var dialogue: String


func base_resist(kind: StringName) -> float:
	return get("resist_%s" % kind)

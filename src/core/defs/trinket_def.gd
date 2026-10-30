## A trinket, DD2's: a hero wears up to two. Each has passive stats, stats that
## only count while a condition holds, and triggers that fire on combat events
## (see Perk). Rarer trinkets drop less often and mostly in harder dungeons;
## boss trinkets only come from region bosses. Nobody owns two of the same.
class_name TrinketDef
extends Perk

enum Rarity { VAGUE, DISTANT, INDELIBLE, ANCESTRAL }

@export var id: StringName
@export var display_name: String
@export var rarity: Rarity = Rarity.VAGUE
## Only this class may wear it; empty for any class.
@export var hero: UnitDef
## Only region bosses give it.
@export var boss_only: bool = false
## Gold at the Nomad Wagon, which buys back at a share of it. 0: never sold.
@export var price: int = 0
## Square icon. Empty draws a placeholder in the rarity's colour.
@export var icon: Texture2D

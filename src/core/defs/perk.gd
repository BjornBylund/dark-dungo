## What trinkets and talents are made of: passive stats, stats that only count
## while a condition holds, and triggers that fire on combat events. Growth
## puts them on a hero's combatant; UiStyle.perk_effects says them in words.
class_name Perk
extends Resource

## Stat -> amount: the combatant stats (see Combatant.buffs), as fractions
## (0.1 = +10%) except "speed" and flat amounts like "dot_dealt_bleed"; and
## "max_hp", a fraction of the class's base max HP.
@export var stats: Dictionary[StringName, float] = {}
## Stats that only count while their condition holds.
@export var bonuses: Array[TrinketBonus] = []
## Effects fired by combat events.
@export var triggers: Array[TrinketTrigger] = []

## One choice in an event: certain, or a chance of success with a fallback.
## The button shows `label` followed by what the outcomes do.
class_name EventChoiceDef
extends Resource

@export var label: String
## A class that must be in the party; it is the hero the "chosen" outcomes affect.
@export var requires: UnitDef
## Chance of the success outcomes; otherwise the failure outcomes happen.
@export_range(0.0, 1.0, 0.05) var chance: float = 1.0
@export var success: Array[EventOutcomeDef] = []
@export_multiline var success_text: String
@export var failure: Array[EventOutcomeDef] = []
@export_multiline var failure_text: String

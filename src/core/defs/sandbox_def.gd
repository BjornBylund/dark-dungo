## The combat sandbox: a fixed party fighting waves in order.
class_name SandboxDef
extends Resource

## Starting order; the first entry stands in rank 1.
@export var party: Array[UnitDef] = []
@export var waves: Array[EncounterDef] = []

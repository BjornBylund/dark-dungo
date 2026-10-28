## A range the balance tool expects an encounter's result in; it flags what falls outside.
class_name BalanceTarget
extends Resource

enum Role { FIGHT, ELITE, FINALE, BOSS }
enum Metric { WIN, HP_LOST }

const ROLE_KEYS: Array[StringName] = [&"fights", &"elites", &"finales", &"boss"]
const METRIC_NAMES := ["win", "HP lost"]

## Which encounters: the regions' fights, elites, finales or bosses.
@export var role: Role = Role.FIGHT
@export var metric: Metric = Metric.WIN
@export_range(0.0, 1.0) var low: float = 0.0
@export_range(0.0, 1.0) var high: float = 1.0
## The preset it applies at, by name.
@export var preset: String = "Base"


func role_key() -> StringName:
	return ROLE_KEYS[role]


## "win 40–46%".
func range_text() -> String:
	return "%s %d–%d%%" % [METRIC_NAMES[metric], roundi(low * 100), roundi(high * 100)]


## "Base boss: win 40–46%".
func describe() -> String:
	return "%s %s: %s" % [preset, ROLE_KEYS[role], range_text()]

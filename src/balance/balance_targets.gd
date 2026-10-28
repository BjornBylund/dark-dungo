## The balance tool's settings, kept in content/balance_targets.tres: the
## power presets it simulates at, the ranges it expects encounters in, and how
## far heroes, skills and trinkets may stray before they are flagged.
class_name BalanceTargets
extends Resource

@export var presets: Array[BalancePreset] = []
@export var targets: Array[BalanceTarget] = []
## Heroes are flagged when their win rate is further than this from the cast's average.
@export_range(0.0, 1.0) var hero_spread: float = 0.05
## Skills and trinkets are flagged when their win difference (with against
## without) is further than this from their group's middle, and further than
## its margin of error...
@export_range(0.0, 1.0) var standout_win: float = 0.08
## ...or their difference in party HP lost is further than this from the middle.
@export_range(0.0, 1.0) var standout_hp: float = 0.04


func preset_named(name: String) -> BalancePreset:
	for preset in presets:
		if preset.name == name:
			return preset
	return presets[0] if not presets.is_empty() else BalancePreset.new()


## The targets for encounters in `role` (&"fights", &"elites"...) at `preset`.
func for_role(role: StringName, preset: BalancePreset) -> Array[BalanceTarget]:
	var result: Array[BalanceTarget] = []
	for target in targets:
		if target.role_key() == role and target.preset == preset.name:
			result.append(target)
	return result

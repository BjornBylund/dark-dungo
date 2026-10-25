## Actions every hero has besides their 5 skills, from DD2's shared `move` and `pass` data.
class_name BasicSkills
extends RefCounted

static var swap: SkillDef = _make_swap()
static var pass_turn: SkillDef = _make_pass()
## DD2's `pass_heal`: only offered below 25% HP.
static var recover: SkillDef = _make_recover()


static func _make_swap() -> SkillDef:
	var skill := SkillDef.new()
	skill.id = &"swap"
	skill.display_name = "Swap"
	skill.description = "Trade places with a nearby ally."
	skill.kind = SkillDef.Kind.SWAP
	skill.side = SkillDef.TargetSide.ALLY
	return skill


static func _make_pass() -> SkillDef:
	var skill := SkillDef.new()
	skill.id = &"pass"
	skill.display_name = "Pass"
	skill.description = "Do nothing this turn. +%d stress." % Rules.PASS_STRESS
	skill.kind = SkillDef.Kind.PASS
	skill.side = SkillDef.TargetSide.SELF
	return skill


static func _make_recover() -> SkillDef:
	var skill := SkillDef.new()
	skill.id = &"recover"
	skill.display_name = "Recover"
	skill.description = "Catch your breath: heal %d%% HP, +%d stress." % [
		roundi(Rules.RECOVER_HEAL_FRACTION * 100), Rules.RECOVER_STRESS]
	skill.side = SkillDef.TargetSide.SELF
	skill.heal_fraction = Rules.RECOVER_HEAL_FRACTION
	skill.self_stress = Rules.RECOVER_STRESS
	skill.cooldown = Rules.RECOVER_COOLDOWN
	skill.condition = SkillDef.Condition.SELF_HP_BELOW
	skill.condition_value = Rules.RECOVER_HP_THRESHOLD
	return skill

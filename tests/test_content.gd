extends TestCase

const SANDBOX_PATH := "res://content/sandbox.tres"


func _sandbox() -> SandboxDef:
	return load(SANDBOX_PATH)


func _all_units() -> Array[UnitDef]:
	var units: Array[UnitDef] = []
	var sandbox := _sandbox()
	units.append_array(sandbox.party)
	for wave in sandbox.waves:
		for enemy in wave.enemies:
			if enemy not in units:
				units.append(enemy)
	return units


func test_sandbox_has_four_heroes_with_five_skills_and_three_waves() -> void:
	var sandbox := _sandbox()
	assert_eq(sandbox.party.size(), 4)
	assert_eq(sandbox.waves.size(), 3)
	for hero in sandbox.party:
		assert_eq(hero.skills.size(), 5, hero.display_name)


func test_waves_fit_in_four_ranks() -> void:
	for wave in _sandbox().waves:
		var ranks := 0
		for enemy in wave.enemies:
			ranks += enemy.size
		assert_true(ranks <= Rules.RANKS, wave.display_name)


func test_skills_are_well_formed() -> void:
	for unit in _all_units():
		var skills := unit.skills.duplicate()
		if unit.riposte_skill:
			skills.append(unit.riposte_skill)
		var ids := {}
		for skill: SkillDef in skills:
			var label := "%s/%s" % [unit.display_name, skill.id]
			assert_ne(skill.id, &"", label + " id")
			assert_ne(skill.display_name, "", label + " name")
			assert_false(skill.launch_ranks.is_empty(), label + " launch ranks")
			assert_false(skill.target_ranks.is_empty(), label + " target ranks")
			assert_true(skill.damage_min <= skill.damage_max, label + " damage range")
			assert_false(ids.has(skill.id), label + " duplicate id")
			ids[skill.id] = true


func test_every_unit_can_act_from_its_starting_rank() -> void:
	var sandbox := _sandbox()
	for wave in sandbox.waves:
		var run := SandboxRun.new(sandbox, 1)
		run.wave_index = sandbox.waves.find(wave) - 1
		var battle := run.start_next_wave()
		for unit in battle.all_units():
			var usable := unit.def.skills.any(func(skill: SkillDef) -> bool: return battle.can_use(unit, skill))
			assert_true(usable, "%s in %s" % [unit.display_name, wave.display_name])

extends TestCase


## The editor beside the field named `title`.
func _row(form: Control, title: String) -> HBoxContainer:
	for label: Label in form.find_children("*", "Label", true, false):
		if label.text == title:
			return label.get_parent()
	return null


func _undo_all(library: BalanceLibrary) -> void:
	while library.history.has_undo():
		library.undo()


func test_two_edits_to_one_key_value_field_both_stay() -> void:
	var library := BalanceLibrary.new()
	var trinket: TrinketDef = library.trinkets.filter(func(t: TrinketDef) -> bool: return t.stats.size() >= 2)[0]
	var before := trinket.stats.duplicate()
	var form := ResourceForm.new(library, trinket, {})
	var spins := _row(form, "Stats").find_children("*", "SpinBox", true, false)
	# Setting a Range's value from script doesn't emit value_changed in Godot 4.7; typing in it does.
	spins[0].value_changed.emit(0.5)
	spins[1].value_changed.emit(0.75)
	var keys := before.keys()
	assert_almost_eq(trinket.stats[keys[0]], 0.5, "the first edit stays")
	assert_almost_eq(trinket.stats[keys[1]], 0.75)
	_undo_all(library)
	assert_eq(trinket.stats, before)
	form.free()


func test_two_rank_toggles_both_stay() -> void:
	var library := BalanceLibrary.new()
	var hero := library.heroes[0]
	var skill := hero.skills[0]
	var before := skill.launch_ranks.duplicate()
	var form := ResourceForm.new(library, skill, {"%d/Ranks" % skill.get_instance_id(): true})
	var checks := _row(form, "Launch Ranks").find_children("*", "CheckBox", true, false)
	for check: CheckBox in checks:
		check.button_pressed = true
	assert_eq(skill.launch_ranks, [1, 2, 3, 4] as Array[int])
	_undo_all(library)
	assert_eq(skill.launch_ranks, before)
	form.free()


func test_new_skills_get_a_name_and_a_free_id() -> void:
	var library := BalanceLibrary.new()
	var hero := library.heroes[0]
	var count := hero.skills.size()
	var form := ResourceForm.new(library, hero, {})
	for i in 2:
		var add: Button = form.find_children("*", "Button", true, false).filter(func(b: Button) -> bool:
			return b.text == "+ Add skill")[0]
		add.pressed.emit()
		form.rebuild()
	assert_eq(hero.skills.size(), count + 2)
	assert_eq(hero.skills[-2].id, &"new_skill")
	assert_eq(hero.skills[-1].id, &"new_skill_2")
	assert_eq(hero.skills[-1].display_name, "New skill")
	_undo_all(library)
	assert_eq(hero.skills.size(), count)
	form.free()

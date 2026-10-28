extends TestCase

const TEMP_FOLDER := "user://balance_test"


## Undoes every edit, so the shared content resources are as loaded for later tests.
func _undo_all(library: BalanceLibrary) -> void:
	while library.history.has_undo():
		library.undo()


func _count_files(folder: String) -> int:
	return Array(DirAccess.get_files_at(folder)).filter(func(file: String) -> bool: return file.ends_with(".tres")).size()


func test_loads_every_content_file() -> void:
	var library := BalanceLibrary.new()
	assert_eq(library.heroes.size(), _count_files("res://content/heroes"))
	assert_eq(library.enemies.size(), _count_files("res://content/enemies"))
	assert_eq(library.encounters.size(), _count_files("res://content/encounters"))
	assert_eq(library.trinkets.size(), _count_files("res://content/trinkets"))
	assert_true(library.unsaved().is_empty(), "nothing unsaved after loading")


func test_an_edit_marks_its_file_unsaved_until_undone() -> void:
	var library := BalanceLibrary.new()
	var hero := library.heroes[0]
	var hp := hero.max_hp
	library.set_value(hero, hero, &"max_hp", hp + 5)
	assert_eq(hero.max_hp, hp + 5)
	assert_eq(library.unsaved(), [hero] as Array[Resource])
	library.undo()
	assert_eq(hero.max_hp, hp)
	assert_true(library.unsaved().is_empty())
	library.redo()
	assert_eq(hero.max_hp, hp + 5)
	assert_true(library.is_unsaved(hero))
	_undo_all(library)


func test_editing_a_skill_marks_the_unit_it_belongs_to() -> void:
	var library := BalanceLibrary.new()
	var hero := library.heroes[0]
	var skill := hero.skills[0]
	library.set_value(hero, skill, &"damage_max", skill.damage_max + 1)
	assert_true(library.is_unsaved(hero))
	_undo_all(library)


func test_quick_edits_of_one_field_undo_together() -> void:
	var library := BalanceLibrary.new()
	var enemy := library.enemies[0]
	var hp := enemy.max_hp
	for step in 3:
		library.set_value(enemy, enemy, &"max_hp", hp + step + 1)
	library.set_value(enemy, enemy, &"speed", enemy.speed + 1)
	library.undo()
	assert_eq(enemy.max_hp, hp + 3, "the speed edit is its own step")
	library.undo()
	assert_eq(enemy.max_hp, hp, "the three HP edits are one step")
	assert_true(library.unsaved().is_empty())
	_undo_all(library)


func test_duplicates_are_independent_and_unsaved() -> void:
	var library := BalanceLibrary.new()
	var hero := library.heroes[0]
	var copy: UnitDef = library.duplicate_root(hero)
	assert_eq(copy.id, StringName(String(hero.id) + "_copy"))
	assert_eq(copy.display_name, hero.display_name + " (copy)")
	assert_eq(library.heroes[1], copy, "placed after the original")
	assert_ne(copy.skills[0], hero.skills[0], "skills are copied")
	assert_eq(copy.skills[0].id, hero.skills[0].id)
	assert_eq(copy.sprite, hero.sprite, "art is shared")
	assert_true(library.is_unsaved(copy))
	assert_false(library.is_locked(copy), "a new unit's id can still change")
	assert_true(library.is_locked(hero))
	library.undo()
	assert_false(copy in library.heroes)
	assert_true(library.unsaved().is_empty())


func test_duplicating_twice_picks_a_free_id() -> void:
	var library := BalanceLibrary.new()
	var trinket := library.trinkets[0]
	library.duplicate_root(trinket)
	var second: TrinketDef = library.duplicate_root(trinket)
	assert_eq(second.id, StringName(String(trinket.id) + "_copy2"))
	_undo_all(library)


func test_listing_a_trinket_in_the_campaign() -> void:
	var library := BalanceLibrary.new()
	var copy: TrinketDef = library.duplicate_root(library.trinkets[0])
	var listing: Dictionary = library.listings(copy)[0]
	assert_false(listing.on)
	library.set_listed(copy, listing, true)
	assert_true(copy in library.campaign.trinkets)
	assert_true(library.is_unsaved(library.campaign))
	assert_true(library.listings(copy)[0].on)
	library.undo()
	assert_false(copy in library.campaign.trinkets)
	_undo_all(library)


func test_a_hero_is_a_starting_hero_or_a_recruit_not_both() -> void:
	var library := BalanceLibrary.new()
	var recruit: UnitDef = library.campaign.recruits[0]
	var starting: Dictionary = library.listings(recruit).filter(func(l: Dictionary) -> bool:
		return l.label == "Starting Heroes")[0]
	library.set_listed(recruit, starting, true)
	assert_true(recruit in library.campaign.starting_heroes)
	assert_false(recruit in library.campaign.recruits)
	library.undo()
	assert_true(recruit in library.campaign.recruits)
	assert_false(recruit in library.campaign.starting_heroes)
	_undo_all(library)


func test_encounter_roles_come_from_the_regions() -> void:
	var library := BalanceLibrary.new()
	for region in library.campaign.regions:
		assert_true("%s boss" % region.display_name in library.roles_of(region.boss), region.display_name)
		for elite in region.elites:
			assert_true("%s elites" % region.display_name in library.roles_of(elite), elite.display_name)


func test_saving_a_new_trinket_writes_its_file() -> void:
	DirAccess.make_dir_recursive_absolute(TEMP_FOLDER)
	var library := BalanceLibrary.new()
	library.folders[BalanceLibrary.Kind.TRINKET] = TEMP_FOLDER
	var copy: TrinketDef = library.duplicate_root(library.trinkets[0])
	library.set_value(copy, copy, &"price", 1234)
	assert_eq(library.save(), OK)
	var path := TEMP_FOLDER.path_join(String(copy.id) + ".tres")
	assert_eq(copy.resource_path, path)
	assert_true(library.unsaved().is_empty())
	assert_true(library.is_locked(copy), "saved, so its id is locked")
	var loaded: TrinketDef = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(loaded.id, copy.id)
	assert_eq(loaded.price, 1234)
	library.undo()
	assert_true(library.is_unsaved(copy), "undoing past a save makes it unsaved again")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(TEMP_FOLDER)
	_undo_all(library)

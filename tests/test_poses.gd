## Pose sprites for the combat close-up, found by convention in each unit's
## folder under art/characters.
extends TestCase


func test_every_hero_skill_has_an_attack_pose_and_every_unit_a_hurt_pose() -> void:
	for dir in ["res://content/heroes", "res://content/enemies"]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".tres"):
				continue
			var unit: UnitDef = load(dir.path_join(file))
			if unit.sprite == null:
				continue
			assert_true(Poses.hurt(unit) != null, "%s hurt pose" % unit.id)
			if dir.ends_with("heroes"):
				for skill in unit.skills:
					assert_true(Poses.attack(unit, skill) != null, "%s %s pose" % [unit.id, skill.id])


func test_each_units_art_lives_in_its_own_folder_named_after_its_class() -> void:
	var folders := {}
	for dir in ["res://content/heroes", "res://content/enemies"]:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".tres"):
				continue
			var unit: UnitDef = load(dir.path_join(file))
			if unit.sprite == null:
				continue
			var folder := Poses.folder(unit)
			assert_eq(unit.sprite.resource_path, folder.path_join("sprite.png"))
			assert_eq(folder.get_base_dir(), Poses.ROOT, "%s sits under art/characters" % unit.id)
			var class_folder := unit.display_name.trim_prefix("The ").to_lower().replace(" ", "_").replace("-", "_")
			assert_eq(folder.get_file(), class_folder, "%s's folder" % unit.display_name)
			assert_false(folders.has(folder), "%s shares a folder" % unit.id)
			folders[folder] = true


func test_a_missing_pose_falls_back_to_the_normal_sprite() -> void:
	var unit := Fixtures.unit("Nobody")
	assert_eq(Poses.hurt(unit), null)
	assert_eq(Poses.attack(unit, Fixtures.attack(1, 2)), null)

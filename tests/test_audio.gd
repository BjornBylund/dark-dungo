extends TestCase

const Sounds := preload("res://tools/audio/sounds.gd")
const Music := preload("res://tools/audio/music.gd")
const TEST_SETTINGS := "user://settings_test.cfg"

var _literal := RegEx.create_from_string("&\"(\\w+)\"")


func _sorted(names: Array) -> Array:
	var copy := names.map(func(name: Variant) -> String: return String(name))
	copy.sort()
	return copy


func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	return found


func _names_in(text: String) -> Array[StringName]:
	var names: Array[StringName] = []
	for found in _literal.search_all(text):
		names.append(StringName(found.get_string(1)))
	return names


func test_every_sound_has_its_recipe_and_files() -> void:
	assert_eq(_sorted(Audio.SOUNDS), _sorted(Sounds.SOUNDS.keys()), "the game's sounds are the recipes'")
	for sound in Audio.SOUNDS:
		assert_eq(Audio.variants(sound).size(), Sounds.SOUNDS[sound][0],
				"%s has a file per variant (tools/make_audio.gd renders them)" % sound)


func test_tracks_loop_and_stings_play_once() -> void:
	assert_eq(_sorted(Audio.TRACKS + Audio.STINGS), _sorted(Music.TRACKS.keys()), "the game's music is the recipes'")
	for track in Audio.TRACKS + Audio.STINGS:
		var loops := track in Audio.TRACKS
		assert_eq(Music.TRACKS[track][0], loops, track)
		var stream: AudioStreamWAV = load(Audio.track_path(track))
		assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD if loops else AudioStreamWAV.LOOP_DISABLED,
				"%s loops from its file's sampler chunk" % track if loops else "%s plays once" % track)


func test_the_code_names_only_sounds_that_exist() -> void:
	var calls := RegEx.create_from_string("Audio\\.(play|play_music|sting)\\(([^)]*)\\)")
	var town_actions := RegEx.create_from_string("_after\\([^\\n]*, (&\"\\w+\")\\)")
	var stings := RegEx.create_from_string("sting = (&\"\\w+\")")
	var known := {"play": Audio.SOUNDS, "play_music": Audio.TRACKS, "sting": Audio.STINGS}
	var named := 0
	for path in _scripts("res://src"):
		var text := FileAccess.get_file_as_string(path)
		for call in calls.search_all(text):
			for sound in _names_in(call.get_string(2)):
				named += 1
				assert_true(sound in known[call.get_string(1)], "%s: %s" % [path.get_file(), call.get_string()])
		for action in town_actions.search_all(text):
			for sound in _names_in(action.get_string(1)):
				named += 1
				assert_true(sound in Audio.SOUNDS, "%s: %s" % [path.get_file(), action.get_string()])
		for sting in stings.search_all(text):
			for sound in _names_in(sting.get_string(1)):
				assert_true(sound in Audio.STINGS, "%s: %s" % [path.get_file(), sting.get_string()])
	assert_true(named > 30, "found the calls")
	for line in FileAccess.get_file_as_string("res://src/ui/combat_sounds.gd").split("\n"):
		if line.strip_edges().begins_with("return"):
			for sound in _names_in(line):
				assert_true(sound in Audio.SOUNDS, "combat_sounds.gd: " + line.strip_edges())
	for sound: StringName in CombatSounds.SKILL_SOUNDS.values() + CombatSounds.DOTS + SettingsWindow.SAMPLES.values():
		assert_true(sound in Audio.SOUNDS, sound)


func test_skills_sound_as_chosen_or_as_their_ranks_suggest() -> void:
	var skill := SkillDef.new()
	skill.launch_ranks = [1, 2]
	skill.target_ranks = [1, 2]
	assert_eq(CombatSounds.skill_sound(skill), SkillDef.Sound.BLADE, "a front-line attack swings")
	skill.launch_ranks = [3, 4]
	skill.target_ranks = [2, 3, 4]
	assert_eq(CombatSounds.skill_sound(skill), SkillDef.Sound.SHOT, "from the back, at the back: a shot")
	skill.sound = SkillDef.Sound.BLADE
	assert_eq(CombatSounds.skill_sound(skill), SkillDef.Sound.BLADE, "a lunge says so")
	skill.sound = SkillDef.Sound.FROM_RANKS
	skill.side = SkillDef.TargetSide.ALLY
	assert_eq(CombatSounds.skill_sound(skill), SkillDef.Sound.SPELL, "help for allies shimmers")
	var crusader: UnitDef = load("res://content/heroes/vanguard.tres")
	var lance: SkillDef = crusader.skills.filter(func(s: SkillDef) -> bool: return s.id == &"holy_lance")[0]
	assert_eq(CombatSounds.skill_sound(lance), SkillDef.Sound.BLADE, "the Crusader's lance lunges, from rank 3")


func test_blows_sound_by_how_they_land() -> void:
	var hit := {type = &"damage", amount = 6, base = 6, attack_mod = 1.0, weak = false, crit = false}
	assert_eq(CombatSounds.of(hit, null), &"hit")
	assert_eq(CombatSounds.of(hit.merged({crit = true}, true), null), &"crit")
	assert_eq(CombatSounds.of(hit.merged({amount = 3}, true), null), &"block", "Block took half")
	assert_eq(CombatSounds.of(hit.merged({amount = 5}, true), null), &"hit", "a little less isn't a clang")
	assert_eq(CombatSounds.of({type = &"damage", amount = 2, cause = &"bleed"}, null), &"bleed")
	var hero := Combatant.new(load("res://content/heroes/vanguard.tres"), true)
	assert_eq(CombatSounds.of({type = &"death"}, hero), &"fallen", "a hero falls to voices")
	assert_eq(CombatSounds.of({type = &"stress", amount = -2}, hero), &"relief")
	assert_eq(CombatSounds.of({type = &"round_start"}, null), &"", "not everything makes a sound")


func test_volumes_set_the_buses_and_are_kept() -> void:
	var real_path := Audio.settings_path
	var music := Audio.volume(Audio.MUSIC_BUS)
	Audio.settings_path = TEST_SETTINGS
	Audio.set_volume(Audio.MUSIC_BUS, 0.5)
	var bus := AudioServer.get_bus_index(Audio.MUSIC_BUS)
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), linear_to_db(0.25), "half way is squared")
	Audio.set_volume(Audio.MUSIC_BUS, 0.0)
	assert_true(AudioServer.is_bus_mute(bus), "nothing at all")
	var config := ConfigFile.new()
	assert_eq(config.load(TEST_SETTINGS), OK)
	assert_eq(config.get_value("volume", "Music"), 0.0)
	Audio.set_volume(Audio.MUSIC_BUS, music)
	Audio.settings_path = real_path
	DirAccess.remove_absolute(TEST_SETTINGS)
	assert_false(AudioServer.is_bus_mute(bus) and music > 0.0)

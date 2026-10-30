## Renders the sound effects and music from the recipes in tools/audio/ into
## audio/sfx/ and audio/music/ as WAV files, which Godot imports compressed.
## The recipes seed their own random numbers, so the same recipes always give
## the same files. Files no recipe makes any more are deleted.
##   godot --headless --path . --script res://tools/make_audio.gd
##   ... -- --only=hit,town   renders just those
extends SceneTree

const Synth := preload("res://tools/audio/synth.gd")
const Sounds := preload("res://tools/audio/sounds.gd")
const Music := preload("res://tools/audio/music.gd")
const SFX_FOLDER := "res://audio/sfx"
const MUSIC_FOLDER := "res://audio/music"
## Sounds end once they are this quiet.
const SILENT := 0.0003
## The music's peaks stay below this.
const PEAK := 0.95


func _initialize() -> void:
	var only := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=").split(",")
	var started := Time.get_ticks_msec()
	var made := {}
	for folder in [SFX_FOLDER, MUSIC_FOLDER]:
		DirAccess.make_dir_recursive_absolute(folder)
	var sounds := Sounds.new()
	for sound: StringName in Sounds.SOUNDS:
		for variant in range(1, Sounds.SOUNDS[sound][0] + 1):
			var path := "%s/%s_%d.wav" % [SFX_FOLDER, sound, variant]
			made[path] = true
			if only.is_empty() or String(sound) in only:
				var s := Synth.new(Sounds.RATE)
				s.rng.seed = hash("%s %d" % [sound, variant])
				var buf := _trim(s, s.clean(sounds.render(s, sound, variant)))
				_write(s, path, s.normalize(buf, Sounds.SOUNDS[sound][1]), false)
	var music := Music.new()
	for track: StringName in Music.TRACKS:
		var path := "%s/%s.wav" % [MUSIC_FOLDER, track]
		made[path] = true
		if only.is_empty() or String(track) in only:
			var loops: bool = Music.TRACKS[track][0]
			var s := Synth.new(Music.RATE)
			s.rng.seed = hash(String(track))
			var buf := music.render(s, track)
			if not loops:
				buf = _trim(s, s.clean(buf))
			var gain := minf(db_to_linear(Music.TRACKS[track][1]) / s.rms(buf), PEAK / s.peak(buf))
			_write(s, path, s.scale(buf, gain), loops)
	if only.is_empty():
		_delete_others(made)
	print("Rendered in %.1f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit()


## Cuts the silence after the sound dies away, ending with a short fade.
func _trim(s: Synth, buf: PackedFloat32Array) -> PackedFloat32Array:
	var top := s.peak(buf)
	var end := buf.size()
	while end > 1 and absf(buf[end - 1]) < SILENT * top:
		end -= 1
	buf.resize(mini(buf.size(), end + s.frames(0.01)))
	return s.fade(buf, 0.0, 0.01)


func _write(s: Synth, path: String, buf: PackedFloat32Array, loop: bool) -> void:
	var error := s.write_wav(path, buf, loop)
	if error != OK:
		push_error("Could not write %s: %s" % [path, error_string(error)])
		return
	print("%-28s %5.2f s  %5.1f dB RMS%s" % [path.get_file(), float(buf.size()) / s.rate,
			linear_to_db(s.rms(buf)), "  loops" if loop else ""])


## Deletes the WAV files (and their import files) that no recipe made.
func _delete_others(made: Dictionary) -> void:
	for folder in [SFX_FOLDER, MUSIC_FOLDER]:
		for file in DirAccess.get_files_at(folder):
			var path: String = folder.path_join(file)
			if file.ends_with(".wav") and not made.has(path):
				DirAccess.remove_absolute(path)
				DirAccess.remove_absolute(path + ".import")
				print("Deleted ", file)

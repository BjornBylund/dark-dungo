## Runs the game and saves a screenshot every few seconds, for checking visuals without a person.
## Usage: godot --path . --script res://tools/capture.gd -- --autoplay --out=<dir> [--shots=10] [--every=2.5]
extends SceneTree

var _out := "user://captures"
var _shots := 10
var _every := 2.5
var _taken := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_shots = int(arg.trim_prefix("--shots="))
		elif arg.begins_with("--every="):
			_every = float(arg.trim_prefix("--every="))
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	_capture_later()


func _capture_later() -> void:
	await create_timer(_every).timeout
	var image := root.get_texture().get_image()
	var path := _out.path_join("shot_%02d.png" % _taken)
	image.save_png(path)
	var screen := current_scene
	var panel: Control = screen.get("_end_panel") if screen else null
	print("Saved %s%s" % [path, " (end panel)" if panel and panel.visible else ""])
	_taken += 1
	if _taken >= _shots:
		quit()
	else:
		_capture_later()

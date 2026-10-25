## Headless test runner. Runs every `test_*` method in every `res://tests/test_*.gd`.
## Usage: godot --headless --path . --script res://tests/run_tests.gd [-- --only=text]
## --only runs just the tests whose file or method name contains the text.
## A test fails on a failed assertion or on any engine/script error it causes.
## Exit code is non-zero when any test fails.
extends SceneTree

const TEST_DIR := "res://tests"


class ErrorRecorder extends Logger:
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		errors.append("%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _initialize() -> void:
	var recorder := ErrorRecorder.new()
	OS.add_logger(recorder)
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	var passed := 0
	var failed := 0
	var files := Array(DirAccess.get_files_at(TEST_DIR))
	files.sort()
	for file: String in files:
		if not (file.begins_with("test_") and file.ends_with(".gd")) or file == "test_case.gd":
			continue
		recorder.errors.clear()
		var script: GDScript = load(TEST_DIR.path_join(file))
		if script == null or not script.can_instantiate():
			failed += 1
			print("  FAIL  %s (does not compile)" % file)
			for error in recorder.errors:
				print("          " + error)
			continue
		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_") or not (only.is_empty() or only in file or only in method_name):
				continue
			recorder.errors.clear()
			var started := Time.get_ticks_msec()
			var suite: TestCase = script.new()
			suite.call(method_name)
			var seconds := (Time.get_ticks_msec() - started) / 1000.0
			var problems: Array[String] = suite.failures.duplicate()
			problems.append_array(recorder.errors)
			if problems.is_empty():
				passed += 1
				print("  ok    %s::%s%s" % [file, method_name, "   (%.1fs)" % seconds if seconds >= 0.5 else ""])
			else:
				failed += 1
				print("  FAIL  %s::%s" % [file, method_name])
				for problem in problems.slice(0, 8):
					print("          " + problem)
	OS.remove_logger(recorder)
	print("\n%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

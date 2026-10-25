## Base class for headless tests. GDScript has no exceptions, so assertions
## record failures and the runner reports them after each test method.
class_name TestCase
extends RefCounted

var failures: Array[String] = []


func assert_true(value: bool, message: String = "expected true") -> void:
	if not value:
		failures.append(message)


func assert_false(value: bool, message: String = "expected false") -> void:
	if value:
		failures.append(message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		failures.append("%sexpected %s, got %s" % [_prefix(message), str(expected), str(actual)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if actual == unexpected:
		failures.append("%sdid not expect %s" % [_prefix(message), str(unexpected)])


func assert_between(actual: float, low: float, high: float, message: String = "") -> void:
	if actual < low or actual > high:
		failures.append("%sexpected %s in [%s, %s]" % [_prefix(message), str(actual), str(low), str(high)])


func fail(message: String) -> void:
	failures.append(message)


func _prefix(message: String) -> String:
	return message + ": " if message != "" else ""

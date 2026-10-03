class_name TestCase
extends RefCounted
## Minimal assertion base for tests/run_tests.gd.

var failures: Array[String] = []
var _current := ""


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("%s: %s" % [_current, msg if msg != "" else "expected true"])


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		failures.append("%s: %s expected %s, got %s" % [_current, msg, str(expected), str(actual)])

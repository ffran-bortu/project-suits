"""
FILE: unit_test.gd
PURPOSE: Base class for unit tests. Provides assertion logic.
"""

extends Node
class_name UnitTest

func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual == expected:
		_pass()
	else:
		_fail("Expected '%s', got '%s'. %s" % [str(expected), str(actual), message])

func assert_true(condition: bool, message: String = "") -> void:
	if condition:
		_pass()
	else:
		_fail("Condition failed. %s" % message)

func assert_false(condition: bool, message: String = "") -> void:
	if not condition:
		_pass()
	else:
		_fail("Expected false, got true. %s" % message)

func _pass() -> void:
	# Access parent runner to increment counters
	# This assumes the test instance is a child of TestRunner
	var runner = get_parent()
	if runner and " _tests_passed" in runner:
		runner._tests_passed += 1
		# Optional: Verbose logging
		# DebugLog.log("  PASS", "green") 

func _fail(reason: String) -> void:
	var runner = get_parent()
	if runner:
		runner._tests_failed += 1
		var method_stack = get_stack()
		var method_name = method_stack[1].function if method_stack.size() > 1 else "Unknown"
		DebugLog.error("  FAIL [%s]: %s" % [method_name, reason])

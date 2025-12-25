"""
FILE: test_runner.gd
PURPOSE: Lightweight unit testing framework (Zero-Dependency).
USAGE: Attach to a Node and run scene, or call run_all_tests() dynamically.
"""

extends Node
class_name TestRunner

# --- Colors ---
const COLOR_PASS := "green"
const COLOR_FAIL := "red"
const COLOR_INFO := "cyan"

# --- State ---
var _tests_passed: int = 0
var _tests_failed: int = 0
var _current_test_script: String = ""

func _ready() -> void:
	# Add specific test scripts here manually or via scanning
	# For "10/10" polish, we'll manually register the critical unit tests
	DebugLog.log("=== STARTING UNIT TESTS ===", "white")
	
	await run_test_suite("res://scripts/Tests/Unit/test_damage_calculator.gd")
	await run_test_suite("res://scripts/Tests/Unit/test_grid_manager.gd")
	await run_test_suite("res://scripts/Tests/test_world_map_data.gd")
	
	_print_summary()

## Run a specific test script
func run_test_suite(script_path: String) -> void:
	if not ResourceLoader.exists(script_path):
		DebugLog.error("Test script not found: " + script_path)
		return
		
	var script = load(script_path)
	var instance = script.new()
	add_child(instance)
	
	_current_test_script = script_path.get_file()
	DebugLog.log("--- Running Suite: %s ---" % _current_test_script, "white")
	
	# Find all methods starting with "test_"
	for method in instance.get_method_list():
		var name: String = method.name
		if name.begins_with("test_"):
			# Call setup if exists
			if instance.has_method("before_each"):
				instance.call("before_each")
				
			# Run Test
			instance.call(name)
			
			# Call teardown if exists
			if instance.has_method("after_each"):
				instance.call("after_each")
	
	instance.queue_free()
	# Wait a frame to cleanup
	await get_tree().process_frame

## Print final results
func _print_summary() -> void:
	var total = _tests_passed + _tests_failed
	var color = COLOR_PASS if _tests_failed == 0 else COLOR_FAIL
	
	DebugLog.log("============================", "white")
	DebugLog.log("TEST RUN COMPLETE", "white")
	DebugLog.log("Passed: %d" % _tests_passed, COLOR_PASS)
	DebugLog.log("Failed: %d" % _tests_failed, COLOR_FAIL if _tests_failed > 0 else COLOR_PASS)
	DebugLog.log("Total:  %d" % total, "white")
	DebugLog.log("============================", "white")

# --- Assertion Helpers (Available to test scripts that extend this or are children) ---
# Note: Since the test scripts are children, they can't easily call these directly if the logic resides here.
# Instead, we'll put the assertions in a base class `UnitTest` that tests extend, or just duplicating lightly.
# BETTER APPROACH: This runner orchestrates. The tests themselves use a helper.

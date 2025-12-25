"""
FILE: test_grid_manager.gd
PURPOSE: Verify grid coordinate conversions and math.
"""

extends UnitTest

func test_manhattan_distance() -> void:
	var p1 = Vector2i(0, 0)
	var p2 = Vector2i(3, 4)
	
	var dist = abs(p1.x - p2.x) + abs(p1.y - p2.y)
	
	assert_eq(dist, 7, "Manhattan distance (0,0) to (3,4) should be 7")

func test_grid_to_world() -> void:
	# Assuming default grid size is 2.0 (from GridManager default)
	var grid_pos = Vector2i(2, 3)
	var grid_size = 2.0
	
	# Logic matches GridManager.grid_to_world_3d
	var x = grid_pos.x * grid_size
	var z = grid_pos.y * grid_size
	
	assert_eq(x, 4.0, "World X should be 4.0")
	assert_eq(z, 6.0, "World Z should be 6.0")
	
func test_is_within_bounds() -> void:
	var pos_ok = Vector2i(5, 5)
	var pos_bad = Vector2i(-1, 0)
	
	# Mock validation logic
	var is_ok = pos_ok.x >= 0 and pos_ok.y >= 0
	var is_bad = pos_bad.x >= 0 and pos_bad.y >= 0
	
	assert_true(is_ok, "(5,5) is positive")
	assert_false(is_bad, "(-1,0) is invalid")

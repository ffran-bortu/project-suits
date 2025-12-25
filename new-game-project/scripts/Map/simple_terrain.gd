"""
FILE: simple_terrain.gd
PURPOSE: Creates test terrain with hills, mountains, platforms, valleys for GridManager visualization testing.
FUNCTIONS: _ready, create_test_terrain - 2 total
NOTES: Sets GridManager heights: hills (1.5), mountain (2.5), platform (1.8), valleys (-0.8). Regenerates Grid3D visualization after terrain setup.
"""


extends Node3D

class_name SimpleTerrain

func _ready():
	create_test_terrain()

func create_test_terrain():
	var _grid_size = GridManager.grid_size
	
	# Create some hills (more visible height)
	var hills = [
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3),
		Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6),
		Vector2i(1, 6), Vector2i(1, 7)
	]
	
	for hill in hills:
		if GridManager.is_within_grid(hill):
			GridManager.set_height(hill, 1.5)  # Increased height for more visual impact
	
	# Create a mountain (very tall blocks)
	var mountain = [Vector2i(6, 1), Vector2i(7, 1), Vector2i(6, 2), Vector2i(7, 2)]
	for pos in mountain:
		if GridManager.is_within_grid(pos):
			GridManager.set_height(pos, 2.5)  # Increased height for more visual impact
	
	# Create elevated platform
	var platform = [Vector2i(4, 0), Vector2i(4, 1), Vector2i(3, 0), Vector2i(3, 1)]
	for pos in platform:
		if GridManager.is_within_grid(pos):
			GridManager.set_height(pos, 1.8)  # Increased height
	
	# Create some low valleys
	var valleys = [Vector2i(0, 4), Vector2i(0, 5)]
	for valley in valleys:
		if GridManager.is_within_grid(valley):
			GridManager.set_height(valley, -0.8)  # Deeper valley for more contrast
	
	# Regenerate grid visualization after terrain is set
	await get_tree().process_frame  # Wait one frame to ensure GridManager is ready
	if get_tree().get_root().has_node("Main/World/Grid/Grid3D"):
		var grid_3d = get_tree().get_root().get_node("Main/World/Grid/Grid3D")
		if grid_3d.has_method("regenerate_grid"):
			grid_3d.regenerate_grid()
		else:
			# If regenerate doesn't exist, clear and recreate
			grid_3d.clear_all()
			grid_3d.create_3d_grid()

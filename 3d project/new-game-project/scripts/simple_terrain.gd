# simple_terrain.gd - Create test terrain with elevation
extends Node3D

func _ready():
	create_test_terrain()

func create_test_terrain():
	var grid_size = GridManager.grid_size
	
	# Create some hills
	var hills = [
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3),
		Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6),
		Vector2i(1, 6), Vector2i(1, 7)
	]
	
	for hill in hills:
		if GridManager.is_within_grid(hill):
			GridManager.set_height(hill, 1.5)  # 1.5 units high
	
	# Create a mountain
	var mountain = [Vector2i(6, 1), Vector2i(7, 1), Vector2i(6, 2), Vector2i(7, 2)]
	for pos in mountain:
		if GridManager.is_within_grid(pos):
			GridManager.set_height(pos, 3.0)  # 3 units high
	
	# Create some low valleys
	var valleys = [Vector2i(0, 4), Vector2i(0, 5)]
	for valley in valleys:
		if GridManager.is_within_grid(valley):
			GridManager.set_height(valley, -0.5)  # Below sea level
	
	print("Test terrain created with elevation")
	
	# Update grid visualization if it exists
	if get_tree().get_root().has_node("Main/World/Grid/Grid3D"):
		var grid_3d = get_tree().get_root().get_node("Main/World/Grid/Grid3D")
		# Grid will update visually when units move



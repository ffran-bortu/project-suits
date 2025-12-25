"""
FILE: tactical_map_data.gd
PURPOSE: Simple 2.5D tactical map data resource - grid with integer height levels (like chess with elevation).

OVERVIEW:
Stores map metadata and a simple height array for tactical grid-based gameplay. Each cell (x,y) has a fixed
height value (0=flat, 1=hill, 2=mountain). This is the Fire Emblem approach - discrete, predictable, editable.

PUBLIC API:
- get_height(grid_x, grid_y) -> int: Returns height at grid position (0 if out of bounds)
- set_height(grid_x, grid_y, height): Sets height at grid position
- initialize_flat(width, height): Creates flat map of given dimensions

CONSTANTS:
- TILE_SIZE: 1.0 - Each tile is 1x1 world units (matches test_arena.tscn spacing)
- TILE_SURFACE_Y: 0.5 - Visual tiles positioned at Y=0.5 (matches test_arena.tscn)
- HEIGHT_STEP: 1.0 - Each height level = 1 unit up in world space

NOTES:
- Height map is 1D array indexed as: height_map[y * grid_width + x]
- Heights are integers for simplicity (0, 1, 2, ...)
- Use GameConfig or inspect test_arena.tscn for visual alignment
- Editable in Godot inspector as Resource
"""

class_name TacticalMapData
extends Resource

## Map metadata
@export var map_name: String = "Default Map"
@export var grid_width: int = 8
@export var grid_height: int = 8

## Height map - 1D array of integer heights
## Size should be grid_width * grid_height
## Index formula: y * grid_width + x
@export var height_map: Array[int] = []

# Visual constants (match test_arena.tscn)
const TILE_SIZE: float = 1.0       # Each tile is 1x1 world units
const TILE_SURFACE_Y: float = 0.5  # Tiles positioned at Y=0.5
const HEIGHT_STEP: float = 1.0     # Each height level = 1 unit up

## Get height at grid position
## @param grid_x: X coordinate (0 to grid_width-1)
## @param grid_y: Y coordinate (0 to grid_height-1)
## @return: Height value (0 if out of bounds)
func get_height(grid_x: int, grid_y: int) -> int:
	if grid_x < 0 or grid_x >= grid_width or grid_y < 0 or grid_y >= grid_height:
		return 0
	
	var index = grid_y * grid_width + grid_x
	if index >= 0 and index < height_map.size():
		return height_map[index]
	return 0

## Set height at grid position
## @param grid_x: X coordinate
## @param grid_y: Y coordinate  
## @param height: Height value to set
func set_height(grid_x: int, grid_y: int, height: int) -> void:
	if grid_x < 0 or grid_x >= grid_width or grid_y < 0 or grid_y >= grid_height:
		return
	
	var index = grid_y * grid_width + grid_x
	if index >= 0 and index < height_map.size():
		height_map[index] = height

## Initialize a flat map of given dimensions
## @param width: Grid width in cells
## @param height: Grid height in cells
func initialize_flat(width: int, height: int) -> void:
	grid_width = width
	grid_height = height
	height_map.clear()
	
	# Fill with zeros (flat ground)
	for i in range(width * height):
		height_map.append(0)

## Get total number of cells
func get_cell_count() -> int:
	return grid_width * grid_height

## Debug print map
func print_map() -> void:
	print("=== Map: ", map_name, " (", grid_width, "x", grid_height, ") ===")
	for y in range(grid_height):
		var row = ""
		for x in range(grid_width):
			row += str(get_height(x, y)) + " "
		print(row)

## GridManager - Handles 3D grid, pathfinding, and terrain
##
## This autoload manages the tactical grid including:
## - Grid-to-world coordinate conversion
## - Height-based terrain
## - AStar pathfinding with height restrictions
## - Movement range calculation
## - Attack range calculation
extends Node

## Grid dimensions in cells
var grid_size = Vector2i(8, 8)
## Size of each grid cell in 3D world units
var cell_size = Vector2(64, 64)

## Cached reference to UnitManager
var unit_manager: Node = null

## Tile system (NEW)
var tiles: Dictionary = {}  # grid_pos -> TacticsTile
var tiles_container: Node3D = null  # Parent node for all tiles
var tile_scene: PackedScene = null  # Tile scene to instantiate

# Constants
const CARDINAL_DIRECTIONS := [
	Vector2i(0, -1),  # Up (North)
	Vector2i(0, 1),   # Down (South)
	Vector2i(-1, 0),  # Left (West)
	Vector2i(1, 0)    # Right (East)
]

# 3D Terrain data
var height_map: Dictionary = {}
var height_unit_scale: float = 3.0
var max_climb_height: float = 1.0

# AStar2D instance for optimized pathfinding
var astar: AStar2D = AStar2D.new()
var _dirty_graph: bool = true

func _ready():
	# Create tiles container if it doesn't exist
	_setup_tiles_container()
	
	initialize_height_map()
	print("GridManager initialized: ", grid_size, " grid with cell size: ", cell_size)

## Setup the container node for all tiles
func _setup_tiles_container():
	if not tiles_container:
		# Try to find existing container in scene
		var world = get_tree().root.get_node_or_null("Main/World")
		if world:
			tiles_container = world.get_node_or_null("Tiles")
			if not tiles_container:
				# Create new container
				tiles_container = Node3D.new()
				tiles_container.name = "Tiles"
				world.add_child(tiles_container)
				print("GridManager: Created tiles container")

## Check if grid position is within valid bounds.
## @param grid_pos: Grid position to check
## @return: true if position is within grid, false otherwise
func is_within_grid(grid_pos: Vector2i) -> bool:
	return (grid_pos.x >= 0 and grid_pos.x < grid_size.x and 
			grid_pos.y >= 0 and grid_pos.y < grid_size.y)

## Convert grid position to 3D world position with height.
## Centers the position within the cell and applies terrain height.
## @param grid_pos: Grid coordinates (x, y)
## @return: 3D world position (Vector3) with height applied
func grid_to_world_3d(grid_pos: Vector2i) -> Vector3:
	if not is_within_grid(grid_pos):
		return Vector3.ZERO
	
	var height = get_height(grid_pos) * height_unit_scale
	return Vector3(
		grid_pos.x * cell_size.x + cell_size.x * 0.5,  # Center in cell
		height,                                         # Y is up (height)
		grid_pos.y * cell_size.y + cell_size.y * 0.5   # Z is forward/depth
	)

# Convert 3D world → 2D grid (ignore height)
func world_to_grid_3d(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int((world_pos.x - cell_size.x * 0.5) / cell_size.x),
		int((world_pos.z - cell_size.y * 0.5) / cell_size.y)
	)

# === HEIGHT MAP ===
func initialize_height_map():
	height_map.clear()
	for x in grid_size.x:
		for y in grid_size.y:
			var pos = Vector2i(x, y)
			height_map[pos] = 0.0  # Flat terrain by default
	
	# Generate tiles after height map is initialized
	generate_tiles()
	
	# Rebuild AStar graph
	_rebuild_astar_graph()

## Generate tile instances for the entire grid
##
## Creates a TacticsTile instance for each grid position and sets up
## their positions, heights, and other properties.
func generate_tiles():
	if not tiles_container:
		push_error("GridManager: Cannot generate tiles - no container!")
		return
	
	# Clear existing tiles
	for tile in tiles.values():
		if tile:
			tile.queue_free()
	tiles.clear()
	
	print("GridManager: Generating ", grid_size.x * grid_size.y, " tiles...")
	
	# Create tiles for each grid position
	for x in grid_size.x:
		for y in grid_size.y:
			var grid_pos = Vector2i(x, y)
			var tile = _create_tile(grid_pos)
			if tile:
				tiles[grid_pos] = tile
	
	print("GridManager: Generated ", tiles.size(), " tiles")

## Create a single tile instance
##
## @param grid_pos: Grid position for this tile
## @return: Created TacticsTile instance
func _create_tile(grid_pos: Vector2i) -> TacticsTile:
	# Create new tile instance
	var tile = Node3D.new()
	tile.name = "Tile_%d_%d" % [grid_pos.x, grid_pos.y]
	
	# Add TacticsTile script
	var script = load("res://scripts/Core/tactics_tile.gd")
	if script:
		tile.set_script(script)
	else:
		push_error("GridManager: Could not load tactics_tile.gd script!")
		return null
	
	# Set up CollisionShape for selection
	var collision_shape = CollisionShape3D.new()
	var box_shape = BoxShape3D.new()
	box_shape.size = Vector3(cell_size.x * 0.9, 0.5, cell_size.y * 0.9)
	collision_shape.shape = box_shape
	tile.add_child(collision_shape)
	collision_shape.position = Vector3(0, 0.25, 0)
	
	# Create visual mesh (hidden by default)
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "TileMesh"
	var quad_mesh = QuadMesh.new()
	quad_mesh.size = Vector2(cell_size.x * 0.95, cell_size.y * 0.95)
	mesh_instance.mesh = quad_mesh
	mesh_instance.rotation_degrees.x = -90
	mesh_instance.position.y = 0.01
	mesh_instance.visible = false
	tile.add_child(mesh_instance)
	
	# Add raycasting container
	var raycast_container = Node3D.new()
	raycast_container.name = "RayCasting"
	tile.add_child(raycast_container)
	
	# Create neighbor detection raycasts
	var neighbors_container = Node3D.new()
	neighbors_container.name = "Neighbors"
	raycast_container.add_child(neighbors_container)
	
	# 4 cardinal directions for neighbor detection
	var directions = [
		Vector3(cell_size.x, 0, 0),      # Right
		Vector3(-cell_size.x, 0, 0),     # Left
		Vector3(0, 0, cell_size.y),      # Down
		Vector3(0, 0, -cell_size.y)      # Up
	]
	
	for dir in directions:
		var ray = RayCast3D.new()
		ray.target_position = dir
		ray.enabled = true
		ray.collision_mask = 1  # Default layer
		neighbors_container.add_child(ray)
	
	# Create upward raycast for occupancy detection
	var above_ray = RayCast3D.new()
	above_ray.name = "Above"
	above_ray.target_position = Vector3(0, 10, 0)  # Ray upward
	above_ray.enabled = true
	above_ray.collision_mask = 2  # Units layer
	raycast_container.add_child(above_ray)
	
	# Set position and height
	var world_pos = grid_to_world_3d(grid_pos)
	var height = get_height(grid_pos)
	
	tile.global_position = world_pos
	tile.grid_pos = grid_pos
	tile.height = height
	
	# Add to scene
	tiles_container.add_child(tile)
	
	return tile

## Get tile at grid position
##
## @param grid_pos: Grid coordinates
## @return: TacticsTile at that position, or null
func get_tile_at(grid_pos: Vector2i) -> TacticsTile:
	if not is_within_grid(grid_pos):
		return null
	return tiles.get(grid_pos, null)

## Get all tiles in the grid
##
## @return: Array of all TacticsTile instances
func get_all_tiles() -> Array[TacticsTile]:
	var result: Array[TacticsTile] = []
	for tile in tiles.values():
		if tile:
			result.append(tile)
	return result

## Reset all tile markers (for pathfinding)
func reset_all_tile_markers():
	for tile in tiles.values():
		if tile and tile.has_method("reset_markers"):
			tile.reset_markers()

## Get the terrain height at a grid position
##
## @param grid_pos: Grid coordinates to query
## @return: Height value (0.0 if not set)
func get_height(grid_pos: Vector2i) -> float:
	return height_map.get(grid_pos, 0.0)

## Set the terrain height at a grid position
##
## @param grid_pos: Grid coordinates to set
## @param height: Height value to assign
func set_height(grid_pos: Vector2i, height: float):
	if is_within_grid(grid_pos):
		height_map[grid_pos] = height
		_dirty_graph = true

## Check if a unit can traverse between two heights
##
## Units can only climb or descend by max_climb height units per step.
## This prevents unrealistic jumps (e.g., from height 1 to height 3).
##
## @param from: Starting grid position
## @param to: Target grid position
## @param max_climb: Maximum height difference allowed (default: max_climb_height)
## @return: true if traversable, false otherwise
func can_traverse_height(from: Vector2i, to: Vector2i, max_climb: float = -1.0) -> bool:
	if max_climb < 0:
		max_climb = max_climb_height
	
	var from_height = get_height(from)
	var to_height = get_height(to)
	var height_diff = to_height - from_height
	
	# Restrict movement: Can only climb/descend by 1 height level
	# Allow going up only if difference <= max_climb (1.0)
	# Allow going down only if difference >= -max_climb (-1.0)
	# This means you can't jump from height 1 to 3 directly
	return abs(height_diff) <= max_climb

# === ASTAR GRAPH ===
# Helper to convert grid pos to unique ID
func _get_point_id(pos: Vector2i) -> int:
	return pos.y * grid_size.x + pos.x

func _rebuild_astar_graph():
	astar.clear()
	astar.reserve_space(grid_size.x * grid_size.y)
	
	# 1. Add all points first
	for x in grid_size.x:
		for y in grid_size.y:
			var pos = Vector2i(x, y)
			var id = _get_point_id(pos)
			# Weight defaults to 1.0. Could use terrain cost here.
			astar.add_point(id, Vector2(pos.x, pos.y))
	
	# 2. Add connections (Edges)
	for x in grid_size.x:
		for y in grid_size.y:
			var current = Vector2i(x, y)
			var current_id = _get_point_id(current)
			
			for dir in CARDINAL_DIRECTIONS:
				var neighbor = current + dir
				if not is_within_grid(neighbor):
					continue
				
				# Check if we can move FROM current TO neighbor
				if can_traverse_height(current, neighbor):
					var neighbor_id = _get_point_id(neighbor)
					# One-way connection allowed?
					# AStar2D connects points. connect_points(a, b, bidirectional=true)
					# For asymmetric, we must use bidirectional=false
					astar.connect_points(current_id, neighbor_id, false)
	
	_dirty_graph = false

## Get all cells reachable from start position within movement range.
## Accounts for terrain height, enemy unit blocking, and movement cost.
## @param start_pos: Starting grid position
## @param movement_range: Maximum movement cost allowed
## @param unit: (Optional) Unit to check for enemy blocking
## @return: Array of Vector2i positions reachable within range
func get_movement_range(start_pos: Vector2i, movement_range: int, unit = null) -> Array:
	if _dirty_graph:
		_rebuild_astar_graph()
		
	# AStar graph handles terrain structure, but for "Reachable Area" BFS is often correctly fine or we can use AStar flood fill.
	# Getting reachable cells is distinct from finding a single path.
	# We can use a simplified BFS on the AStar graph or just keep the BFS logic since it works well for ranges.
	# NOTE: We must respect dynamic unit blocking. AStar graph is static terrain.
	
	var reachable_cells = []
	var visited = {start_pos: 0}
	var queue = [start_pos]
	
	while queue.size() > 0:
		var current = queue.pop_front()
		var current_cost = visited[current]
		
		for dir in CARDINAL_DIRECTIONS:
			var next = current + dir
			if not is_within_grid(next): continue
			
			# Unit Blocking Check (Dynamic)
			if unit and is_cell_blocked_by_enemy(next, unit):
				continue
			
			# Height Check (Using logic or AStar graph check)
			# Since we have the graph, we can check if connection exists
			var curr_id = _get_point_id(current)
			var next_id = _get_point_id(next)
			if not astar.are_points_connected(curr_id, next_id):
				continue
				
			var next_cost = current_cost + 1 # + terrain cost if implemented
			
			if next_cost <= movement_range and not visited.has(next):
				visited[next] = next_cost
				queue.append(next)
				if next != start_pos:
					reachable_cells.append(next)
	
	return reachable_cells

## Calculate pathfinding from start to target using AStar2D.
## Temporarily disables enemy unit positions to avoid pathing through them.
## @param start_pos: Starting grid position
## @param target_pos: Target grid position
## @param unit: (Optional) Unit to check for enemy blocking
## @return: Array of Vector2i positions from start to target (includes start position)
func get_grid_path(start_pos: Vector2i, target_pos: Vector2i, unit = null) -> Array:
	if _dirty_graph:
		_rebuild_astar_graph()
		
	if not is_within_grid(start_pos) or not is_within_grid(target_pos):
		return []
		
	# For unit blocking, we might need to temporarily disable points?
	# Or implement a custom AStar pass. 
	# Godot's AStar won't respect "Enemy Unit" unless we disable the point.
	# Optimize: Disable points occupied by enemies, compute path, re-enable.
	
	var disabled_points = []
	if unit and unit_manager:
		var all_units = unit_manager.units
		for other_unit in all_units:
			if other_unit != unit and other_unit.is_alive() and other_unit.team != unit.team:
				var uid = _get_point_id(other_unit.grid_position)
				if astar.has_point(uid) and not astar.is_point_disabled(uid):
					astar.set_point_disabled(uid, true)
					disabled_points.append(uid)
	
	var start_id = _get_point_id(start_pos)
	var end_id = _get_point_id(target_pos)
	
	# Godot AStar path
	var path_2d = astar.get_point_path(start_id, end_id)
	
	# Cleanup: Re-enable points
	for uid in disabled_points:
		astar.set_point_disabled(uid, false)
	
	# Convert PackedVector2Array to Array[Vector2i]
	var path_cells = []
	for p in path_2d:
		path_cells.append(Vector2i(int(p.x), int(p.y)))
	
	return path_cells

func is_cell_blocked_by_enemy(grid_pos: Vector2i, moving_unit) -> bool:
	if not unit_manager:
		return false
	var unit_at_pos = unit_manager.get_unit_at_position(grid_pos)
	if unit_at_pos and unit_at_pos != moving_unit:
		return unit_at_pos.team != moving_unit.team
	return false

## Get all cells within attack range from unit position.
## Uses Manhattan distance (diamond pattern).
## @param unit_pos: Unit's current grid position
## @param max_range: Maximum attack range
## @param min_range: Minimum attack range (default 1 for melee)
## @return: Array of Vector2i positions within attack range
func get_attack_range(unit_pos: Vector2i, max_range: int, min_range: int = 1) -> Array:
	var attack_cells = []
	
	# Diamond pattern for Manhattan movement
	for x in range(-max_range, max_range + 1):
		for y in range(-max_range, max_range + 1):
			var distance = abs(x) + abs(y)
			if min_range <= distance and distance <= max_range:
				var cell_pos = unit_pos + Vector2i(x, y)
				if is_within_grid(cell_pos):
					attack_cells.append(cell_pos)
	
	return attack_cells

# === UNIT SCALING HELPER ===
func get_unit_scale() -> Vector3:
	# Returns recommended scale for units based on grid size
	# Adjust this based on your actual unit model size
	# Current: 2.5x scale for visibility
	return Vector3(2.5, 2.5, 2.5)

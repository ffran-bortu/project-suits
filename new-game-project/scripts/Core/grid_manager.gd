"""
FILE: grid_manager.gd
PURPOSE: Autoload managing 3D tactical grid, tile-based pathfinding, terrain height, and movement/attack range calculation.

OVERVIEW:
This critical autoload manages the entire tactical grid system including coordinate conversion (grid ↔ world 3D),
height-based terrain with climb restrictions, tile generation with visual/collision components, A* pathfinding with
enemy/terrain awareness, BFS movement range calculation with cost penalties for climbing, and attack range diamond
patterns. Uses TacticsTile instances for each grid cell with neighbor caching and pathfinding state. Integrates with
UnitManager for occupancy checks and provides all spatial queries for battle systems.

FUNCTIONS IN THIS FILE:

1. initialize()
   - What it does: Manual init called by Main - sets up tiles container, generates all tiles, builds AStar graph
   - Uses: Called by Main scene after scene tree ready
   - Returns: void

2. is_within_grid(grid_pos)
   - What it does: Validates grid position is within bounds (0 to grid_size)
   - Uses: For all grid operations to prevent out-of-bounds errors
   - Returns: bool

3. grid_to_world_3d(grid_pos)
   - What it does: Converts grid coordinates to 3D world position with height (centers in cell)
   - Uses: For placing units, camera positioning, visual effects
   - Returns: Vector3

4. world_to_grid_3d(world_pos)
   - What it does: Converts 3D world position to grid coordinates (ignores height)
   - Uses: For mouse click detection, world position queries
   - Returns: Vector2i

5. initialize_height_map()
   - What it does: Calls generate_tiles() then rebuilds AStar graph
   - Uses: During initialization
   - Returns: void

6. generate_tiles()
   - What it does: Creates TacticsTile instance for each grid position with mesh, collision, raycasts
   - Uses: During initialization to populate grid
   - Returns: void

7. get_tile_at(grid_pos)
   - What it does: Returns TacticsTile instance at position from tiles dictionary
   - Uses: For tile queries throughout codebase
   - Returns: TacticsTile or null

8. get_all_tiles()
   - What it does: Returns array of all TacticsTile instances in grid
   - Uses: For iteration, display updates, global operations
   - Returns: Array[TacticsTile]

9. reset_all_tile_markers()
   - What it does: Resets pathfinding state (pf_distance, pf_root) on all tiles
   - Uses: Before each pathfinding operation
   - Returns: void

10. get_height(grid_pos)
    - What it does: Returns terrain height at position from tile
    - Uses: For height checks, visual positioning
    - Returns: float

11. set_height(grid_pos, height)
    - What it does: Sets terrain height and updates tile world position
    - Uses: For dynamic terrain modification
    - Returns: void

12. can_traverse_height(from, to, max_climb)
    - What it does: Checks if height difference allows traversal (default max_climb=1.0)
    - Uses: For pathfinding neighbor validation
    - Returns: bool

13. get_movement_cost_with_height(from, to)
    - What it does: Returns movement cost (1 base, +1 gentle climb, +2 steep climb)
    - Uses: For pathfinding cost calculation
    - Returns: int

14. get_movement_range(start_pos, movement_range, unit)
    - What it does: BFS calculation of all reachable cells within movement cost, respects height/enemies
    - Uses: For highlighting movement area when unit selected
    - Returns: Array[Vector2i]

15. get_grid_path(start_pos, target_pos, unit)
    - What it does: A* pathfinding from start to target avoiding enemies, respecting height
    - Uses: For unit movement execution, path preview
    - Returns: Array[Vector2i] (path including start)

16. get_attack_range(unit_pos, max_range, min_range)
    - What it does: Returns diamond pattern of cells within Manhattan distance range
    - Uses: For attack targeting, highlighting attack area
    - Returns: Array[Vector2i]

17. is_cell_blocked_by_enemy(grid_pos, moving_unit)
    - What it does: Checks if cell occupied by enemy unit via UnitManager
    - Uses: During pathfinding to avoid enemies
    - Returns: bool

18. _create_tile(grid_pos) [private]
    - What it does: Creates single StaticBody3D tile with collision, mesh, raycasts, adds to scene
    - Uses: Called by generate_tiles() for each grid position
    - Returns: TacticsTile (or null on failure)

19. _rebuild_astar_graph() [private]
    - What it does: Rebuilds AStar2D graph with height-aware connections (DEPRECATED - tile-based pathfinding preferred)
    - Uses: For backward compatibility, not actively used
    - Returns: void

20. _heuristic(from, to) [private]
    - What it does: Manhattan distance for A* heuristic
    - Uses: During A* pathfinding
    - Returns: int

21. _get_lowest_f_score(open_set, f_scores) [private]
    - What it does: Finds tile with lowest f_score in open set for A*
    - Uses: During A* pathfinding
    - Returns: TacticsTile

22. _reconstruct_path(came_from, current) [private]
    - What it does: Traces back through came_from dict to build final path
    - Uses: After A* reaches target
    - Returns: Array[Vector2i]

NOTES:
- Autoload singleton (always available as GridManager)
- Grid size: 8x8 default, cell size 64x64 world units
- Height scale: height_unit_scale=3.0 (height 1.0 = 3 units up)
- Max climb: 1.0 height level per move (prevents unrealistic jumps)
- Tile structure: StaticBody3D with BoxShape3D collision, QuadMesh visual, RayCast3D for neighbors/occupancy
- Pathfinding: Tile-based A* with Manhattan heuristic, respects height+enemies+cost
- Movement range: BFS with cost accumulation (climbing costs more)
- Attack range: Diamond pattern (Manhattan distance), no pathfinding
- Dirty flag pattern: _dirty_graph marks when AStar needs rebuild
- Dependencies: UnitManager (for enemy checks), TacticsTile script
- Critical for: Unit movement, AI positioning, combat targeting, spatial queries
"""

## GridManager - Handles 3D grid, pathfinding, and terrain
##
## This autoload manages the tactical grid including:
## - Grid-to-world coordinate conversion
## - Height-based terrain
## - AStar pathfinding with height restrictions
## - Movement range calculation
## - Attack range calculation
extends Node

## Current tactical map data
var current_map: TacticalMapData = null

## Grid dimensions in cells (loaded from map or default)
var grid_size = Vector2i(8, 8)
## Size of each grid cell in 3D world units
var cell_size = Vector2(1, 1)

## Cached reference to UnitManager
var unit_manager: Node = null


## Tile system - Used for pathfinding and state management
## Dictionary maps Vector2i grid positions to TacticsTile instances
var tiles: Dictionary[Vector2i, TacticsTile] = {}
var tiles_container: Node3D = null  # Parent node for all tiles
var tile_scene: PackedScene = null  # Tile scene to instantiate (currently unused - tiles created programmatically)

# Preload script for strict typing checks
const TACTICS_TILE_SCRIPT = preload("res://scripts/Core/tactics_tile.gd")

# Constants
const CARDINAL_DIRECTIONS := [
	Vector2i(0, -1),  # Up (North)
	Vector2i(0, 1),   # Down (South)
	Vector2i(-1, 0),  # Left (West)
	Vector2i(1, 0)    # Right (East)
]

# 3D Terrain data
# DEPRECATED: height_map removed - use tiles[pos].height instead
var height_unit_scale: float = 1.0
var max_climb_height: float = 1.0

# DEPRECATED: Old AStar2D system - kept for backward compatibility
# New pathfinding uses tile-based algorithm (see get_movement_range and get_grid_path)
var astar: AStar2D = AStar2D.new()
var _dirty_graph: bool = true

func _ready():
	print("=== GridManager._ready() CALLED (autoload) ===")
	# As an autoload, we initialize when explicitly called by the battle scene
	# Don't auto-initialize here since Main scene doesn't exist yet
	
	# Set default constants from TacticalMapData if available
	if TacticalMapData:
		cell_size = Vector2(TacticalMapData.TILE_SIZE, TacticalMapData.TILE_SIZE)
		height_unit_scale = TacticalMapData.HEIGHT_STEP

## Load tactical map data
## @param map_resource: TacticalMapData resource to load
func load_map(map_resource: TacticalMapData) -> void:
	if not map_resource:
		push_error("GridManager.load_map() called with null resource!")
		return
	
	current_map = map_resource
	grid_size = Vector2i(map_resource.grid_width, map_resource.grid_height)
	
	# Update cell size from constants
	cell_size = Vector2(TacticalMapData.TILE_SIZE, TacticalMapData.TILE_SIZE)
	height_unit_scale = TacticalMapData.HEIGHT_STEP
	
	print("GridManager: Loaded map '%s' (%dx%d)" % [map_resource.map_name, grid_size.x, grid_size.y])

## Manual initialization - called by Main scene when battle starts
## This ensures the scene tree is fully ready before we create tiles
func initialize():
	print("=== GridManager.initialize() CALLED ===")
	
	# Find the Main node (should exist now)
	var main_node = get_tree().root.get_node_or_null("Main")
	print("GridManager: main_node = %s" % main_node)
	
	if not main_node:
		push_error("GridManager.initialize() called but Main node not found!")
		return
	
	# Create tiles container if it doesn't exist
	_setup_tiles_container()
	print("GridManager: After _setup_tiles_container, tiles_container = %s" % tiles_container)
	
	# Only initialize if we have a container
	if tiles_container:
		print("GridManager: Calling initialize_height_map()...")
		initialize_height_map()
		print("GridManager initialized: ", grid_size, " grid with cell size: ", cell_size)
		print("GridManager: tiles dictionary now has %d entries" % tiles.size())
	else:
		push_error("GridManager: No tiles container found!")

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
##
## *** UNIT POSITIONING LAYER 1 of 3: WORLD SPACE ***
## This provides the BASE world position for gameplay (physics, pathfinding).
## Units are positioned at TILE_SURFACE_Y + terrain_height.
##
## Additional layers:
## - Layer 2: unit.gd adds GameConfig.unit.ground_offset (gameplay tweaks)
## - Layer 3: visual_component.gd sets sprite.offset.y (visual alignment)
##
## @param grid_pos: Grid coordinates (x, y)
## @return: 3D world position (Vector3) with height applied
func grid_to_world_3d(grid_pos: Vector2i) -> Vector3:
	if not is_within_grid(grid_pos):
		return Vector3.ZERO
	
	# Get height from map or fallback
	var logical_height = get_height(grid_pos)
	var world_y = TacticalMapData.TILE_SURFACE_Y + (logical_height * height_unit_scale)
	
	var result = Vector3(
		grid_pos.x * cell_size.x + cell_size.x * 0.5,  # Center in cell (X)
		world_y,                                        # Y is up (surface + height)
		grid_pos.y * cell_size.y + cell_size.y * 0.5   # Z is forward/depth
	)
	
	print("GridManager.grid_to_world_3d: (%d,%d) h=%d → World (%.2f, %.2f, %.2f)" % [
		grid_pos.x, grid_pos.y, logical_height, result.x, result.y, result.z
	])
	
	return result

# Convert 3D world → 2D grid (ignore height)
func world_to_grid_3d(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int((world_pos.x - cell_size.x * 0.5) / cell_size.x),
		int((world_pos.z - cell_size.y * 0.5) / cell_size.y)
	)

# Height data storage (GridPos -> float)
var height_data: Dictionary = {}

# === HEIGHT INITIALIZATION ===
func initialize_height_map():
	# Scan for terrain height
	# scan_grid_heights() # Disabled per user request (overkill)
	print("GridManager: Terrain scan disabled. Using flat grid.")
	
	# Generate tiles based on scanned height
	generate_tiles()
	
	# Rebuild AStar graph
	_rebuild_astar_graph()

## Scan the scene for collision logic to determine terrain height
func scan_grid_heights() -> void:
	print("GridManager: Scanning terrain heights...")
	height_data.clear()
	
	var space_state = get_tree().root.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.new()
	query.collision_mask = 1 | 3 # Default and Terrain layers (adjust as needed)
	
	var hit_count = 0
	
	for x in grid_size.x:
		for y in grid_size.y:
			var grid_pos = Vector2i(x, y)
			
			# Calculate rough XZ center for raycast
			# We can't use grid_to_world_3d because it uses height_data!
			# But grid_to_world_3d only uses height for Y. X and Z are pure grid math.
			# Let's duplicate the XZ math here to avoid circular dep or issues.
			var world_x = x * cell_size.x + cell_size.x * 0.5
			var world_z = y * cell_size.y + cell_size.y * 0.5
			
			var from = Vector3(world_x, 20.0, world_z) # High up
			var to = Vector3(world_x, -10.0, world_z) # Down
			
			query.from = from
			query.to = to
			
			var result = space_state.intersect_ray(query)
			if result:
				var hit_y = result.position.y
				# Convert world Y to integer height units roughly?
				# Or just store exact height?
				# Grid usually expects quantized height if using steps (0, 1, 2).
				# But let's store raw for now or quantize?
				# If we quantize: round(hit_y / height_unit_scale)
				# Given height_unit_scale is now 1.0, this is easy.
				
				# Let's snap to nearest 0.5 or 0.25 to avoid float errors? 
				# Better: align to height_unit_scale steps.
				var height_units = hit_y / height_unit_scale
				height_data[grid_pos] = height_units
				hit_count += 1
				# print("Hit at %s: Y=%.2f -> H=%.2f" % [grid_pos, hit_y, height_units])
			else:
				height_data[grid_pos] = 0.0 # Default
				
	print("GridManager: Scanned %d terrain points." % hit_count)
	if hit_count == 0:
		push_warning("GridManager: No terrain collision found! Defaulting to flat grid.")

## Generate tile instances for the entire grid
##
## Creates a TacticsTile instance for each grid position and sets up
## their positions, heights, and other properties.
func generate_tiles():
	print("GridManager.generate_tiles: Starting, tiles_container=%s" % tiles_container)
	
	if not tiles_container:
		push_warning("GridManager: No tiles container - skipping tile generation")
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
			else:
				print("GridManager: WARNING - Failed to create tile at %s" % grid_pos)
	
	print("GridManager: Generated ", tiles.size(), " tiles (expected %d)" % (grid_size.x * grid_size.y))

## Create a single tile instance
##
## @param grid_pos: Grid position for this tile
## @return: Created TacticsTile instance, or null on failure
func _create_tile(grid_pos: Vector2i) -> TacticsTile:
	# Create new StaticBody3D for the tile
	var tile = StaticBody3D.new()
	tile.name = "Tile_%d_%d" % [grid_pos.x, grid_pos.y]
	
	# Add TacticsTile script
	tile.set_script(TACTICS_TILE_SCRIPT)
	
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
	
	# Add to scene first (required for global_position to work)
	tiles_container.add_child(tile)
	
	# Set position and height after adding to tree
	var world_pos = grid_to_world_3d(grid_pos)
	var height = get_height(grid_pos)
	
	tile.global_position = world_pos
	tile.grid_pos = grid_pos
	tile.height = height
	
	return tile

## Get tile at grid position
##
## @param grid_pos: Grid coordinates
## @return: TacticsTile at that position, or null if not found or out of bounds
func get_tile_at(grid_pos: Vector2i) -> TacticsTile:
	if not is_within_grid(grid_pos):
		return null
	var tile = tiles.get(grid_pos, null)
	if tile and not tile is TacticsTile:
		push_error("GridManager: Invalid tile type at position ", grid_pos)
		return null
	return tile

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
## @return: Height value (0.0 if tile not found)
func get_height(grid_pos: Vector2i) -> float:
	# Priority: 1) Map data, 2) Tile instance, 3) height_data fallback, 4) Zero
	var height: float = 0.0
	var source = "default"
	
	if current_map:
		height = float(current_map.get_height(grid_pos.x, grid_pos.y))
		source = "map_data"
	elif tiles.has(grid_pos) and tiles[grid_pos]:
		height = tiles[grid_pos].height
		source = "tile"
	elif height_data.has(grid_pos):
		height = height_data[grid_pos]
		source = "height_data"
	
	print("  get_height(%d,%d) = %.2f [%s]" % [grid_pos.x, grid_pos.y, height, source])
	return height

## Set the terrain height at a grid position
##
## @param grid_pos: Grid coordinates to set
## @param height: Height value to assign
func set_height(grid_pos: Vector2i, height: float):
	if is_within_grid(grid_pos):
		var tile = get_tile_at(grid_pos)
		if tile:
			tile.height = height
			# Update tile's world position to reflect new height
			var world_pos = grid_to_world_3d(grid_pos)
			tile.global_position = world_pos
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

## Calculate movement cost between two adjacent grid positions
##
## Takes into account height differences - climbing costs more movement.
##
## @param from: Starting grid position
## @param to: Target grid position
## @return: Movement cost (1 base, +1 for gentle climb, +2 for steep climb)
func get_movement_cost_with_height(from: Vector2i, to: Vector2i) -> int:
	var from_height = get_height(from)
	var to_height = get_height(to)
	var height_diff = to_height - from_height
	
	# Base cost
	var cost = 1
	
	# Additional cost for climbing uphill
	if height_diff > 0.5:
		cost += 2  # Steep climb
	elif height_diff > 0.1:
		cost += 1  # Gentle climb
	# Downhill or flat has no additional cost
	
	return cost

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
## Uses tile-based pathfinding for better performance and cleaner code.
## @param start_pos: Starting grid position
## @param movement_range: Maximum movement cost allowed
## @param unit: (Optional) Unit to check for enemy blocking
## @return: Array of Vector2i positions reachable within range
func get_movement_range(start_pos: Vector2i, movement_range: int, unit: Node = null) -> Array[Vector2i]:
	# Use tile-based BFS for movement range calculation
	var start_tile = get_tile_at(start_pos)
	if not start_tile:
		push_warning("GridManager: No tile at start position ", start_pos)
		return []
	
	var reachable_cells: Array[Vector2i] = []
	var visited: Dictionary = {start_pos: 0}
	var queue: Array[TacticsTile] = [start_tile]
	
	# Reset pathfinding markers on all tiles
	reset_all_tile_markers()
	start_tile.pf_distance = 0
	
	while queue.size() > 0:
		var current_tile: TacticsTile = queue.pop_front()
		var current_cost = visited[current_tile.grid_pos]
		
		# Get neighbors using tile system
		var max_climb = unit.max_climb_height if unit and "max_climb_height" in unit else max_climb_height
		var neighbors = current_tile.get_neighbors(max_climb)
		
		for neighbor_tile in neighbors:
			var next_pos = neighbor_tile.grid_pos
			
			# Skip if already visited
			if visited.has(next_pos):
				continue
			
			# Unit blocking check (dynamic)
			if unit and is_cell_blocked_by_enemy(next_pos, unit):
				continue
			
			# Calculate movement cost (includes height traversal cost)
			var move_cost = get_movement_cost_with_height(current_tile.grid_pos, next_pos)
			var next_cost = current_cost + move_cost
			
			# Add to queue if within range
			if next_cost <= movement_range:
				visited[next_pos] = next_cost
				neighbor_tile.pf_distance = next_cost
				neighbor_tile.pf_root = current_tile
				queue.append(neighbor_tile)
				
				if next_pos != start_pos:
					reachable_cells.append(next_pos)
	
	return reachable_cells

## Calculate pathfinding from start to target using tile-based A* algorithm.
## Avoids enemy unit positions and respects height traversal limits.
## @param start_pos: Starting grid position
## @param target_pos: Target grid position
## @param unit: (Optional) Unit to check for enemy blocking and climb limits
## @return: Array of Vector2i positions from start to target (includes start position)
func get_grid_path(start_pos: Vector2i, target_pos: Vector2i, unit: Node = null) -> Array[Vector2i]:
	if not is_within_grid(start_pos) or not is_within_grid(target_pos):
		return []
	
	var start_tile = get_tile_at(start_pos)
	var target_tile = get_tile_at(target_pos)
	
	if not start_tile or not target_tile:
		push_warning("GridManager: Invalid tiles for pathfinding")
		return []
	
	# Reset pathfinding markers
	reset_all_tile_markers()
	
	# A* implementation using tiles
	var open_set: Array[TacticsTile] = [start_tile]
	var closed_set: Dictionary = {}
	var g_scores: Dictionary = {start_pos: 0}
	var f_scores: Dictionary = {start_pos: _heuristic(start_pos, target_pos)}
	var came_from: Dictionary = {}
	
	var max_climb = unit.max_climb_height if unit and "max_climb_height" in unit else max_climb_height
	
	while open_set.size() > 0:
		# Find tile with lowest f_score
		var current_tile: TacticsTile = _get_lowest_f_score(open_set, f_scores)
		var current_pos = current_tile.grid_pos
		
		# Reached target
		if current_pos == target_pos:
			return _reconstruct_path(came_from, current_pos)
		
		open_set.erase(current_tile)
		closed_set[current_pos] = true
		
		# Check neighbors
		var neighbors = current_tile.get_neighbors(max_climb)
		for neighbor_tile in neighbors:
			var neighbor_pos = neighbor_tile.grid_pos
			
			# Skip if in closed set
			if closed_set.has(neighbor_pos):
				continue
			
			# Skip if blocked by enemy
			if unit and is_cell_blocked_by_enemy(neighbor_pos, unit):
				continue
			
			# Calculate tentative g_score
			var move_cost = get_movement_cost_with_height(current_pos, neighbor_pos)
			var tentative_g = g_scores[current_pos] + move_cost
			
			# Add to open set if not already there
			if not open_set.has(neighbor_tile):
				open_set.append(neighbor_tile)
			elif tentative_g >= g_scores.get(neighbor_pos, INF):
				continue  # Not a better path
			
			# Best path so far
			came_from[neighbor_pos] = current_pos
			g_scores[neighbor_pos] = tentative_g
			f_scores[neighbor_pos] = tentative_g + _heuristic(neighbor_pos, target_pos)
	
	# No path found
	return []

## A* heuristic function (Manhattan distance)
## @param from: Starting position
## @param to: Target position
## @return: Estimated distance
func _heuristic(from: Vector2i, to: Vector2i) -> int:
	return abs(to.x - from.x) + abs(to.y - from.y)

## Get tile with lowest f_score from open set
## @param open_set: Array of tiles to check
## @param f_scores: Dictionary of f_scores
## @return: Tile with lowest f_score ("as TacticsTile" cast needed if strict typing issues persist)
func _get_lowest_f_score(open_set: Array[TacticsTile], f_scores: Dictionary) -> TacticsTile:
	var lowest_tile: TacticsTile = open_set[0]
	var lowest_score = f_scores.get(lowest_tile.grid_pos, INF)
	
	for tile in open_set:
		var score = f_scores.get(tile.grid_pos, INF)
		if score < lowest_score:
			lowest_score = score
			lowest_tile = tile
	
	return lowest_tile

## Reconstruct path from A* came_from dictionary
## @param came_from: Dictionary mapping positions to their predecessors
## @param current: Current (target) position
## @return: Array of Vector2i positions from start to target
func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	
	return path

func is_cell_blocked_by_enemy(grid_pos: Vector2i, moving_unit: Node) -> bool:
	if not unit_manager:
		print_debug("GridManager: UnitManager is null!")
		return false
	var unit_at_pos = unit_manager.get_unit_at_position(grid_pos)
	if unit_at_pos and unit_at_pos != moving_unit:
		var different_teams = unit_at_pos.team != moving_unit.team
		if different_teams:
			print("GridManager: Blocked at %s. Occupant: %s (Team %d) vs Mover: %s (Team %d)" % [
				grid_pos, unit_at_pos.unit_name, unit_at_pos.team, moving_unit.unit_name, moving_unit.team
			])
		return different_teams
	return false

## Get all cells within attack range from unit position.
## Uses Manhattan distance (diamond pattern).
## @param unit_pos: Unit's current grid position
## @param max_range: Maximum attack range
## @param min_range: Minimum attack range (default 1 for melee)
## @return: Array of Vector2i positions within attack range
func get_attack_range(unit_pos: Vector2i, max_range: int, min_range: int = 1) -> Array[Vector2i]:
	var attack_cells: Array[Vector2i] = []
	
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
	if GameConfig.visual.has("unit_scale"):
		return GameConfig.visual["unit_scale"]
	return Vector3(2.5, 2.5, 2.5)
